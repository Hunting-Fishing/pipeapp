"use strict";

const crypto = require("node:crypto");
const { HttpsError } = require("firebase-functions/v2/https");
const { enforceUserRateLimit } = require("./abuse_rate_limit");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {
  DELETION_GRACE_DAYS,
  DEVICE_HISTORY_DAYS,
  EXPORT_RETENTION_DAYS,
  normalizeDeletionMode,
  normalizeDeviceRegistration,
  requireDeletionConfirmation,
  requireNoDeletionBlockers,
  requireRecentAuthentication,
  summarizeDeletionBlockers,
} = require("./account_privacy_policy");

// Firestore documents are limited to 1 MiB; use a conservative character
// ceiling because a Unicode character can occupy several UTF-8 bytes.
const EXPORT_CHUNK_CHARACTERS = 180000;
const EXPORT_DOCUMENT_LIMIT = 5000;
const EXPORT_SCHEMA_VERSION = 1;
const DELETION_POLICY_VERSION = 2;
const APPLE_DELETION_AUTHORIZATION_MINUTES = 10;
const DELETION_MUTATION_DRAIN_MINUTES = 2;
const DELETION_PROCESSING_LEASE_MINUTES = 30;
const DELETION_TOMBSTONE_RETENTION_HOURS = 24;

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value && typeof value.toDate === "function") {
    return value.toDate().getTime();
  }
  return Number.NaN;
}

function requireAppleDeletionAuthorization({
  authorization,
  authorizationId,
  authTimeSeconds,
  nowMillis,
  uid,
}) {
  if (
    typeof authorizationId !== "string" ||
    !/^[a-f0-9-]{36}$/i.test(authorizationId) ||
    !authorization ||
    authorization.ownerUid !== uid ||
    authorization.authorizationId !== authorizationId ||
    authorization.status !== "pending_apple_revocation"
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Start account deletion again before revoking Apple authorization.",
    );
  }
  const expiresAtMillis = timestampMillis(authorization.expiresAt);
  if (!Number.isFinite(expiresAtMillis) || expiresAtMillis <= nowMillis) {
    throw new HttpsError(
      "failed-precondition",
      "The Apple deletion authorization expired. Start account deletion again.",
    );
  }
  const initialAuthTimeSeconds = Number(authorization.initialAuthTimeSeconds);
  if (
    !Number.isFinite(authTimeSeconds) ||
    !Number.isFinite(initialAuthTimeSeconds) ||
    authTimeSeconds <= initialAuthTimeSeconds
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Reauthenticate with Apple before requesting account deletion.",
    );
  }
}

function deletionRequestCanBeClaimed(data, nowMillis) {
  if (!data || timestampMillis(data.deleteAt) > nowMillis) return false;
  if (data.status === "scheduled") return true;
  if (data.status !== "processing") return false;
  const leaseExpiresAtMillis = timestampMillis(data.processingLeaseExpiresAt);
  return !Number.isFinite(leaseExpiresAtMillis) || leaseExpiresAtMillis <= nowMillis;
}

function accountDeviceDocumentId(uid, deviceId) {
  return crypto
      .createHash("sha256")
      .update(`${uid}|${deviceId}`)
      .digest("hex");
}

function privacyError(error) {
  if (error instanceof HttpsError) return error;
  if (error instanceof AccountSecurityError) {
    return new HttpsError(error.code, error.message);
  }
  console.error("Account privacy command failed", error);
  return new HttpsError(
    "internal",
    "The account privacy action could not be completed.",
  );
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      throw privacyError(error);
    }
  };
}

function normalizeExportValue(value) {
  if (
    value == null ||
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  )
    return value;
  if (Array.isArray(value)) return value.map(normalizeExportValue);
  if (typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  if (
    typeof value.latitude === "number" &&
    typeof value.longitude === "number"
  ) {
    return { latitude: value.latitude, longitude: value.longitude };
  }
  if (typeof value.path === "string" && value.firestore) {
    return { documentPath: value.path };
  }
  if (typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [
        key,
        normalizeExportValue(item),
      ]),
    );
  }
  return String(value);
}

function exportedDocument(snapshot) {
  return { id: snapshot.id, ...normalizeExportValue(snapshot.data()) };
}

async function queryDocuments(query, maximum = EXPORT_DOCUMENT_LIMIT) {
  const documents = [];
  let cursor = null;
  while (documents.length < maximum) {
    let pageQuery = query
      .orderBy("__name__")
      .limit(Math.min(250, maximum - documents.length));
    if (cursor) pageQuery = pageQuery.startAfter(cursor);
    const page = await pageQuery.get();
    documents.push(...page.docs.map(exportedDocument));
    if (page.size < 250) break;
    cursor = page.docs[page.docs.length - 1];
  }
  if (documents.length === maximum) {
    throw new HttpsError(
        "resource-exhausted",
        "This account export is larger than the automated safety limit. Contact support for an assisted export.",
    );
  }
  return documents;
}

