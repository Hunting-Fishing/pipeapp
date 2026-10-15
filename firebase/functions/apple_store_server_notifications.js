"use strict";

const crypto = require("node:crypto");
const {
  APPLE_APP_ID,
  AppleStoreServerValidationError,
  isAppleVerificationError,
  isRetryableAppleVerificationError,
  normalizeAccountToken,
} = require("./apple_store_server_client");
const {
  APPLE_BUNDLE_ID,
  appleNativeMembershipProduct,
} = require("./native_membership_policy");

const NOTIFICATION_COLLECTION = "app_store_notification_events";
const ACCOUNT_TOKEN_COLLECTION = "native_membership_account_tokens";
const DEFAULT_NOTIFICATION_LEASE_MILLIS = 5 * 60 * 1000;
const DEFAULT_NOTIFICATION_RETENTION_MILLIS = 35 * 24 * 60 * 60 * 1000;
const MAX_SIGNED_PAYLOAD_LENGTH = 200000;

class AppStoreNotificationError extends Error {
  constructor(code, message, {httpStatus = 500, retryable = true} = {}) {
    super(message);
    this.name = "AppStoreNotificationError";
    this.code = code;
    this.httpStatus = httpStatus;
    this.retryable = retryable;
  }
}

function notificationDocumentId(notificationUUID) {
  return crypto.createHash("sha256")
      .update(String(notificationUUID || "").toLowerCase(), "utf8")
      .digest("hex");
}

function accountTokenDocumentId(accountToken) {
  return crypto.createHash("sha256")
      .update(normalizeAccountToken(accountToken), "utf8")
      .digest("hex");
}

function validNotificationUUID(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(String(value || "").trim());
}

function safeEventText(value, maximumLength = 80) {
  return String(value || "").replace(/[^a-zA-Z0-9_.:-]/g, "_")
      .slice(0, maximumLength);
}

