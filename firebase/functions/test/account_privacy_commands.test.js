"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  accountDeviceDocumentId,
  normalizeExportValue,
} = require("../account_privacy_commands");

test("account device document ids do not expose their source values", () => {
  const id = accountDeviceDocumentId(
      "user-123",
      "a1b2c3d4-1111-4222-8333-1234567890ab",
  );
  assert.match(id, /^[a-f0-9]{64}$/);
  assert.equal(id.includes("user-123"), false);
  assert.equal(id.includes("a1b2c3d4"), false);
});

test("account exports normalize timestamps, locations, and nested values", () => {
  const timestamp = { toDate: () => new Date("2026-07-23T01:02:03.000Z") };
  const normalized = normalizeExportValue({
    createdAt: timestamp,
    location: { latitude: 55.17, longitude: -118.79 },
    values: [timestamp, true, 42],
  });
  assert.deepEqual(normalized, {
    createdAt: "2026-07-23T01:02:03.000Z",
    location: { latitude: 55.17, longitude: -118.79 },
    values: ["2026-07-23T01:02:03.000Z", true, 42],
  });
});
