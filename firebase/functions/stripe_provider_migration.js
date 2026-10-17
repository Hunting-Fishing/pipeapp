"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  providerUsesAccountsV2,
  recipientAccountReadiness,
  safePipeBuyerCallbackUrl,
  stripeAccountMode,
  stripeConnectRequest,
  stripeV2RecipientAccountPayload,
} = require("./stripe_marketplace_commands");
const {
  normalizeActiveStripeMode,
  requireStoredStripeMode,
  stripeSecretValueForMode,
} = require("./stripe_runtime_environment");

const PROVIDER_COLLECTION = "payment_provider_accounts";
const READINESS_COLLECTION = "platform_configuration";
const READINESS_DOCUMENT = "payment_provider_readiness";
const MAX_ATOMIC_MIGRATION_TRANSACTIONS = 400;

function safeIdentifier(value, field) {
  const id = String(value || "").trim();
  if (!id || id.length > 180 || id.includes("/")) {
    throw new HttpsError("invalid-argument", `${field} is missing or invalid.`);
  }
  return id;
}

function safeAccountId(value, field) {
  const id = safeIdentifier(value, field);
  if (!id.startsWith("acct_")) {
    throw new HttpsError(
        "invalid-argument",
        `${field} must be a Stripe connected-account ID.`,
    );
  }
  return id;
}

function safeReason(value) {
  const reason = String(value || "").trim();
  if (reason.length < 10 || reason.length > 1000) {
    throw new HttpsError(
        "invalid-argument",
        "A concise connected-account migration reason is required.",
    );
  }
  return reason;
}

function migrationIdempotencyKey(uid, legacyAccountId, mode) {
  const digest = crypto.createHash("sha256")
      .update(`pipebuyer-recipient-migration-v1:${uid}:${legacyAccountId}:${mode}`)
      .digest("hex");
  return `pipebuyer-recipient-migration-${digest}`;
}

function saleUsesStripeSellerSettlement(sale = {}) {
  return String(sale.settlementMode || "") === "stripe_checkout" ||
    String(sale.paymentMethod || "") === "stripe_checkout" ||
    Boolean(
        sale.stripeCheckoutAttemptId ||
        sale.stripeCheckoutSessionId ||
        sale.stripePaymentIntentId ||
        sale.stripeChargeId ||
        sale.stripeSellerTransferId ||
        sale.sellerReleaseRequestDestination,
    );
}

function legacyMigrationBlockingReasons(sale = {}) {
  if (!saleUsesStripeSellerSettlement(sale)) return [];
  const reasons = [];
  const providerStatus = String(sale.paymentProviderStatus || "");
  const payoutStatus = String(sale.sellerPayoutStatus || "");
  const refundState = String(sale.refundRequestState || "");
  const refundStatus = String(sale.refundStatus || "");
  const disputeStatus = String(sale.disputeStatus || "");
  if (sale.financialHold === true) reasons.push("financial_hold");
  if (refundState || refundStatus || Number(sale.refundedMinor || 0) > 0 ||
      Number(sale.refundPendingMinor || 0) > 0) {
    reasons.push("refund_history_or_request");
  }
  if (disputeStatus || (Array.isArray(sale.stripeDisputeIds) &&
      sale.stripeDisputeIds.length > 0)) {
    reasons.push("dispute_history_or_case");
  }
  if ([
    "release_reserved",
    "release_dispatching",
    "release_outcome_unknown",
    "release_invalidated_recovery_processing",
    "release_invalidated_recovery_required",
    "blocked_financial_hold",
    "blocked_seller_recovery",
  ].includes(payoutStatus)) {
    reasons.push("seller_release_or_recovery_in_progress");
  }
  const hasCharge = String(sale.stripeChargeId || "").startsWith("ch_");
  if (hasCharge && payoutStatus !== "released") {
    reasons.push("seller_proceeds_not_released");
  }
  if (!hasCharge && !["failed", "refunded"].includes(providerStatus)) {
    reasons.push("stripe_payment_not_terminal");
  }
  return [...new Set(reasons)];
}

