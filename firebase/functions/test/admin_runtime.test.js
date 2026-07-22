const assert = require("node:assert/strict");
const test = require("node:test");

const { createAdminRuntime } = require("../admin_runtime");

test("Admin 14 modular adapter exposes only the command runtime contract", () => {
  const runtime = createAdminRuntime();

  assert.equal(typeof runtime.auth, "function");
  assert.equal(typeof runtime.firestore, "function");
  assert.equal(typeof runtime.firestore.FieldValue.serverTimestamp, "function");
  assert.equal(typeof runtime.firestore.FieldValue.increment, "function");
  assert.equal(typeof runtime.firestore.GeoPoint, "function");
  assert.equal(typeof runtime.firestore.Timestamp.now, "function");
});
