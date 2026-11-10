# Runbook: converting a standalone mongod to a single-member replica set

## Why this change is not symmetric

Converting a standalone `mongod` to a single-member replica set is cheap and
sounds alarming, which is the wrong way round. It is an in-place restart: the
standalone's data directory becomes the primary's data directory, the initiation
writes one configuration document, and nothing is copied or reloaded. Watched
once, the server's options line goes from carrying neither `replication` nor
`security.keyFile` to carrying both, against the same volume, with the document
count unchanged.

**The reversal is the dangerous half, and it fails in the opposite direction from
the one people expect.** The folklore is that `mongod` refuses to start as a
standalone until the `local` database is dropped. On 8.0.29 it does not refuse. It
starts, serves normally, keeps the data intact, and **silently stops running the
TTL collection monitor**. The only sign is startup warning 20547, whose operative
sentence is that the monitor will not start.

That was measured rather than read off the warning: with `ttlMonitorSleepSecs`
lowered to 1 and a document already 60 seconds past its `expireAfterSeconds`,
`serverStatus().metrics.ttl.passes` stayed at 0 across 20 seconds and the document
survived. After the reversal completed properly, the same probe reported 21 passes
and one deleted document.

So a rollback performed the obvious way **looks like it worked**. The server
answers, the application boots, the data is all there, and expiry has quietly
stopped. A refusal would have been safer. This is why the rollback below ends in a
check on the server rather than a check on the application, and why "the service is
up" is not evidence.

**The reversal also needs a privilege nobody plans for.** The `root` role cannot
remove the configuration document: `dropDatabase` on `local` and a delete on
`local.system.replset` both return `Unauthorized (13)`, with or without
`--replSet`. The working route grants `__system` temporarily and revokes it
afterwards. Whoever holds the window needs credentials that can grant roles, and
that is worth confirming before the window rather than discovering inside one.

**The exposure window is wider than the drop.** TTL expiry is off from the moment
the standalone starts until the final restart completes, not just while `local` is
being dropped.

## Why the member host name is the other thing to get right

`rs.initiate()` records the member's host name, and every client is redirected to
that name after the initial handshake, whatever it used as a seed. A deployment
whose clients reach the database by more than one name, a compose service name
from inside the project and a container name from a project attached to the same
network, has two candidates and `rs.initiate()` picks one for everybody.

The catastrophic version of this mistake cannot be made silently. `rs.initiate()`
**refuses outright** a member host it cannot map to itself, with
`No host described in new configuration ... maps to this node` and a non-zero exit,
at initiation time.

The version that reaches production is narrower: a member host that resolves for
the **server** and not for some **client**. That surfaces as
`MongoServerSelectionError: getaddrinfo ENOTFOUND <member-host>` after the
handshake has already succeeded, and **the error names the member host rather than
the seed**, which is why it reads as "the database is down" rather than as a
configuration error.

So the rule is not "initiate with a particular name". It is: initiate with a name
that resolves from every client network, and verify that before the window.

**Do not reach for `directConnection=true` when a connection fails.** On a
deliberately broken topology every check passes, writes included, with the driver
reporting `topology type=Single` while `hello().me` still points at the unreachable
host. It does not fix the misconfiguration. It stops the driver from looking, and
leaves the broken member host invisible until something else needs the topology.

## Before the window

Set the parameters once per session. Every command below reads them, and nothing
below hard-codes a value that belongs to one deployment:

```sh
export MONGO_CONTAINER=mongodb
export MONGO_DB=appdb
export MONGO_ROOT_USER=root
export MONGO_ROOT_PASSWORD='<from your secrets store>'
export RS_NAME=rs0
export RS_MEMBER_HOST="${MONGO_CONTAINER}:27017"
export KEYFILE_HOST=/etc/mongodb/keyfile
export KEYFILE_PATH=/etc/mongo-keyfile
export COMPOSE_DIR="$(pwd)/app"
export BACKUP_DIR="$(pwd)/dump"
mkdir -p "${BACKUP_DIR}"
```

Define one helper, so the steps stay readable rather than repeating six lines of
connection boilerplate:

```sh
msh() {
  docker exec -i "${MONGO_CONTAINER}" mongosh --quiet admin \
    -u "${MONGO_ROOT_USER}" -p "${MONGO_ROOT_PASSWORD}" \
    --authenticationDatabase admin "$@"
}
msh --eval 'print(db.hello().ok)'
```