function migrationTransactionPatch(sale, legacyAccountId, mode) {
  if (!saleUsesStripeSellerSettlement(sale)) return null;
  const existingMode = String(sale.stripeMode || "").trim();
  const existingDestination = String(
      sale.stripeSellerDestinationAccountId ||
      sale.sellerReleaseRequestDestination || "",
  ).trim();
  if (existingMode && existingMode !== mode) {
    throw new HttpsError(
        "failed-precondition",
        "A historical transaction belongs to a different Stripe environment.",
    );
  }
  if (existingDestination && existingDestination !== legacyAccountId) {
    throw new HttpsError(
        "failed-precondition",
        "A historical transaction references a different seller payout account.",
    );
  }
  return {
    stripeMode: mode,
    stripeSellerDestinationAccountId: legacyAccountId,
  };
}

function currentMigration(provider = {}) {
  return provider.legacyMigration &&
    typeof provider.legacyMigration === "object" ?
    provider.legacyMigration : {};
}

function requireMigrationIdentity({
  provider,
  uid,
  legacyAccountId,
  replacementAccountId,
  mode,
}) {
  const migration = currentMigration(provider);
  if (String(migration.uid || "") !== uid ||
      String(migration.legacyAccountId || "") !== legacyAccountId ||
      String(migration.replacementAccountId || "") !== replacementAccountId ||
      String(migration.legacyMode || "") !== mode ||
      String(migration.replacementMode || "") !== mode) {
    throw new HttpsError(
        "failed-precondition",
        "The connected-account migration identity changed. Start a new audited review.",
    );
  }
  return migration;
}

async function loadMigrationReadiness(db) {
  const snapshot = await db.collection(READINESS_COLLECTION)
      .doc(READINESS_DOCUMENT).get();
  const data = snapshot.exists ? snapshot.data() : {};
  const mode = normalizeActiveStripeMode(data.stripeMode);
  if (data.stripeConnectOnboardingEnabled !== true) {
    throw new HttpsError(
        "failed-precondition",
        "Stripe connected-account onboarding is not enabled for the selected environment.",
    );
  }
  return {
    mode,
    connectReturnUrl: safePipeBuyerCallbackUrl(
        data.connectReturnUrl,
        "Stripe Connect return URL",
    ),
    connectRefreshUrl: safePipeBuyerCallbackUrl(
        data.connectRefreshUrl,
        "Stripe Connect refresh URL",
    ),
  };
}

