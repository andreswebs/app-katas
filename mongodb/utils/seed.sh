#!/usr/bin/env bash
#
# Seed synthetic documents and print the resulting count.
#
# Synthetic on purpose. Nothing here needs real data: a dump, a restore and a
# count comparison exercise the same mechanics either way, and a throwaway stack
# is the wrong place for anything that matters.
#
# Runs through `docker exec`, so no mongosh is needed on the host.
#
# Usage: MONGO_ROOT_USER=... MONGO_ROOT_PASSWORD=... ./utils/seed.sh [count]

set -euo pipefail

CONTAINER="${MONGO_CONTAINER:-mongodb}"
MONGO_DB="${MONGO_DB:-appdb}"
SEED_COUNT="${1:-${SEED_COUNT:-5000}}"

: "${MONGO_ROOT_USER:?MONGO_ROOT_USER is required}"
: "${MONGO_ROOT_PASSWORD:?MONGO_ROOT_PASSWORD is required}"

uri="mongodb://${MONGO_ROOT_USER}:${MONGO_ROOT_PASSWORD}@localhost:27017/admin?directConnection=true"

echo "seed: inserting ${SEED_COUNT} documents into ${MONGO_DB}.people"

docker exec -i "${CONTAINER}" mongosh "${uri}" --quiet --eval "
  const target = ${SEED_COUNT};
  const dbName = '${MONGO_DB}';
  const people = db.getSiblingDB(dbName).people;
  const tenants = ['tenant-a', 'tenant-b', 'tenant-c'];
  const batchSize = 1000;
  let inserted = 0;
  while (inserted < target) {
    const batch = [];
    const n = Math.min(batchSize, target - inserted);
    for (let i = 0; i < n; i++) {
      const seq = inserted + i;
      batch.push({
        tenantId: tenants[seq % tenants.length],
        name: 'Synthetic Person ' + seq,
        externalId: 'ext-' + seq,
        counts: { reads: seq % 17, writes: seq % 7 },
        seq: seq,
        createdAt: new Date(1700000000000 + seq * 1000),
      });
    }
    people.insertMany(batch);
    inserted += n;
  }
  print('seed: ' + dbName + '.people count = ' + people.countDocuments({}));
"
