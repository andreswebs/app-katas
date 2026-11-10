#!/usr/bin/env bash
#
# Idempotent rs.initiate(), safe to run on every `up`.
#
# It has to come from outside the server, authenticated. The official image
# strips --replSet and --keyFile from the temporary mongod that creates the root
# user (`_mongod_hack_ensure_no_arg_val` in the entrypoint), and adds no
# --transitionToAuth, so on a fresh volume the root user is created standalone
# and the real mongod comes up with replication and auth already on.
#
# This is also why the popular healthcheck-as-initiator pattern does not work
# here: `db.adminCommand('ping')` needs no auth, but `rs.status()` does.
#
# directConnection=true is used *here only*, because before initiation there is
# no topology to discover. Application clients must not use it: it suppresses
# exactly the topology awareness exercise 4 exists to observe.

set -euo pipefail

RS_NAME="${RS_NAME:-rs0}"
RS_MEMBER_HOST="${RS_MEMBER_HOST:-mongodb:27017}"
RS_INIT_TARGET="${RS_INIT_TARGET:-mongo:27017}"
RS_CONNECT_RETRIES="${RS_CONNECT_RETRIES:-60}"

# Credentials are optional, because a stack with authorization disabled needs no
# keyfile and no user. Absent credentials means an unauthenticated connection
# string, which is the test and CI shape.
if [ -n "${MONGO_ROOT_USER:-}" ] && [ -n "${MONGO_ROOT_PASSWORD:-}" ]; then
  uri="mongodb://${MONGO_ROOT_USER}:${MONGO_ROOT_PASSWORD}@${RS_INIT_TARGET}/admin?directConnection=true"
  auth_mode="authenticated"
else
  uri="mongodb://${RS_INIT_TARGET}/admin?directConnection=true"
  auth_mode="no auth"
fi

echo "rs-init: target=${RS_INIT_TARGET} set=${RS_NAME} member=${RS_MEMBER_HOST} (${auth_mode})"

# A sidecar could wait on a healthcheck instead, but a healthcheck that asserts
# PRIMARY cannot pass until this script has run, so the initiator waits on
# `service_started` and does its own waiting here. A CI job container has no
# healthcheck to wait on at all: GitLab waits only for the service's port to
# accept a connection before starting the job.
echo "rs-init: waiting for the server to answer"
for i in $(seq 1 "${RS_CONNECT_RETRIES}"); do
  if mongosh "${uri}" --quiet --eval 'db.adminCommand({ ping: 1 })' > /dev/null 2>&1; then
    break
  fi
  if [ "${i}" -eq "${RS_CONNECT_RETRIES}" ]; then
    echo "rs-init: server did not answer after ${RS_CONNECT_RETRIES} attempts"

    # Diagnose here rather than leaving the caller to re-run with more logging.
    # Four unrelated failures produce the same silence above: the name not
    # resolving, the name resolving to something that refuses the port, the
    # server refusing the client, and a broken client exiting non-zero after a
    # command that actually worked. The last one is real: mongosh 2.10.0 prints
    # the right answer and then throws on its way out. Separate them in one pass.
    init_host="${RS_INIT_TARGET%%:*}"
    init_port="${RS_INIT_TARGET##*:}"
    [ "${init_port}" = "${init_host}" ] && init_port=27017

    echo "rs-init: --- DNS ---"
    # Both names on purpose: an init target that does not resolve and a member
    # host that does not resolve are different failures with different fixes,
    # and the second is exercise 4's trap.
    for candidate in "${init_host}" "${RS_MEMBER_HOST%%:*}"; do
      getent hosts "${candidate}" || echo "rs-init: ${candidate} does not resolve"
    done
    # Under container links the aliases land in /etc/hosts; on a user-defined or
    # per-build network they come from the embedded DNS server instead. Which of
    # the two is in play is usually the question.
    echo "rs-init: --- /etc/hosts ---"
    cat /etc/hosts
    echo "rs-init: --- nameservers ---"
    grep -E '^nameserver' /etc/resolv.conf || true

    echo "rs-init: --- TCP to ${init_host}:${init_port} ---"
    if timeout 5 bash -c "exec 3<>/dev/tcp/${init_host}/${init_port}" 2> /dev/null; then
      echo "rs-init: port ${init_port} accepts connections"
    else
      echo "rs-init: port ${init_port} refused or unreachable"
    fi

    echo "rs-init: --- mongosh, with its error ---"
    mongosh "${uri}" --quiet --eval 'db.adminCommand({ ping: 1 })' || true

    exit 1
  fi
  sleep 1
done

mongosh "${uri}" --quiet --eval "
  const memberHost = '${RS_MEMBER_HOST}';
  const setName = '${RS_NAME}';
  try {
    const status = rs.status();
    print('rs-init: already initiated as ' + status.set + ', members: ' +
      status.members.map((m) => m.name + '=' + m.stateStr).join(', '));
  } catch (err) {
    if (err.codeName !== 'NotYetInitialized' && err.code !== 94) {
      print('rs-init: rs.status() failed unexpectedly: ' +
        err.codeName + ' (' + err.code + ') ' + err.message);
      quit(1);
    }
    print('rs-init: not initiated, initiating with member ' + memberHost);
    const res = rs.initiate({
      _id: setName,
      members: [{ _id: 0, host: memberHost }],
    });
    printjson(res);
  }
"

echo "rs-init: waiting for PRIMARY"
mongosh "${uri}" --quiet --eval "
  for (let i = 0; i < 60; i++) {
    try {
      if (db.hello().isWritablePrimary) {
        print('rs-init: PRIMARY, hello().me = ' + db.hello().me);
        quit(0);
      }
    } catch (err) {
      // still stepping up
    }
    sleep(1000);
  }
  print('rs-init: timed out waiting for PRIMARY');
  quit(1);
"
