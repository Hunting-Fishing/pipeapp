"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  loadPhase1FeatureFlags,
  requirePhase1Feature,
} = require("./phase1_feature_flags");

const MARKETPLACE_LISTING_ACTIVE_DAYS = 30;
const MARKETPLACE_LISTING_WARNING_DAYS = 3;
const DAY_MS = 24 * 60 * 60 * 1000;

function lifecycleMillis(value) {
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

function listingExpiryMillis(
    publishedAt,
    durationDays = MARKETPLACE_LISTING_ACTIVE_DAYS,
) {
  const published = lifecycleMillis(publishedAt);
  const days = Number(durationDays);
  if (published == null || !Number.isFinite(days) || days <= 0) return null;
  return published + Math.round(days * DAY_MS);
}

function listingLifecycleState(listing, nowMillis = Date.now()) {
  const data = listing || {};
  const status = String(data.status || "active").trim().toLowerCase();
  const expiresAt = lifecycleMillis(data.expiresAt);
  const remainingMs = expiresAt == null ? null : expiresAt - nowMillis;
  return {
    status,
    expiresAt,
    expired: status === "expired" ||
      (expiresAt != null && remainingMs <= 0 &&
       ["active", "paused"].includes(status)),
    expiringSoon: expiresAt != null && remainingMs > 0 &&
      remainingMs <= MARKETPLACE_LISTING_WARNING_DAYS * DAY_MS,
    remainingMs,
  };
}

function renewalUpdate({listing, Timestamp, FieldValue, now}) {
  const current = listing || {};
  if (String(current.transactionType || "") === "Auction") {
    throw new HttpsError(
        "failed-precondition",
        "Timed auctions use their auction schedule and cannot be renewed here.",
    );
  }
  if (String(current.status || "").toLowerCase() !== "expired") {
    throw new HttpsError(
        "failed-precondition",
        "Only an expired Marketplace listing can be renewed.",
    );
  }
  const nowTimestamp = now || Timestamp.now();
  const nextExpiry = Timestamp.fromMillis(
      nowTimestamp.toMillis() + MARKETPLACE_LISTING_ACTIVE_DAYS * DAY_MS,
  );
  return {
    status: "active",
    expiresAt: nextExpiry,
    renewedAt: nowTimestamp,
    updatedAt: FieldValue.serverTimestamp(),
    renewalCount: Number(current.renewalCount || 0) + 1,
    listingDurationDays: MARKETPLACE_LISTING_ACTIVE_DAYS,
    lifecycleVersion: 1,
    expiryWarningSentAt: FieldValue.delete(),
    expiryWarningFor: FieldValue.delete(),
    revision: Number(current.revision || 1) + 1,
  };
}

function createMarketplaceListingLifecycle(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  async function initializeListing(listingId, listing) {
    if (!listingId || !listing || listing.transactionType === "Auction") {
      return {initialized: false};
    }
    if (listing.expiresAt != null && listing.publishedAt != null) {
      return {initialized: false};
    }
    const publishedMillis = lifecycleMillis(listing.publishedAt) ||
      lifecycleMillis(listing.createdAt) ||
      lifecycleMillis(listing.created_time) ||
      lifecycleMillis(listing.createdTime) ||
      Date.now();
    const publishedAt = Timestamp.fromMillis(publishedMillis);
    const expiresAt = Timestamp.fromMillis(
        listingExpiryMillis(publishedMillis),
    );
    await db.collection("public_listings").doc(listingId).set({
      publishedAt,
      expiresAt,
      listingDurationDays: MARKETPLACE_LISTING_ACTIVE_DAYS,
      renewalCount: Number(listing.renewalCount || 0),
      lifecycleVersion: 1,
    }, {merge: true});
    return {initialized: true, publishedAt, expiresAt};
  }

  async function renewMarketplaceListing(request) {
    const identity = requireAuthenticatedIdentity(request);
    const uid = identity.uid;
    const flags = await loadPhase1FeatureFlags(db);
    requirePhase1Feature(flags, "marketplace");
    await enforceUserRateLimit({
      db,
      admin,
      request,
      scope: "marketplace",
    });
    const listingId = String(request.data && request.data.listingId || "").trim();
    if (!listingId || listingId.length > 180 || listingId.includes("/")) {
      throw new HttpsError("invalid-argument", "Listing identifier is invalid.");
    }
    const listingRef = db.collection("public_listings").doc(listingId);
    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(listingRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "This listing is unavailable.");
      }
      const listing = snapshot.data() || {};
      if (String(listing.sellerUid || "") !== uid) {
        throw new HttpsError(
            "permission-denied",
            "Only the listing owner can renew this listing.",
        );
      }
      const now = Timestamp.now();
      const update = renewalUpdate({listing, Timestamp, FieldValue, now});
      transaction.update(listingRef, update);
      const nextRevision = update.revision;
      transaction.set(
          listingRef.collection("revisions").doc(String(nextRevision)),
          {
            actorUid: uid,
            event: "renewed_30_days",
            previousStatus: "expired",
            status: "active",
            expiresAt: update.expiresAt,
            renewalCount: update.renewalCount,
            revision: nextRevision,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.set(
          db.collection("users").doc(uid)
              .collection("notifications").doc(`listing-renewed-${listingId}`),
          {
            recipientUid: uid,
            actorUid: uid,
            type: "listing_renewed",
            title: "Listing renewed for 30 days",
            body: String(listing.title || "Your Marketplace listing"),
            listingId,
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
      );
      return {
        listingId,
        status: "active",
        expiresAt: update.expiresAt.toMillis(),
        renewalCount: update.renewalCount,
      };
    });
  }

  async function expireStatus(status, now) {
    const snapshot = await db.collection("public_listings")
        .where("status", "==", status)
        .where("expiresAt", "<=", now)
        .limit(100)
        .get();
    let expiredCount = 0;
    const results = await Promise.allSettled(snapshot.docs.map(
        (document) => db.runTransaction(async (transaction) => {
          const fresh = await transaction.get(document.ref);
          if (!fresh.exists) return false;
          const listing = fresh.data() || {};
          if (listing.transactionType === "Auction") return false;
          if (!["active", "paused"].includes(String(listing.status || ""))) {
            return false;
          }
          const expiresMillis = lifecycleMillis(listing.expiresAt);
          if (expiresMillis == null || expiresMillis > now.toMillis()) return false;
          const nextRevision = Number(listing.revision || 1) + 1;
          transaction.update(document.ref, {
            status: "expired",
            expiredAt: now,
            updatedAt: FieldValue.serverTimestamp(),
            revision: nextRevision,
          });
          transaction.set(
              document.ref.collection("revisions").doc(String(nextRevision)),
              {
                actorUid: "listing_lifecycle_scheduler",
                event: "expired_30_days",
                previousStatus: listing.status,
                status: "expired",
                expiresAt: listing.expiresAt,
                revision: nextRevision,
                createdAt: FieldValue.serverTimestamp(),
              },
          );
          const sellerUid = String(listing.sellerUid || "").trim();
          if (sellerUid) {
            transaction.set(
                db.collection("users").doc(sellerUid)
                    .collection("notifications")
                    .doc(`listing-expired-${document.id}-${expiresMillis}`),
                {
                  recipientUid: sellerUid,
                  actorUid: "listing_lifecycle_scheduler",
                  type: "listing_expired",
                  title: "Your Marketplace listing expired",
                  body: `${String(listing.title || "Listing")} reached its 30-day listing period. Renew it for another 30 days if it is still available.`,
                  listingId: document.id,
                  action: "renew_listing",
                  read: false,
                  createdAt: FieldValue.serverTimestamp(),
                },
            );
          }
          return true;
        }),
    ));
    for (const result of results) {
      if (result.status === "fulfilled" && result.value === true) {
        expiredCount += 1;
      } else if (result.status === "rejected") {
        console.error("Marketplace listing expiration failed", result.reason);
      }
    }
    return expiredCount;
  }

  async function expireMarketplaceListings() {
    const now = Timestamp.now();
    const active = await expireStatus("active", now);
    const paused = await expireStatus("paused", now);
    return {expiredCount: active + paused};
  }

  async function notifyExpiringListings() {
    const now = Timestamp.now();
    const cutoff = Timestamp.fromMillis(
        now.toMillis() + MARKETPLACE_LISTING_WARNING_DAYS * DAY_MS,
    );
    const snapshot = await db.collection("public_listings")
        .where("status", "==", "active")
        .where("expiresAt", ">", now)
        .where("expiresAt", "<=", cutoff)
        .limit(100)
        .get();
    let notificationCount = 0;
    const results = await Promise.allSettled(snapshot.docs.map(
        (document) => db.runTransaction(async (transaction) => {
          const fresh = await transaction.get(document.ref);
          if (!fresh.exists) return false;
          const listing = fresh.data() || {};
          if (listing.transactionType === "Auction" ||
              String(listing.status || "") !== "active") return false;
          const expiryMillis = lifecycleMillis(listing.expiresAt);
          if (expiryMillis == null || expiryMillis <= now.toMillis() ||
              expiryMillis > cutoff.toMillis()) return false;
          if (Number(listing.expiryWarningFor || 0) === expiryMillis) return false;
          transaction.update(document.ref, {
            expiryWarningSentAt: FieldValue.serverTimestamp(),
            expiryWarningFor: expiryMillis,
          });
          const sellerUid = String(listing.sellerUid || "").trim();
          if (!sellerUid) return true;
          const daysRemaining = Math.max(
              1,
              Math.ceil((expiryMillis - now.toMillis()) / DAY_MS),
          );
          transaction.set(
              db.collection("users").doc(sellerUid)
                  .collection("notifications")
                  .doc(`listing-expiring-${document.id}-${expiryMillis}`),
              {
                recipientUid: sellerUid,
                actorUid: "listing_lifecycle_scheduler",
                type: "listing_expiring",
                title: `Listing expires in ${daysRemaining} day${daysRemaining === 1 ? "" : "s"}`,
                body: `${String(listing.title || "Your listing")} can be renewed after it expires if the inventory is still available.`,
                listingId: document.id,
                read: false,
                createdAt: FieldValue.serverTimestamp(),
              },
          );
          return true;
        }),
    ));
    for (const result of results) {
      if (result.status === "fulfilled" && result.value === true) {
        notificationCount += 1;
      } else if (result.status === "rejected") {
        console.error("Marketplace expiry warning failed", result.reason);
      }
    }
    return {notificationCount};
  }

  return {
    expireMarketplaceListings,
    initializeListing,
    notifyExpiringListings,
    renewMarketplaceListing,
  };
}

module.exports = {
  DAY_MS,
  MARKETPLACE_LISTING_ACTIVE_DAYS,
  MARKETPLACE_LISTING_WARNING_DAYS,
  createMarketplaceListingLifecycle,
  lifecycleMillis,
  listingExpiryMillis,
  listingLifecycleState,
  renewalUpdate,
};