If the database runs on a remote host, prefix each command with your usual remote
invocation rather than rewriting them; the helper is the only thing that needs to
change.

**Take a backup, and do not treat it as optional.** This is the first step that can
lose data. Dump the application database, verify the archive against a count taken
**before** the dump, and copy it somewhere that is not this host:

```sh
msh --eval "print(db.getSiblingDB('${MONGO_DB}').stats().objects)"

docker exec "${MONGO_CONTAINER}" mongodump \
  --username "${MONGO_ROOT_USER}" --password "${MONGO_ROOT_PASSWORD}" \
  --authenticationDatabase admin \
  --db "${MONGO_DB}" --gzip --archive=/dump/pre-conversion.archive.gz
```

`mongodump` prints `done dumping <namespace> (N documents)` per collection on
stderr. That is the count actually written into the archive, and comparing it
against the pre-dump count verifies the archive without waiting for a restore. Do
not read the progress bar's denominator for this: it comes from collection
metadata and drifts under writes.

**Record the running server version, and pin it.** A floating image tag and a
version-sensitive restart do not belong in the same window. If the tag resolves to
something newer than what is running, the container recreate below becomes a
conversion **and** a server upgrade in one restart, which makes a rollback
inconclusive:

```sh
docker inspect "${MONGO_CONTAINER}" --format '{{.Config.Image}}  ->  {{.Image}}'
docker exec "${MONGO_CONTAINER}" mongod --version | head -1
```

Pin the exact patch that prints, in the compose file, before continuing. Moving to
a newer patch is a legitimate change and it belongs in its own window.

**Confirm the member host resolves from every client.** List every container that
holds a connection string, and check the name you are about to write into the
configuration from inside each one:

```sh
for c in ${CLIENT_CONTAINERS}; do
  printf '%-32s ' "${c}"
  docker exec "${c}" getent hosts "${RS_MEMBER_HOST%%:*}" || echo 'DOES NOT RESOLVE'
done
```

Every line must print an address, and it must be the same address. A missing line
here is the `getaddrinfo ENOTFOUND` failure above, found before the window instead
of during it.

**Read every client's connection string, live and on disk.** The value running in
the container and the value a restart would apply can differ, and if they have
drifted then restarting to pick up your edit applies something else as well:

```sh
for c in ${CLIENT_CONTAINERS}; do
  printf '%-32s ' "${c}"
  docker exec "${c}" sh -c 'echo "${MONGO_URL:-<unset>}"' |
    sed 's#://[^@]*@#://<redacted>@#'
done
```

Then read the env files or compose files that supply them and confirm they match.
Note whether each string already carries a query string, because that decides
whether the parameter you add later is introduced with `?` or appended with `&`.

**Establish whether anything depends on TTL indexes.** This decides what the
rollback's exposure window actually costs, and a deployment with none pays nothing
for it:

```sh
msh --eval "
  const d = db.getSiblingDB('${MONGO_DB}');
  let n = 0;
  for (const c of d.getCollectionNames()) {
    if (c.startsWith('system.')) continue;
    for (const i of d[c].getIndexes()) {
      if (i.expireAfterSeconds !== undefined) {
        print('TTL  ' + c + '.' + i.name + '  expireAfterSeconds=' + i.expireAfterSeconds);
        n++;
      }
    }
  }
  print('TTL indexes: ' + n);
"
```

Re-run it immediately before converting, not just once while planning. A deploy in
between can add one, and this is the fact the rollback's safety rests on.

**Confirm you can grant roles.** The rollback needs `__system`, and a user without
the authority to grant it cannot complete the reversal:

```sh
msh --eval "printjson(db.getUser('${MONGO_ROOT_USER}').roles)"
```

`root` on `admin` is sufficient, verified. A user scoped to one database is not.

**Capture the startup-warning baseline.** The rollback check asks whether warning
20547 is absent, and most servers already log several unrelated warnings. Without a
baseline they read as new damage:

```sh
msh --eval "
  for (const l of db.adminCommand({getLog: 'startupWarnings'}).log) {
    const e = JSON.parse(l);
    print(e.id + '  ' + (e.attr && e.attr.note ? e.attr.note : e.msg));
  }
" | tee "${BACKUP_DIR}/startup-warnings-before.txt"
```

Confirm 20547 is **not** in that list. If it is, the data directory has been
initiated before and this is not the situation this runbook describes.

