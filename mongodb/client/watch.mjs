/**
 * watch.mjs: a change stream on <db>.people, printing each event and the resume
 * token it leaves behind.
 *
 * Change streams need a replica set; a standalone mongod cannot serve them at
 * all. That is one of the two reasons to do the conversion in the first place.
 *
 * The connection string carries ?replicaSet=rs0 and no directConnection: the
 * point is to go through topology discovery, not around it.
 *
 * Usage:
 *   MONGO_URI=... node watch.mjs
 *   WATCH_EVENTS=5 MONGO_URI=... node watch.mjs   # exit after 5 events
 */

import { MongoClient } from "mongodb";

const uri = process.env.MONGO_URI;
const dbName = process.env.MONGO_DB || "appdb";
const maxEvents = Number(process.env.WATCH_EVENTS || 0);

if (!uri) {
  console.error("MONGO_URI is required");
  process.exit(2);
}

if (uri.includes("directConnection=true")) {
  console.warn(
    "watch: directConnection=true is set; this suppresses the topology " +
      "awareness this exercise exists to observe",
  );
}

const client = new MongoClient(uri);
await client.connect();

const stream = client.db(dbName).collection("people").watch([], {
  fullDocument: "updateLookup",
});

console.log(`watch: streaming ${dbName}.people, Ctrl-C to stop`);
if (maxEvents) console.log(`watch: will exit after ${maxEvents} events`);

let seen = 0;

const shutdown = async (reason) => {
  console.log(`\nwatch: closing (${reason})`);
  await stream.close().catch(() => {});
  await client.close().catch(() => {});
  process.exit(0);
};

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

stream.on("error", async (err) => {
  console.error(`watch: stream error: ${err.name}: ${err.codeName || err.code}: ${err.message}`);
  await shutdown("error");
});

for await (const event of stream) {
  seen += 1;
  const id = event.documentKey?._id;
  console.log(
    `watch: #${seen} ${event.operationType} _id=${id} ` +
      `clusterTime=${event.clusterTime}`,
  );
  if (event.fullDocument?.name) {
    console.log(`       name=${event.fullDocument.name}`);
  }
  console.log(`       resumeToken=${JSON.stringify(stream.resumeToken)}`);

  if (maxEvents && seen >= maxEvents) {
    await shutdown(`${maxEvents} events seen`);
  }
}