async function queryForUser(db, collection, fields, uid) {
  const found = new Map();
  for (const field of fields) {
    const documents = await queryDocuments(
      db
        .collection(collection)
        .where(field, field === "memberUids" ? "array-contains" : "==", uid),
    );
    for (const document of documents) found.set(document.id, document);
  }
  return [...found.values()];
}

async function optionalDocument(db, collection, id) {
  const snapshot = await db.collection(collection).doc(id).get();
  return snapshot.exists ? exportedDocument(snapshot) : null;
}

async function attachSubcollection(db, collection, documents, childCollection) {
  const enriched = [];
  for (const document of documents) {
    enriched.push({
      ...document,
      [childCollection]: await queryDocuments(
        db
          .collection(collection)
          .doc(document.id)
          .collection(childCollection),
      ),
    });
  }
  return enriched;
}

async function buildAccountExport(db, auth, uid, generatedAt) {
  const userRecord = await auth.getUser(uid);
  const direct = await Promise.all([
    optionalDocument(db, "users", uid),
    optionalDocument(db, "public_seller_profiles", uid),
    optionalDocument(db, "public_business_profiles", uid),
    optionalDocument(db, "business_private", uid),
    optionalDocument(db, "verification_requests", uid),
    optionalDocument(db, "dispatch_carriers", uid),
  ]);
  const userCollections = [
    "saved_listings",
    "followed_sellers",
    "saved_locations",
    "profile_tags",
    "notifications",
    "watch_keywords",
    "account_devices",
  ];
  const owned = {};
  for (const collection of userCollections) {
    owned[collection] = await queryDocuments(
      db.collection("users").doc(uid).collection(collection),
    );
  }
  const sections = await Promise.all([
    queryForUser(db, "public_listings", ["sellerUid"], uid),
    queryForUser(db, "offers", ["buyerUid", "sellerUid"], uid),
    queryForUser(db, "conversations", ["memberUids"], uid),
    queryForUser(db, "auction_bids", ["bidderUid"], uid),
    queryForUser(
      db,
      "marketplace_transactions",
      ["buyerUid", "sellerUid"],
      uid,
    ),
    queryForUser(db, "auction_transactions", ["buyerUid", "sellerUid"], uid),
    queryForUser(db, "dispatch_jobs", ["createdByUid"], uid),
    queryForUser(db, "dispatch_bids", ["carrierUid"], uid),
    queryForUser(
      db,
      "dispatch_transactions",
      ["customerUid", "carrierUid"],
      uid,
    ),
    // Reports submitted by this account belong in its export. Reports made by
    // someone else remain private to protect reporter safety.
    queryForUser(db, "trust_reports", ["reporterUid"], uid),
    queryForUser(db, "verification_review_events", ["userUid"], uid),
    queryForUser(
        db,
        "dispatch_provider_review_events",
        ["providerUid"],
        uid,
    ),
  ]);
  const [listings, conversations, marketplaceTransactions,
    auctionTransactions, dispatchJobs] = await Promise.all([
    attachSubcollection(db, "public_listings", sections[0], "revisions"),
    attachSubcollection(db, "conversations", sections[2], "messages"),
    attachSubcollection(
      db,
      "marketplace_transactions",
      sections[4],
      "revisions",
    ),
    attachSubcollection(db, "auction_transactions", sections[5], "revisions"),
    attachSubcollection(db, "dispatch_jobs", sections[6], "revisions"),
  ]);
  const dispatchCarrier = direct[5]
    ? {
      ...direct[5],
      vehicles: await queryDocuments(
        db.collection("dispatch_carriers").doc(uid).collection("vehicles"),
      ),
      savedQuotes: await queryDocuments(
        db.collection("dispatch_carriers").doc(uid).collection("saved_quotes"),
      ),
    }
    : null;
  const listingDrafts = await queryForUser(
    db,
    "marketplace_listing_drafts",
    ["sellerUid"],
    uid,
  );
  return {
    schemaVersion: EXPORT_SCHEMA_VERSION,
    generatedAt: generatedAt.toISOString(),
    description: "Private account data export generated at the user's request.",
    authentication: {
      uid,
      email: userRecord.email || null,
      emailVerified: userRecord.emailVerified,
      phoneNumber: userRecord.phoneNumber || null,
      disabled: userRecord.disabled,
      createdAt: userRecord.metadata.creationTime || null,
      lastSignInAt: userRecord.metadata.lastSignInTime || null,
      providerIds: userRecord.providerData.map((item) => item.providerId),
    },
    profiles: {
      user: direct[0],
      seller: direct[1],
      business: direct[2],
      businessPrivate: direct[3],
      verification: direct[4],
      dispatchCarrier,
    },
    accountCollections: owned,
    marketplace: {
      drafts: listingDrafts,
      listings,
      offers: sections[1],
      conversations,
    },
    auctions: { bids: sections[3], transactions: auctionTransactions },
    transactions: { marketplace: marketplaceTransactions },
    dispatch: {
      jobs: dispatchJobs,
      bids: sections[7],
      transactions: sections[8],
      providerReviewHistory: sections[11],
    },
    safety: { reports: sections[9], verificationHistory: sections[10] },
    retentionNote:
      "Shared transaction, message, dispute, and safety records may be retained after deletion when needed for another participant, fraud prevention, dispute handling, or legal obligations.",
  };
}

