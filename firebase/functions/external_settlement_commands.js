"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  loadPhase1FeatureFlags,
  requirePhase1Feature,
} = require("./phase1_feature_flags");
const {
  loadProviderReadiness,
  stripeSecretKey,
} = require("./stripe_marketplace_commands");
const {
  requirePlatformFeeBillingReady,
  safeConfiguredUrl,
  stripeFormRequest,
} = require("./stripe_checkout_commands");
const {
  automaticTaxEnabled,
  provisionalTaxReserveMinor,
  taxCollectionStatus,
} = require("./pending_tax_policy");
const {
  requireCanadaSmallSupplierRuntimeEvidence,
} = require("./canada_small_supplier_runtime_gate");
const {
  externalSettlementFullyConfirmed,
  hasStartedStripeMarketplaceCheckout,
} = require("./marketplace_payment_path_guard");
const {
  externalFeeCheckoutAttempt,
  externalFeeCheckoutIdempotencyKey,
  externalFeeCheckoutSessionId,
  externalFeeCheckoutState,
  nextExternalFeeCheckoutAttempt,
} = require("./external_settlement_fee_checkout_policy");
const {
  existingExternalFeeSessionDecision,
  externalFeePostProviderPersistenceDecision,
} = require("./external_settlement_fee_provider_policy");

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function transactionIdFromRequest(request) {
  const value = String(request.data && request.data.transactionId || "").trim();
  if (!value || value.length > 180 || value.includes("/")) {
    throw new HttpsError("invalid-argument", "The transaction is invalid.");
  }
  return value;
}

function participantRole(sale, uid) {
  if (sale && sale.buyerUid === uid) return "buyer";
  if (sale && sale.sellerUid === uid) return "seller";
  throw new HttpsError(
      "permission-denied",
      "Only the buyer or seller can update this transaction.",
  );
}

function validStripeCheckoutUrl(value) {
  try {
    const url = new URL(String(value || ""));
    return url.protocol === "https:" && url.hostname === "checkout.stripe.com";
  } catch (_) {
    return false;
  }
}