function createStripeProviderMigration(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const requestStripe = options.stripeRequest || stripeConnectRequest;
  const readStripeSecret = options.stripeSecret || stripeSecretValueForMode;
  const accountReadiness = options.recipientAccountReadiness ||
    recipientAccountReadiness;

  async function prepareLegacyStripeSellerMigration(request) {
    try {
      const administratorUid = requireAdministrator(request);
      const uid = safeIdentifier(request.data && request.data.uid, "Seller UID");
      const expectedLegacyAccountId = safeAccountId(
          request.data && request.data.expectedLegacyAccountId,
          "Expected legacy account ID",
      );
      const reason = safeReason(request.data && request.data.reason);
      const readiness = await loadMigrationReadiness(db);
      const providerRef = db.collection(PROVIDER_COLLECTION).doc(uid);
      const providerSnapshot = await providerRef.get();
      if (!providerSnapshot.exists) {
        throw new HttpsError("not-found", "The seller payout account was not found.");
      }
      const provider = providerSnapshot.data() || {};
      const legacyAccountId = safeAccountId(
          provider.stripeAccountId,
          "Stored legacy account ID",
      );
      if (legacyAccountId !== expectedLegacyAccountId) {
        throw new HttpsError(
            "failed-precondition",
            "The stored legacy connected account changed during review.",
        );
      }
      if (providerUsesAccountsV2(provider)) {
        throw new HttpsError(
            "failed-precondition",
            "This seller already uses the current Stripe connected-account model.",
        );
      }
      const storedMode = String(provider.mode || "").trim();
      if (storedMode) {
        requireStoredStripeMode({
          expectedMode: readiness.mode,
          storedMode,
          subject: "Legacy seller payout account",
        });
      } else if (String(request.data && request.data.confirmLegacyMode || "") !==
          readiness.mode) {
        throw new HttpsError(
            "failed-precondition",
            "A legacy account without a stored mode requires an explicit environment confirmation.",
        );
      }
      const existingMigration = currentMigration(provider);
      if (String(existingMigration.status || "") &&
          existingMigration.status !== "cancelled") {
        if (existingMigration.legacyAccountId === legacyAccountId &&
            existingMigration.legacyMode === readiness.mode) {
          return {
            uid,
            legacyAccountId,
            replacementAccountId: String(
                existingMigration.replacementAccountId || "",
            ),
            mode: readiness.mode,
            status: String(existingMigration.status),
            alreadyPrepared: true,
          };
        }
        throw new HttpsError(
            "failed-precondition",
            "A different connected-account migration is already in progress.",
        );
      }

      const secretKey = readStripeSecret(readiness.mode);
      const legacyAccount = await requestStripe({
        secretKey,
        path: `/v1/accounts/${encodeURIComponent(legacyAccountId)}`,
        method: "GET",
      });
      if (String(legacyAccount.id || "") !== legacyAccountId) {
        throw new HttpsError(
            "failed-precondition",
            "Stripe did not confirm the reviewed legacy connected account.",
        );
      }
      if (stripeAccountMode(legacyAccount) !== readiness.mode) {
        throw new HttpsError(
            "failed-precondition",
            "The reviewed legacy connected account belongs to a different Stripe environment.",
        );
      }
      const userRecord = await admin.auth().getUser(uid);
      const contactEmail = String(userRecord.email || "").trim();
      if (!contactEmail || userRecord.emailVerified !== true) {
        throw new HttpsError(
            "failed-precondition",
            "The seller must have a verified email before re-onboarding.",
        );
      }
      const replacement = await requestStripe({
        secretKey,
        path: "/v2/core/accounts",
        fields: stripeV2RecipientAccountPayload({
          contactEmail,
          country: provider.country,
          uid,
        }),
        idempotencyKey: migrationIdempotencyKey(
            uid,
            legacyAccountId,
            readiness.mode,
        ),
      });
      const replacementAccountId = safeAccountId(
          replacement.id,
          "Replacement connected account ID",
      );
      if (replacementAccountId === legacyAccountId) {
        throw new HttpsError(
            "failed-precondition",
            "Stripe returned the existing legacy account instead of a replacement.",
        );
      }
      const replacementReadiness = accountReadiness(replacement);
      if (replacementReadiness.accountMode !== readiness.mode) {
        throw new HttpsError(
            "failed-precondition",
            "The replacement connected account belongs to a different Stripe environment.",
        );
      }
      if (!replacementReadiness.recipientConfigurationReady) {
        throw new HttpsError(
            "failed-precondition",
            "The replacement account does not have the required recipient configuration.",
        );
      }
      const migrationId = crypto.randomUUID();
      const auditRef = db.collection("stripe_provider_migration_audit")
          .doc(migrationId);
      await db.runTransaction(async (transaction) => {
        const current = await transaction.get(providerRef);
        if (!current.exists ||
            String(current.data().stripeAccountId || "") !== legacyAccountId ||
            providerUsesAccountsV2(current.data())) {
          throw new HttpsError(
              "aborted",
              "The seller payout account changed while migration was prepared.",
          );
        }
        const currentPending = currentMigration(current.data());
        if (String(currentPending.status || "") &&
            currentPending.status !== "cancelled") {
          throw new HttpsError(
              "aborted",
              "Another connected-account migration was prepared first.",
          );
        }
        const appliedSellerPayoutHold = current.data().sellerPayoutHold !== true;
        transaction.set(providerRef, {
          migrationRequired: true,
          sellerPayoutHold: true,
          ...(appliedSellerPayoutHold ? {
            sellerPayoutHoldReason: "stripe_provider_migration",
          } : {}),
          legacyMigration: {
            migrationId,
            uid,
            status: "onboarding_required",
            legacyAccountId,
            legacyMode: readiness.mode,
            replacementAccountId,
            replacementMode: readiness.mode,
            replacementAccountObject: replacementReadiness.accountObject,
            replacementTransferStatus: replacementReadiness.transferStatus,
            replacementPayoutStatus: replacementReadiness.payoutStatus,
            replacementRecipientConfigurationReady:
              replacementReadiness.recipientConfigurationReady,
            appliedSellerPayoutHold,
            preparedByUid: administratorUid,
            preparedReason: reason,
            preparedAt: FieldValue.serverTimestamp(),
          },
          onboardingStatus: "migration_onboarding_required",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        transaction.create(auditRef, {
          action: "prepare_legacy_reonboarding",
          migrationId,
          uid,
          administratorUid,
          reason,
          legacyAccountId,
          legacyMode: readiness.mode,
          replacementAccountId,
          replacementMode: readiness.mode,
          currentAccountReplaced: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      });
      return {
        uid,
        migrationId,
        legacyAccountId,
        replacementAccountId,
        mode: readiness.mode,
        status: "onboarding_required",
        alreadyPrepared: false,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Stripe legacy provider migration preparation failed", error);
      throw new HttpsError(
          "internal",
          "The connected-account migration could not be prepared.",
      );
    }
  }

  async function createLegacyStripeSellerMigrationOnboardingLink(request) {
    try {
      const uid = requireAuthenticatedIdentity(
          request,
          {requirePhone: false},
      ).uid;
      const readiness = await loadMigrationReadiness(db);
      const providerRef = db.collection(PROVIDER_COLLECTION).doc(uid);
      const providerSnapshot = await providerRef.get();
      if (!providerSnapshot.exists) {
        throw new HttpsError("not-found", "The seller payout account was not found.");
      }
      const provider = providerSnapshot.data() || {};
      const migration = currentMigration(provider);
      const legacyAccountId = safeAccountId(
          migration.legacyAccountId,
          "Legacy account ID",
      );
      const replacementAccountId = safeAccountId(
          migration.replacementAccountId,
          "Replacement account ID",
      );
      requireMigrationIdentity({
        provider,
        uid,
        legacyAccountId,
        replacementAccountId,
        mode: readiness.mode,
      });
      if (!["onboarding_required", "link_created"].includes(
          String(migration.status || ""),
      )) {
        throw new HttpsError(
            "failed-precondition",
            "This connected-account migration is not awaiting onboarding.",
        );
      }
      if (String(provider.stripeAccountId || "") !== legacyAccountId) {
        throw new HttpsError(
            "failed-precondition",
            "The current connected account changed before re-onboarding.",
        );
      }
      const accountLink = await requestStripe({
        secretKey: readStripeSecret(readiness.mode),
        path: "/v1/account_links",
        fields: {
          account: replacementAccountId,
          refresh_url: readiness.connectRefreshUrl,
          return_url: readiness.connectReturnUrl,
          type: "account_onboarding",
          "collection_options[fields]": "eventually_due",
          "collection_options[future_requirements]": "include",
        },
      });
      const url = String(accountLink.url || "");
      if (!url.startsWith("https://")) {
        throw new HttpsError(
            "internal",
            "Stripe did not return a valid re-onboarding link.",
        );
      }
      await db.runTransaction(async (transaction) => {
        const current = await transaction.get(providerRef);
        if (!current.exists) {
          throw new HttpsError(
              "not-found",
              "The seller payout account was not found.",
          );
        }
        const currentProvider = current.data() || {};
        const currentMigrationState = requireMigrationIdentity({
          provider: currentProvider,
          uid,
          legacyAccountId,
          replacementAccountId,
          mode: readiness.mode,
        });
        if (!["onboarding_required", "link_created"].includes(
            String(currentMigrationState.status || ""),
        ) || String(currentProvider.stripeAccountId || "") !== legacyAccountId) {
          throw new HttpsError(
              "aborted",
              "The connected-account migration changed before the onboarding link was saved.",
          );
        }
        transaction.set(providerRef, {
          legacyMigration: {
            ...currentMigrationState,
            status: "link_created",
            onboardingLinkExpiresAt: accountLink.expires_at || null,
            onboardingLinkCreatedAt: FieldValue.serverTimestamp(),
          },
          onboardingStatus: "migration_link_created",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
      return {
        migrationId: String(migration.migrationId || ""),
        onboardingUrl: url,
        expiresAt: accountLink.expires_at || null,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Stripe legacy provider re-onboarding link failed", error);
      throw new HttpsError(
          "internal",
          "Seller payout re-onboarding could not be started.",
      );
    }
  }

  async function activateLegacyStripeSellerMigration(request) {
    try {
      const administratorUid = requireAdministrator(request);
      if (request.data && request.data.confirmCutover !== true) {
        throw new HttpsError(
            "failed-precondition",
            "Connected-account cutover requires explicit confirmation.",
        );
      }
      const uid = safeIdentifier(request.data && request.data.uid, "Seller UID");
      const legacyAccountId = safeAccountId(
          request.data && request.data.expectedLegacyAccountId,
          "Expected legacy account ID",
      );
      const replacementAccountId = safeAccountId(
          request.data && request.data.expectedReplacementAccountId,
          "Expected replacement account ID",
      );
      const reason = safeReason(request.data && request.data.reason);
      const readiness = await loadMigrationReadiness(db);
      const secretKey = readStripeSecret(readiness.mode);
      const replacement = await requestStripe({
        secretKey,
        path: `/v2/core/accounts/${encodeURIComponent(replacementAccountId)}`,
        method: "GET",
        query: {
          include: [
            "configuration.recipient",
            "defaults",
            "requirements",
          ],
        },
      });
      if (String(replacement.id || "") !== replacementAccountId) {
        throw new HttpsError(
            "failed-precondition",
            "Stripe did not confirm the reviewed replacement account.",
        );
      }
      const replacementReadiness = accountReadiness(replacement);
      if (replacementReadiness.accountMode !== readiness.mode) {
        throw new HttpsError(
            "failed-precondition",
            "The reviewed replacement account belongs to a different Stripe environment.",
        );
      }
      if (!replacementReadiness.payoutReady) {
        throw new HttpsError(
            "failed-precondition",
            "The replacement connected account has not completed payout onboarding.",
        );
      }

      const providerRef = db.collection(PROVIDER_COLLECTION).doc(uid);
      const sellerSalesQuery = db.collection("marketplace_transactions")
          .where("sellerUid", "==", uid)
          .limit(MAX_ATOMIC_MIGRATION_TRANSACTIONS + 1);
      const auditId = crypto.randomUUID();
      const auditRef = db.collection("stripe_provider_migration_audit")
          .doc(auditId);
      const legacyArchiveRef = providerRef.collection("legacy_accounts")
          .doc(legacyAccountId);
      const result = await db.runTransaction(async (transaction) => {
        const [providerSnapshot, saleSnapshots] = await Promise.all([
          transaction.get(providerRef),
          transaction.get(sellerSalesQuery),
        ]);
        if (!providerSnapshot.exists) {
          throw new HttpsError("not-found", "The seller payout account was not found.");
        }
        const provider = providerSnapshot.data() || {};
        const migration = requireMigrationIdentity({
          provider,
          uid,
          legacyAccountId,
          replacementAccountId,
          mode: readiness.mode,
        });
        if (!["onboarding_required", "link_created"].includes(
            String(migration.status || ""),
        )) {
          throw new HttpsError(
              "failed-precondition",
              "This connected-account migration is not ready for cutover.",
          );
        }
        if (String(provider.stripeAccountId || "") !== legacyAccountId ||
            providerUsesAccountsV2(provider)) {
          throw new HttpsError(
              "failed-precondition",
              "The current connected account changed before cutover.",
          );
        }
        if (provider.sellerPayoutHold === true &&
            migration.appliedSellerPayoutHold !== true) {
          throw new HttpsError(
              "failed-precondition",
              "Resolve the seller's existing payout hold before connected-account cutover.",
          );
        }
        if (saleSnapshots.docs.length > MAX_ATOMIC_MIGRATION_TRANSACTIONS) {
          throw new HttpsError(
              "failed-precondition",
              "This seller has too many transactions for one audited cutover. Run the bounded migration backfill procedure first.",
          );
        }
        const blocking = [];
        const patches = [];
        for (const document of saleSnapshots.docs) {
          const sale = document.data() || {};
          const reasons = legacyMigrationBlockingReasons(sale);
          if (reasons.length) {
            blocking.push({transactionId: document.id, reasons});
            continue;
          }
          const patch = migrationTransactionPatch(
              sale,
              legacyAccountId,
              readiness.mode,
          );
          if (patch) patches.push({ref: document.ref, patch});
        }
        if (blocking.length) {
          throw new HttpsError(
              "failed-precondition",
              "Resolve all unsettled, held, refund, dispute, and seller-recovery transactions before connected-account cutover.",
              {blockingTransactions: blocking.slice(0, 50)},
          );
        }
        if (patches.length > MAX_ATOMIC_MIGRATION_TRANSACTIONS) {
          throw new HttpsError(
              "failed-precondition",
              "This seller has too many historical Stripe transactions for one audited cutover. Run the migration backfill procedure first.",
          );
        }
        for (const item of patches) {
          transaction.set(item.ref, {
            ...item.patch,
            stripeProviderMigrationId: String(migration.migrationId || ""),
            stripeProviderMigrationAnnotatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        transaction.set(legacyArchiveRef, {
          uid,
          stripeAccountId: legacyAccountId,
          mode: readiness.mode,
          connectAccountApiVersion: String(
              provider.connectAccountApiVersion || "v1",
          ),
          connectAccountObject: String(provider.connectAccountObject || "account"),
          transferStatus: String(provider.transferStatus || "unknown"),
          payoutReady: provider.payoutReady === true,
          migrationId: String(migration.migrationId || ""),
          replacedByStripeAccountId: replacementAccountId,
          archivedByUid: administratorUid,
          archiveReason: reason,
          archivedAt: FieldValue.serverTimestamp(),
        }, {merge: false});
        transaction.set(providerRef, {
          stripeAccountId: replacementAccountId,
          mode: readiness.mode,
          connectAccountApiVersion: "v2",
          connectAccountObject: replacementReadiness.accountObject,
          dashboard: replacementReadiness.dashboard,
          feesCollector: replacementReadiness.feesCollector,
          lossesCollector: replacementReadiness.lossesCollector,
          appliedConfigurations: replacementReadiness.appliedConfigurations,
          transferStatus: replacementReadiness.transferStatus,
          payoutStatus: replacementReadiness.payoutStatus,
          recipientConfigurationReady:
            replacementReadiness.recipientConfigurationReady,
          payoutReady: replacementReadiness.payoutReady,
          migrationRequired: false,
          onboardingStatus: "payout_ready",
          legacyStripeAccountIds: FieldValue.arrayUnion(legacyAccountId),
          ...(migration.appliedSellerPayoutHold === true ? {
            sellerPayoutHold: false,
            sellerPayoutHoldReason: FieldValue.delete(),
          } : {}),
          legacyMigration: {
            ...migration,
            status: "completed",
            activatedByUid: administratorUid,
            activationReason: reason,
            activatedAt: FieldValue.serverTimestamp(),
            auditId,
          },
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        transaction.create(auditRef, {
          action: "activate_legacy_reonboarding",
          auditId,
          migrationId: String(migration.migrationId || ""),
          uid,
          administratorUid,
          reason,
          legacyAccountId,
          legacyMode: readiness.mode,
          replacementAccountId,
          replacementMode: readiness.mode,
          annotatedHistoricalTransactions: patches.length,
          currentAccountReplaced: true,
          createdAt: FieldValue.serverTimestamp(),
        });
        return {migrationId: String(migration.migrationId || ""), patches};
      });
      return {
        uid,
        migrationId: result.migrationId,
        legacyAccountId,
        replacementAccountId,
        mode: readiness.mode,
        annotatedHistoricalTransactions: result.patches.length,
        activated: true,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Stripe legacy provider migration activation failed", error);
      throw new HttpsError(
          "internal",
          "The connected-account migration could not be activated.",
      );
    }
  }

  return {
    activateLegacyStripeSellerMigration,
    createLegacyStripeSellerMigrationOnboardingLink,
    prepareLegacyStripeSellerMigration,
  };
}

module.exports = {
  MAX_ATOMIC_MIGRATION_TRANSACTIONS,
  createStripeProviderMigration,
  legacyMigrationBlockingReasons,
  migrationIdempotencyKey,
  migrationTransactionPatch,
  requireMigrationIdentity,
  saleUsesStripeSellerSettlement,
};