**Install the keyfile, once.** Authorization plus replication requires internal
cluster authentication, so any deployment with a root user configured needs one. A
deployment with authorization disabled does not, and can skip this step entirely.

**Check before creating.** If a keyfile already exists and has been copied
anywhere, generating a new one silently invalidates that copy, and a keyfile that
differs by a byte fails at `rs.initiate()` rather than at creation:

```sh
sudo stat -c '%a  %U:%G  %n' "$(dirname "${KEYFILE_HOST}")" "${KEYFILE_HOST}" 2>/dev/null ||
  echo 'no keyfile yet, create it below'
```

Otherwise create it:

```sh
sudo install -d -m 700 -o root -g root "$(dirname "${KEYFILE_HOST}")"
sudo sh -c "umask 077 && openssl rand -base64 756 > '${KEYFILE_HOST}'"
sudo chown 999:999 "${KEYFILE_HOST}"
sudo chmod 400 "${KEYFILE_HOST}"
sudo ls -l "${KEYFILE_HOST}"
```

Mode `0400` owned by uid 999, which is `mongodb` inside the official image. A
bind-mounted file with host ownership and default permissions is rejected with a
permissions error that names neither the mount nor the fix.

**Expect `stat` to report an owner that is not `mongodb`, and do not correct it.**
The host resolves uid and gid 999 through its own passwd and group files, not the
image's, so the same correct file can print as `UNKNOWN:UNKNOWN`, or as some
unrelated system group that happens to sit at gid 999. One Debian host prints
`UNKNOWN:systemd-journal`. What matters is the numeric ownership and the mode:
`0400` at 999:999 is what `mongod` needs. Chowning it to a host user makes it
readable to that user and unreadable to the container.

**The expected size is 1024 bytes**, which is not an approximation.
`openssl rand -base64 756` emits 1008 base64 characters plus 16 line breaks.
MongoDB strips whitespace and accepts 6 to 1024 characters, so the significant
length is 1008 and sits just under the limit. That is why 756 appears in MongoDB's
own documentation rather than a rounder number, and it is why a keyfile that
arrives at some other size is worth investigating before use.

The `umask 077` matters: without it the redirect creates the file world-readable
for the instant before `chmod` runs. The enclosing directory can stay `root:root
0700`, because the Docker daemon does the traversal as root and the container only
ever sees the file itself.

**On a Lima-backed Docker, meaning Docker Desktop or Rancher Desktop on macOS, the
bind mount will not work.** Ownership and mode do not survive virtiofs: `chown`
fails with `Permission denied` and the file appears as `nobody:nobody` or
`root:root`. Use a named volume populated by a one-shot init container instead, as
`utils/keyfile.sh` does. On a Linux host the bind mount is correct.

Copy the keyfile somewhere off the host, handled as the credential it is. On a
single-member set it is not irreplaceable, since there is no peer to authenticate
against and a lost one can be regenerated, but the copy saves reading it back out
of a running server and it is the value every member must share if the set ever
gains a second one.

## Convert

1. **Edit the compose file.** Three things change in the database service and
   nothing else does: the image pin, two flags on the command, and one mount.

   ```yaml
   mongo:
     image: mongo:8.0.29 # the exact patch read back above, never a floating tag
     command: mongod --replSet rs0 --keyFile /etc/mongo-keyfile
     volumes:
       - mongo-data:/data/db
       - /etc/mongodb/keyfile:/etc/mongo-keyfile:ro
   ```

   Keep every other flag the service already passed to `mongod`, and keep the
   healthcheck as it is. **Leave the healthcheck alone in particular.** It
   typically runs `db.adminCommand('ping')` unauthenticated, which still works with
   authorization enabled, and it cannot be extended into an `rs.status()` check
   because that one needs credentials. The initiation belongs in step 3.

   A healthcheck asserting PRIMARY through `db.hello().isWritablePrimary`, which
   needs no credentials either, is a reasonable thing to want and **not a change
   to make inside this window**. It moves the condition under which every
   dependent service starts, while the point of this step is that one variable
   moves. Do it before or after, on its own.

   Confirm the file still parses before recreating anything:

   ```sh
   (cd "${COMPOSE_DIR}" && docker compose config --quiet && echo 'compose config OK')
   ```

2. **Recreate the database container only, without pulling.** `docker compose up -d`
   uses the local image when one is present, which is what is wanted here. Do not
   add `--pull` and do not run `docker compose pull` first, or the server version
   moves inside this window:

   ```sh
   (cd "${COMPOSE_DIR}" && docker compose up -d mongo)
   docker exec "${MONGO_CONTAINER}" mongod --version | head -1
   ```

   Confirm the version did not move before continuing.

