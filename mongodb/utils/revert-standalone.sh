#!/usr/bin/env bash
#
# Exercise 3: take an initiated single-member replica set back to a standalone.
#
# This is not the inverse of the change that got here, but it fails in a
# different way than folklore says. Measured on 8.0.29:
#
#   1. mongod DOES start standalone on an initiated data directory. It does not
#      refuse. It logs startup warning id 20547 and carries on serving.
#   2. That warning matters: "The TTL collection monitor will not start because
#      of this". TTL indexes silently stop expiring documents. The server looks
#      healthy and is quietly not doing one of its jobs.
#   3. The replica set configuration document lives in `local.system.replset`,
#      and the `root` role CANNOT touch it. Both dropDatabase on `local` and a
#      delete on the collection come back Unauthorized (13), whether mongod is
#      running with --replSet or without it.
#
# So the reversal needs a privilege escalation the plan has to allow for: grant
# `__system` to the admin user, drop `local`, revoke it again, restart. That is
# a deliberate step, and it is exactly the kind of thing that should be written
# down before a maintenance window rather than discovered inside one.
#
#   ./utils/revert-standalone.sh attempt
#     Start the initiated data directory without --replSet and capture what
#     mongod says, verbatim. Expect a warning and a running server, not a
#     refusal. Do not clean up after it.
#
#   ./utils/revert-standalone.sh revert
#     The working sequence, as above, ending with a clean standalone whose TTL
#     monitor is alive again.
#
# Both leave the stack in a state the README names, so the next exercise starts
# from something known.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
APP_DIR="${ROOT_DIR}/app"

CONTAINER="${MONGO_CONTAINER:-mongodb}"
MONGO_DB="${MONGO_DB:-appdb}"

: "${MONGO_ROOT_USER:?MONGO_ROOT_USER is required}"
: "${MONGO_ROOT_PASSWORD:?MONGO_ROOT_PASSWORD is required}"

uri="mongodb://${MONGO_ROOT_USER}:${MONGO_ROOT_PASSWORD}@localhost:27017/admin?directConnection=true"

compose_rs() { docker compose -f "${APP_DIR}/compose.yaml" "$@"; }
compose_standalone() {
  docker compose -f "${APP_DIR}/compose.standalone.yaml" "$@"
}

count_people() {
  docker exec -i "${CONTAINER}" mongosh "${uri}" --quiet --eval "
    print(db.getSiblingDB('${MONGO_DB}').people.countDocuments({}));
  "
}

case "${1:-}" in
  attempt)
    echo "== recording the count before anything is touched =="
    count_people

    echo
    echo "== stopping the replica-set stack =="
    compose_rs stop mongo

    echo
    echo "== starting the same data directory WITHOUT --replSet =="
    echo "== this is expected to fail; the error text is the finding =="
    compose_standalone up -d mongo || true

    echo
    echo "== mongod logs, verbatim; copy these into the findings table =="
    sleep 5
    docker logs "${CONTAINER}" 2>&1 | tail -n 40
    ;;

  revert)
    echo "== starting standalone on the initiated data directory =="
    echo "== this succeeds; it is the TTL monitor that does not =="
    compose_rs stop mongo || true
    compose_standalone up -d mongo

    echo
    echo "== waiting for the standalone to answer =="
    for _ in $(seq 1 60); do
      if docker exec -i "${CONTAINER}" mongosh --quiet \
        --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    echo
    echo "== granting __system so the config document can be removed =="
    echo "== the root role is NOT sufficient for local.system.replset =="
    docker exec -i "${CONTAINER}" mongosh "${uri}" --quiet --eval "
      db.getSiblingDB('admin').grantRolesToUser('${MONGO_ROOT_USER}', ['__system']);
      print('granted __system');
    "

    echo
    echo "== dropping the local database =="
    docker exec -i "${CONTAINER}" mongosh "${uri}" --quiet --eval "
      printjson(db.getSiblingDB('local').dropDatabase());
    "

    echo
    echo "== revoking __system again =="
    docker exec -i "${CONTAINER}" mongosh "${uri}" --quiet --eval "
      db.getSiblingDB('admin').revokeRolesFromUser('${MONGO_ROOT_USER}', ['__system']);
      print('revoked __system');
    "

    echo
    echo "== restarting so the TTL monitor starts =="
    compose_standalone restart mongo
    for _ in $(seq 1 60); do
      if docker exec -i "${CONTAINER}" mongosh --quiet \
        --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    echo
    echo "== startup warning 20547 should now be absent =="
    docker exec -i "${CONTAINER}" mongosh "${uri}" --quiet --eval "
      const w = db.adminCommand({getLog: 'startupWarnings'}).log
        .filter((l) => JSON.parse(l).id === 20547);
      print('warning 20547 present: ' + (w.length > 0));
      print('replset config document present: ' +
        (db.getSiblingDB('local').system.replset.countDocuments({}) > 0));
    "

    echo
    echo "== data intact? =="
    count_people

    echo
    echo "== rs.status() should now error =="
    docker exec -i "${CONTAINER}" mongosh "${uri}" --quiet --eval "
      try {
        printjson(rs.status());
        print('UNEXPECTED: rs.status() succeeded on a standalone');
      } catch (err) {
        print('expected error: ' + err.codeName + ' (' + err.code + ') ' +
          err.message);
      }
    "
    ;;

  *)
    echo "usage: revert-standalone.sh [attempt|revert]" >&2
    exit 2
    ;;
esac