async function deletionBlockers(db, uid) {
  const [
    listings,
    offers,
    marketplaceTransactions,
    auctionTransactions,
    dispatchJobs,
    dispatchTransactions,
    administratorRole,
  ] = await Promise.all([
    queryForUser(db, "public_listings", ["sellerUid"], uid),
    queryForUser(db, "offers", ["buyerUid", "sellerUid"], uid),
    queryForUser(
      db,
      "marketplace_transactions",
      ["buyerUid", "sellerUid"],
      uid,
    ),
    queryForUser(db, "auction_transactions", ["buyerUid", "sellerUid"], uid),
    queryForUser(db, "dispatch_jobs", ["createdByUid"], uid),
    queryForUser(
      db,
      "dispatch_transactions",
      ["customerUid", "carrierUid"],
      uid,
    ),
    optionalDocument(db, "administrator_roles", uid),
  ]);
  const countActive = (items, terminal) =>
    items.filter(
      (item) => !terminal.has(String(item.status || item.auctionStatus || "")),
    ).length;
  return {
    listings: listings.filter((item) =>
      ["active", "draft", "pending_sale", "scheduled", "live"].includes(
        String(item.status || item.auctionStatus || ""),
      ),
    ).length,
    offers: countActive(
      offers,
      new Set([
        "archived",
        "withdrawn",
        "cancelled",
        "completed",
        "declined",
        "rejected",
        "expired",
      ]),
    ),
    marketplaceTransactions: countActive(
      marketplaceTransactions,
      new Set(["completed", "cancelled", "refunded", "released"]),
    ),
    auctionTransactions: countActive(
      auctionTransactions,
      new Set(["completed", "cancelled", "refunded", "released"]),
    ),
    dispatchJobs: countActive(dispatchJobs, new Set(["closed", "cancelled"])),
    dispatchTransactions: countActive(
      dispatchTransactions,
      new Set(["closed", "cancelled"]),
    ),
    administratorRole: administratorRole && administratorRole.active ? 1 : 0,
  };
}

async function deleteMatching(db, collection, fields, uid) {
  const records = await queryForUser(db, collection, fields, uid);
  for (const record of records) {
    await db.recursiveDelete(db.collection(collection).doc(record.id));
  }
}

