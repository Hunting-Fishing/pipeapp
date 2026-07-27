"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  DELETION_CONFIRMATION,
  normalizeDeviceRegistration,
  requireDeletionConfirmation,
  requireNoDeletionBlockers,
  requireRecentAuthentication,
  summarizeDeletionBlockers,
} = require("../account_privacy_policy");

test("device registration accepts only bounded app installation metadata", () => {
  assert.deepEqual(
    normalizeDeviceRegistration({
      deviceId: "A1B2C3D4-1111-4222-8333-1234567890AB",
      label: "  Android   device  ",
      platform: "ANDROID",
    }),
    {
      deviceId: "a1b2c3d4-1111-4222-8333-1234567890ab",
      label: "Android device",
      platform: "android",
    },
  );
  assert.throws(
    () => normalizeDeviceRegistration({deviceId: "phone", label: "Phone", platform: "android"}),
    (error) => error.code === "invalid-argument",
  );
  assert.throws(
    () => normalizeDeviceRegistration({
      deviceId: "a1b2c3d4-1111-4222-8333-1234567890ab",
      label: "Phone",
      platform: "gps-tracker",
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("sensitive privacy commands require a recent authenticated session", () => {
  assert.equal(
    requireRecentAuthentication(
      {
        auth: { token: { auth_time: 9_500 } },
      },
      10_000,
    ),
    9_500,
  );
  assert.throws(
    () =>
      requireRecentAuthentication(
        {
          auth: { token: { auth_time: 9_000 } },
        },
        10_000,
      ),
    (error) =>
      error.code === "failed-precondition" &&
      error.message.includes("sign in again"),
  );
});

test("deletion confirmation is explicit and cannot be approximated", () => {
  assert.doesNotThrow(() =>
    requireDeletionConfirmation({
      confirmation: DELETION_CONFIRMATION,
    }),
  );
  assert.throws(
    () => requireDeletionConfirmation({ confirmation: "delete" }),
    (error) => error.code === "invalid-argument",
  );
});

test("active commercial responsibilities block account deletion", () => {
  const blockers = summarizeDeletionBlockers({
    listings: 2,
    offers: 1,
    marketplaceTransactions: 0,
  });
  assert.deepEqual(
    blockers.map((item) => item.key),
    ["listings", "offers"],
  );
  assert.throws(
    () => requireNoDeletionBlockers({ dispatchTransactions: 1 }),
    /unfinished Dispatch deliveries/,
  );
  assert.deepEqual(requireNoDeletionBlockers({}), []);
});
