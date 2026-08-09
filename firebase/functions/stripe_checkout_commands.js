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
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function safeConfiguredUrl(value, field) {
  let url;
  try {
    url = new URL(String(value || ""));
  } catch (_) {
    throw new HttpsError("failed-precondition", `${field} is not configured.`);
  }
  const host = url.hostname.toLowerCase();
  if (url.protocol !== "https:" ||
      !(host === "pipebuyer.com" || host.endsWith(".pipebuyer.com"))) {
    throw new HttpsError(
        "failed-precondition",
        `${field} must use an HTTPS pipebuyer.com address.`,
    );
  }
  return url.toString();
}

function requireCheckoutReady(readiness) {
  const ready =
    ["sandbox", "production"].includes(readiness.stripeMode) &&
    readiness.stripeCheckoutEnabled &&
    readiness.stripeWebhookVerified &&
    readiness.stripeTaxReady &&
    readiness.stripeReconciliationReady;
  if (!ready) {
    throw new HttpsError(
        "failed-precondition",
        "Marketplace checkout is not yet approved for live money movement.",
    );
  }
}

function appendFormValue(form, key, value) {
  if (value == null) return;
  if (Array.isArray(value)) {
    for (const item of value) form.append(`${key}[]`, String(item));
    return;
  }
  form.append(key, String(value));
}

async function stripeFormRequest({
  secretKey,
  path,
  fields,
  idempotencyKey,
  method = "POST",
}) {
  const form = new URLSearchParams();
  for (const [key, value] of Object.entries(fields || {})) {
    appendFormValue(form, key, value);
  }
  const response = await fetch(`https://api.stripe.com${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
      "Stripe-Version": stripeMarketplaceConfig.apiVersion,
      ...(idempotencyKey ? {"Idempotency-Key": idempotencyKey} : {}),
    },
    ...(method === "GET" ? {} : {body: form.toString()}),
  });
  let payload = null;
  try {
    payload = await response.json();
  } catch (_) {
    payload = null;
  }
  if (!response.ok) {
    const stripeCode = String(
        payload && payload.error && (payload.error.code || payload.error.type) || "",
    ).slice(0, 120);
    console.error("Stripe Checkout request failed", {
      path,
      status: response.status,
      stripeCode,
    });
    throw new HttpsError(
        response.status === 429 ? "resource-exhausted" : "failed-precondition",
        "Stripe could not start this marketplace payment.",
    );
  }
  return payload || {};
}

function createStripeCheckoutCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const createMarketplaceCheckout = async (request) => {
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

      const transactionId = String(
          request.data && request.data.transactionId || "",
      ).trim();
      if (!transactionId || transactionId.length > 180 || transactionId.includes("/")) {
        throw new HttpsError("invalid-argument", "The transaction is invalid.");
      }
      const transactionRef = db.collection("marketplace_transactions")
          .doc(transactionId);
      const transactionSnapshot = await transactionRef.get();
      if (!transactionSnapshot.exists) {
        throw new HttpsError("not-found", "This marketplace transaction is unavailable.");
      }
      const sale = transactionSnapshot.data();
      if (sale.buyerUid !== uid) {
        throw new HttpsError(
            "permission-denied",
            "Only the buyer can start the marketplace payment.",
        );
      }
      if (!["pending_completion", "pending_payment"].includes(String(sale.status))) {
        throw new HttpsError(
            "failed-precondition",
            "This transaction is not eligible for a new payment.",
        );
      }
      const fee = sale.marketplaceFeeSnapshot;
      if (!fee || !Number.isSafeInteger(Number(fee.marketplaceFeeMinor))) {
        throw new HttpsError(
            "failed-precondition",
            "The server marketplace fee snapshot is not ready yet.",
        );
      }
      const sellerProvider = await db.collection("payment_provider_accounts")
          .doc(String(sale.sellerUid || "")).get();
      if (!sellerProvider.exists || sellerProvider.data().transferStatus !== "active") {
        throw new HttpsError(
            "failed-precondition",
            "The seller must finish payout verification before online checkout.",
        );
      }
      if (sellerProvider.data().sellerPayoutHold === true) {
        throw new HttpsError(
            "failed-precondition",
            "The seller has an unresolved refund or dispute recovery hold.",
        );
      }
      const listingSnapshot = await db.collection("public_listings")
          .doc(String(sale.listingId || "")).get();
      if (!listingSnapshot.exists) {
        throw new HttpsError("not-found", "The marketplace listing is unavailable.");
      }
      const listing = listingSnapshot.data();
      const amountMinor = Number(fee.agreedTotalMinor);
      if (!Number.isSafeInteger(amountMinor) || amountMinor <= 0) {
        throw new HttpsError("failed-precondition", "The checkout amount is invalid.");
      }
      const currency = String(fee.currency || sale.currency || "CAD").toLowerCase();
      const transferGroup = `PB_${transactionId}`.slice(0, 200);
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
      const existingSessionId = String(sale.stripeCheckoutSessionId || "");
      if (existingSessionId &&
          ["checkout_created", "processing", "paid"].includes(
              String(sale.paymentProviderStatus || ""),
          )) {
        return {
          transactionId,
          checkoutSessionId: existingSessionId,
          alreadyCreated: true,
        };
      }

      const session = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/checkout/sessions",
        idempotencyKey: `pipebuyer-checkout-${transactionId}-${sale.revision || 1}`,
        fields: {
          mode: "payment",
          success_url: successUrl,
          cancel_url: cancelUrl,
          client_reference_id: transactionId,
          billing_address_collection: "required",
          "automatic_tax[enabled]": "true",
          "line_items[0][quantity]": 1,
          "line_items[0][price_data][currency]": currency,
          "line_items[0][price_data][unit_amount]": amountMinor,
          "line_items[0][price_data][tax_behavior]": "exclusive",
          "line_items[0][price_data][product_data][name]":
            String(listing.title || "Pipe Buyer marketplace purchase").slice(0, 240),
          "line_items[0][price_data][product_data][tax_code]": taxCode,
          "payment_intent_data[transfer_group]": transferGroup,
          "payment_intent_data[metadata][pipeBuyerTransactionId]": transactionId,
          "metadata[pipeBuyerTransactionId]": transactionId,
          "metadata[listingId]": String(sale.listingId || ""),
          "metadata[sellerUid]": String(sale.sellerUid || ""),
          "metadata[buyerUid]": String(sale.buyerUid || ""),
          "metadata[feeScheduleRevision]": String(fee.scheduleRevision || ""),
        },
      });
      const sessionId = String(session.id || "");
      const checkoutUrl = String(session.url || "");
      if (!sessionId.startsWith("cs_") || !checkoutUrl.startsWith("https://")) {
        throw new HttpsError("internal", "Stripe did not return a valid checkout session.");
      }
      await transactionRef.set({
        paymentMethod: "stripe_checkout",
        paymentProvider: "stripe",
        paymentProviderStatus: "checkout_created",
        stripeCheckoutSessionId: sessionId,
        stripeTransferGroup: transferGroup,
        stripeCheckoutCreatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        transactionId,
        checkoutSessionId: sessionId,
        checkoutUrl,
        alreadyCreated: false,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace Stripe Checkout creation failed", error);
      throw new HttpsError("internal", "Marketplace checkout could not be started.");
    }
  };

  return {createMarketplaceCheckout};
}

module.exports = {
  createStripeCheckoutCommands,
  requireCheckoutReady,
  safeConfiguredUrl,
  stripeFormRequest,
};
