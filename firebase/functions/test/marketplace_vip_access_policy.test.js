"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  activeVipProfile,
  requireVipEarlyListingAccess,
  vipEarlyAccessUntilMillis,
} = require("../marketplace_vip_access_policy");

const hour = 60 * 60 * 1000;
const now = Date.UTC(2026, 7, 14, 12, 0, 0);

function dbWithProfile(profile) {
  return {
    collection(name) {
      assert.equal(name, "users");
      return {
        doc() {
          return {
            async get() {
              return {
                exists: profile != null,
                data: () => profile || {},
              };
            },
          };
        },
      };
    },
  };
}

test("unflagged historical listing has no VIP gate", () => {
  assert.equal(vipEarlyAccessUntilMillis({createdAt: now}), null);
});

test("flagged listing receives a 24 hour window from publication", () => {
  assert.equal(
      vipEarlyAccessUntilMillis({
        vipEarlyAccessEnabled: true,
        publishedAt: now,
      }),
      now + 24 * hour,
  );
});

test("active VIP membership honors expiration", () => {
  assert.equal(activeVipProfile({
    vipActive: true,
    vipStatus: "active",
    vipExpiresAt: now + hour,
  }, now), true);
  assert.equal(activeVipProfile({
    vipActive: true,
    vipStatus: "active",
    vipExpiresAt: now - 1,
  }, now), false);
});

test("standard user is blocked during the early-access window", async () => {
  await assert.rejects(
      requireVipEarlyListingAccess({
        db: dbWithProfile({membershipTier: "standard", vipActive: false}),
        request: {auth: {token: {}}},
        uid: "buyer-1",
        listing: {
          sellerUid: "seller-1",
          vipEarlyAccessEnabled: true,
          vipEarlyAccessUntil: now + 4 * hour,
        },
        nowMillis: now,
      }),
      (error) => error &&
        error.code === "failed-precondition" &&
        /VIP early-access/.test(error.message),
  );
});

test("VIP user and listing seller can transact immediately", async () => {
  await requireVipEarlyListingAccess({
    db: dbWithProfile({
      membershipTier: "vip",
      vipActive: true,
      vipStatus: "active",
      vipExpiresAt: now + 30 * 24 * hour,
    }),
    request: {auth: {token: {}}},
    uid: "buyer-1",
    listing: {
      sellerUid: "seller-1",
      vipEarlyAccessEnabled: true,
      vipEarlyAccessUntil: now + 4 * hour,
    },
    nowMillis: now,
  });

  await requireVipEarlyListingAccess({
    db: dbWithProfile(null),
    request: {auth: {token: {}}},
    uid: "seller-1",
    listing: {
      sellerUid: "seller-1",
      vipEarlyAccessEnabled: true,
      vipEarlyAccessUntil: now + 4 * hour,
    },
    nowMillis: now,
  });
});
