/**
 * probe.mjs: everything these exercises need to observe about a server, from a
 * driver pinned to one exact version.
 *
 * The pin matters. Some frameworks bundle the MongoDB driver as a transitive
 * dependency of a core package, where it cannot be overridden from the
 * application's own package.json, so the driver version is a property of the
 * framework release rather than a choice. Pin whatever the real application
 * resolves to; 6.16.0 is pinned here, and its declared ceiling is server 8.0
 * (MAX_SUPPORTED_WIRE_VERSION 25).
 *
 * Every check runs independently and reports its own outcome. A refusal is a
 * result, not a crash: several exercises exist precisely to find out which of
 * these a least-privilege user is allowed to do.
 *
 * Usage:
 *   MONGO_URI=... node probe.mjs
 */

import { MongoClient } from "mongodb";

const uri = process.env.MONGO_URI;
const dbName = process.env.MONGO_DB || "appdb";

if (!uri) {
  console.error("MONGO_URI is required");
  process.exit(2);
}

/** Redact the password before anything prints the connection string. */
const redact = (value) => value.replace(/\/\/([^:]+):[^@]+@/, "//$1:***@");

const results = [];

const check = async (name, fn) => {
  try {
    const value = await fn();
    results.push({ name, status: "OK", detail: value });
  } catch (err) {
    results.push({
      name,
      status: "FAIL",
      detail: `${err.name}: ${err.codeName || err.code || "-"}: ${err.message}`,
    });
  }
};

console.log(`probe: uri = ${redact(uri)}`);
console.log(`probe: db  = ${dbName}`);

const client = new MongoClient(uri);

/**
 * Topology is the whole point of exercise 4. The driver rewrites its server
 * list to whatever rs.initiate() recorded as the member host, whatever was used
 * as a seed, so the last description the driver emits is the redirect made
 * visible.
 */
let topology = null;
client.on("topologyDescriptionChanged", (event) => {
  topology = event.newDescription;
});

try {
  await client.connect();
} catch (err) {
  console.error(`probe: connect failed: ${err.name}: ${err.message}`);
  process.exit(1);
}

const admin = client.db(dbName).admin();

await check("connect", () => "connected");

await check("topology", () => {
  if (!topology) return "no topology description emitted";
  const servers = [...topology.servers.entries()].map(
    ([address, description]) => `${address}=${description.type}`,
  );
  return `type=${topology.type} setName=${topology.setName || "-"} servers=[${servers.join(", ")}]`;
});

await check("hello().me", async () => {
  const hello = await admin.command({ hello: 1 });
  return [
    `me=${hello.me || "-"}`,
    `setName=${hello.setName || "-"}`,
    `primary=${hello.primary || "-"}`,
    `hosts=[${(hello.hosts || []).join(", ")}]`,
    `isWritablePrimary=${hello.isWritablePrimary}`,
    `minWireVersion=${hello.minWireVersion}`,
    `maxWireVersion=${hello.maxWireVersion}`,
  ].join(" ");
});

/**
 * The cheapest round trip the driver offers, and the usual choice for a
 * readiness probe. If a least-privilege user is refused here, the health
 * endpoint reports the database unreachable while it is fine, which is the
 * worst possible failure for a probe sitting in front of a load balancer.
 */
await check("admin ping (readiness probe)", async () => {
  const res = await admin.command({ ping: 1 });
  return `ok=${res.ok}`;
});

await check("buildInfo.version", async () => {
  const info = await admin.command({ buildInfo: 1 });
  return `${info.version} (gitVersion ${info.gitVersion})`;
});

await check("featureCompatibilityVersion", async () => {
  const res = await admin.command({
    getParameter: 1,
    featureCompatibilityVersion: 1,
  });
  return res.featureCompatibilityVersion.version;
});

await check("retryWrites", () => String(client.options.retryWrites));

await check(`read ${dbName}.people`, async () => {
  const count = await client.db(dbName).collection("people").countDocuments({});
  return `countDocuments = ${count}`;
});

await check(`write ${dbName}.probe`, async () => {
  const res = await client
    .db(dbName)
    .collection("probe")
    .insertOne({ at: new Date(), from: "probe.mjs" });
  return `insertedId = ${res.insertedId}`;
});

/**
 * Change streams need a replica set, so this is one of the two things the whole
 * conversion buys. On Atlas it is also where the documentation contradicts
 * itself; see exercise 15.
 */
await check("change stream (open and close)", async () => {
  const stream = client.db(dbName).collection("people").watch();
  try {
    // tryNext() is what forces the aggregate to be issued. Constructing the
    // stream is lazy: without this the check reports success against a server
    // it never contacted, and a user with no privilege on the database passes.
    await stream.tryNext();
    return "aggregate issued, no error";
  } finally {
    await stream.close().catch(() => {});
  }
});

/**
 * Oplog tailing is the fallback when change streams are unavailable or too
 * slow, and it needs read access to `local`. Whether a managed cluster grants
 * that is exercise 15's question.
 */
await check("read local.oplog.rs", async () => {
  const doc = await client
    .db("local")
    .collection("oplog.rs")
    .findOne({}, { sort: { $natural: -1 } });
  return doc ? `latest op ts=${doc.ts} op=${doc.op}` : "collection is empty";
});

await client.close();

console.log("");
const width = Math.max(...results.map((r) => r.name.length));
for (const { name, status, detail } of results) {
  console.log(`${name.padEnd(width)}  ${status.padEnd(4)}  ${detail}`);
}

const failed = results.filter((r) => r.status === "FAIL").length;
console.log(`\nprobe: ${results.length - failed} ok, ${failed} failed`);
