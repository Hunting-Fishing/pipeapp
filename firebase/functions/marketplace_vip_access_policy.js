"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {isAdministrator} = require("./administrator_authorization");

const VIP_EARLY_ACCESS_HOURS = 24;

function toMillis(value) {
  if (value == null) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function vipEarlyAccessUntilMillis(listing) {
  if (!listing) return null;
  const explicit = toMillis(listing.vipEarlyAccessUntil);
  if (explicit != null) return explicit;
  if (listing.vipEarlyAccessEnabled !== true) return null;
  const published = toMillis(listing.publishedAt) || toMillis(listing.createdAt);
  return published == null ? null : published + VIP_EARLY_ACCESS_HOURS * 60 * 60 * 1000;
}

function activeVipProfile(profile, nowMillis = Date.now()) {
  const data = profile || {};
  const membership = data.membership && typeof data.membership === "object" ?
    data.membership : {};
  const tier = String(
      data.membershipTier || data.subscriptionTier || membership.tier || "",
  ).trim().toLowerCase();
  const status = String(
      data.vipStatus || data.subscriptionStatus || membership.status || "",
  ).trim().toLowerCase();
  const active = data.vipActive === true || data.isVip === true || tier === "vip";
  if (!active) return false;
  if (status && !new Set(["active", "trialing", "vip"]).has(status)) return false;
  const expiry = toMillis(data.vipExpiresAt) ||
    toMillis(data.vipUntil) ||
    toMillis(membership.expiresAt);
  return expiry == null || expiry > nowMillis;
}

async function requireVipEarlyListingAccess({
  db,
  request,
  uid,
  listing,
  transaction = null,
  nowMillis = Date.now(),
}) {
  if (!listing) return;
  const sellerUid = String(listing.sellerUid || listing.ownerUid || "").trim();
  if (uid && uid === sellerUid) return;
  if (request && isAdministrator(request)) return;
  const until = vipEarlyAccessUntilMillis(listing);
  if (until == null || until <= nowMillis) return;

  const userRef = db.collection("users").doc(uid);
  const snapshot = transaction ?
    await transaction.get(userRef) :
    await userRef.get();
  if (snapshot.exists && activeVipProfile(snapshot.data(), nowMillis)) return;

  const remainingMinutes = Math.max(1, Math.ceil((until - nowMillis) / 60000));
  throw new HttpsError(
      "failed-precondition",
      `This new listing is in its 24-hour VIP early-access period. ` +
      `Standard access opens in about ${remainingMinutes} minute` +
      `${remainingMinutes === 1 ? "" : "s"}.`,
  );
}

module.exports = {
  VIP_EARLY_ACCESS_HOURS,
  activeVipProfile,
  requireVipEarlyListingAccess,
  toMillis,
  vipEarlyAccessUntilMillis,
};
