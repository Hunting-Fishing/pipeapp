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
  EXPORT_RETENTION_DAYS,
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
const DELETION_POLICY_VERSION = 1;

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
      new Set(["archived", "withdrawn", "cancelled", "completed"]),
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
    await db.collection("account_privacy_events").add({
      ownerUid: identity.uid,
      type: "sessions_revoked",
      createdAt: FieldValue.serverTimestamp(),
    });
    return { revoked: true };
  });

  const requestAccountDeletion = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    requireRecentAuthentication(request);
    requireDeletionConfirmation(request.data);
    await enforceUserRateLimit({ db, admin, request, scope: "privacy" });
    const userSnapshot = await db.collection("users").doc(identity.uid).get();
    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "Complete your account profile first.");
    }
    const results = await deletionBlockers(db, identity.uid);
    requireNoDeletionBlockers(results);
    const now = Date.now();
    const deleteAt = admin.firestore.Timestamp.fromMillis(
      now + DELETION_GRACE_DAYS * 24 * 60 * 60 * 1000,
    );
    await db.runTransaction(async (transaction) => {
      const requestRef = db
        .collection("account_deletion_requests")
        .doc(identity.uid);
      const existing = await transaction.get(requestRef);
      const revision =
        Number((existing.data() && existing.data().revision) || 0) + 1;
      transaction.set(
        requestRef,
        {
          ownerUid: identity.uid,
          status: "scheduled",
          revision,
          policyVersion: DELETION_POLICY_VERSION,
          requestedAt: FieldValue.serverTimestamp(),
          deleteAt,
          blockerSnapshot: results,
        },
        { merge: false },
      );
      transaction.set(
        db.collection("users").doc(identity.uid),
        {
          accountStatus: "deletion_scheduled",
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
          type: "account_deletion_scheduled",
          title: "Account deletion scheduled",
          message: `Your account is scheduled for deletion in ${DELETION_GRACE_DAYS} days. You can cancel before that date.`,
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        },
      );
    });
    return { status: "scheduled", deleteAt: deleteAt.toDate().toISOString() };
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

  async function finalizeScheduledAccountDeletions(batchLimit = 10) {
    const due = await db
      .collection("account_deletion_requests")
      .where("status", "==", "scheduled")
      .where("deleteAt", "<=", admin.firestore.Timestamp.now())
      .limit(batchLimit)
      .get();
    let completed = 0;
    for (const snapshot of due.docs) {
      const uid = snapshot.id;
      const blockers = await deletionBlockers(db, uid);
      const blockerSummary = summarizeDeletionBlockers(blockers);
      if (blockerSummary.length) {
        await snapshot.ref.update({
          status: "blocked",
          blockers: blockerSummary,
          blockedAt: FieldValue.serverTimestamp(),
        });
        continue;
      }
      const userSnapshot = await db.collection("users").doc(uid).get();
      const phoneRegistryKey = userSnapshot.exists
        ? String(userSnapshot.data().phoneRegistryKey || "")
        : "";
      await anonymizeListings(db, uid, FieldValue);
      // Finish cross-service media cleanup first. A Storage outage therefore
      // leaves the scheduled request intact and safely retryable.
      await Promise.all([
        admin
          .storage()
          .bucket()
          .deleteFiles({ prefix: `profile_media/${uid}/` }),
        admin
          .storage()
          .bucket()
          .deleteFiles({ prefix: `listing_media/${uid}/` }),
        admin
          .storage()
          .bucket()
          .deleteFiles({ prefix: `business_documents/${uid}/` }),
      ]);
      await Promise.all([
        db.recursiveDelete(db.collection("users").doc(uid)),
        db.recursiveDelete(db.collection("public_seller_profiles").doc(uid)),
        db.recursiveDelete(db.collection("public_business_profiles").doc(uid)),
        db.recursiveDelete(db.collection("business_private").doc(uid)),
        db.recursiveDelete(db.collection("verification_requests").doc(uid)),
        db.recursiveDelete(db.collection("dispatch_carriers").doc(uid)),
        deleteMatching(db, "verification_review_events", ["userUid"], uid),
        deleteMatching(db, "account_exports", ["ownerUid"], uid),
      ]);
      if (phoneRegistryKey) {
        await db
          .collection("account_phone_registry")
          .doc(phoneRegistryKey)
          .delete();
      }
      try {
        await admin.auth().deleteUser(uid);
      } catch (error) {
        if (error.code !== "auth/user-not-found") throw error;
      }
      await snapshot.ref.delete();
      await db
        .collection("account_deletion_audits")
        .doc(crypto.createHash("sha256").update(uid).digest("hex"))
        .set({
          subjectHash: crypto.createHash("sha256").update(uid).digest("hex"),
          policyVersion: DELETION_POLICY_VERSION,
          completedAt: FieldValue.serverTimestamp(),
        });
      completed += 1;
    }
    return completed;
  }

  return {
    cancelAccountDeletion,
    cleanupExpiredAccountExports,
    finalizeScheduledAccountDeletions,
    requestAccountDataExport,
    requestAccountDeletion,
    revokeAccountSessions,
  };
}

module.exports = {
  buildAccountExport,
  createAccountPrivacyCommands,
  deletionBlockers,
  normalizeExportValue,
};