3. **Initiate from outside, authenticated.** The official image strips `--replSet`
   and `--keyFile` from the temporary `mongod` that creates the root user, so the
   initiation cannot come from the entrypoint. It cannot come from the healthcheck
   either, because that runs unauthenticated. Guard it on `rs.status()` so a re-run
   is a no-op:

   ```sh
   docker exec -i "${MONGO_CONTAINER}" mongosh --quiet \
     "mongodb://${MONGO_ROOT_USER}:${MONGO_ROOT_PASSWORD}@localhost:27017/admin?directConnection=true" \
     --eval "
       try {
         print('already initiated as ' + rs.status().set);
       } catch (err) {
         if (err.code !== 94) { print('unexpected: ' + err.codeName); quit(1); }
         printjson(rs.initiate({
           _id: '${RS_NAME}',
           members: [{ _id: 0, host: '${RS_MEMBER_HOST}' }],
         }));
       }
     "
   ```

   `directConnection=true` is correct **here and only here**: the initiation talks
   to one server that is not yet a member of a set. Do not carry it into any
   client's connection string.

   `utils/rs-init.sh` in this directory is the same guard as a script, and works
   unchanged from a compose sidecar or a CI job step. Prefer one script over two
   spellings of the same logic.

4. **Confirm `PRIMARY`** before touching any client:

   ```sh
   msh --eval "
     const s = rs.status();
     print(s.set + '  ' + s.members.map(m => m.name + '=' + m.stateStr).join(', '));
     print('hello().me: ' + db.hello().me);
   "
   ```

   `hello().me` must read the value of `RS_MEMBER_HOST`. That is the name clients
   will be redirected to, and the pre-flight resolution check was for this value.

   Run before step 3, this command fails with
   `MongoServerError: not running with --replSet`, which is the correct answer on a
   standalone rather than a problem.

5. **Add the replica set to every client's connection string.** `replicaSet=<name>`
   introduced with `?` if the string has no query yet, appended with `&` if it
   does. Leave each client's host name exactly as it is: the seed only matters for
   the first handshake, and after it every client is redirected to
   `RS_MEMBER_HOST` regardless.

   Restart the clients one at a time, confirming each answers before starting the
   next, and restart anything downstream that a client restart is known to require.

6. **Enable change streams, or any other reactivity that needed a replica set, as
   its own restart** once the set has been up long enough to be boring. Two changes
   in one restart makes an inconclusive rollback.

## Confirm it worked

Each of these can fail, which is why they are listed separately rather than as
"check the application works":

- `rs.status()` reports one healthy `PRIMARY`, and `hello().me` is the value the
  pre-flight resolution check verified.
- Per-collection document counts match what the pre-window dump recorded.
- Every client connects, and a client that polls or subscribes still sees data.
- The application renders **with its console open and clean**. An `HTTP 200` is not
  evidence: a front end that throws on its first module still answers 200 and
  serves a correct server-rendered document.
- A document changed directly in `mongosh` reaches a subscribed client, if the
  deployment has any.

## Roll back

Only if the conversion has to be undone. Read "Why this change is not symmetric"
first if you have not.

1. **Record the document count** before touching anything, so the end state has a
   reference:

   ```sh
   msh --eval "print(db.getSiblingDB('${MONGO_DB}').stats().objects)"
   ```

2. **Stop the container and start the same data directory without `--replSet`.**
   This succeeds. Expect startup warning 20547, not a refusal. Removing the
   `--keyFile` flag at the same time is optional and makes no difference to the
   steps below.

3. **Grant `__system` temporarily.** The `root` role cannot remove the
   configuration document:

   ```sh
   msh --eval "
     db.getSiblingDB('admin').grantRolesToUser('${MONGO_ROOT_USER}', ['__system']);
     print('granted __system');
   "
   ```

4. **Drop `local`.** Now it succeeds:

   ```sh
   msh --eval "printjson(db.getSiblingDB('local').dropDatabase())"
   ```

5. **Revoke `__system` again.** Do not leave it granted:

   ```sh
   msh --eval "
     db.getSiblingDB('admin').revokeRolesFromUser('${MONGO_ROOT_USER}', ['__system']);
     print('revoked __system');
   "
   ```

