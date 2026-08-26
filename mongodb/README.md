# MongoDB: single-member replica set, and the Atlas end

A throwaway stack for the mechanical questions that come up when moving MongoDB
from a standalone `mongod` container to Atlas, via an intermediate step where
the existing container becomes a single-member replica set.

Those questions are mechanical rather than application-level: `mongod` flags,
keyfile ownership and mode, what `rs.initiate()` records as the member host,
what it takes to revert an initiated member, and what a managed cluster permits
a least-privilege user to do. Every one can be settled here, against synthetic
data, before a maintenance window opens on anything that matters.

Two things make this migration worth rehearsing rather than improvising. It
touches live data in place, on a data directory with no second copy unless
someone made one. And two of its steps are **asymmetric**: reverting an
initiated replica-set member is not the inverse of initiating it, and neither is
reverting a `featureCompatibilityVersion` bump. Asymmetric reversals are the
ones that have to be written down beforehand, because the window is the worst
possible place to discover them.

## Status

**Part 1 has been run end to end**, on Docker 29.5.3 (Rancher Desktop, Linux
containers on an arm64 Mac), against MongoDB **8.0.29** with driver **6.16.0**.
Every exercise below carries both what was expected and what was **observed**,
and the [findings table](#findings-table) records the result of each.

Three of the eight local exercises came back against expectation, and one of
them, [exercise 3](#exercise-3-reversal-to-standalone), inverts the received
wisdom about how a replica-set member reverts. Running the exercises also found
a defect in this repository's own probe, described at the end of exercise 6b.

**Part 2 has not been run.** It provisions billable resources on an external
service and needs Atlas credentials. Those rows read "not run", not "passed".

## The version is held, deliberately, and it is not the newest

Everything here runs at **8.0.29** throughout. The reasoning is worth having in
one place, because "run the newest" looks obviously right and is not:

- **8.0 is a fully supported Major line.** Per
  [endoflife.date/mongodb](https://endoflife.date/mongodb), 8.0 released
  2024-10-31 and is supported to 2029-10-31. 8.3 released 2026-05-31 and is
  supported to **the same date**. The gap between them is features, not support
  lifetime. 8.1 and 8.2 were Rapid releases, both EOL, and never supported
  off Atlas.
- **Atlas gives version control or the newest version, never both.** Per
  [MongoDB Versions in Atlas](https://www.mongodb.com/docs/atlas/atlas-versions/),
  Free and Flex clusters are pinned to 8.0 with Atlas controlling the upgrade,
  and 8.3 on a dedicated cluster is available only on the "Latest Version With
  Auto Upgrades" cadence, which surrenders the ability to hold any version at
  all. At 8.3 the cluster also forfeits Live Migration and mongosync, which are
  unsupported on minor versions.
- **The driver may cap its declared support lower than you expect.** Some
  frameworks bundle the MongoDB driver inside a core package as a transitive
  dependency that the application's own `package.json` cannot override, so the
  driver version is a property of the framework release. The driver pinned here,
  6.16.0, declares `MAX_SUPPORTED_WIRE_VERSION = 25`, which is server `8.0`
  exactly. Check what the real application resolves to before choosing a server
  version, not after.

At 8.0 the local server and a Flex cluster run the same version by construction,
the restore in exercise 13 is same-version, and there is no cross-version
behaviour to characterise. That is a lot of complexity avoided for nothing given
up.

What does still need fixing, everywhere, is the floating tag. `mongo:8.0` is a
range, not a version: it takes patch upgrades silently on any image pull, with
nothing in the diff to show it. Relevant to that, MongoBleed (CVE-2025-14847),
an unauthenticated out-of-bounds read, was fixed in 8.0.17. Everything here pins
an exact patch through a single `MONGO_TAG` variable, and holding a line is a
decision to take patches deliberately, not a decision to stop patching.

The version-upgrade research and the five exercises that test it are kept in
[appendix A](#appendix-a-the-version-upgrade-kept-and-unrun), unrun.

## Layout

```text
mongodb/
  README.md                    exercises, expected results, findings table
  .env.example                 committed; copy to app/.env
  .envrc.example               committed; copy to .envrc, which is ignored
  app/
    compose.yaml               single-member replica set, auth + keyfile, pinned tag
    compose.standalone.yaml    the "before" state, for the conversion exercise
    compose.noauth.yaml        the test and CI shape: replica set, no auth, no keyfile
  client/
    package.json               one dependency, pinned: mongodb@6.16.0
    probe.mjs                  topology, buildInfo, FCV, ping, oplog read, hello().me
    watch.mjs                  change stream; prints events and the resume token
  utils/
    keyfile.sh                 generate a keyfile into a named volume, 0400 uid 999
    rs-init.sh                 idempotent rs.initiate, guarded by rs.status()
    seed.sh                    synthetic documents
    revert-standalone.sh       revert an initiated member (needs a __system grant)
    fcv.sh                     read featureCompatibilityVersion (set, for appendix A)
  tf/
    disposable Atlas Flex cluster, project, two users, one access-list entry
```

## Prerequisites

- Docker with Compose v2. Rancher Desktop or Docker Desktop is fine; see the
  keyfile note below for what a Lima-backed Docker changes.
- Terraform, for part 2 only.
- An Atlas organization and either an API key pair or a service account, for
  part 2 only.

## Setup

```sh
cd mongodb
cp .env.example app/.env         # edit MONGO_ROOT_PASSWORD
cp .envrc.example .envrc         # if using direnv; .envrc is gitignored
```

The `utils/` scripts run on the host and read `MONGO_ROOT_USER` and
`MONGO_ROOT_PASSWORD` from the environment. Compose reads `app/.env`
automatically. Using `.envrc` covers both; using only `app/.env` means exporting
those two by hand before running a script.

Install the client's single dependency once:

```sh
cd app
docker compose run --rm client npm install
```

## Why the compose file looks the way it does

`app/compose.yaml` is close to an ordinary single-container MongoDB service:
root credentials from the environment, a bounded WiredTiger cache and a memory
cap, a named data volume, and a healthcheck with `start_interval` so a cold
start is not gated on the 30-second interval. Four things are deliberate on top
of that.

**The keyfile lives in a named volume, populated by an init container, not a
host bind mount.** This is a finding in its own right, and it means the
instruction differs between a Linux host and a Mac. Rancher Desktop and Docker
Desktop run containers on Linux, so the container side is faithful; the mount
side is not. A host path reaches the VM over virtiofs, where ownership and mode
do not survive: `chown` inside the container fails with `Permission denied`, and
files commonly appear as `nobody:nobody` or `root:root` with wide modes. A path
inside the VM's own filesystem behaves exactly as Linux does. See
[lima-vm/lima#231](https://github.com/lima-vm/lima/issues/231) and its Rancher
Desktop reports
[#1209](https://github.com/rancher-sandbox/rancher-desktop/issues/1209),
[#1679](https://github.com/rancher-sandbox/rancher-desktop/issues/1679) and
[#7924](https://github.com/rancher-sandbox/rancher-desktop/issues/7924), the
last specifically on VZ plus virtiofs.

**Both hostnames resolve, always.** The container answers to `mongo` (the
compose service name) and to `mongodb` (the container name). Two clients each
hardcoding a different one for the same server is an ordinary situation, and it
is what turns the member-host question in exercise 4 into something observable
rather than theoretical.

**The port publishes on `127.0.0.1:27018`,** so this stack cannot collide with
another mongod already listening locally.

**`MONGO_TAG` is pinned to an exact patch,** so a version finding names a
version.

### Why initiation comes from a one-shot container

The official image strips `--replSet` and `--keyFile` from the temporary
`mongod` that creates the root user. From the
[8.0 entrypoint](https://github.com/docker-library/mongo/blob/master/8.0/docker-entrypoint.sh):
`_mongod_hack_ensure_no_arg_val --keyFile` unconditionally, and the same for
`--replSet` when both `MONGO_INITDB_ROOT_USERNAME` and
`MONGO_INITDB_ROOT_PASSWORD` are set. It adds no `--transitionToAuth`.

So on a fresh volume the root user is created standalone, then the real `mongod`
starts with replication and auth already on, and `rs.initiate()` must come from
outside, authenticated. That is why a `mongo-init` one-shot is the right shape,
and it rules out the popular healthcheck-as-initiator pattern:
`db.adminCommand('ping')` needs no auth and works as-is, but `rs.status()` does.

`utils/rs-init.sh` uses `directConnection=true`, and it is the only thing here
that may. Before initiation there is no topology to discover. Application
clients must not use it: it suppresses exactly the topology awareness exercise 4
exists to exercise.

### The keyfile, and why it costs people an afternoon

`mongod` refuses to start with `--replSet` when authorization is enabled unless
internal cluster authentication is configured. Any stack that sets
`MONGO_INITDB_ROOT_USERNAME` therefore needs a keyfile the moment it gains
`--replSet`; a test stack with no auth does not. Generate it with
`openssl rand -base64 756`, mount it with mode `0400` owned by uid 999, the
`mongodb` user inside the image. A file with host ownership and default
permissions is rejected with a permissions error that names neither the mount
nor the fix, which is the whole problem.

The keyfile is a secret. Keep it out of the repository and out of the image, and
throw it away when a managed cluster takes over.

## Part 1: the local single-member replica set

### Exercise 1: fresh volume, and idempotent re-up

```sh
cd app
docker compose down -v
docker compose up -d
docker compose logs mongo-init
```

**Expected.** `keyfile-init` exits 0 having written a `0400` keyfile owned by
`999:999`. The `mongo` logs show the entrypoint creating the root user in a
temporary standalone `mongod`, then the real `mongod` starting with `--replSet`
and `--keyFile`. `mongo-init` initiates and reports `PRIMARY`.

**Observed.** Keyfile written on the first run, in the volume, correctly owned
without any `chown` fight:

```text
keyfile: generating /keyfile/mongodb-keyfile
-r-------- 1 mongodb mongodb 1024 /keyfile/mongodb-keyfile
```

1024 bytes rather than 756, because `openssl rand -base64 756` produces 1024
characters of base64.

The two-phase startup is visible in the `mongo` logs, and it is worth reading
the two "Options set by command line" lines side by side, because the difference
between them is the entrypoint behaviour the design depends on:

```text
# temporary mongod, the one that creates the root user
{"options":{"net":{"bindIp":"127.0.0.1", ...},
            "processManagement":{"fork":true,
              "pidFilePath":"/tmp/docker-entrypoint-temp-mongod.pid"}, ...}}

MongoDB init process complete; ready for start up.

# the real mongod
{"options":{"net":{"bindIp":"*"},
            "replication":{"replSet":"rs0"},
            "security":{"authorization":"enabled",
                        "keyFile":"/keyfile/mongodb-keyfile"}, ...}}
```

No `replication`, no `security`, no `--transitionToAuth` on the first. Both
appear only on the second. Between them, mongod logs `Did not find local replica
set configuration document at startup` with `NoMatchingDocument (47)`, which is
the pre-initiation state, and then `replSetInitiate admin command received from
client` once `mongo-init` connects.

Confirm the set:

```sh
docker exec -it mongodb mongosh \
  -u "${MONGO_ROOT_USER}" -p "${MONGO_ROOT_PASSWORD}" \
  --authenticationDatabase admin --eval 'rs.status()'
```

**Expected.** One member, `stateStr: "PRIMARY"`, `health: 1`.

**Observed.** `set=rs0  members=1`, `mongodb:27017  PRIMARY  health=1`.

Then idempotency, run twice, and an unaided restart:

```sh
docker compose up -d
docker compose up -d
docker compose logs mongo-init | tail -n 5
docker compose restart mongo
```

**Expected.** `mongo-init` exits 0 both times reporting "already initiated" and
does not re-initiate. `mongo` returns to `PRIMARY` on its own after the restart.

**Observed.** Confirmed, and the guard reports itself clearly:

```text
rs-init: already initiated as rs0, members: mongodb:27017=PRIMARY
rs-init: PRIMARY, hello().me = mongodb:27017
```

Exit 0 on every run, `RestartCount` 0. After `docker compose restart mongo`, the
member was back to `PRIMARY` within a second with no initiator involvement.

One incidental behaviour worth knowing so it is not mistaken for a fault: on a
third consecutive `up -d`, Compose may not restart the completed one-shot at
all. Force it with `docker compose up -d --force-recreate mongo-init` if the
point is to prove the guard rather than to reach a state.

Record what the floating tag resolves to versus the pin, and the `mongodump`
version the image ships:

```sh
docker run --rm mongo:8.0 mongod --version | head -n 1
docker exec mongodb mongod --version | head -n 1
docker exec mongodb mongodump --version | head -n 1
docker image inspect mongo:8.0 --format '{{index .RepoDigests 0}}'
docker image inspect mongo:8.0.29 --format '{{index .RepoDigests 0}}'
```

The tools version matters because it decides whether the backup step needs a new
image or a host package install, or neither.

**Observed.**

| Thing | Value |
| --- | --- |
| `mongo:8.0` (floating) | `db version v8.0.29` |
| `mongo:8.0.29` (pinned) | `db version v8.0.29` |
| Digest, both tags | `sha256:02a0cc7939f5ed38f30f9bc714ef5f682d49baf9350c54acf302ce833087fe8a` |
| `featureCompatibilityVersion` | `8.0` |
| Database Tools in the image | `mongodump` / `mongorestore` **100.18.0** |

**The two tags are the same image today.** So pinning is a no-op at the moment
it is applied: no recreate, no downtime, nothing to schedule. Its entire value
is protective, against the *next* pull. That is a useful thing to be able to say
when arguing for the change, and it is also why the pin should be applied while
the levels match rather than during an incident when they do not.

The tools being in the image means the dump and restore steps need no new image
and no host package install.

### Exercise 1b: the no-auth replica set, and the shape CI needs

A replica set with authorization disabled needs **no keyfile at all**. Internal
cluster authentication is only required when authorization is enabled, so a test
or CI stack with no root credentials gains `--replSet` for free. Getting this
wrong in either direction costs an afternoon: adding a keyfile here is pointless
ceremony, and omitting one from an authenticated stack is a refusal to start
whose error message names neither the mount nor the fix.

Worth running as its own exercise rather than assumed, because a migration
typically has to convert several stacks at once, and a pin or a flag applied to
some of them is a new inconsistency rather than a fix.

```sh
cd app
docker compose -f compose.noauth.yaml down -v
docker compose -f compose.noauth.yaml up -d
docker compose -f compose.noauth.yaml logs mongo-init
docker exec -it mongodb mongosh --quiet --eval 'rs.status().members'
```

**Expected.** No `keyfile-init` service runs, `mongod` starts with `--replSet`
and no `--keyFile`, `mongo-init` reports `(no auth)` and initiates, and
`rs.status()` needs no credentials. The data directory is a tmpfs, so this file
never touches the volume the other two share.

**Observed.** All of it. The startup options are the whole answer, and they are
short precisely because nothing extra is needed:

```text
{"options":{"net":{"bindIp":"*"},
            "replication":{"replSet":"rs0"},
            "systemLog":{"quiet":true}}}
```

No `security` block at all: no `keyFile`, no `authorization`. Compare that with
the authenticated stack in exercise 1, where both appear. The initiator logs
`(no auth)` and initiates normally, `rs.status()` answers with no credentials
and returns `set=rs0  mongodb:27017  PRIMARY`, and `df -h /data/db` inside the
container reports `tmpfs`, confirming the shared volume was untouched.

So the rule is confirmed in both directions: **the keyfile is required by
authorization, not by replication.** A test or CI stack that has no users needs
`--replSet` and nothing else.

**The CI variant.** A CI service container has no sidecar available and cannot
initiate itself, so the initiation moves into the job's `before_script` and runs
from the job container instead. Same script, same guard, different caller:

```sh
docker compose -f compose.noauth.yaml up -d mongo
docker compose -f compose.noauth.yaml run --rm --entrypoint bash mongo-init /utils/rs-init.sh
```

**Expected.** Identical result. Confirm it by running it a second time and
getting "already initiated", because in CI this command runs on every job.

**Observed.** Identical result, exit 0, in all three situations that matter: on
a set already initiated by the sidecar, on a genuinely fresh server with no
sidecar involved at all, and on a second call immediately after that one, which
reported `already initiated as rs0`. That last case is the one CI actually
exercises, since the command runs on every job.

### Exercise 2: in-place standalone to replica set conversion

The step that touches real data. The standalone's data becomes the primary's
data; nothing is copied.

```sh
cd app
docker compose down -v
docker compose -f compose.standalone.yaml up -d
cd ..
./utils/seed.sh 5000
```

**Expected.** `appdb.people` holds 5000 documents on a standalone `mongod` with
no `--replSet` and no keyfile.

**Observed.** `seed: appdb.people count = 5000`, on a `mongod` whose options are
`authorization: enabled` and nothing else — no `replication`, no `keyFile`.

Take the backup first, using the tools already in the image. **Take the source
count before the dump, not after**, so the comparison has a fixed reference:

```sh
mkdir -p dump
docker exec -it mongodb mongosh \
  -u "${MONGO_ROOT_USER}" -p "${MONGO_ROOT_PASSWORD}" \
  --authenticationDatabase admin appdb \
  --eval 'print(db.people.countDocuments({}))'

docker exec mongodb mongodump \
  --username "${MONGO_ROOT_USER}" --password "${MONGO_ROOT_PASSWORD}" \
  --authenticationDatabase admin \
  --db appdb --gzip --archive=/dump/appdb.archive.gz
ls -l dump/
```

**Observed.** An 87,590-byte archive, and this line on stderr:

```text
done dumping `appdb.people` (5000 documents)
```

**That line is a free verification of the archive's contents, and it is worth
knowing about.** `mongodump` emits two numbers per collection from different
sources: the progress bar's denominator is a fast estimate from collection
metadata, which drifts under writes and can be wrong by a few documents on large
collections; the trailing `done dumping` count is the number of documents
actually written into the archive. Compared against a count taken before the
dump, it verifies content per namespace **at dump time**, without waiting for a
restore. Since the restore is the expensive half, the alternative is discovering
a short dump only after paying for it, and in a cutover window that means
discovering it after the source has stopped taking writes.

Two conditions make the comparison exact: take the source count first, and stop
writers. A dump taken while writes are landing sees some of them and not others.

Note also that the archive lands on the `dump/` bind mount, not in the volume,
so it survives the `docker compose down -v` that later exercises begin with.

Then convert in place:

```sh
cd app
docker compose -f compose.standalone.yaml stop mongo
docker compose up -d
docker compose logs mongo-init
```

**Expected.** The same named volume, now served by a `mongod` with `--replSet`
and `--keyFile`, initiated on the existing data directory. The count is
unchanged and it is now the primary's data.

```sh
docker exec -it mongodb mongosh \
  -u "${MONGO_ROOT_USER}" -p "${MONGO_ROOT_PASSWORD}" \
  --authenticationDatabase admin appdb \
  --eval 'print(db.people.countDocuments({}))'
```

**Observed.** `rs: rs0 mongodb:27017 PRIMARY`, `appdb.people = 5000`. The
options line now carries `replication.replSet` and `security.keyFile` where a
moment earlier it carried neither, against the same `mongodb_mongo-data` volume.
Nothing was copied and nothing was reloaded; the initiation wrote a
configuration document and the existing data directory became the primary's.

This is the cheapest step in the whole migration and the one that sounds most
alarming. It is worth having watched once.

### Exercise 3: reversal to standalone

The first asymmetric reversal, and the exercise that most repays running rather
than reasoning about. The folklore is that `mongod` refuses to start as a
standalone until `local` is dropped. **On 8.0.29 it does not refuse**, and what
actually happens is worse than a refusal.

```sh
./utils/revert-standalone.sh attempt
```

**Observed, 8.0.29.** The server **starts and serves normally**. Data is intact,
`rs.status()` returns `NoReplicationEnabled (76) not running with --replSet`,
and the configuration document is still sitting in `local.system.replset`. The
only sign is startup warning id 20547:

```text
Document(s) exist in 'system.replset', but started without --replSet. Database
contents may appear inconsistent with the writes that were visible when this
node was running as part of a replica set. Restart with --replSet unless you are
doing maintenance and no other clients are connected. The TTL collection monitor
will not start because of this.
```

**That last sentence is the whole finding.** TTL indexes silently stop expiring
documents. Confirmed by measurement rather than by reading the warning: with
`ttlMonitorSleepSecs` lowered to 1 and a document already 60 seconds past its
`expireAfterSeconds`, `serverStatus().metrics.ttl.passes` stayed at **0** across
20 seconds, and the document was still there. After the reversal completes,
the same probe gives `passes = 21` and `deletedDocuments = 1`.

So the hazard is not that the reversal is blocked. It is that the reversal
**appears to succeed** while the server quietly stops doing one of its jobs. A
refusal would have been the safer behaviour.

Then the working sequence:

```sh
./utils/revert-standalone.sh revert
```

**The second surprise, which is what makes this a procedure rather than a
command.** The `root` role **cannot remove the configuration document**. Every
route is refused with `Unauthorized (13)`, whether `mongod` is running with
`--replSet` or without it:

| Attempt | Result as `root` |
| --- | --- |
| `db.getSiblingDB('local').dropDatabase()` | `Unauthorized (13) not authorized on local` |
| `local.system.replset.deleteMany({})` | `Unauthorized (13) not authorized on local` |
| `local.system.replset.drop()` | fails on retryable writes |

The working route is a deliberate, temporary privilege escalation, which the
script performs and then undoes:

1. Start standalone (this works, warning and all).
2. `grantRolesToUser(<admin user>, ["__system"])`.
3. `db.getSiblingDB('local').dropDatabase()` — now succeeds.
4. `revokeRolesFromUser(<admin user>, ["__system"])`.
5. Restart, so the TTL monitor starts.

**Expected after that.** Warning 20547 absent, `local.system.replset` empty,
data count unchanged, `rs.status()` erroring, and TTL expiry working again.

Two things for the runbook: the reversal needs a role grant nobody plans for,
and any deployment relying on TTL indexes is degraded from the moment the
standalone starts until step 5 completes.

### Exercise 4: the member-hostname trap

`rs.initiate()` records the member's host name, and every client is redirected
to that name after the initial handshake, whatever it used as a seed. So a
single-member set can be reachable under one name and unreachable under another,
even though both resolve to the same container, and the failure appears only
after the handshake succeeds.

The claim under test: initiate with the name every client can already resolve,
and no client's connection string needs to change.

Start from a set initiated as `mongodb:27017`, which is the default:

```sh
cd app
docker compose down -v
docker compose up -d
```

Probe with each seed in turn:

```sh
docker compose run --rm \
  -e MONGO_URI="mongodb://root:changeme@mongo:27017/appdb?replicaSet=rs0&authSource=admin" \
  client node probe.mjs

docker compose run --rm \
  -e MONGO_URI="mongodb://root:changeme@mongodb:27017/appdb?replicaSet=rs0&authSource=admin" \
  client node probe.mjs
```

**Observed.** Both work, and the redirect is plainly visible: seeded with
`mongo:27017`, the driver reports
`servers=[mongodb:27017=RSPrimary]` and `hello().me = mongodb:27017`. It
discarded the seed address and adopted the member host.

Now re-initiate the other way and repeat:

```sh
docker compose down -v
RS_MEMBER_HOST=mongo:27017 docker compose up -d
```

**Observed.** Both seeds still work, in both directions. **The member host name
is not, by itself, the trap** — not when every name involved resolves from every
client's network. Docker resolves a container's own name on every network it is
attached to, so `mongodb` is always reachable; only the compose aliases are
network-scoped.

Two experiments locate where the real risk is.

**First, `rs.initiate()` refuses a host it cannot map to itself.** Initiate with
a name that resolves nowhere:

```sh
docker compose down -v
RS_MEMBER_HOST=not-a-real-name:27017 docker compose up -d
docker logs mongodb-init
```

**Observed.** `MongoServerError: No host described in new configuration with
{version: 1, term: 0} for replica set rs0 maps to this node`, initiator exits 1.
Loud, immediate, at initiation time. So the catastrophic version of this
mistake cannot be made silently.

**Second, the failure that can actually reach production** needs the member host
to resolve for the *server* and not for some *client*. Reproduce it by giving a
client a network where only the container name resolves, and initiating on a
network-scoped alias:

```sh
docker compose down -v
RS_MEMBER_HOST=mongo:27017 docker compose up -d
docker network create probe-net
docker network connect probe-net mongodb        # no alias: only "mongodb" resolves here

docker run --rm --network probe-net -v "$PWD/../client:/client" -w /client \
  -e MONGO_URI="mongodb://root:changeme@mongodb:27017/appdb?replicaSet=rs0&authSource=admin&serverSelectionTimeoutMS=8000" \
  node:22-bookworm-slim node probe.mjs
```

**Observed.** `MongoServerSelectionError: getaddrinfo ENOTFOUND mongo`. The seed
resolved and the handshake succeeded; the redirect target did not resolve. Note
that **the error names the member host, not the seed** — which is the diagnostic
clue, and the reason this presents as "the database is down" rather than as a
configuration error.

Now the same broken topology with `directConnection=true`:

```sh
docker run --rm --network probe-net -v "$PWD/../client:/client" -w /client \
  -e MONGO_URI="mongodb://root:changeme@mongodb:27017/appdb?directConnection=true&authSource=admin&serverSelectionTimeoutMS=8000" \
  node:22-bookworm-slim node probe.mjs

docker network disconnect probe-net mongodb && docker network rm probe-net
```

**Observed.** Every check passes, writes included: `topology type=Single
setName=-`, while `hello().me` still reports the unreachable `mongo:27017`. The
parameter does not fix the misconfiguration, it stops the driver from ever
looking. Reach for it when a connection fails and the broken member host stays
broken and invisible until something else needs the topology.

**So the rule to carry forward** is not "initiate with a particular name". It is:
initiate with a name that resolves from **every** client network, and never use
`directConnection` to make a connection problem go away.

### Exercise 5: change streams, and the oplog

Change streams need a replica set; a standalone `mongod` cannot serve them at
all. This establishes the self-hosted baseline that part 2's Atlas answer is
measured against.

Return to the default member host, then in one terminal:

```sh
cd app
docker compose down -v
docker compose up -d
docker compose run --rm \
  -e MONGO_URI="mongodb://root:changeme@mongodb:27017/appdb?replicaSet=rs0&authSource=admin" \
  client node watch.mjs
```

In another:

```sh
docker exec -it mongodb mongosh \
  -u "${MONGO_ROOT_USER}" -p "${MONGO_ROOT_PASSWORD}" \
  --authenticationDatabase admin appdb \
  --eval 'db.people.insertOne({ name: "Change Stream Probe", seq: -1 })'
```

**Expected.** The insert surfaces in the watcher within a second, with a resume
token printed. Note the connection string carries `?replicaSet=rs0` and no
`directConnection`.

**Observed.** Well under a second, with the token:

```text
watch: #1 insert _id=6a8e6b5f828c135e95fcb727 clusterTime=7678192470479339522
       name=Change Stream Probe
       resumeToken={"_data":"826A8E6B5F000000022B042C0100296E5A1004AC5297F4...
```

Set `WATCH_EVENTS=1` to make the watcher exit after the first event, which is
what turns this into a scriptable check rather than something needing two
terminals.

Also read the oplog as root, which `probe.mjs` does as its last check. Oplog
tailing is the usual fallback when change streams are unavailable or too slow,
and it needs read access to `local`.

**Expected.** `local.oplog.rs` is readable and returns the latest operation.

**Observed, as root.** Readable: `latest op ts=7678191602895945730 op=i`. Note
the qualifier — exercise 6 shows this is a property of the user, not of the
deployment.

### Exercise 6: least-privilege users

Self-hosted answers for each check, so part 2 can report a difference rather
than an absolute.

```sh
docker exec -it mongodb mongosh \
  -u "${MONGO_ROOT_USER}" -p "${MONGO_ROOT_PASSWORD}" \
  --authenticationDatabase admin admin --eval '
    db.createUser({
      user: "app-user",
      pwd: "changeme",
      roles: [{ role: "readWrite", db: "appdb" }],
    })
  '

cd app
docker compose run --rm \
  -e MONGO_URI="mongodb://app-user:changeme@mongodb:27017/appdb?replicaSet=rs0&authSource=admin" \
  client node probe.mjs
```

**Expected, self-hosted.** Reads and writes on the application database succeed.
Record what happens to each of `admin().command({ ping: 1 })`, the change
stream, and the `local.oplog.rs` read. Those three rows are what exercises 12
and 15 compare against.

**Observed.** 9 of 11 checks pass. The full privilege matrix, which is the
baseline everything on the Atlas side is measured against:

| Check | `root` | `readWrite` on `appdb` only |
| --- | --- | --- |
| `admin.command({ping: 1})` | OK | **OK** |
| `buildInfo` | OK | OK |
| `getParameter` / FCV | OK | `Unauthorized (13)` on `admin` |
| read and write own database | OK | OK |
| change stream on own database | OK | OK |
| read `local.oplog.rs` | OK | **`Unauthorized (13)` on `local`** |

Two rows carry the weight.

**`ping` succeeds**, which retires a worry rather than confirming one. A
readiness probe built on `admin.command({ping: 1})` is not endangered by giving
the application a least-privilege user: `ping` requires no privilege. Whether a
managed cluster agrees is exercise 12, but the least-privilege split is not by
itself the thing that would break it.

**The oplog read fails, and it fails here, self-hosted.** This reframes the
question that usually gets asked about managed clusters. Oplog access is a
**privilege** question before it is a hosting question: a `readWrite`-only user
cannot read `local` on any deployment, and an oplog-tailing fallback has always
needed a user holding something like `clusterMonitor` or an explicit read on
`local`. So "the managed cluster took the oplog away" is the wrong framing. The
right question, and the one exercise 15 should be read as asking, is whether a
role granting `local` reads can be created at all on the target.

### Exercise 6b: the wrong database name, and what least privilege turns it into

A connection string with the wrong database name is a common configuration
error, and the usual worry is that it fails silently: MongoDB creates a database
on first write, so a wrong name does not error, it just reports an empty
collection and then quietly creates the database when something writes.

That worry is correct **only for a user with broad privileges**. For a user
scoped to one database, the same mistake is an authorization error on the first
operation. So the least-privilege split is not only an access-control measure,
it converts a silent misconfiguration into a loud one, and that is worth knowing
before choosing which user each client gets.

No new tooling: `probe.mjs` already takes `MONGO_DB`, and it reads, writes and
opens a change stream, which is enough to tell the two outcomes apart. Point it
at a database that does not exist, as each user in turn.

```sh
cd app

# broad privileges
docker compose run --rm -e MONGO_DB=wrongdb \
  -e MONGO_URI="mongodb://root:changeme@mongodb:27017/wrongdb?replicaSet=rs0&authSource=admin" \
  client node probe.mjs

# scoped to appdb only, from exercise 6
docker compose run --rm -e MONGO_DB=wrongdb \
  -e MONGO_URI="mongodb://app-user:changeme@mongodb:27017/wrongdb?replicaSet=rs0&authSource=admin" \
  client node probe.mjs
```

**Expected, as root.** The read returns `countDocuments = 0` and the **write
succeeds**, creating `wrongdb`. Nothing failed, and the misconfiguration is now
a real empty database. Confirm it exists afterwards with `show dbs`.

**Observed.** Exactly that. 11 of 11 checks pass, including the write, and
afterwards:

```text
admin    110592 bytes
appdb     16384 bytes
config    81920 bytes
local    315392 bytes
wrongdb    8192 bytes
```

A database that exists only because a typo was written to. Nothing in the client
reported a problem; it would report "no records found" indefinitely.

**Expected, as the scoped user.** An authorization error on the first operation
that touches `wrongdb`, naming the database. Loud, immediate, and diagnosable
from the message alone.

**Observed.** 4 of 11 checks fail, and the message names the database every
time:

```text
read wrongdb.people   FAIL  Unauthorized: not authorized on wrongdb to execute
                            command { aggregate: "people", ... $db: "wrongdb" }
write wrongdb.probe   FAIL  Unauthorized: not authorized on wrongdb to execute
                            command { insert: "probe", ... $db: "wrongdb" }
change stream         FAIL  Unauthorized: not authorized on wrongdb to execute
                            command { aggregate: "people",
                                      pipeline: [ { $changeStream: {} } ], ... }
```

**So the mitigation for this hazard is the least-privilege split itself.** Scope
each client to the database it is supposed to use, and a wrong database name
stops being a silent empty result and becomes an authorization error naming the
mistake. That is an argument for per-client users that is independent of access
control, and it is worth making when the split is being justified.

Repeat both against Atlas in part 2 and compare. The interesting question is
whether a managed cluster changes either answer; on this evidence what decides
the outcome is which user the client was given, not where the server is.

**One caveat about this exercise, and it is a general one.** The first run of it
reported the change stream as succeeding for the scoped user, which is
impossible. Constructing a change stream is lazy: `watch()` does not contact the
server, so a check that only opens one can pass without any round trip.
`probe.mjs` now calls `tryNext()` to force the aggregate to be issued. If you
adapt this harness, make sure every check actually reaches the server before you
record what it says.

## Part 2: the Atlas end

Exercise numbering skips 7 to 10 and 14. Those are the version-upgrade
exercises, kept in appendix A and deliberately unrun. The numbers stay where
they are so the findings table keeps referring to the same things.

`tf/` provisions a disposable Flex cluster. It uses
`mongodbatlas_advanced_cluster` with `provider_name = "FLEX"` rather than
`mongodbatlas_flex_cluster`, because the same resource type covers Flex, tenant
and dedicated, which is what makes exercise 17 a `plan` rather than a rewrite.
`mongo_db_major_version` is deliberately not set: Atlas pins it on Flex, and
setting it invites a perpetual diff.

**What Flex cannot answer.** 5 GB storage and 500 ops/sec, so no full-volume
rehearsal and no meaningful latency number. No configurable backup policy, so
backup retention cannot be tested here. No region or provider change. 8.0 only.
Record every Atlas finding **with its tier**, and flag the tier-sensitive ones
as needing re-verification on a dedicated cluster before anything depends on
them.

**Where the documentation contradicts itself.** The
[Flex limitations](https://www.mongodb.com/docs/atlas/reference/flex-limitations/)
page says Flex clusters do support change streams, restricted only in that
database-name filters must be strings or regexes rather than operators like
`$in`, and that read access to the oplog is the single carve-out from an
otherwise closed `local` database. The
[Triggers limitations](https://www.mongodb.com/docs/atlas/atlas-ui/triggers/limitations/)
page says Flex does not support change streams. It is also widely repeated that
Atlas denies `local` outright. Exercise 15 settles all three by driver
observation, which is the only way to settle a documentation conflict.

Before `apply`, confirm the ignore rules are in effect. `terraform.tfstate` will
contain the Atlas connection strings and the generated user passwords in
cleartext.

```sh
cd tf
git check-ignore -v terraform.tfstate
export TF_VAR_operator_ip="$(curl -s https://checkip.amazonaws.com)"
terraform init
terraform fmt -check
terraform validate
terraform plan
```

### Exercise 11: provision and connect

```sh
terraform apply
terraform output cluster
```

**Expected.** A Flex cluster reporting an 8.0.x version. Record the cluster's
actual `buildInfo.version` from `probe.mjs`, not the Terraform attribute, and
compare it to the local `MONGO_TAG`. The patch levels will differ, since Atlas
patches on its own schedule. **How far apart they drift is the useful finding**,
because that gap is what a "Major Version" cadence means in practice: a held
major line, and a patch level someone else chooses.

Then build the connection string wrong on purpose, carrying a `tls=false` over
from a local-development template:

```sh
cd ../app
docker compose run --rm \
  -e MONGO_URI="mongodb+srv://app-user:PASSWORD@CLUSTER.mongodb.net/appdb?tls=false" \
  client node probe.mjs
```

**Expected.** A failure. Record it verbatim. This is worth doing once, because
the real hazard is not the failure, it is the habit of deleting TLS parameters
until something connects, and then repeating it somewhere it succeeds.

Then run it correctly, with the URI from `terraform output -raw app_uri`, and
confirm `retryWrites` reports `true`. Against a replica set it defaults on, and
it is a small improvement in write safety that is better known than discovered.

### Exercise 12: does `ping` work for a least-privilege user?

A readiness probe that calls `admin().command({ ping: 1 })` is the usual choice,
because it is the cheapest round trip the driver offers. If that command is
refused for a least-privilege user, the health endpoint reports the database
unreachable while it is fine, which is the worst possible failure for a probe
sitting in front of a load balancer. Test it before the rehearsal, not after.

```sh
docker compose run --rm \
  -e MONGO_URI="$(cd ../tf && terraform output -raw app_uri)" \
  client node probe.mjs
```

Read the `admin ping (readiness probe)` row. **Flex closes `admin` to reads
generally**, so a failure here needs dedicated-tier re-verification before it is
treated as the answer.

### Exercise 13: does restore need `atlasAdmin`?

MongoDB documents that restoring into Atlas requires the Atlas admin role,
because Atlas offers no individual `restore` role or privilege action. That is
worth confirming, because a migration plan that assumes a least-privilege
operations user can run the restore has a hole in it exactly where the pressure
is highest.

Restore the exercise 2 archive twice, once as each user:

```sh
docker exec mongodb mongorestore \
  --uri="APP_URI" --gzip --archive=/dump/appdb.archive.gz --nsFrom='appdb.*' --nsTo='appdb.*'

docker exec mongodb mongorestore \
  --uri="OPS_URI" --gzip --archive=/dump/appdb.archive.gz --nsFrom='appdb.*' --nsTo='appdb.*'
```

Record which succeeded and on what error the other failed.

Constraints, all of which come from Atlas rather than from choice: dump and
restore the application database only, never `admin`, since Flex errors on
`--db admin` outright; and skip `--oplogReplay`, `--preserveUUID` and
`--restoreDbUsersAndRoles`, all unsupported here.

Then run a per-collection count comparison, and expect it to be less clean than
it sounds. Three asymmetries are normal and are not failures: a collection
declared by application code but never written to does not exist, because
MongoDB creates a collection on first write; `mongodump` excludes every
`system.` collection except `system.js`, so `system.profile` is never in an
archive and must be filtered out of **both** sides; and framework-owned
collections that no application code declares still hold real data and must
restore. Reconcile the list before the comparison, not during it.

Storage caps at 5 GB, so this proves mechanics on synthetic data, not on a real
dataset.

### Exercise 15: change streams and the oplog on Atlas

The documentation contradiction, settled by observation.

```sh
docker compose run --rm \
  -e MONGO_URI="$(cd ../tf && terraform output -raw app_uri)" \
  client node watch.mjs
```

Then read the `change stream` and `read local.oplog.rs` rows from `probe.mjs`
for **both** users.

**If oplog reads are permitted**, then an oplog URL is not categorically
unavailable on Atlas, and the fallback leg of the reactivity chain survives the
move. If they are not, the fallback is polling, and any plan that depends on
oplog tailing needs costing against the worse case. Tag the result Flex-only and
list dedicated-tier re-verification as a prerequisite either way.

### Exercise 16: the access list is the outage

Removing an access-list entry presents as a total outage with a clean-looking
application: nothing is misconfigured, no code changed, and every connection
fails. It is worth having seen once, in a stack where it costs nothing.

```sh
cd ../tf
terraform apply -var 'operator_ip=203.0.113.10'
```

Confirm the connection is now refused, record what the driver says, then restore
the real entry:

```sh
terraform apply
```

This is also the argument for keeping the access list in code rather than in a
click path. It is exactly the thing that has to change in lockstep with a host
move, and it is invisible in a diff if it lives in a console.

### Exercise 17: `terraform import`, and the Flex-to-dedicated question

Two cheap rehearsals.

First, adopting a cluster that already exists, which is the common case when
someone provisioned one through the UI before the Terraform was written:

```sh
terraform state rm mongodbatlas_advanced_cluster.this
terraform import mongodbatlas_advanced_cluster.this "PROJECT_ID/CLUSTER_NAME"
terraform plan
```

**Expected.** A clean plan after the import, or a diff that names exactly what
the configuration does not describe.

Second, the one-way-door question. The argument for deciding the tier up front
rests on Flex being irreversible; the provider changelog suggests Flex to
dedicated is an upgrade rather than a replacement. **Plan only, no apply:**

```sh
terraform plan -var 'provider_name=AWS' -var 'region_name=EU_CENTRAL_1'
```

Record whether the provider reports an in-place update or a replacement. Region
and provider changes remain impossible on Flex either way, which is the part of
that argument that does hold.

### Exercise 18: teardown

```sh
terraform destroy
```

Then confirm in the Atlas UI that the project and the cluster are gone. This is
carried as a discipline, not a footnote: Flex is cheap and usage-billed, but a
cluster left running is a recurring charge with nothing watching it.

### Exercise 19: the dedicated-tier re-verification, deferred

**Run this last, and only when the Flex answers are in.** It is the one step
here that costs real money, and it is worth it for exactly one reason: several
of the most important answers above are properties of the **tier**, not of
Atlas, and Flex cannot discriminate between "Atlas permits this" and "Flex
permits this".

The sharpest case is the oplog. Flex documents oplog reads as the single
carve-out from an otherwise closed `local` database. So a successful oplog read
in exercise 15 is consistent with a dedicated cluster permitting it **and** with
a dedicated cluster refusing it. A Flex result cannot settle the question, and
whether the oplog is readable decides whether an oplog-based fallback exists at
all after the move. The same tier ambiguity applies to exercise 12, since Flex
closes `admin` to reads generally, and to exercise 13's restore privilege.

The whole point of using `mongodbatlas_advanced_cluster` from the start is that
this costs a variable rather than a rewrite:

```sh
cd tf
terraform apply -var 'provider_name=AWS' -var 'region_name=EU_CENTRAL_1'
```

Then re-run **exercises 12, 13 and 15 only**, record each result against the new
tier, and destroy immediately:

```sh
terraform destroy
```

Bound the cost by treating it as a single sitting: provision, run the three
exercises, destroy. Do not leave it up overnight to finish tomorrow. Put the
teardown confirmation in the findings table like any other result, because an
undestroyed dedicated cluster is a standing charge that nothing will remind you
about.

## Findings table

The real output. One row per exercise. No empty cells: an exercise that could
not run on Flex is recorded as blocked with the reason, not left blank.

| #   | What the migration plan assumes | Observed | Version and tier | Amendment needed |
| --- | ------------------------------- | -------- | ---------------- | ---------------- |
| 1   | A one-shot initiator is idempotent; the entrypoint creates root standalone | Confirmed. Temp `mongod` runs with no `replSet`/`keyFile`/auth, then real one with all three. Initiator idempotent across 3 runs, exit 0; `restart` returns `PRIMARY` in ~1s unaided. `mongo:8.0` and `mongo:8.0.29` are the **same digest today**, so the pin costs no downtime now. Tools 100.18.0 | 8.0.29, self-hosted | No |
| 1b  | A replica set with no authorization needs no keyfile; CI initiates from outside | Confirmed. `--replSet` with no auth needs **no keyfile**: options show `replSet: rs0` and no `keyFile`/`authorization`. `rs.status()` works unauthenticated. Same script from a job container is idempotent, exit 0 | 8.0.29, self-hosted | No |
| 2   | A standalone converts in place; nothing is copied | Confirmed. 5,000 docs seeded on the standalone, dumped (87 KB gz), then served by the replica set on the same volume. Count unchanged, nothing copied. `done dumping (5000 documents)` matched the pre-dump count exactly | 8.0.29, self-hosted | No |
| 3   | Reverting needs `local` dropped first | **Wrong, and dangerously so.** `mongod` does **not** refuse: it starts and serves, with warning 20547. TTL monitor never starts (`ttl.passes` 0 over 20s at a 1s interval; 21 after the fix). `root` **cannot** drop `local` or the config doc: `Unauthorized (13)` on both, with or without `--replSet`. Needs a temporary `__system` grant | 8.0.29, self-hosted | **Yes** — the reversal is not blocked, it is silently degrading, and it needs a role grant |
| 4   | Initiate with the name every client resolves, and no client changes | Partly. Both names work in both directions here, so the name alone is not the trap. `rs.initiate()` **refuses** an unmappable host outright (initiator exits 1). Real failure needs a client-side resolution gap: reproduced as `MongoServerSelectionError: getaddrinfo ENOTFOUND mongo`, **naming the member host, not the seed**. `directConnection=true` passes 11/11 on that same broken topology | 8.0.29, self-hosted | Restate as *resolves from every client network*, not as a specific name |
| 5   | Change streams work on a single-member set; the oplog is readable | Confirmed. Insert surfaced in the change stream in well under a second with a resume token. `local.oplog.rs` readable **as root** | 8.0.29, self-hosted | No |
| 6   | A `readWrite`-only user can ping, watch and read the oplog | Mixed, and better than feared. `admin.command({ping:1})` **succeeds** for a `readWrite`-only user; so does `buildInfo`. `getParameter`/FCV is refused. Change stream on its own database succeeds. **Oplog read refused: `Unauthorized (13) not authorized on local`** | 8.0.29, self-hosted | **Yes** — oplog access is a *privilege* question, not an Atlas one; it already fails self-hosted |
| 6b  | A wrong database name fails silently | Confirmed, and the cause is privilege, not Atlas. As root: read 0, **write succeeds and creates the database** (`wrongdb`, 8,192 bytes). As the scoped user: `Unauthorized (13)` on read, write and change stream, naming the database | 8.0.29, self-hosted | Note that least privilege is itself the mitigation |
| 11  | The managed cluster answers 8.0.x; `tls=false` breaks the string | Not run | — | Blocked: needs an Atlas cluster |
| 12  | `ping` is permitted for the least-privilege application user | Not run | — | Blocked: needs an Atlas cluster |
| 13  | A least-privilege operations user can run the restore | Not run | — | Blocked: needs an Atlas cluster |
| 15  | Atlas denies `local` and therefore the oplog | Not run | — | Blocked: needs an Atlas cluster |
| 16  | Removing the access-list entry presents as a total outage | Not run | — | Blocked: needs an Atlas cluster |
| 17  | Flex to dedicated is a one-way door | Not run | — | Blocked: needs an Atlas cluster |
| 18  | Teardown leaves nothing billable | Not run | — | Blocked: needs an Atlas cluster |
| 19  | 12, 13 and 15 hold on a dedicated tier, not only on Flex | Not run | — | Blocked: needs an Atlas cluster |

### What part 1 actually changed

Three of the eight local rows came back against expectation, and two of those
change what a runbook has to say.

- **Reverting is not blocked, it is silently degrading (exercise 3).** The
  received wisdom, that `mongod` refuses to start until `local` is dropped, is
  false on 8.0.29. It starts, and the TTL collection monitor does not. Any
  procedure written on the assumption of a refusal will "succeed" and leave TTL
  expiry dead until someone notices. The reversal also needs a temporary
  `__system` grant, because `root` cannot touch `local.system.replset`. Both
  belong in the written procedure.
- **Oplog access is a privilege question, not an Atlas question (exercise 6).**
  A `readWrite`-only user is refused `local.oplog.rs` with `Unauthorized (13)`
  **on a self-hosted server**. So framing an oplog-based fallback as something a
  managed cluster takes away is wrong twice over: it is already unavailable to a
  least-privilege user anywhere, and the real question is whether a role that
  grants it can be created at all on the target. That reframes what exercise 15
  is asking.
- **The member host name is not itself the trap (exercise 4).** Where every name
  resolves, either choice works, and `rs.initiate()` refuses a host it cannot map
  to itself. The residual risk is narrower and more specific: a member host that
  resolves for the server and not for some client, which surfaces as a server
  selection error **naming the member host rather than the seed**.

Two rows confirmed comfortably, and are worth stating because they were flagged
as worst-case risks:

- **`ping` works for a least-privilege user** on a self-hosted server, so a
  readiness probe built on `admin.command({ping:1})` is not endangered by the
  least-privilege split as such. Whether Atlas agrees is exercise 12.
- **The patch pin costs nothing today.** `mongo:8.0` and `mongo:8.0.29` resolve
  to the same digest, so pinning is a no-op change now and purely protective of
  future pulls.

Still open, and all of them Atlas-side:

- **The claim that Atlas denies `local`** and therefore the oplog.
- **The assumption that a least-privilege user can run a restore.**
- **The tier decision's version axis**: Atlas grants version control or the
  newest version, not both, and the observed patch-level drift between a managed
  cluster and a local pin is still unmeasured.
- **The driver ceiling**, if the application's framework pins one. At 8.0 it
  costs nothing; it becomes a standing risk only on the appendix A path.

One correction to the harness itself, found by running it: `probe.mjs`'s change
stream check used to report success without contacting the server, because
constructing a change stream is lazy. It passed for a user with no privilege on
the database. It now calls `tryNext()` to force the aggregate, and that user
correctly fails. Any change-stream result gathered before that fix is worthless.

## Verification

The exercises are the tests. Beyond that:

- `docker compose config` clean on all three compose files at the pinned tag;
  `terraform fmt -check` and `terraform validate` clean in `tf/`.
- Every exercise runs from a documented cold start: `docker compose down -v`,
  then the commands above verbatim, with no undocumented step between. An
  exercise needing a step not written here is not finished.
- Exercise 1 re-run three times, to confirm idempotency is real rather than an
  artefact of ordering.
- Every version-sensitive result records `buildInfo.version` and FCV **as
  observed**, not as intended. A finding that names "8.x" is not a finding.
- `git status` clean of secrets before any commit: no keyfile, no `.envrc`, no
  `.tfvars`, no `terraform.tfstate`.

**Status of that list, as of the part 1 run.** All of it holds:
`markdownlint`, `shellcheck`, `node --check`, `yamllint` and
`docker compose config` (all three files, with and without the `client` profile)
are clean; `terraform fmt -check` and `terraform validate` are clean against the
real provider schema, though `plan` and `apply` have deliberately not been run.
Exercise 1's initiator was exercised three times plus an unaided restart. Every
version-sensitive row names `8.0.29` and FCV `8.0` as read back from the server.
Teardown left no containers, volumes or networks behind.

**One warning from the run, about the credential files rather than the code.**
`.env.example` is committed and `app/.env` is not, and it is easy to paste a
real password into the first. Before committing, confirm the template still
holds its placeholder:

```sh
grep '^MONGO_ROOT_PASSWORD=' .env.example    # must not be a real secret
git check-ignore -v app/.env .envrc
```

## Out of scope

- **The version upgrade.** Appendix A, deliberately unrun. It costs a second
  pinned tag, four exercises and a cross-version restore, and it buys nothing
  until Atlas or the application's driver changes.
- **The application half.** Verifying that a real app boots, renders and stays
  reactive against a replica set belongs with that app. What is isolated here is
  the driver, pinned to one exact version.
- **Latency measurement.** Flex caps throughput at 500 ops/sec and the data is
  synthetic, so any number would mislead.
- **Cloud backup policy, the "Major Version" cadence in practice, VPC peering and
  PrivateLink.** Flex has no configurable backup policy and no cadence to
  choose, so these exercises cannot test the settings themselves, only the 8.0
  server they land on. Dedicated-tier behaviour is not out of scope but is
  deferred: exercise 19 covers the three answers that are tier-sensitive, and
  nothing else.
- **8.1 and 8.2.** EOL, Atlas-only when they were current, and not a path to
  anything.

## Appendix A: the version upgrade, kept and unrun

These exercises were part 2 before the version decision settled on holding 8.0.
They are kept because the research behind them is real, and because what
displaced them is a trade against Atlas rather than a finding against 8.3.
Nothing here runs unless that decision is revisited.

Running any of it costs a second pinned tag, `8.3.8`, and the `utils/fcv.sh set`
path.

**A1 (was 7). Upgrade a standalone, 8.0.29 to 8.3.8.** The state a
single-container deployment is in *today*. Read FCV first (`8.0` expected),
`mongodump` first, stop, change `MONGO_TAG`, start, confirm
`buildInfo.version`, confirm the data and counts, then
`setFeatureCompatibilityVersion: "8.3", confirm: true` as a separate deliberate
step. Record whether anything needed doing between the two.

**A2 (was 8). Upgrade an initiated single-member replica set, 8.0.29 to 8.3.8.**
The state it is in *after exercise 2*. Follow the official 8.0-to-8.3 replica
set procedure adapted to one member: confirm `replSetGetStatus` shows no member
in `ROLLBACK` or `RECOVERING` and no initial sync in progress, confirm FCV
`8.0`, then swap the binary and re-check `PRIMARY`. Then the FCV bump. Record
elapsed time for each, and whether the member returns to `PRIMARY` without an
election stall.

**A3 (was 9). Downgrade 8.3.8 to 8.0.29, and the FCV trap.** The second
asymmetric reversal, and the reason the FCV bump is a separate step from the
binary swap. Deliberately do it wrong first: with FCV at `8.3`, start the 8.0.29
binary on that data directory and capture the refusal verbatim. Then do it
right: lower FCV to `8.0`, stop, start 8.0.29, confirm data intact. Same
treatment as exercise 3, and for the same reason: a written procedure before the
window rather than a discovery inside one. Also record whether the FCV
downgrade is instant or does work.

**A4 (was 10). Driver compatibility, and what the negotiation actually costs.**
Run `probe.mjs` and `watch.mjs` against 8.3.8 and record: the server's advertised
`minWireVersion` and `maxWireVersion` from `hello`, the wire version actually
negotiated (expected 25), whether any `MongoCompatibilityError` is raised, and
whether CRUD, a change stream and `ping` all work. Then re-run against 8.0.29
and diff, so the finding distinguishes "works identically" from "works with
degradation".

**A5 (was 14). The downward cross-version restore.** Take the archive dumped
from the local 8.3.8 server at FCV `8.3` in A2, restore it into the Flex 8.0
cluster, and record whether it succeeds, warns, or fails, and on what. This is
what happens if a server is upgraded before cutting over to a cluster that is
not dedicated on the auto-upgrade cadence, and it is the sharpest argument for
the version parity that holding 8.0 gets for free.

### Why the driver analysis says "connects" rather than "works"

A driver's declared ceiling is not enforced against newer servers. The gate in
`lib/cmap/connect.js` is asymmetric:

```js
const serverVersionHighEnough = maxWireVersion >= MIN_SUPPORTED_WIRE_VERSION; // server max >= 7
const serverVersionLowEnough = minWireVersion <= MAX_SUPPORTED_WIRE_VERSION; // server min <= 25
```

It rejects only when the server's *minimum* exceeds the driver's maximum, and
does not care that the server's maximum exceeds the driver's. Server 8.3
advertises maxWireVersion 28, and per
[`wire_version.h`](https://github.com/mongodb/mongo/blob/master/src/mongo/db/wire_version.h)
the minimum incoming wire version for *external* clients begins at
`RELEASE_2_4_AND_BEFORE`, which is 0; the FCV-derived `maxWireVersion - 1`
minimum in that header governs internal cluster clients, not application
drivers. And
[Compatibility Changes in MongoDB 8.3](https://www.mongodb.com/docs/manual/release-notes/8.3-compatibility/)
records no minWireVersion bump and no driver-support drop.

So the pairing is **unblocked but untested**: connecting at wire version 25,
outside MongoDB's published support matrix, with no 8.1, 8.2 or 8.3-gated driver
feature reachable. That is a worse position than "it works", because nothing
fails at the point where it could be caught cheaply. Driver 7.x does cover 8.3.
A4 confirms a mechanism rather than hunts a blocker, and if a
`MongoCompatibilityError` did appear, the upgrade is blocked behind a framework
release outright.

### The 8.3 upgrade path

MongoDB publishes a direct path,
[Upgrade 8.0 Replica Set to 8.3](https://www.mongodb.com/docs/manual/release-notes/8.3-upgrade-from-8.0-replica-set/),
so 8.1 and 8.2 are not stepping stones. Precondition: FCV `8.0` on the source.
Downgrade is single-version only, and the FCV bump is the door that closes.

Before running any of it, grep the application for the behavioural changes 8.3
introduces, so nobody re-litigates them later: error code `4031700` and
`ExceededMemoryLimit` handling, `allowDiskUse`, and `$**` wildcard index
declarations. One more is a live-database question rather than a code one:
whether any non-time-series `system.buckets` collections exist.

Worth knowing before anyone proposes moving the driver at all, separately from
8.3: count the call sites that reach past the abstraction into the raw driver
(`rawCollection`, `rawDatabase` and equivalents). That count is the real size of
the driver coupling, and it is usually much larger than expected.

## References

- [MongoDB Versions in Atlas](https://www.mongodb.com/docs/atlas/atlas-versions/)
- [Atlas Flex Limitations](https://www.mongodb.com/docs/atlas/reference/flex-limitations/)
- [Atlas Triggers Limitations](https://www.mongodb.com/docs/atlas/atlas-ui/triggers/limitations/)
- [endoflife.date/mongodb](https://endoflife.date/mongodb)
- [docker-library/mongo 8.0 entrypoint](https://github.com/docker-library/mongo/blob/master/8.0/docker-entrypoint.sh)
- [lima-vm/lima#231](https://github.com/lima-vm/lima/issues/231)