async function anonymizeListings(db, uid, FieldValue) {
  const records = await queryForUser(db, "public_listings", ["sellerUid"], uid);
  for (let offset = 0; offset < records.length; offset += 400) {
    const batch = db.batch();
    for (const record of records.slice(offset, offset + 400)) {
      batch.set(
        db.collection("public_listings").doc(record.id),
        {
          sellerUid: FieldValue.delete(),
          sellerDisplayName: "Deleted account",
          sellerPhotoUrl: FieldValue.delete(),
          sellerProfileDeleted: true,
          sellerProfileDeletedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    await batch.commit();
  }
}

function createAccountPrivacyCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const requestAccountDataExport = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    requireRecentAuthentication(request);
    await enforceUserRateLimit({ db, admin, request, scope: "privacy" });
    const now = new Date();
    const exportId = crypto.randomUUID();
    const payload = JSON.stringify(
      await buildAccountExport(db, admin.auth(), identity.uid, now),
      null,
      2,
    );
    const chunks = [];
    for (
      let index = 0;
      index < payload.length;
      index += EXPORT_CHUNK_CHARACTERS
    ) {
      chunks.push(payload.slice(index, index + EXPORT_CHUNK_CHARACTERS));
    }
    const exportRef = db.collection("account_exports").doc(exportId);
    const expiresAt = admin.firestore.Timestamp.fromMillis(
      now.getTime() + EXPORT_RETENTION_DAYS * 24 * 60 * 60 * 1000,
    );
    const metadataBatch = db.batch();
    metadataBatch.create(exportRef, {
      ownerUid: identity.uid,
      status: "generating",
      schemaVersion: EXPORT_SCHEMA_VERSION,
      chunkCount: chunks.length,
      characterCount: payload.length,
      fileName: `pipe-account-export-${now.toISOString().slice(0, 10)}.json`,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt,
    });
    await metadataBatch.commit();
    for (let offset = 0; offset < chunks.length; offset += 400) {
      const chunkBatch = db.batch();
      chunks.slice(offset, offset + 400).forEach((content, relativeIndex) => {
        const index = offset + relativeIndex;
        chunkBatch.create(
          exportRef.collection("chunks").doc(String(index).padStart(6, "0")),
          { ownerUid: identity.uid, index, content },
        );
      });
      await chunkBatch.commit();
    }
    const readyBatch = db.batch();
    readyBatch.update(exportRef, {
      status: "ready",
      readyAt: FieldValue.serverTimestamp(),
    });
    readyBatch.create(db.collection("account_privacy_events").doc(), {
      ownerUid: identity.uid,
      type: "data_export_generated",
      exportId,
      createdAt: FieldValue.serverTimestamp(),
    });
    await readyBatch.commit();
    return {
      exportId,
      chunkCount: chunks.length,
      fileName: `pipe-account-export-${now.toISOString().slice(0, 10)}.json`,
      expiresAt: expiresAt.toDate().toISOString(),
    };
  });

  const revokeAccountSessions = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    requireRecentAuthentication(request);
    await enforceUserRateLimit({ db, admin, request, scope: "privacy" });
    await admin.auth().revokeRefreshTokens(identity.uid);
    let historyUpdated = true;
    try {
      const userRef = db.collection("users").doc(identity.uid);
      const [devices, notificationEndpoints] = await Promise.all([
        userRef.collection("account_devices").limit(50).get(),
        userRef.collection("notification_endpoints")
            .where("status", "==", "active").limit(20).get(),
      ]);
      const batch = db.batch();
      for (const device of devices.docs) {
        batch.update(device.ref, {
          status: "revoked",
          revokedAt: FieldValue.serverTimestamp(),
        });
      }
      for (const endpoint of notificationEndpoints.docs) {
        batch.update(endpoint.ref, {
          status: "revoked",
          token: FieldValue.delete(),
          revokedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      batch.create(db.collection("account_privacy_events").doc(), {
        ownerUid: identity.uid,
        type: "sessions_revoked",
        deviceCount: devices.size,
        notificationEndpointCount: notificationEndpoints.size,
        createdAt: FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (error) {
      // Refresh-token revocation is the security boundary. A history-write
      // outage must not make the client believe revocation itself failed.
      historyUpdated = false;
      console.error("Session history could not be updated after revocation", error);
    }
    return { revoked: true, historyUpdated };
  });

  const registerAccountDevice = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
    const device = normalizeDeviceRegistration(request.data);
    await enforceUserRateLimit({db, admin, request, scope: "privacy"});
    const deviceDocumentId = accountDeviceDocumentId(
        identity.uid,
        device.deviceId,
    );
    const deviceRef = db
        .collection("users")
        .doc(identity.uid)
        .collection("account_devices")
        .doc(deviceDocumentId);
    let isNew = false;
    const authTimeSeconds = Number(request.auth.token.auth_time);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(deviceRef);
      isNew = !snapshot.exists;
      transaction.set(deviceRef, {
        ownerUid: identity.uid,
        label: device.label,
        platform: device.platform,
        status: "active",
        lastSeenAt: FieldValue.serverTimestamp(),
        lastAuthenticationAt: Number.isFinite(authTimeSeconds) &&
            authTimeSeconds > 0 ?
          admin.firestore.Timestamp.fromMillis(authTimeSeconds * 1000) :
          FieldValue.serverTimestamp(),
        revokedAt: FieldValue.delete(),
        ...(!snapshot.exists ?
          {firstSeenAt: FieldValue.serverTimestamp()} : {}),
      }, {merge: true});
      if (isNew) {
        transaction.create(
            db.collection("users").doc(identity.uid)
                .collection("notifications")
                .doc(`new-device-${deviceDocumentId}`),
            {
              recipientUid: identity.uid,
              type: "new_device",
              title: "New device remembered",
              message: `${device.label} was added to your account device history.`,
              read: false,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
      }
    });
    return {deviceDocumentId, isNew};
  });

  const checkAccountDeletionReadiness = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    requireRecentAuthentication(request);
    requireDeletionConfirmation(request.data);
    await enforceUserRateLimit({db, admin, request, scope: "privacy"});
    const [userSnapshot, authUser] = await Promise.all([
      db.collection("users").doc(identity.uid).get(),
      admin.auth().getUser(identity.uid),
    ]);
    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "Complete your account profile first.");
    }
    const results = await deletionBlockers(db, identity.uid);
    requireNoDeletionBlockers(results);
    const providerIds = authUser.providerData
      .map((provider) => String(provider.providerId || "").toLowerCase())
      .filter(Boolean);
    const requiresAppleRevocation = providerIds.includes("apple.com");
    let appleDeletionAuthorizationId = null;
    if (requiresAppleRevocation) {
      appleDeletionAuthorizationId = crypto.randomUUID();
      const nowMillis = Date.now();
      await db
        .collection("account_deletion_authorizations")
        .doc(identity.uid)
        .set({
          ownerUid: identity.uid,
          authorizationId: appleDeletionAuthorizationId,
          status: "pending_apple_revocation",
          initialAuthTimeSeconds: Number(request.auth.token.auth_time),
          issuedAt: admin.firestore.Timestamp.fromMillis(nowMillis),
          expiresAt: admin.firestore.Timestamp.fromMillis(
            nowMillis + APPLE_DELETION_AUTHORIZATION_MINUTES * 60 * 1000,
          ),
        });
    }
    return {
      eligible: true,
      providerIds,
      requiresAppleRevocation,
      appleDeletionAuthorizationId,
      allowedModes: requiresAppleRevocation
        ? ["immediate"]
        : ["immediate", "scheduled"],
    };
  });

  const requestAccountDeletion = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    requireRecentAuthentication(request);
    requireDeletionConfirmation(request.data);
    const mode = normalizeDeletionMode(request.data);
    await enforceUserRateLimit({db, admin, request, scope: "privacy"});
    const [userSnapshot, authUser] = await Promise.all([
      db.collection("users").doc(identity.uid).get(),
      admin.auth().getUser(identity.uid),
    ]);
    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "Complete your account profile first.");
    }
    const providerIds = authUser.providerData
      .map((provider) => String(provider.providerId || "").toLowerCase());
    const usesApple = providerIds.includes("apple.com");
    if (usesApple && mode !== "immediate") {
      throw new HttpsError(
        "failed-precondition",
        "Apple-linked accounts must use immediate deletion so Apple authorization can be revoked during reauthentication.",
      );
    }
    const results = await deletionBlockers(db, identity.uid);
    requireNoDeletionBlockers(results);
    const now = Date.now();
    const deleteAt = admin.firestore.Timestamp.fromMillis(
      mode === "immediate"
        ? now + DELETION_MUTATION_DRAIN_MINUTES * 60 * 1000
        : now + DELETION_GRACE_DAYS * 24 * 60 * 60 * 1000,
    );
    const requestRef = db
      .collection("account_deletion_requests")
      .doc(identity.uid);
    const userRef = db.collection("users").doc(identity.uid);
    const appleAuthorizationRef = db
      .collection("account_deletion_authorizations")
      .doc(identity.uid);
    const appleDeletionAuthorizationId = String(
      (request.data && request.data.appleDeletionAuthorizationId) || "",
    );
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(requestRef);
      const currentUser = await transaction.get(userRef);
      const appleAuthorization = usesApple
        ? await transaction.get(appleAuthorizationRef)
        : null;
      if (!currentUser.exists) {
        throw new HttpsError("not-found", "Complete your account profile first.");
      }
      if (usesApple) {
        requireAppleDeletionAuthorization({
          authorization: appleAuthorization.exists
            ? appleAuthorization.data()
            : null,
          authorizationId: appleDeletionAuthorizationId,
          authTimeSeconds: Number(request.auth.token.auth_time),
          nowMillis: now,
          uid: identity.uid,
        });
      }
      const revision =
        Number((existing.data() && existing.data().revision) || 0) + 1;
      transaction.set(
        requestRef,
        {
          ownerUid: identity.uid,
          status: "scheduled",
          mode,
          revision,
          policyVersion: DELETION_POLICY_VERSION,
          requestedAt: FieldValue.serverTimestamp(),
          deleteAt,
          blockerSnapshot: results,
          phoneRegistryKey: String(
            currentUser.data().phoneRegistryKey || "",
          ),
          appleDeletionAuthorizationId: usesApple
            ? appleDeletionAuthorizationId
            : null,
        },
        { merge: false },
      );
      if (usesApple) {
        transaction.update(appleAuthorizationRef, {
          status: "consumed",
          consumedAt: FieldValue.serverTimestamp(),
          requestRevision: revision,
        });
      }
      if (mode === "immediate") {
        transaction.set(
          db.collection("account_deletion_tombstones").doc(identity.uid),
          {
            ownerUid: identity.uid,
            requestRevision: revision,
            status: "processing",
            createdAt: FieldValue.serverTimestamp(),
            deleteAfterAt: FieldValue.delete(),
          },
          {merge: true},
        );
      }
      transaction.set(
        userRef,
        {
          accountStatus: mode === "immediate"
            ? "deletion_processing"
            : "deletion_scheduled",
          deletionScheduledAt: deleteAt,
        },
        { merge: true },
      );
      transaction.set(
        db
          .collection("users")
          .doc(identity.uid)
          .collection("notifications")
          .doc(`deletion-${revision}`),
        {
          recipientUid: identity.uid,
          type: mode === "immediate"
            ? "account_deletion_processing"
            : "account_deletion_scheduled",
          title: mode === "immediate"
            ? "Account deletion requested"
            : "Account deletion scheduled",
          message: mode === "immediate"
            ? "Immediate account deletion is now processing. You will be signed out and cannot cancel this request."
            : `Your account is scheduled for deletion in ${DELETION_GRACE_DAYS} days. You can cancel before that date.`,
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        },
      );
    });
    if (mode === "immediate") {
      try {
        await admin.auth().updateUser(identity.uid, {disabled: true});
        await admin.auth().revokeRefreshTokens(identity.uid);
      } catch (error) {
        // The durable due-now deletion request is authoritative. The frequent
        // worker will retry final cleanup even if session shutdown is briefly
        // unavailable, while the client signs out locally.
        console.error(
          "Immediate deletion queued but session shutdown is pending",
          error,
        );
      }
      return {
        status: "processing",
        mode,
        deleteAt: deleteAt.toDate().toISOString(),
      };
    }
    return {
      status: "scheduled",
      mode,
      deleteAt: deleteAt.toDate().toISOString(),
    };
  });

  const cancelAccountDeletion = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    requireRecentAuthentication(request);
    await enforceUserRateLimit({ db, admin, request, scope: "privacy" });
    const requestRef = db
      .collection("account_deletion_requests")
      .doc(identity.uid);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(requestRef);
      if (!snapshot.exists || snapshot.data().status !== "scheduled") {
        throw new HttpsError(
          "failed-precondition",
          "No scheduled deletion is available to cancel.",
        );
      }
      if (snapshot.data().mode === "immediate") {
        throw new HttpsError(
          "failed-precondition",
          "Immediate account deletion cannot be cancelled.",
        );
      }
      transaction.update(requestRef, {
        status: "cancelled",
        cancelledAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        db.collection("users").doc(identity.uid),
        {
          accountStatus: "active",
          deletionScheduledAt: FieldValue.delete(),
        },
        { merge: true },
      );
    });
    return { status: "cancelled" };
  });

  async function cleanupExpiredAccountExports(batchLimit = 20) {
    const expired = await db
      .collection("account_exports")
      .where("expiresAt", "<=", admin.firestore.Timestamp.now())
      .limit(batchLimit)
      .get();
    for (const snapshot of expired.docs) await db.recursiveDelete(snapshot.ref);
    return expired.size;
  }

  async function cleanupExpiredAccountDeletionAuthorizations(batchLimit = 200) {
    const expired = await db
        .collection("account_deletion_authorizations")
        .where("expiresAt", "<=", admin.firestore.Timestamp.now())
        .limit(batchLimit)
        .get();
    for (const snapshot of expired.docs) await db.recursiveDelete(snapshot.ref);
    return expired.size;
  }

  async function cleanupStaleAccountDevices(batchLimit = 200) {
    const cutoff = admin.firestore.Timestamp.fromMillis(
        Date.now() - DEVICE_HISTORY_DAYS * 24 * 60 * 60 * 1000,
    );
    const stale = await db
        .collectionGroup("account_devices")
        .where("lastSeenAt", "<=", cutoff)
        .limit(batchLimit)
        .get();
    if (stale.empty) return 0;
    const batch = db.batch();
    for (const document of stale.docs) batch.delete(document.ref);
    await batch.commit();
    return stale.size;
  }

  async function claimAccountDeletion(requestRef) {
    const nowMillis = Date.now();
    const claimId = crypto.randomUUID();
    return db.runTransaction(async (transaction) => {
      const requestSnapshot = await transaction.get(requestRef);
      if (
        !requestSnapshot.exists ||
        !deletionRequestCanBeClaimed(requestSnapshot.data(), nowMillis)
      ) {
        return null;
      }
      const uid = requestSnapshot.id;
      const userRef = db.collection("users").doc(uid);
      const tombstoneRef = db
        .collection("account_deletion_tombstones")
        .doc(uid);
      const [userSnapshot, tombstoneSnapshot] = await Promise.all([
        transaction.get(userRef),
        transaction.get(tombstoneRef),
      ]);
      const requestData = requestSnapshot.data();
      const quiescencePending = !tombstoneSnapshot.exists;
      const phoneRegistryKey = String(
        requestData.phoneRegistryKey ||
          (userSnapshot.exists && userSnapshot.data().phoneRegistryKey) ||
          "",
      );
      transaction.update(requestRef, {
        status: "processing",
        claimId,
        processingStartedAt:
          requestData.processingStartedAt || FieldValue.serverTimestamp(),
        processingLeaseExpiresAt: admin.firestore.Timestamp.fromMillis(
          nowMillis +
            (quiescencePending
              ? DELETION_MUTATION_DRAIN_MINUTES
              : DELETION_PROCESSING_LEASE_MINUTES) *
              60 *
              1000,
        ),
        phoneRegistryKey,
      });
      transaction.set(
        tombstoneRef,
        {
          ownerUid: uid,
          requestRevision: Number(requestData.revision || 0),
          status: "processing",
          ...(quiescencePending
            ? {createdAt: FieldValue.serverTimestamp()}
            : {}),
          deleteAfterAt: FieldValue.delete(),
        },
        {merge: true},
      );
      return {
        ...requestData,
        claimId,
        phoneRegistryKey,
        quiescencePending,
        uid,
      };
    });
  }

  async function blockAccountDeletionClaim(requestRef, claimId, blockers) {
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(requestRef);
      if (
        !current.exists ||
        current.data().status !== "processing" ||
        current.data().claimId !== claimId
      ) {
        return;
      }
      const uid = current.id;
      const userRef = db.collection("users").doc(uid);
      const userSnapshot = await transaction.get(userRef);
      transaction.update(requestRef, {
        status: "blocked",
        blockers,
        blockedAt: FieldValue.serverTimestamp(),
        claimId: FieldValue.delete(),
        processingLeaseExpiresAt: FieldValue.delete(),
      });
      transaction.delete(
        db.collection("account_deletion_tombstones").doc(uid),
      );
      if (userSnapshot.exists) {
        transaction.set(
          userRef,
          {
            accountStatus: "deletion_blocked",
            deletionScheduledAt: FieldValue.delete(),
          },
          {merge: true},
        );
      }
    });
  }

  async function recoverBlockedAccountDeletion(
      requestRef,
      claim,
      blockers,
      authUser,
  ) {
    if (claim.mode === "immediate" && authUser) {
      // A callable that passed the shared guard just before the tombstone can
      // still finish and create a new obligation. Restore sign-in before
      // removing the tombstone so the owner can resolve that obligation and
      // make a new deletion request. This is automatic failure recovery, not
      // a user cancellation of an accepted immediate deletion.
      await admin.auth().updateUser(claim.uid, {disabled: false});
    }
    await blockAccountDeletionClaim(requestRef, claim.claimId, blockers);
  }

  async function completeAccountDeletionClaim(requestRef, claim) {
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(requestRef);
      if (
        !current.exists ||
        current.data().status !== "processing" ||
        current.data().claimId !== claim.claimId
      ) {
        return false;
      }
      const subjectHash = crypto
        .createHash("sha256")
        .update(claim.uid)
        .digest("hex");
      transaction.set(
        db.collection("account_deletion_tombstones").doc(claim.uid),
        {
          ownerUid: claim.uid,
          status: "completed",
          completedAt: FieldValue.serverTimestamp(),
          deleteAfterAt: admin.firestore.Timestamp.fromMillis(
            Date.now() + DELETION_TOMBSTONE_RETENTION_HOURS * 60 * 60 * 1000,
          ),
        },
        {merge: true},
      );
      transaction.set(
        db.collection("account_deletion_audits").doc(subjectHash),
        {
          subjectHash,
          policyVersion: DELETION_POLICY_VERSION,
          mode: String(claim.mode || "scheduled"),
          completedAt: FieldValue.serverTimestamp(),
        },
      );
      transaction.delete(requestRef);
      return true;
    });
  }

  async function cleanupExpiredDeletionTombstones(batchLimit = 200) {
    const expired = await db
      .collection("account_deletion_tombstones")
      .where("deleteAfterAt", "<=", admin.firestore.Timestamp.now())
      .limit(batchLimit)
      .get();
    if (expired.empty) return 0;
    let removed = 0;
    for (const document of expired.docs) {
      // A resumable upload authorized before the tombstone may finish after
      // the initial account-deletion sweep. Repeat the owner-scoped cleanup
      // immediately before removing the final cached-token barrier.
      await deleteOwnedAccountMedia(document.id);
      await document.ref.delete();
      removed += 1;
    }
    return removed;
  }

  async function deleteOwnedAccountMedia(uid) {
    await Promise.all([
      admin
        .storage()
        .bucket()
        .deleteFiles({prefix: `profile_media/${uid}/`}),
      admin
        .storage()
        .bucket()
        .deleteFiles({prefix: `listing_media/${uid}/`}),
      admin
        .storage()
        .bucket()
        .deleteFiles({prefix: `business_documents/${uid}/`}),
      admin
        .storage()
        .bucket()
        .deleteFiles({prefix: `business_logos/${uid}/`}),
    ]);
  }

  async function finalizeScheduledAccountDeletions(batchLimit = 10) {
    const due = await db
      .collection("account_deletion_requests")
      .where("status", "in", ["scheduled", "processing"])
      .where("deleteAt", "<=", admin.firestore.Timestamp.now())
      .limit(batchLimit)
      .get();
    let completed = 0;
    for (const snapshot of due.docs) {
      const uid = snapshot.id;
      const claim = await claimAccountDeletion(snapshot.ref);
      if (!claim) continue;
      // Scheduled requests receive their tombstone only when they become due.
      // Give every pre-existing callable time to finish before reading final
      // blockers or performing destructive cleanup. Immediate requests have
      // already observed this drain through their delayed deleteAt timestamp.
      if (claim.quiescencePending) continue;
      let authUser = null;
      try {
        authUser = await admin.auth().getUser(uid);
      } catch (error) {
        if (error.code !== "auth/user-not-found") throw error;
      }
      const usesApple = authUser && authUser.providerData.some(
        (provider) => String(provider.providerId || "").toLowerCase() === "apple.com",
      );
      if (
        usesApple &&
        (typeof claim.appleDeletionAuthorizationId !== "string" ||
          !claim.appleDeletionAuthorizationId)
      ) {
        await recoverBlockedAccountDeletion(snapshot.ref, claim, [
          {
            key: "appleTokenRevocation",
            label: "Sign in with Apple authorization revocation",
            count: 1,
          },
        ], authUser);
        continue;
      }
      const blockers = await deletionBlockers(db, uid);
      const blockerSummary = summarizeDeletionBlockers(blockers);
      if (blockerSummary.length) {
        await recoverBlockedAccountDeletion(
          snapshot.ref,
          claim,
          blockerSummary,
          authUser,
        );
        continue;
      }
      if (authUser) {
        await admin.auth().updateUser(uid, {disabled: true});
        await admin.auth().revokeRefreshTokens(uid);
      }
      await anonymizeListings(db, uid, FieldValue);
      // Finish cross-service media cleanup first. A Storage outage therefore
      // leaves the processing request and its lease intact and safely retryable.
      await deleteOwnedAccountMedia(uid);
      if (claim.phoneRegistryKey) {
        await db
          .collection("account_phone_registry")
          .doc(claim.phoneRegistryKey)
          .delete();
      }
      await Promise.all([
        db.recursiveDelete(db.collection("users").doc(uid)),
        db.recursiveDelete(
            db.collection("account_deletion_authorizations").doc(uid),
        ),
        db.recursiveDelete(db.collection("public_seller_profiles").doc(uid)),
        db.recursiveDelete(db.collection("public_business_profiles").doc(uid)),
        db.recursiveDelete(db.collection("business_private").doc(uid)),
        db.recursiveDelete(db.collection("verification_requests").doc(uid)),
        db.recursiveDelete(db.collection("dispatch_carriers").doc(uid)),
        deleteMatching(
          db,
          "marketplace_listing_drafts",
          ["sellerUid"],
          uid,
        ),
        deleteMatching(db, "verification_review_events", ["userUid"], uid),
        deleteMatching(
          db,
          "dispatch_provider_review_events",
          ["providerUid"],
          uid,
        ),
        deleteMatching(db, "media_upload_authorizations", ["ownerUid"], uid),
        deleteMatching(db, "account_exports", ["ownerUid"], uid),
      ]);
      try {
        await admin.auth().deleteUser(uid);
      } catch (error) {
        if (error.code !== "auth/user-not-found") throw error;
      }
      if (await completeAccountDeletionClaim(snapshot.ref, claim)) completed += 1;
    }
    return completed;
  }

  return {
    cancelAccountDeletion,
    checkAccountDeletionReadiness,
    cleanupExpiredAccountDeletionAuthorizations,
    cleanupExpiredDeletionTombstones,
    cleanupExpiredAccountExports,
    cleanupStaleAccountDevices,
    finalizeScheduledAccountDeletions,
    registerAccountDevice,
    requestAccountDataExport,
    requestAccountDeletion,
    revokeAccountSessions,
  };
}

module.exports = {
  accountDeviceDocumentId,
  buildAccountExport,
  createAccountPrivacyCommands,
  deletionRequestCanBeClaimed,
  deletionBlockers,
  normalizeExportValue,
  requireAppleDeletionAuthorization,
};