function createFirestoreNotificationEventStore({
  db,
  admin,
  now = () => Date.now(),
  leaseMillis = DEFAULT_NOTIFICATION_LEASE_MILLIS,
  retentionMillis = DEFAULT_NOTIFICATION_RETENTION_MILLIS,
}) {
  if (!db || typeof db.runTransaction !== "function" ||
      !admin || !admin.firestore || !admin.firestore.FieldValue ||
      !admin.firestore.Timestamp ||
      typeof admin.firestore.Timestamp.fromMillis !== "function") {
    throw new TypeError("Firestore notification event store is not configured.");
  }
  if (!Number.isFinite(retentionMillis) ||
      retentionMillis < DEFAULT_NOTIFICATION_RETENTION_MILLIS) {
    throw new RangeError("App Store notification retention is too short.");
  }
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;
  const retentionExpiresAt = () => Timestamp.fromMillis(now() + retentionMillis);

  return {
    async begin(event) {
      const notificationUUID = String(event.notificationUUID || "").toLowerCase();
      const ref = db.collection(NOTIFICATION_COLLECTION)
          .doc(notificationDocumentId(notificationUUID));
      const leaseId = crypto.randomUUID();
      return db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const existing = snapshot.exists ? snapshot.data() : {};
        const status = String(existing.status || "");
        if (new Set(["processed", "ignored"]).has(status)) {
          return {state: "duplicate"};
        }
        if (status === "processing" &&
            Number(existing.leaseExpiresAtMillis || 0) > now()) {
          return {state: "in_progress"};
        }
        transaction.set(ref, {
          notificationUUID,
          notificationType: safeEventText(event.notificationType),
          subtype: safeEventText(event.subtype),
          environment: safeEventText(event.environment),
          status: "processing",
          leaseId,
          attemptCount: Number(existing.attemptCount || 0) + 1,
          leaseExpiresAtMillis: now() + leaseMillis,
          retentionExpiresAt: retentionExpiresAt(),
          updatedAt: FieldValue.serverTimestamp(),
          ...(snapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
        }, {merge: true});
        return {state: "acquired", leaseId};
      });
    },

    async complete(notificationUUID, outcome, claim) {
      const ref = db.collection(NOTIFICATION_COLLECTION)
          .doc(notificationDocumentId(notificationUUID));
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const existing = snapshot.exists ? snapshot.data() : {};
        if (existing.status !== "processing" || !claim ||
            existing.leaseId !== claim.leaseId) {
          throw new AppStoreNotificationError(
              "notification_lease_lost",
              "The App Store notification processing lease was lost.",
              {httpStatus: 409, retryable: true},
          );
        }
        transaction.set(ref, {
          status: outcome.status === "ignored" ? "ignored" : "processed",
          outcome: safeEventText(outcome.outcome),
          ownerUidHash: outcome.ownerUid ?
            crypto.createHash("sha256").update(String(outcome.ownerUid))
                .digest("hex") : "",
          leaseId: "",
          leaseExpiresAtMillis: 0,
          retentionExpiresAt: retentionExpiresAt(),
          processedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
    },

    async fail(notificationUUID, error, claim) {
      const ref = db.collection(NOTIFICATION_COLLECTION)
          .doc(notificationDocumentId(notificationUUID));
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const existing = snapshot.exists ? snapshot.data() : {};
        if (existing.status !== "processing" || !claim ||
            existing.leaseId !== claim.leaseId) {
          return;
        }
        transaction.set(ref, {
          status: "failed",
          lastErrorCode: safeEventText(
              error && error.code || "notification_failed",
          ),
          retryable: error && error.retryable !== false,
          leaseId: "",
          leaseExpiresAtMillis: 0,
          retentionExpiresAt: retentionExpiresAt(),
          lastFailedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
    },
  };
}

function createNativeMembershipOwnerResolver({db}) {
  if (!db || typeof db.collection !== "function") {
    throw new TypeError("Native membership owner resolver is not configured.");
  }
  return async (accountToken) => {
    const normalizedToken = normalizeAccountToken(accountToken);
    if (!normalizedToken) return "";
    const indexSnapshot = await db.collection(ACCOUNT_TOKEN_COLLECTION)
        .doc(accountTokenDocumentId(normalizedToken)).get();
    if (indexSnapshot.exists) {
      const indexed = indexSnapshot.data() || {};
      if (normalizeAccountToken(indexed.storeAccountToken) !== normalizedToken) {
        throw new AppStoreNotificationError(
            "account_token_index_mismatch",
            "The native membership account index is inconsistent.",
        );
      }
      return String(indexed.ownerUid || "").trim();
    }

    // Temporary activation fallback for accounts created before the reverse
    // index existed. The runbook requires a backfill before production enablement.
    const matches = await db.collection("native_membership_accounts")
        .where("storeAccountToken", "==", normalizedToken)
        .limit(2)
        .get();
    if (matches.size > 1) {
      throw new AppStoreNotificationError(
          "account_token_not_unique",
          "The native membership account token is not unique.",
      );
    }
    return matches.empty ? "" : String(matches.docs[0].id || "").trim();
  };
}

function notificationTerminalStatus(notificationType) {
  const type = String(notificationType || "");
  if (type === "REFUND") return "refunded";
  if (type === "REVOKE") return "revoked";
  if (new Set(["EXPIRED", "GRACE_PERIOD_EXPIRED"]).has(type)) return "expired";
  return "inactive";
}

function environmentMatches(value, expectedEnvironment) {
  return String(value || "").toLowerCase() ===
    String(expectedEnvironment || "").toLowerCase();
}

function createAppStoreServerNotificationProcessor({
  expectedEnvironment,
  verifier,
  eventStore,
  resolveOwnerByAccountToken,
  authorizeOwnerForEnvironment,
  mutationEnabled,
  beginReconciliation,
  loadProviderState,
  reconcileSubscription,
  applyNativeEntitlement,
  clearExpiredNativeEntitlement,
}) {
  const dependencies = [
    verifier && verifier.verifyAndDecodeNotification,
    verifier && verifier.verifyAndDecodeTransaction,
    eventStore && eventStore.begin,
    eventStore && eventStore.complete,
    eventStore && eventStore.fail,
    resolveOwnerByAccountToken,
    authorizeOwnerForEnvironment,
    mutationEnabled,
    beginReconciliation,
    loadProviderState,
    reconcileSubscription,
    applyNativeEntitlement,
    clearExpiredNativeEntitlement,
  ];
  if (dependencies.some((dependency) => typeof dependency !== "function")) {
    throw new TypeError("App Store notification processor is not configured.");
  }

  return async (signedPayload) => {
    const decoded = await verifier.verifyAndDecodeNotification(signedPayload);
    const notificationUUID = String(decoded && decoded.notificationUUID || "")
        .trim().toLowerCase();
    if (!validNotificationUUID(notificationUUID)) {
      throw new AppStoreNotificationError(
          "notification_uuid_invalid",
          "The App Store notification identifier is invalid.",
          {httpStatus: 400, retryable: false},
      );
    }
    const data = decoded && decoded.data || {};
    const notificationType = String(decoded && decoded.notificationType || "");
    const subtype = String(decoded && decoded.subtype || "");
    if (data.environment && !environmentMatches(data.environment, expectedEnvironment)) {
      throw new AppStoreNotificationError(
          "notification_environment_mismatch",
          "The App Store notification environment did not match this endpoint.",
          {httpStatus: 400, retryable: false},
      );
    }
    if (data.bundleId && String(data.bundleId) !== APPLE_BUNDLE_ID) {
      throw new AppStoreNotificationError(
          "notification_bundle_mismatch",
          "The App Store notification bundle did not match this app.",
          {httpStatus: 400, retryable: false},
      );
    }
    if (String(expectedEnvironment).toLowerCase() === "production" &&
        data.appAppleId && Number(data.appAppleId) !== APPLE_APP_ID) {
      throw new AppStoreNotificationError(
          "notification_app_id_mismatch",
          "The App Store notification app identifier did not match this app.",
          {httpStatus: 400, retryable: false},
      );
    }

    if (notificationType !== "TEST") {
      const enabled = await mutationEnabled({
        expectedEnvironment,
        notificationType,
        subtype,
      });
      if (enabled !== true) {
        throw new AppStoreNotificationError(
            "notification_mutation_disabled",
            "App Store lifecycle processing is not enabled for this environment.",
            {httpStatus: 503, retryable: true},
        );
      }
    }

    const claim = await eventStore.begin({
      notificationUUID,
      notificationType,
      subtype,
      environment: data.environment || expectedEnvironment,
    });
    if (claim.state === "duplicate") {
      return {status: "duplicate", notificationUUID};
    }
    if (claim.state !== "acquired") {
      throw new AppStoreNotificationError(
          "notification_in_progress",
          "The App Store notification is already being processed.",
          {httpStatus: 409, retryable: true},
      );
    }

    try {
      if (notificationType === "TEST") {
        await eventStore.complete(notificationUUID, {
          status: "processed",
          outcome: "test_verified",
        }, claim);
        return {status: "processed", outcome: "test_verified", notificationUUID};
      }

      const signedTransactionInfo = String(data.signedTransactionInfo || "").trim();
      if (!signedTransactionInfo) {
        await eventStore.complete(notificationUUID, {
          status: "ignored",
          outcome: "no_subscription_transaction",
        }, claim);
        return {
          status: "ignored",
          outcome: "no_subscription_transaction",
          notificationUUID,
        };
      }
      const transaction = await verifier.verifyAndDecodeTransaction(
          signedTransactionInfo,
      );
      if (String(transaction.bundleId || "") !== APPLE_BUNDLE_ID ||
          !environmentMatches(transaction.environment, expectedEnvironment)) {
        throw new AppStoreNotificationError(
            "notification_transaction_mismatch",
            "The signed App Store transaction did not match this app.",
            {httpStatus: 400, retryable: false},
        );
      }
      const product = appleNativeMembershipProduct(transaction.productId);
      if (!product) {
        await eventStore.complete(notificationUUID, {
          status: "ignored",
          outcome: "product_not_configured",
        }, claim);
        return {
          status: "ignored",
          outcome: "product_not_configured",
          notificationUUID,
        };
      }
      const accountToken = normalizeAccountToken(transaction.appAccountToken);
      const originalTransactionId = String(
          transaction.originalTransactionId || "",
      ).trim();
      if (!accountToken || !originalTransactionId) {
        throw new AppStoreNotificationError(
            "notification_account_binding_missing",
            "The App Store transaction cannot be mapped to a Pipe Buyer account.",
        );
      }
      const uid = await resolveOwnerByAccountToken(accountToken);
      if (!uid) {
        throw new AppStoreNotificationError(
            "notification_account_not_found",
            "The App Store transaction account could not be resolved.",
            {httpStatus: 503, retryable: true},
        );
      }
      const ownerAuthorized = await authorizeOwnerForEnvironment({
        uid,
        accountToken,
        expectedEnvironment,
      });
      if (!ownerAuthorized) {
        await eventStore.complete(notificationUUID, {
          status: "ignored",
          outcome: "environment_owner_not_authorized",
          ownerUid: uid,
        }, claim);
        return {
          status: "ignored",
          outcome: "environment_owner_not_authorized",
          notificationUUID,
        };
      }

      // Query the current subscription state rather than trusting event order.
      // Apple may deliver retries or lifecycle notifications out of order.
      const reconciliationGeneration = await beginReconciliation({uid});
      const entitlement = await reconcileSubscription({
        originalTransactionId,
        accountToken,
        expectedEnvironment,
      });
      if (entitlement) {
        if (String(entitlement.originalTransactionId || "") !==
            originalTransactionId) {
          throw new AppStoreNotificationError(
              "notification_reconciliation_mismatch",
              "The reconciled App Store subscription did not match the event.",
          );
        }
        const applied = await applyNativeEntitlement({
          uid,
          accountToken,
          entitlement,
          reconciliationGeneration,
        });
        if (applied === false) {
          await eventStore.complete(notificationUUID, {
            status: "ignored",
            outcome: "stale_entitlement_preserved",
            ownerUid: uid,
          }, claim);
          return {
            status: "ignored",
            outcome: "stale_entitlement_preserved",
            notificationUUID,
          };
        }
        await eventStore.complete(notificationUUID, {
          status: "processed",
          outcome: "entitlement_applied",
          ownerUid: uid,
        }, claim);
        return {
          status: "processed",
          outcome: "entitlement_applied",
          notificationUUID,
        };
      }

      const providerState = await loadProviderState(uid);
      const providerMatches = providerState &&
        providerState.ownerUid === uid &&
        providerState.provider === "app_store" &&
        String(providerState.originalTransactionId || "") === originalTransactionId;
      if (!providerMatches) {
        await eventStore.complete(notificationUUID, {
          status: "ignored",
          outcome: "no_matching_entitlement",
          ownerUid: uid,
        }, claim);
        return {
          status: "ignored",
          outcome: "no_matching_entitlement",
          notificationUUID,
        };
      }
      const cleared = await clearExpiredNativeEntitlement({
        uid,
        providerState,
        terminalStatus: notificationTerminalStatus(notificationType),
        reconciliationGeneration,
      });
      if (cleared === false) {
        await eventStore.complete(notificationUUID, {
          status: "ignored",
          outcome: "stale_entitlement_preserved",
          ownerUid: uid,
        }, claim);
        return {
          status: "ignored",
          outcome: "stale_entitlement_preserved",
          notificationUUID,
        };
      }
      await eventStore.complete(notificationUUID, {
        status: "processed",
        outcome: "entitlement_cleared",
        ownerUid: uid,
      }, claim);
      return {
        status: "processed",
        outcome: "entitlement_cleared",
        notificationUUID,
      };
    } catch (error) {
      await eventStore.fail(notificationUUID, error, claim);
      throw error;
    }
  };
}

function createAppStoreServerNotificationHttpHandler({
  processNotification,
  verificationError = isAppleVerificationError,
  retryableVerificationError = isRetryableAppleVerificationError,
}) {
  if (typeof processNotification !== "function") {
    throw new TypeError("App Store notification HTTP handler is not configured.");
  }
  return async (request, response) => {
    if (request.method !== "POST") {
      response.set("Allow", "POST");
      response.status(405).send({ok: false, code: "method_not_allowed"});
      return;
    }
    const signedPayload = String(
        request.body && request.body.signedPayload || "",
    ).trim();
    if (signedPayload.length < 64 || signedPayload.length > MAX_SIGNED_PAYLOAD_LENGTH) {
      response.status(400).send({ok: false, code: "signed_payload_invalid"});
      return;
    }
    try {
      const result = await processNotification(signedPayload);
      response.status(200).send({ok: true, status: result.status});
    } catch (error) {
      if (error instanceof AppStoreNotificationError) {
        response.status(error.httpStatus).send({ok: false, code: error.code});
        return;
      }
      if (error instanceof AppleStoreServerValidationError) {
        response.status(400).send({ok: false, code: error.code});
        return;
      }
      if (verificationError(error)) {
        const retryable = retryableVerificationError(error);
        response.status(retryable ? 503 : 400).send({
          ok: false,
          code: retryable ? "verification_temporarily_unavailable" :
            "signed_payload_verification_failed",
        });
        return;
      }
      response.status(500).send({ok: false, code: "notification_processing_failed"});
    }
  };
}

module.exports = {
  ACCOUNT_TOKEN_COLLECTION,
  AppStoreNotificationError,
  DEFAULT_NOTIFICATION_LEASE_MILLIS,
  DEFAULT_NOTIFICATION_RETENTION_MILLIS,
  MAX_SIGNED_PAYLOAD_LENGTH,
  NOTIFICATION_COLLECTION,
  accountTokenDocumentId,
  createAppStoreServerNotificationHttpHandler,
  createAppStoreServerNotificationProcessor,
  createFirestoreNotificationEventStore,
  createNativeMembershipOwnerResolver,
  notificationDocumentId,
  notificationTerminalStatus,
  validNotificationUUID,
};
