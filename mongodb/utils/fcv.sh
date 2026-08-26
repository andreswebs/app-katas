#!/usr/bin/env bash
#
# Read featureCompatibilityVersion, or set it.
#
# Reading it is cheap now and awkward to establish later, and it is the
# precondition for any version move. Nothing in the main exercise sequence moves
# FCV off the running major line.
#
# The `set` path exists only for appendix A, the version upgrade that is kept
# and deliberately unrun. Bumping FCV is the door that closes: an older binary
# refuses to start against a data directory whose FCV is above its own line, and
# downgrades are single-version only. Same asymmetry as exercise 3, in a second
# guise.
#
# Usage:
#   ./utils/fcv.sh            # read
#   ./utils/fcv.sh set 8.3    # appendix A only

set -euo pipefail

CONTAINER="${MONGO_CONTAINER:-mongodb}"

: "${MONGO_ROOT_USER:?MONGO_ROOT_USER is required}"
: "${MONGO_ROOT_PASSWORD:?MONGO_ROOT_PASSWORD is required}"

uri="mongodb://${MONGO_ROOT_USER}:${MONGO_ROOT_PASSWORD}@localhost:27017/admin?directConnection=true"

action="${1:-get}"

case "${action}" in
  get)
    docker exec -i "${CONTAINER}" mongosh "${uri}" --quiet --eval "
      const res = db.adminCommand({
        getParameter: 1,
        featureCompatibilityVersion: 1,
      });
      print('buildInfo.version = ' + db.version());
      print('featureCompatibilityVersion = ' +
        res.featureCompatibilityVersion.version);
    "
    ;;
  set)
    target="${2:?usage: fcv.sh set <version>}"
    echo "fcv: setting featureCompatibilityVersion to ${target}"
    echo "fcv: this is an appendix A operation, and it is not symmetric"
    docker exec -i "${CONTAINER}" mongosh "${uri}" --quiet --eval "
      printjson(db.adminCommand({
        setFeatureCompatibilityVersion: '${target}',
        confirm: true,
      }));
    "
    ;;
  *)
    echo "usage: fcv.sh [get|set <version>]" >&2
    exit 2
    ;;
esac