6. **Restart, so the TTL monitor starts.** Until this completes, expiry is still
   off.

7. **Check the server, not the application.** This is the step that distinguishes a
   real rollback from one that looks like it worked:

   ```sh
   msh --eval "
     const w = db.adminCommand({getLog: 'startupWarnings'}).log
       .filter(l => JSON.parse(l).id === 20547);
     print('warning 20547 present:      ' + (w.length > 0) + '   (want false)');
     print('replset config doc present: ' +
       (db.getSiblingDB('local').system.replset.countDocuments({}) > 0) + '   (want false)');
     print('ttl passes:                 ' + db.serverStatus().metrics.ttl.passes);
     try { rs.status(); print('rs.status(): UNEXPECTED success on a standalone'); }
     catch (e) { print('rs.status():                ' + e.codeName + ' (' + e.code + ')   (want NoReplicationEnabled 76)'); }
   "
   ```

   Run it twice, **at least twice `ttlMonitorSleepSecs` apart**, and confirm
   `ttl passes` increases. The default is 60 seconds, so a shorter gap can show a
   static count on a perfectly healthy monitor. Compare the warning list against
   the baseline file captured before the window rather than against an empty
   expectation.

8. **Restore the clients.** Remove the `replicaSet` parameter, restart each, and
   confirm the document count matches step 1.

## Reference

### Parameters

Every value this runbook needs, declared in one place. The defaults are the ones
this directory's compose files use.

| Parameter             | Default                     | What it is                                            |
| --------------------- | --------------------------- | ----------------------------------------------------- |
| `MONGO_CONTAINER`     | `mongodb`                   | container running `mongod`                            |
| `MONGO_DB`            | `appdb`                     | application database, the one that gets dumped        |
| `MONGO_ROOT_USER`     | `root`                      | a user with `root` on `admin`                         |
| `MONGO_ROOT_PASSWORD` | none                        | from a secrets store, never from a document           |
| `RS_NAME`             | `rs0`                       | replica set name, written into the config             |
| `RS_MEMBER_HOST`      | `mongodb:27017`             | the name every client will be redirected to           |
| `RS_CONNECT_RETRIES`  | `60`                        | one-second attempts the initiator waits for an answer |
| `KEYFILE_HOST`        | `/etc/mongodb/keyfile`      | bind-mount source on the host                         |
| `KEYFILE_PATH`        | `/etc/mongo-keyfile`        | where the keyfile appears inside the container        |
| `COMPOSE_DIR`         | `./app`                     | directory holding the compose file                    |
| `BACKUP_DIR`          | `./dump`                    | archives and captured baselines                       |
| `CLIENT_CONTAINERS`   | none                        | space-separated list of containers holding a connection string |

`CLIENT_CONTAINERS` has no sensible default and enumerating it is part of the
work. A client missed here is a client that discovers the member host change on its
own schedule.

### What this assumes about the deployment

Check each one before starting. The procedure is wrong, not merely inconvenient, if
any is false.

| Assumption | If it is false |
| --- | --- |
| One `mongod`, no existing replica set | This is a different procedure; do not use this one |
| The data directory is a named volume or bind mount that survives a container recreate | The conversion loses the data it was supposed to keep |
| Authorization is enabled and a root user exists | The keyfile steps are unnecessary; skip them |
| The image tag is pinned, or is about to be | The recreate may change the server version silently |
| Clients read their connection string from the environment | Editing the environment will not reach them |
| The operator can grant roles | The rollback cannot be completed |

### Error texts and codes

| Situation | What the server says |
| --- | --- |
| `rs.status()` on a standalone | `NoReplicationEnabled (76) not running with --replSet` |
| `rs.status()` before initiation | `NotYetInitialized (94)` |
| Member host the server cannot map to itself | `No host described in new configuration ... maps to this node`, non-zero exit |
| Member host a client cannot resolve | `MongoServerSelectionError: getaddrinfo ENOTFOUND <member-host>` |
| Member host given as a bare IPv6 address | `More than one ':' detected. If this is an ipv6 address, it needs to be surrounded by '[' and ']'` |
| Standalone started on an initiated data directory | startup warning id 20547, server runs |
| Keyfile with wrong ownership or mode | permissions error naming neither the mount nor the fix |
| `stat` shows the keyfile owned by `UNKNOWN` or an unrelated group | Correct: the host has no user or group at 999, the container does |

Warning 20547 in full, because the last sentence is the finding:

