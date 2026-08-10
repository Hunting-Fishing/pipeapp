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

function createExternalSettlementCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const confirmExternalSettlement = async (request) => {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "marketplace");
      requirePhase1Feature(flags, "offers");
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
        if (sale.paymentProviderStatus === "paid" || sale.stripePaymentIntentId) {
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
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "marketplace");
      requirePhase1Feature(flags, "offers");
      requirePhase1Feature(flags, "paidFeatures");
      const readinessSnapshot = await db.collection("platform_configuration")
          .doc("payment_provider_readiness").get();
      const readinessData = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const readiness = {
        ...(await loadProviderReadiness(db)),
        stripeFeeBillingEnabled: readinessData.stripeFeeBillingEnabled === true,
        stripeTaxRegistrationPending:
          readinessData.stripeTaxRegistrationPending === true,
        checkoutSuccessUrl: String(readinessData.checkoutSuccessUrl || ""),
        checkoutCancelUrl: String(readinessData.checkoutCancelUrl || ""),
      };
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
      if (sale.paymentMethod !== "external_settlement" ||
          sale.externalSettlementBuyerConfirmed !== true ||
          sale.externalSettlementSellerConfirmed !== true) {
        throw new HttpsError(
            "failed-precondition",
            "Both parties must confirm external settlement before the marketplace fee is billed.",
        );
      }
      if (sale.marketplaceFeeStatus === "collected") {
        return {
          transactionId,
          alreadyPaid: true,
          checkoutSessionId: String(sale.stripeMarketplaceFeeSessionId || ""),
        };
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
      const session = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/checkout/sessions",
        idempotencyKey: `pipebuyer-external-fee-${transactionId}-${sale.revision || 1}`,
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
        },
      });
      const sessionId = String(session.id || "");
      const checkoutUrl = String(session.url || "");
      if (!sessionId.startsWith("cs_") || !checkoutUrl.startsWith("https://")) {
        throw new HttpsError("internal", "Stripe did not return a valid fee checkout session.");
      }
      await transactionRef.set({
        marketplaceFeeStatus: "checkout_created",
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
      return {
        transactionId,
        checkoutSessionId: sessionId,
        checkoutUrl,
        alreadyPaid: false,
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
};