function createExternalSettlementCommands(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const authUid = options.authUid || requireAuth;
  const rateLimit = options.rateLimit || enforceUserRateLimit;
  const loadFeatureFlags = options.loadFeatureFlags || loadPhase1FeatureFlags;
  const requireFeature = options.requireFeature || requirePhase1Feature;
  const providerReadiness = options.loadProviderReadiness || loadProviderReadiness;
  const stripeRequest = options.stripeRequest || stripeFormRequest;
  const secretProvider = options.secretProvider || (() => stripeSecretKey.value());

  const confirmExternalSettlement = async (request) => {
    try {
      const uid = authUid(request);
      await rateLimit({db, admin, request, scope: "offers"});
      const flags = await loadFeatureFlags(db);
      requireFeature(flags, "marketplace");
      requireFeature(flags, "offers");
      const transactionId = transactionIdFromRequest(request);
      const transactionRef = db.collection("marketplace_transactions")
          .doc(transactionId);
      return db.runTransaction(async (firestoreTransaction) => {
        const snapshot = await firestoreTransaction.get(transactionRef);
        if (!snapshot.exists) {
          throw new HttpsError("not-found", "This marketplace transaction is unavailable.");
        }
        const sale = snapshot.data();
        const role = participantRole(sale, uid);
        if (["cancelled", "disputed"].includes(String(sale.status || ""))) {
          throw new HttpsError(
              "failed-precondition",
              "This transaction cannot switch to external settlement.",
          );
        }
        if (hasStartedStripeMarketplaceCheckout(sale)) {
          throw new HttpsError(
              "failed-precondition",
              "A Stripe marketplace payment has already started for this transaction.",
          );
        }
        const buyerConfirmed = role === "buyer" ? true :
          sale.externalSettlementBuyerConfirmed === true;
        const sellerConfirmed = role === "seller" ? true :
          sale.externalSettlementSellerConfirmed === true;
        const fullyConfirmed = buyerConfirmed && sellerConfirmed;
        firestoreTransaction.set(transactionRef, {
          externalSettlementBuyerConfirmed: buyerConfirmed,
          externalSettlementSellerConfirmed: sellerConfirmed,
          [`externalSettlement${role === "buyer" ? "Buyer" : "Seller"}ConfirmedAt`]:
            FieldValue.serverTimestamp(),
          ...(fullyConfirmed ? {
            paymentMethod: "external_settlement",
            paymentProvider: "external",
            paymentProviderStatus: "external_agreed",
            marketplaceFeeStatus: "pending_collection",
            externalSettlementAgreedAt: FieldValue.serverTimestamp(),
          } : {}),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {
          transactionId,
          role,
          buyerConfirmed,
          sellerConfirmed,
          fullyConfirmed,
        };
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("External settlement confirmation failed", error);
      throw new HttpsError("internal", "External settlement could not be confirmed.");
    }
  };

  const createExternalSettlementFeeCheckout = async (request) => {
    try {
      const uid = authUid(request);
      await rateLimit({db, admin, request, scope: "offers"});
      const flags = await loadFeatureFlags(db);
      requireFeature(flags, "marketplace");
      requireFeature(flags, "offers");
      requireFeature(flags, "paidFeatures");
      const readinessSnapshot = await db.collection("platform_configuration")
          .doc("payment_provider_readiness").get();
      const readinessData = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const readiness = {
        ...(await providerReadiness(db)),
        stripeFeeBillingEnabled: readinessData.stripeFeeBillingEnabled === true,
        stripeTaxRegistrationPending:
          readinessData.stripeTaxRegistrationPending === true,
        stripeTaxPendingBillingApproved:
          readinessData.stripeTaxPendingBillingApproved === true,
        canadaGstHstSmallSupplier:
          readinessData.canadaGstHstSmallSupplier === true,
        canadaGstHstSmallSupplierAssessmentRevision:
          readinessData.canadaGstHstSmallSupplierAssessmentRevision,
        checkoutSuccessUrl: String(readinessData.checkoutSuccessUrl || ""),
        checkoutCancelUrl: String(readinessData.checkoutCancelUrl || ""),
      };
      await requireCanadaSmallSupplierRuntimeEvidence(db, readiness);
      requirePlatformFeeBillingReady(readiness);
      const collectionStatus = taxCollectionStatus(readiness);
      const transactionId = transactionIdFromRequest(request);
      const transactionRef = db.collection("marketplace_transactions")
          .doc(transactionId);
      const transactionSnapshot = await transactionRef.get();
      if (!transactionSnapshot.exists) {
        throw new HttpsError("not-found", "This marketplace transaction is unavailable.");
      }
      const sale = transactionSnapshot.data();
      if (sale.sellerUid !== uid) {
        throw new HttpsError(
            "permission-denied",
            "The seller is responsible for the current Pipe Buyer marketplace fee.",
        );
      }
      if (hasStartedStripeMarketplaceCheckout(sale)) {
        throw new HttpsError(
            "failed-precondition",
            "This transaction is already using Stripe marketplace checkout.",
        );
      }
      if (!externalSettlementFullyConfirmed(sale)) {
        throw new HttpsError(
            "failed-precondition",
            "Both parties must confirm external settlement before the marketplace fee is billed.",
        );
      }

      const localCheckoutState = externalFeeCheckoutState(sale);
      if (localCheckoutState === "paid") {
        return {
          transactionId,
          alreadyPaid: true,
          checkoutSessionId: externalFeeCheckoutSessionId(sale),
        };
      }
      if (localCheckoutState === "inconsistent") {
        throw new HttpsError(
            "failed-precondition",
            "The marketplace fee payment state needs review before another checkout can start.",
        );
      }

      if (localCheckoutState === "active") {
        const existingSessionId = externalFeeCheckoutSessionId(sale);
        const existingSession = await stripeRequest({
          secretKey: secretProvider(),
          path: `/v1/checkout/sessions/${encodeURIComponent(existingSessionId)}`,
          method: "GET",
        });
        const existingUrl = String(existingSession.url || "");
        const decision = existingExternalFeeSessionDecision({
          localFeeStatus: sale.marketplaceFeeStatus,
          providerStatus: existingSession.status,
          paymentStatus: existingSession.payment_status,
          checkoutUrlValid: validStripeCheckoutUrl(existingUrl),
        });

        if (decision.action === "processing") {
          return {
            transactionId,
            checkoutSessionId: existingSessionId,
            alreadyPaid: false,
            alreadyCreated: true,
            processing: true,
            taxCollectionStatus: collectionStatus,
          };
        }
        if (decision.action === "reuse") {
          return {
            transactionId,
            checkoutSessionId: existingSessionId,
            checkoutUrl: existingUrl,
            alreadyPaid: false,
            alreadyCreated: true,
            processing: false,
            taxCollectionStatus: collectionStatus,
          };
        }
        if (decision.action === "invalid_url") {
          throw new HttpsError(
              "failed-precondition",
              "The existing Stripe fee checkout link is unavailable.",
          );
        }
        if (decision.action === "review") {
          throw new HttpsError(
              "failed-precondition",
              "The existing marketplace fee payment needs review before another checkout can start.",
          );
        }
      }

      const fee = sale.marketplaceFeeSnapshot || {};
      const feeMinor = Number(fee.marketplaceFeeMinor);
      if (!Number.isSafeInteger(feeMinor) || feeMinor <= 0) {
        throw new HttpsError(
            "failed-precondition",
            "The Pipe Buyer marketplace fee snapshot is not ready.",
        );
      }
      const successUrl = safeConfiguredUrl(
          readiness.checkoutSuccessUrl,
          "Stripe Checkout success URL",
      );
      const cancelUrl = safeConfiguredUrl(
          readiness.checkoutCancelUrl,
          "Stripe Checkout cancel URL",
      );
      const productLabel = fee.feeClass === "pipe" ?
        "Pipe Buyer Marketplace Fee - Pipe" :
        "Pipe Buyer Marketplace Fee - Equipment & Assets";
      const reserveIfCollectedMinor = provisionalTaxReserveMinor(
          feeMinor,
          collectionStatus,
      );
      const attempt = nextExternalFeeCheckoutAttempt(sale);
      const session = await stripeRequest({
        secretKey: secretProvider(),
        path: "/v1/checkout/sessions",
        idempotencyKey: externalFeeCheckoutIdempotencyKey(transactionId, attempt),
        fields: {
          mode: "payment",
          success_url: successUrl,
          cancel_url: cancelUrl,
          client_reference_id: transactionId,
          billing_address_collection: "required",
          "automatic_tax[enabled]": automaticTaxEnabled(readiness) ? "true" : "false",
          "line_items[0][quantity]": 1,
          "line_items[0][price_data][currency]":
            String(fee.currency || sale.currency || "CAD").toLowerCase(),
          "line_items[0][price_data][unit_amount]": feeMinor,
          "line_items[0][price_data][tax_behavior]": "exclusive",
          "line_items[0][price_data][product_data][name]": productLabel,
          "line_items[0][price_data][product_data][tax_code]": "txcd_10000000",
          "metadata[pipeBuyerTransactionId]": transactionId,
          "metadata[billingType]": "marketplace_fee_only",
          "metadata[feeScheduleRevision]": String(fee.scheduleRevision || ""),
          "metadata[sellerUid]": String(sale.sellerUid || ""),
          "metadata[taxCollectionStatus]": collectionStatus,
          "metadata[checkoutAttempt]": attempt,
        },
      });
      const sessionId = String(session.id || "");
      const checkoutUrl = String(session.url || "");
      if (!sessionId.startsWith("cs_") || !validStripeCheckoutUrl(checkoutUrl)) {
        throw new HttpsError("internal", "Stripe did not return a valid fee checkout session.");
      }

      const attemptRef = transactionRef.collection("marketplace_fee_checkout_attempts")
          .doc(String(attempt).padStart(4, "0"));
      const persistedState = await db.runTransaction(async (firestoreTransaction) => {
        const currentSnapshot = await firestoreTransaction.get(transactionRef);
        if (!currentSnapshot.exists) {
          throw new HttpsError("not-found", "This marketplace transaction is unavailable.");
        }
        const current = currentSnapshot.data();
        const currentStatus = String(current.marketplaceFeeStatus || "");
        const currentSessionId = externalFeeCheckoutSessionId(current);
        const currentAttempt = externalFeeCheckoutAttempt(current);

        firestoreTransaction.set(attemptRef, {
          attempt,
          stripeCheckoutSessionId: sessionId,
          status: "checkout_created",
          feeMinor,
          currency: String(fee.currency || sale.currency || "CAD").toUpperCase(),
          taxCollectionStatus: collectionStatus,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        const persistenceDecision = externalFeePostProviderPersistenceDecision({
          currentStatus,
          currentSessionId,
          currentAttempt,
          createdSessionId: sessionId,
          createdAttempt: attempt,
        });
        if (persistenceDecision !== "checkout_created") {
          return persistenceDecision;
        }

        firestoreTransaction.set(transactionRef, {
          marketplaceFeeStatus: "checkout_created",
          marketplaceFeeCheckoutAttempt: attempt,
          stripeMarketplaceFeeSessionId: sessionId,
          marketplaceFeeTaxCollectionStatus: collectionStatus,
          marketplaceFeeTaxExposureReviewRequired:
            collectionStatus === "registration_pending",
          marketplaceFeeProvisionalTaxReserveIfCollectedMinor:
            reserveIfCollectedMinor,
          marketplaceFeeAutomaticTaxEnabled: automaticTaxEnabled(readiness),
          marketplaceFeeCheckoutCreatedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return "checkout_created";
      });

      if (persistedState === "paid") {
        return {
          transactionId,
          checkoutSessionId: sessionId,
          alreadyPaid: true,
        };
      }
      if (persistedState === "processing") {
        return {
          transactionId,
          checkoutSessionId: sessionId,
          alreadyPaid: false,
          alreadyCreated: true,
          processing: true,
          taxCollectionStatus: collectionStatus,
        };
      }
      if (persistedState === "payment_failed") {
        return {
          transactionId,
          checkoutSessionId: sessionId,
          alreadyPaid: false,
          alreadyCreated: true,
          processing: false,
          paymentFailed: true,
          taxCollectionStatus: collectionStatus,
        };
      }
      if (persistedState === "superseded") {
        throw new HttpsError(
            "failed-precondition",
            "A newer marketplace fee checkout already exists. Refresh and try again.",
        );
      }

      return {
        transactionId,
        checkoutSessionId: sessionId,
        checkoutUrl,
        alreadyPaid: false,
        alreadyCreated: false,
        processing: false,
        paymentFailed: false,
        checkoutAttempt: attempt,
        taxCollectionStatus: collectionStatus,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("External settlement marketplace fee checkout failed", error);
      throw new HttpsError(
          "internal",
          "The Pipe Buyer marketplace fee checkout could not be started.",
      );
    }
  };

  return {
    confirmExternalSettlement,
    createExternalSettlementFeeCheckout,
  };
}

module.exports = {
  createExternalSettlementCommands,
  participantRole,
  validStripeCheckoutUrl,
};