```text
Document(s) exist in 'system.replset', but started without --replSet. Database
contents may appear inconsistent with the writes that were visible when this
node was running as part of a replica set. Restart with --replSet unless you are
doing maintenance and no other clients are connected. The TTL collection monitor
will not start because of this.
```

### What `root` cannot do

Measured with `mongod` running both with and without `--replSet`. The result was
the same in both cases.

| Attempt | Result as `root` |
| --- | --- |
| `db.getSiblingDB('local').dropDatabase()` | `Unauthorized (13) not authorized on local` |
| `local.system.replset.deleteMany({})` | `Unauthorized (13) not authorized on local` |
| `local.system.replset.drop()` | fails on retryable writes |

### Which configurations need a keyfile

The keyfile is required by **authorization**, not by replication.

| Configuration | Auth | Keyfile | Observed |
| --- | --- | --- | --- |
| Root user configured | yes | required | `security.keyFile` plus `authorization: enabled` |
| No users | no | not required | no `security` block at all; `rs.status()` answers unauthenticated |

That difference is why a test or CI configuration is genuinely less work than a
production one rather than a lighter version of the same work.

### TTL exposure, as measured

| Probe | Standalone on an initiated directory | After a completed reversal |
| --- | --- | --- |
| `metrics.ttl.passes` over 20 s | 0 | 21 |
| `metrics.ttl.deletedDocuments` | 0 | 1 |
| Document 60 s past `expireAfterSeconds` | survived | deleted |

Taken with `ttlMonitorSleepSecs` lowered to 1 so the effect was observable inside
an exercise. The default is 60, so the same behaviour appears on a sixty-second
clock and a sample taken seconds apart proves nothing either way.

### Failure modes, by symptom

The reason this table exists: most of these present as something other than what
they are.

| Symptom | Cause | What to do |
| --- | --- | --- |
| Clients fail after a successful handshake, error names a host nobody configured | The member host does not resolve from that client's network | Fix resolution, or re-initiate with a name every client resolves |
| `mongod` will not start after adding `--replSet` | Authorization is on and the keyfile is missing, unreadable, or too permissive | Mode `0400`, uid 999; read the container log for the real message |
| Initiation exits non-zero naming the configuration | The member host does not resolve from the **server** | Use a name the server can map to itself. In CI, where a service container does not resolve its own alias, use its IP address |
| A readiness or guard check fails while the command it runs prints the right answer | The client exits non-zero after succeeding. `mongosh 2.10.0` throws on its way out | Pin a working client version; 2.9.2 exits 0. Print the client's real error before concluding anything about the network |
| Every failure reports the same cause, and the cause does not fit the evidence | A wait loop is discarding the error it saw | Make the loop print DNS, `/etc/hosts`, a raw TCP probe and the client's error before it exits |
| Everything passes, including writes, but the topology looks wrong | `directConnection=true` is in the connection string | Remove it; it is hiding a real misconfiguration |
| Rollback appears to succeed, documents stop expiring | The configuration document is still in `local.system.replset` | Complete the reversal, then confirm warning 20547 is absent |
| `dropDatabase` on `local` returns `Unauthorized` as `root` | Expected; `root` is not sufficient | Grant `__system` temporarily |
| The server version changed during the window | A floating image tag plus a container recreate | Pin the patch, and treat the upgrade as its own window |

### Things that differ per deployment and must be measured, not assumed

- The running server patch level, and whether the image tag resolves to something
  else.
- Which containers hold a connection string, and whether each is a real client.
- Whether the live environment of a client matches the file a restart would apply.
- Whether any TTL index exists.
- Whether the host is Linux or Lima-backed, which decides bind mount against named
  volume for the keyfile.
- The set of startup warnings the server already logs.

### Provenance

Every measurement here comes from exercises in this directory, run against MongoDB
**8.0.29** with Node driver **6.16.0** on synthetic data, on Docker 29.5.3 on an
arm64 Linux VM. The exercise numbers and the raw output are in `README.md`.

The procedure is assembled from those exercises and has not been run end to end as
a procedure. Treat the command text as reviewed rather than proven, read the actual
output at each step, and expect to correct it on first real use. Behaviour measured
on 8.0.29 is very likely to hold across the 8.0 line and is not guaranteed to.

Credentials appear on the command line in several steps, which makes them visible
to other users on the host through the process list. That is acceptable on a
single-tenant host and is not acceptable on a shared one; move them into a
`--config` file if it matters.
