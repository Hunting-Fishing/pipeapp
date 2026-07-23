"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { normalizeExportValue } = require("../account_privacy_commands");

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
