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
  requireCheckoutReady,
  safeConfiguredUrl,
  stripeFormRequest,
} = require("./stripe_checkout_commands");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {
  createMarketplaceTaxCompliance,
} = require("./marketplace_tax_compliance");

const PAYMENT_PARTS = new Set(["deposit", "balance"]);

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function cleanId(value, field) {
  const id = String(value || "").trim();
  if (!id || id.length > 180 || id.includes("/")) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return id;
}

function cleanPartId(value) {
  const partId = String(value || "").trim().toLowerCase();
  if (!PAYMENT_PARTS.has(partId)) {
    throw new HttpsError("invalid-argument", "Choose the deposit or remaining balance.");
  }
  return partId;
}

function createMarketplaceSplitCheckoutCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const taxCompliance = createMarketplaceTaxCompliance(admin);

  const createMarketplacePaymentPartCheckout = async (request) => {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "marketplace");
      requirePhase1Feature(flags, "offers");
      requirePhase1Feature(flags, "paidFeatures");

      const readinessSnapshot = await db.collection("platform_configuration")
          .doc("payment_provider_readiness").get();
      const readiness = {
        ...(await loadProviderReadiness(db)),
        checkoutSuccessUrl: String(
            readinessSnapshot.data() && readinessSnapshot.data().checkoutSuccessUrl || "",
        ),
        checkoutCancelUrl: String(
            readinessSnapshot.data() && readinessSnapshot.data().checkoutCancelUrl || "",
        ),
      };
      requireCheckoutReady(readiness);

      const transactionId = cleanId(
          request.data && request.data.transactionId,
          "transactionId",
      );
      const partId = cleanPartId(request.data && request.data.partId);
      const saleRef = db.collection("marketplace_transactions").doc(transactionId);
      const partRef = saleRef.collection("payment_parts").doc(partId);
      const [saleSnapshot, partSnapshot] = await Promise.all([
        saleRef.get(),
        partRef.get(),
      ]);
      if (!saleSnapshot.exists || !partSnapshot.exists) {
        throw new HttpsError("not-found", "The split payment is unavailable.");
      }
      const sale = saleSnapshot.data();
      const part = partSnapshot.data();
      if (sale.buyerUid !== uid) {
        throw new HttpsError(
            "permission-denied",
            "Only the buyer can pay a marketplace deposit or balance.",
        );
      }
      if (sale.paymentPlan !== "deposit_balance" || sale.paymentPlanStatus !== "active") {
        throw new HttpsError(
            "failed-precondition",
            "This transaction does not have an approved deposit payment plan.",
        );
      }
      if (!["pending_completion", "pending_payment"].includes(String(sale.status))) {
        throw new HttpsError(
            "failed-precondition",
            "This transaction is not eligible for another payment.",
        );
      }
      const fee = sale.marketplaceFeeSnapshot;
      if (!fee || !Number.isSafeInteger(Number(fee.marketplaceFeeMinor))) {
        throw new HttpsError(
            "failed-precondition",
            "The server marketplace fee snapshot is not ready yet.",
        );
      }
      const expectedTotal = Number(fee.agreedTotalMinor);
      if (!Number.isSafeInteger(expectedTotal) ||
          expectedTotal !== Number(sale.paymentRequiredMinor)) {
        throw new HttpsError(
            "failed-precondition",
            "The approved payment plan no longer matches the immutable sale total.",
        );
      }

      const partAmount = Number(part.amountMinor);
      const expectedPartAmount = partId === "deposit" ?
        Number(sale.depositAmountMinor) : Number(sale.balanceAmountMinor);
      if (!Number.isSafeInteger(partAmount) || partAmount <= 0 ||
          partAmount !== expectedPartAmount) {
        throw new HttpsError("failed-precondition", "The payment part amount is invalid.");
      }
      if (part.status === "paid") {
        return {
          transactionId,
          partId,
          alreadyCreated: true,
          alreadyPaid: true,
        };
      }
      if (partId === "balance") {
        const depositSnapshot = await saleRef.collection("payment_parts").doc("deposit").get();
        if (!depositSnapshot.exists || depositSnapshot.data().status !== "paid") {
          throw new HttpsError(
              "failed-precondition",
              "The deposit must be paid before the remaining balance.",
          );
        }
      } else if (![
        "pending", "checkout_created", "processing", "payment_failed",
      ].includes(String(part.status || ""))) {
        throw new HttpsError(
            "failed-precondition",
            "The deposit is not payable in its current state.",
        );
      }

      const buyerUid = String(sale.buyerUid || "");
      const sellerUid = String(sale.sellerUid || "");
      const [buyerTaxProfile, sellerTaxProfile, sellerProvider, listingSnapshot] =
        await Promise.all([
          db.collection("business_tax_profiles").doc(buyerUid).get(),
          db.collection("business_tax_profiles").doc(sellerUid).get(),
          db.collection("payment_provider_accounts").doc(sellerUid).get(),
          db.collection("public_listings").doc(String(sale.listingId || "")).get(),
        ]);
      if ((buyerTaxProfile.exists && buyerTaxProfile.data().taxComplianceHold === true) ||
          (sellerTaxProfile.exists && sellerTaxProfile.data().taxComplianceHold === true)) {
        throw new HttpsError(
            "failed-precondition",
            "A buyer or seller tax-compliance recovery hold must be resolved before online checkout.",
        );
      }
      if (!sellerProvider.exists || sellerProvider.data().transferStatus !== "active") {
        throw new HttpsError(
            "failed-precondition",
            "The seller must finish payout verification before online checkout.",
        );
      }
      if (sellerProvider.data().sellerPayoutHold === true) {
        throw new HttpsError(
            "failed-precondition",
            "The seller has an unresolved financial recovery hold.",
        );
      }
      if (!listingSnapshot.exists) {
        throw new HttpsError("not-found", "The marketplace listing is unavailable.");
      }
      const listing = listingSnapshot.data();

      const automaticTax = readiness.stripeTaxReady === true;
      const taxCollectionStatus = automaticTax ? "registered" : "collection_deferred";
      const taxComplianceSnapshot = automaticTax ?
        await taxCompliance.evaluateTransactionTaxCompliance(sale) : {
          collectionMode: "deferred",
          taxPolicyVersion: "marketplace-tax-collection-deferred-v1",
          taxResponsibilityPolicyVersion: "marketplace-tax-collection-deferred-v1",
          manualTaxReviewRequired: false,
          eligibleForAutomatedCheckout: true,
        };
      if (automaticTax && taxComplianceSnapshot.manualTaxReviewRequired) {
        throw new HttpsError(
            "failed-precondition",
            "This transaction has a tax exemption claim that requires Pipe Buyer tax review before online checkout.",
        );
      }
      if (automaticTax && !taxComplianceSnapshot.eligibleForAutomatedCheckout) {
        throw new HttpsError(
            "failed-precondition",
            "Buyer and seller tax profiles must be current and verified before automatic-tax marketplace checkout.",
        );
      }

      const existingSessionId = String(part.stripeCheckoutSessionId || "");
      if (existingSessionId && ["checkout_created", "processing"].includes(part.status)) {
        const existingSession = await stripeFormRequest({
          secretKey: stripeSecretKey.value(),
          path: `/v1/checkout/sessions/${encodeURIComponent(existingSessionId)}`,
          method: "GET",
        });
        const existingUrl = String(existingSession.url || "");
        if (existingUrl.startsWith("https://") &&
            String(existingSession.status || "") === "open") {
          return {
            transactionId,
            partId,
            checkoutSessionId: existingSessionId,
            checkoutUrl: existingUrl,
            alreadyCreated: true,
            alreadyPaid: false,
          };
        }
      }

      const currency = String(part.currency || sale.currency || fee.currency || "CAD")
          .toLowerCase();
      const transferGroup = String(sale.stripeTransferGroup || `PB_${transactionId}`)
          .slice(0, 200);
      const successUrl = safeConfiguredUrl(
          readiness.checkoutSuccessUrl,
          "Stripe Checkout success URL",
      );
      const cancelUrl = safeConfiguredUrl(
          readiness.checkoutCancelUrl,
          "Stripe Checkout cancel URL",
      );
      const taxCode = String(
          listing.stripeTaxCode || stripeMarketplaceConfig.defaultPhysicalGoodsTaxCode,
      );
      const productName = partId === "deposit" ?
        `${String(listing.title || "Pipe Buyer purchase").slice(0, 190)} — deposit` :
        `${String(listing.title || "Pipe Buyer purchase").slice(0, 180)} — remaining balance`;
      const session = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/checkout/sessions",
        idempotencyKey:
          `pipebuyer-part-${transactionId}-${partId}-${sale.paymentPlanProposalRevision || 1}`,
        fields: {
          mode: "payment",
          success_url: successUrl,
          cancel_url: cancelUrl,
          client_reference_id: transactionId,
          billing_address_collection: "required",
          "tax_id_collection[enabled]": automaticTax ? "true" : "false",
          "automatic_tax[enabled]": automaticTax ? "true" : "false",
          "line_items[0][quantity]": 1,
          "line_items[0][price_data][currency]": currency,
          "line_items[0][price_data][unit_amount]": partAmount,
          ...(automaticTax ? {
            "line_items[0][price_data][tax_behavior]": "exclusive",
          } : {}),
          "line_items[0][price_data][product_data][name]": productName,
          ...(automaticTax ? {
            "line_items[0][price_data][product_data][tax_code]": taxCode,
          } : {}),
          "payment_intent_data[transfer_group]": transferGroup,
          "payment_intent_data[metadata][pipeBuyerTransactionId]": transactionId,
          "payment_intent_data[metadata][paymentPartId]": partId,
          "metadata[billingType]": "marketplace_payment_part",
          "metadata[pipeBuyerTransactionId]": transactionId,
          "metadata[paymentPartId]": partId,
          "metadata[listingId]": String(sale.listingId || ""),
          "metadata[sellerUid]": sellerUid,
          "metadata[buyerUid]": buyerUid,
          "metadata[feeScheduleRevision]": String(fee.scheduleRevision || ""),
          "metadata[taxCollectionStatus]": taxCollectionStatus,
          "metadata[taxPolicyVersion]": String(
              taxComplianceSnapshot.taxPolicyVersion || "",
          ),
          "metadata[taxResponsibilityTermsVersion]": String(
              taxComplianceSnapshot.taxResponsibilityPolicyVersion || "",
          ),
        },
      });
      const sessionId = String(session.id || "");
      const checkoutUrl = String(session.url || "");
      if (!sessionId.startsWith("cs_") || !checkoutUrl.startsWith("https://")) {
        throw new HttpsError("internal", "Stripe did not return a valid checkout session.");
      }
      await partRef.set({
        status: "checkout_created",
        paymentProvider: "stripe",
        stripeCheckoutSessionId: sessionId,
        stripeTransferGroup: transferGroup,
        taxCollectionStatus,
        stripeAutomaticTaxEnabled: automaticTax,
        taxComplianceSnapshot,
        checkoutCreatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await saleRef.set({
        paymentMethod: "stripe_checkout",
        paymentProvider: "stripe",
        stripeTransferGroup: transferGroup,
        ...(partId === "deposit" ? {
          paymentProviderStatus: "checkout_created",
        } : {}),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        transactionId,
        partId,
        checkoutSessionId: sessionId,
        checkoutUrl,
        alreadyCreated: false,
        alreadyPaid: false,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace split Stripe Checkout creation failed", error);
      throw new HttpsError("internal", "Marketplace split payment could not be started.");
    }
  };

  return {createMarketplacePaymentPartCheckout};
}

module.exports = {
  createMarketplaceSplitCheckoutCommands,
  cleanPartId,
};
