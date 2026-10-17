"use strict";

const crypto = require("node:crypto");
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
  refreshStripeRecipientAccountStatus,
} = require("./stripe_marketplace_commands");
const {
  requireStripeProviderMode,
  requireStripeTransactionMode,
  stripeSecretValueForMode,
} = require("./stripe_runtime_environment");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {
  createMarketplaceTaxCompliance,
} = require("./marketplace_tax_compliance");
const {taxBillingPrepared} = require("./pending_tax_policy");
const {
  requireFullGmvCheckoutEconomics,
} = require("./marketplace_checkout_economics");

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
    (readiness.stripeTaxReady ||
      readiness.marketplaceTaxCollectionDeferredApproved) &&
    readiness.stripeReconciliationReady;
  if (!ready) {
    throw new HttpsError(
        "failed-precondition",
        "Full marketplace checkout is not yet approved for live money movement.",
    );
  }
}

function requirePlatformFeeBillingReady(readiness) {
  const ready =
    ["sandbox", "production"].includes(readiness.stripeMode) &&
    readiness.stripeFeeBillingEnabled &&
    readiness.stripeWebhookVerified &&
    taxBillingPrepared(readiness) &&
    readiness.stripeReconciliationReady;
  if (!ready) {
    throw new HttpsError(
        "failed-precondition",
        "Pipe Buyer marketplace fee billing is not enabled yet.",
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

function safeStripeLogPath(path) {
  return String(path || "").split("?", 1)[0];
}

function stripeCheckoutRequestSnapshot(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError(
        "failed-precondition",
        "The Stripe checkout request cannot be resumed safely.",
    );
  }
  const snapshot = {};
  for (const key of Object.keys(value).sort()) {
    const item = value[key];
    if (!key || key.length > 180 ||
        !["string", "number", "boolean"].includes(typeof item)) {
      throw new HttpsError(
          "failed-precondition",
          "The Stripe checkout request cannot be resumed safely.",
      );
    }
    snapshot[key] = item;
  }
  if (!Object.keys(snapshot).length ||
      Buffer.byteLength(JSON.stringify(snapshot), "utf8") > 32 * 1024) {
    throw new HttpsError(
        "failed-precondition",
        "The Stripe checkout request cannot be resumed safely.",
    );
  }
  return snapshot;
}

function sameStripeCheckoutRequestSnapshot(left, right) {
  try {
    return JSON.stringify(stripeCheckoutRequestSnapshot(left)) ===
      JSON.stringify(stripeCheckoutRequestSnapshot(right));
  } catch (_) {
    return false;
  }
}

function marketplaceCheckoutAttemptId(
    transactionId,
    transactionRevision,
    attemptNumber,
) {
  const safeTransactionId = String(transactionId || "").trim();
  const safeRevision = Number(transactionRevision || 1);
  const safeAttemptNumber = Number(attemptNumber);
  if (!safeTransactionId || safeTransactionId.length > 180 ||
      safeTransactionId.includes("/") ||
      !Number.isSafeInteger(safeRevision) || safeRevision < 1 ||
      !Number.isSafeInteger(safeAttemptNumber) || safeAttemptNumber < 1) {
    throw new HttpsError(
        "failed-precondition",
        "The Stripe checkout attempt cannot be created safely.",
    );
  }
  return crypto.createHash("sha256")
      .update(JSON.stringify([
        "pipebuyer-marketplace-checkout-v1",
        safeTransactionId,
        safeRevision,
        safeAttemptNumber,
      ]))
      .digest("hex");
}

function marketplaceCheckoutIdempotencyKey(attemptId) {
  const safeAttemptId = String(attemptId || "").trim().toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(safeAttemptId)) {
    throw new HttpsError(
        "failed-precondition",
        "The Stripe checkout attempt cannot be resumed safely.",
    );
  }
  return `pipebuyer-checkout-${safeAttemptId}`;
}

function marketplaceExecutionCurrency(fee, sale) {
  const safeFee = fee && typeof fee === "object" ? fee : {};
  const safeSale = sale && typeof sale === "object" ? sale : {};
  const feeCurrency = String(safeFee.currency || "").trim().toUpperCase();
  const saleCurrency = String(safeSale.currency || "").trim().toUpperCase();
  if (feeCurrency && saleCurrency && feeCurrency !== saleCurrency) {
    throw new HttpsError(
        "failed-precondition",
        "The marketplace fee and sale currencies do not match.",
    );
  }
  const currency = feeCurrency || saleCurrency;
  if (!new Set(["CAD", "USD"]).has(currency)) {
    throw new HttpsError(
        "failed-precondition",
        "The marketplace transaction has no supported currency and must be reviewed.",
    );
  }
  return currency.toLowerCase();
}

function assertMarketplaceCheckoutSessionIdentity({
  sale,
  session,
  transactionId,
}) {
  const safeSale = sale && typeof sale === "object" ? sale : {};
  const safeSession = session && typeof session === "object" ? session : {};
  const expectedTransactionId = String(transactionId || "").trim();
  const sessionId = String(safeSession.id || "").trim();
  const metadata = safeSession.metadata &&
    typeof safeSession.metadata === "object" ? safeSession.metadata : {};
  const metadataTransactionId = String(
      metadata.pipeBuyerTransactionId || "",
  ).trim();
  const storedAttemptId = String(
      safeSale.stripeCheckoutAttemptId || "",
  ).trim();
  const metadataAttemptId = String(
      metadata.pipeBuyerCheckoutAttemptId || "",
  ).trim();
  const storedStripeMode = String(safeSale.stripeMode || "").trim();
  const metadataStripeMode = String(
      metadata.pipeBuyerStripeMode || "",
  ).trim();
  const storedSessionId = String(
      safeSale.stripeCheckoutSessionId || "",
  ).trim();
  const storedSettlementMode = String(
      safeSale.settlementMode || "",
  ).trim();
  const storedSettlementGeneration = Number(
      safeSale.settlementGeneration || 0,
  );
  const metadataSettlementGeneration = Number(
      metadata.pipeBuyerSettlementGeneration || 0,
  );
  const saleStatus = String(safeSale.status || "").trim();

  if (!sessionId.startsWith("cs_") || !expectedTransactionId ||
      metadataTransactionId !== expectedTransactionId ||
      ["cancelled", "disputed", "buyer_default_reported",
        "seller_default_reported"].includes(saleStatus)) {
    throw new Error("Stripe Checkout session identity does not match the sale.");
  }
  if (storedAttemptId) {
    if (storedSettlementMode !== "stripe_checkout" ||
        !["sandbox", "production"].includes(storedStripeMode) ||
        metadataStripeMode !== storedStripeMode ||
        !Number.isSafeInteger(storedSettlementGeneration) ||
        storedSettlementGeneration < 1 ||
        metadataSettlementGeneration !== storedSettlementGeneration ||
        metadataAttemptId !== storedAttemptId ||
        (storedSessionId && storedSessionId !== sessionId)) {
      throw new Error(
          "Stripe Checkout session attempt does not match the reserved sale.",
      );
    }
  } else if (!storedSessionId || storedSessionId !== sessionId) {
    throw new Error(
        "Legacy Stripe Checkout session does not match the stored sale session.",
    );
  }
  return {sessionId, attemptId: storedAttemptId || null};
}

function assertMarketplaceFeeCheckoutSessionIdentity({
  sale,
  session,
  transactionId,
}) {
  const safeSale = sale && typeof sale === "object" ? sale : {};
  const safeSession = session && typeof session === "object" ? session : {};
  const metadata = safeSession.metadata &&
    typeof safeSession.metadata === "object" ? safeSession.metadata : {};
  const expectedTransactionId = String(transactionId || "").trim();
  const sessionId = String(safeSession.id || "").trim();
  const storedSessionId = String(
      safeSale.stripeMarketplaceFeeSessionId || "",
  ).trim();
  const storedAttemptId = String(
      safeSale.stripeMarketplaceFeeAttemptId || "",
  ).trim();
  const metadataAttemptId = String(
      metadata.pipeBuyerFeeCheckoutAttemptId || "",
  ).trim();
  const storedStripeMode = String(safeSale.stripeMode || "").trim();
  const metadataStripeMode = String(
      metadata.pipeBuyerStripeMode || "",
  ).trim();
  const feeStatus = String(safeSale.marketplaceFeeStatus || "").trim();
  const settlementGeneration = Number(safeSale.settlementGeneration || 0);
  const attemptGeneration = Number(
      safeSale.stripeMarketplaceFeeSettlementGeneration || 0,
  );
  const metadataGeneration = Number(
      metadata.pipeBuyerSettlementGeneration || 0,
  );
  const modernAttemptMatches = storedAttemptId &&
    metadataAttemptId === storedAttemptId &&
    ["sandbox", "production"].includes(storedStripeMode) &&
    metadataStripeMode === storedStripeMode &&
    settlementGeneration > 0 &&
    attemptGeneration === settlementGeneration &&
    metadataGeneration === settlementGeneration;
  const sessionMatches = storedSessionId === sessionId ||
    (!storedSessionId && feeStatus === "checkout_creating" &&
      modernAttemptMatches);
  if (!expectedTransactionId || !sessionId.startsWith("cs_") ||
      String(metadata.pipeBuyerTransactionId || "").trim() !==
        expectedTransactionId ||
      !sessionMatches ||
      String(safeSale.paymentMethod || "") !== "external_settlement" ||
      (String(safeSale.settlementMode || "") &&
        String(safeSale.settlementMode || "") !== "external_settlement") ||
      (storedAttemptId ? !modernAttemptMatches :
        settlementGeneration > 0 &&
          metadataGeneration !== settlementGeneration)) {
    throw new Error(
        "Stripe marketplace-fee session identity does not match the sale.",
    );
  }
  return {
    sessionId,
    settlementGeneration,
    attemptId: storedAttemptId || null,
  };
}

function stripeCheckoutSessionState(session) {
  const safeSession = session && typeof session === "object" ? session : {};
  const status = String(safeSession.status || "").trim();
  const checkoutUrl = String(safeSession.url || "").trim();
  if (status === "open" && checkoutUrl.startsWith("https://")) {
    return {state: "open", checkoutUrl};
  }
  if (status === "expired") return {state: "expired", checkoutUrl: null};
  return {state: "pending", checkoutUrl: null};
}

function hasExternalSettlementState(sale) {
  const safeSale = sale && typeof sale === "object" ? sale : {};
  return String(safeSale.settlementMode || "") === "external_settlement" ||
    String(safeSale.paymentMethod || "") === "external_settlement" ||
    String(safeSale.paymentProvider || "") === "external" ||
    String(safeSale.paymentProviderStatus || "") === "external_agreed" ||
    safeSale.externalSettlementBuyerConfirmed === true ||
    safeSale.externalSettlementSellerConfirmed === true ||
    Boolean(String(safeSale.externalSettlementAgreedAt || "").trim());
}

function hasStripeCheckoutState(sale) {
  const safeSale = sale && typeof sale === "object" ? sale : {};
  const providerStatus = String(
      safeSale.paymentProviderStatus || "",
  ).trim();
  return String(safeSale.settlementMode || "") === "stripe_checkout" ||
    String(safeSale.paymentMethod || "") === "stripe_checkout" ||
    String(safeSale.paymentProvider || "") === "stripe" ||
    !["", "not_started"].includes(providerStatus) ||
    Boolean(String(safeSale.stripeCheckoutSessionId || "").trim()) ||
    Boolean(String(safeSale.stripeCheckoutAttemptId || "").trim()) ||
    Boolean(String(safeSale.stripeCheckoutIdempotencyKey || "").trim());
}

function marketplaceCheckoutSaleIdentity(sale) {
  const safeSale = sale && typeof sale === "object" ? sale : {};
  const fee = safeSale.marketplaceFeeSnapshot &&
    typeof safeSale.marketplaceFeeSnapshot === "object" ?
    safeSale.marketplaceFeeSnapshot : {};
  return JSON.stringify([
    String(safeSale.buyerUid || ""),
    String(safeSale.sellerUid || ""),
    String(safeSale.listingId || ""),
    Number(safeSale.revision || 1),
    Number(fee.agreedTotalMinor),
    String(fee.currency || safeSale.currency || ""),
    Number(fee.marketplaceFeeMinor),
    Number(fee.sellerProceedsBeforeTaxMinor),
    String(fee.scheduleRevision || ""),
  ]);
}

function marketplaceCheckoutReservationFromSale(sale) {
  const safeSale = sale && typeof sale === "object" ? sale : {};
  const attemptId = String(safeSale.stripeCheckoutAttemptId || "").trim();
  const idempotencyKey = String(
      safeSale.stripeCheckoutIdempotencyKey || "",
  ).trim();
  const settlementGeneration = Number(safeSale.settlementGeneration || 0);
  const attemptNumber = Number(safeSale.stripeCheckoutAttemptNumber || 0);
  const fields = stripeCheckoutRequestSnapshot(
      safeSale.stripeCheckoutRequestSnapshot,
  );
  if (String(safeSale.settlementMode || "") !== "stripe_checkout" ||
      !Number.isSafeInteger(settlementGeneration) || settlementGeneration < 1 ||
      !Number.isSafeInteger(attemptNumber) || attemptNumber < 1 ||
      idempotencyKey !== marketplaceCheckoutIdempotencyKey(attemptId)) {
    throw new HttpsError(
        "failed-precondition",
        "The reserved marketplace checkout cannot be resumed safely.",
    );
  }
  return {
    attemptId,
    attemptNumber,
    fields,
    idempotencyKey,
    settlementGeneration,
  };
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
    const stripeErrorCode = String(
        payload && payload.error && payload.error.code || "",
    ).slice(0, 120);
    const stripeErrorType = String(
        payload && payload.error && payload.error.type || "",
    ).slice(0, 120);
    const stripeCode = stripeErrorCode || stripeErrorType;
    const ambiguousStripeCode = new Set([
      "idempotency_error",
      "idempotency_key_in_use",
    ]);
    const stripeIdempotencyAmbiguous =
      ambiguousStripeCode.has(stripeErrorCode.toLowerCase()) ||
      ambiguousStripeCode.has(stripeErrorType.toLowerCase());
    console.error("Stripe Checkout request failed", {
      path: safeStripeLogPath(path),
      status: response.status,
      stripeCode,
    });
    throw new HttpsError(
        response.status === 429 ? "resource-exhausted" : "failed-precondition",
        "Stripe could not start this marketplace payment.",
        {
          stripeRequestDefinitiveFailure:
            response.status >= 400 && response.status < 500 &&
            !new Set([408, 409, 424, 429]).has(response.status) &&
            !stripeIdempotencyAmbiguous,
          stripeHttpStatus: response.status,
          stripeCode,
        },
    );
  }
  return payload || {};
}

function createStripeCheckoutCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const taxCompliance = createMarketplaceTaxCompliance(admin);

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
      const stripeMode = String(readiness.stripeMode || "").trim();
      const stripeSecret = stripeSecretValueForMode(stripeMode);

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
      if (hasExternalSettlementState(sale)) {
        throw new HttpsError(
            "failed-precondition",
            "This transaction is already using external settlement.",
        );
      }
      if (hasStripeCheckoutState(sale)) {
        requireStripeTransactionMode(sale, stripeMode);
      }
      const fee = sale.marketplaceFeeSnapshot;
      if (!fee || !Number.isSafeInteger(Number(fee.marketplaceFeeMinor))) {
        throw new HttpsError(
            "failed-precondition",
            "The server marketplace fee snapshot is not ready yet.",
        );
      }
      const checkoutEconomics = requireFullGmvCheckoutEconomics({
        readiness,
        feeSnapshot: fee,
      });
      const buyerUid = String(sale.buyerUid || "");
      const sellerUid = String(sale.sellerUid || "");
      const [buyerTaxProfile, sellerTaxProfile] = await Promise.all([
        db.collection("business_tax_profiles").doc(buyerUid).get(),
        db.collection("business_tax_profiles").doc(sellerUid).get(),
      ]);
      if ((buyerTaxProfile.exists && buyerTaxProfile.data().taxComplianceHold === true) ||
          (sellerTaxProfile.exists && sellerTaxProfile.data().taxComplianceHold === true)) {
        throw new HttpsError(
            "failed-precondition",
            "A buyer or seller tax-compliance recovery hold must be resolved before online checkout.",
        );
      }
      const sellerProviderRef = db.collection("payment_provider_accounts")
          .doc(sellerUid);
      const sellerProvider = await sellerProviderRef.get();
      if (!sellerProvider.exists) {
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
      requireStripeProviderMode(sellerProvider.data(), stripeMode);
      const sellerRecipientStatus = await refreshStripeRecipientAccountStatus({
        providerRef: sellerProviderRef,
        providerData: sellerProvider.data(),
        FieldValue,
        secretKey: stripeSecret,
        expectedMode: stripeMode,
      });
      if (!sellerRecipientStatus.payoutReady) {
        throw new HttpsError(
            "failed-precondition",
            "The seller must finish payout verification before online checkout.",
        );
      }
      const listingSnapshot = await db.collection("public_listings")
          .doc(String(sale.listingId || "")).get();
      if (!listingSnapshot.exists) {
        throw new HttpsError("not-found", "The marketplace listing is unavailable.");
      }
      const listing = listingSnapshot.data();
      const automaticTax = readiness.stripeTaxReady === true;
      const taxCollectionStatus = automaticTax ?
        "registered" : "collection_deferred";
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
      const amountMinor = Number(fee.agreedTotalMinor);
      if (!Number.isSafeInteger(amountMinor) || amountMinor <= 0) {
        throw new HttpsError("failed-precondition", "The checkout amount is invalid.");
      }
      const currency = marketplaceExecutionCurrency(fee, sale);
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
      const initialSaleIdentity = marketplaceCheckoutSaleIdentity(sale);

      function checkoutFields(attemptId, settlementGeneration) {
        return stripeCheckoutRequestSnapshot({
          mode: "payment",
          integration_identifier:
            stripeMarketplaceConfig.integrationIdentifiers
                .marketplaceCheckout,
          payment_method_configuration:
            checkoutEconomics.paymentMethodConfigurationId,
          success_url: successUrl,
          cancel_url: cancelUrl,
          client_reference_id: transactionId,
          billing_address_collection: "required",
          "tax_id_collection[enabled]": automaticTax ? "true" : "false",
          "automatic_tax[enabled]": automaticTax ? "true" : "false",
          "line_items[0][quantity]": 1,
          "line_items[0][price_data][currency]": currency,
          "line_items[0][price_data][unit_amount]": amountMinor,
          ...(automaticTax ? {
            "line_items[0][price_data][tax_behavior]": "exclusive",
          } : {}),
          "line_items[0][price_data][product_data][name]":
            String(listing.title || "Pipe Buyer marketplace purchase")
                .slice(0, 240),
          ...(automaticTax ? {
            "line_items[0][price_data][product_data][tax_code]": taxCode,
          } : {}),
          "payment_intent_data[transfer_group]": transferGroup,
          "payment_intent_data[metadata][pipeBuyerTransactionId]": transactionId,
          "payment_intent_data[metadata][pipeBuyerCheckoutAttemptId]": attemptId,
          "payment_intent_data[metadata][pipeBuyerSettlementGeneration]":
            settlementGeneration,
          "metadata[pipeBuyerTransactionId]": transactionId,
          "metadata[pipeBuyerCheckoutAttemptId]": attemptId,
          "metadata[pipeBuyerSettlementGeneration]": settlementGeneration,
          "metadata[pipeBuyerStripeMode]": stripeMode,
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
        });
      }

      const reservation = await db.runTransaction(
          async (firestoreTransaction) => {
            const currentSnapshot = await firestoreTransaction.get(transactionRef);
            if (!currentSnapshot.exists) {
              throw new HttpsError(
                  "not-found",
                  "This marketplace transaction is unavailable.",
              );
            }
            const currentSale = currentSnapshot.data();
            if (currentSale.buyerUid !== uid) {
              throw new HttpsError(
                  "permission-denied",
                  "Only the buyer can start the marketplace payment.",
              );
            }
            if (!["pending_completion", "pending_payment"].includes(
                String(currentSale.status || ""),
            )) {
              throw new HttpsError(
                  "failed-precondition",
                  "This transaction is not eligible for a new payment.",
              );
            }
            if (hasExternalSettlementState(currentSale)) {
              throw new HttpsError(
                  "failed-precondition",
                  "This transaction is already using external settlement.",
              );
            }
            if (marketplaceCheckoutSaleIdentity(currentSale) !==
                initialSaleIdentity) {
              throw new HttpsError(
                  "aborted",
                  "The transaction changed while checkout was being prepared. Try again.",
              );
            }

            const providerStatus = String(
                currentSale.paymentProviderStatus || "",
            ).trim();
            if (hasStripeCheckoutState(currentSale)) {
              requireStripeTransactionMode(currentSale, stripeMode);
            }
            const existingSessionId = String(
                currentSale.stripeCheckoutSessionId || "",
            ).trim();
            if (providerStatus === "paid") {
              return {
                kind: "paid",
                sessionId: existingSessionId,
              };
            }
            if (["checkout_created", "processing"].includes(providerStatus)) {
              if (!existingSessionId.startsWith("cs_")) {
                throw new HttpsError(
                    "failed-precondition",
                    "The active marketplace checkout is missing its Stripe session.",
                );
              }
              return {
                kind: "existing",
                sale: currentSale,
                sessionId: existingSessionId,
              };
            }
            if (providerStatus === "checkout_creating") {
              return {
                kind: "reserved",
                sale: currentSale,
                ...marketplaceCheckoutReservationFromSale(currentSale),
                resumed: true,
              };
            }
            if (!["", "not_started", "failed"].includes(providerStatus)) {
              throw new HttpsError(
                  "failed-precondition",
                  "This transaction cannot start another Stripe checkout.",
              );
            }
            const currentSettlementMode = String(
                currentSale.settlementMode || "",
            ).trim();
            if (currentSettlementMode &&
                currentSettlementMode !== "stripe_checkout") {
              throw new HttpsError(
                  "failed-precondition",
                  "This transaction is reserved for another settlement method.",
              );
            }
            const previousGeneration = Number(
                currentSale.settlementGeneration || 0,
            );
            const previousAttemptNumber = Number(
                currentSale.stripeCheckoutAttemptNumber || 0,
            );
            if (!Number.isSafeInteger(previousGeneration) ||
                previousGeneration < 0 ||
                !Number.isSafeInteger(previousAttemptNumber) ||
                previousAttemptNumber < 0) {
              throw new HttpsError(
                  "failed-precondition",
                  "The marketplace checkout history is invalid.",
              );
            }
            const settlementGeneration = previousGeneration + 1;
            const attemptNumber = previousAttemptNumber + 1;
            const attemptId = marketplaceCheckoutAttemptId(
                transactionId,
                currentSale.revision || 1,
                attemptNumber,
            );
            const idempotencyKey = marketplaceCheckoutIdempotencyKey(attemptId);
            const fields = checkoutFields(attemptId, settlementGeneration);
            firestoreTransaction.set(transactionRef, {
              settlementMode: "stripe_checkout",
              settlementGeneration,
              paymentMethod: "stripe_checkout",
              paymentProvider: "stripe",
              paymentProviderStatus: "checkout_creating",
              stripeMode,
              stripeSellerDestinationAccountId:
                sellerRecipientStatus.accountId,
              stripeCheckoutSessionId: FieldValue.delete(),
              stripeCheckoutAttemptId: attemptId,
              stripeCheckoutAttemptNumber: attemptNumber,
              stripeCheckoutIdempotencyKey: idempotencyKey,
              stripeCheckoutRequestSnapshot: fields,
              stripeCheckoutEconomicsDecision: checkoutEconomics,
              stripeTransferGroup: transferGroup,
              taxCollectionStatus,
              stripeAutomaticTaxEnabled: automaticTax,
              taxComplianceSnapshot,
              stripeCheckoutAttemptReservedAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            }, {merge: true});
            return {
              kind: "reserved",
              sale: {
                ...currentSale,
                settlementMode: "stripe_checkout",
                settlementGeneration,
                stripeCheckoutAttemptId: attemptId,
                stripeMode,
                stripeSellerDestinationAccountId:
                  sellerRecipientStatus.accountId,
              },
              attemptId,
              attemptNumber,
              fields,
              idempotencyKey,
              settlementGeneration,
              resumed: false,
            };
          },
      );

      if (reservation.kind === "paid") {
        return {
          transactionId,
          checkoutSessionId: reservation.sessionId,
          alreadyCreated: true,
          alreadyPaid: true,
        };
      }
      if (reservation.kind === "existing") {
        const existingSession = await stripeFormRequest({
          secretKey: stripeSecret,
          path: `/v1/checkout/sessions/${encodeURIComponent(
              reservation.sessionId,
          )}`,
          method: "GET",
        });
        assertMarketplaceCheckoutSessionIdentity({
          sale: reservation.sale,
          session: existingSession,
          transactionId,
        });
        const existingState = stripeCheckoutSessionState(existingSession);
        if (existingState.state === "open") {
          return {
            transactionId,
            checkoutSessionId: reservation.sessionId,
            checkoutUrl: existingState.checkoutUrl,
            alreadyCreated: true,
            alreadyPaid: false,
          };
        }
        if (existingState.state === "expired") {
          await db.runTransaction(async (firestoreTransaction) => {
            const currentSnapshot = await firestoreTransaction.get(transactionRef);
            if (!currentSnapshot.exists) return;
            const currentSale = currentSnapshot.data();
            if (String(currentSale.stripeCheckoutSessionId || "") !==
                  reservation.sessionId ||
                !["checkout_created", "processing"].includes(
                    String(currentSale.paymentProviderStatus || ""),
                )) {
              return;
            }
            firestoreTransaction.set(transactionRef, {
              paymentProviderStatus: "failed",
              stripeCheckoutExpiredAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            }, {merge: true});
          });
          throw new HttpsError(
              "failed-precondition",
              "The previous checkout expired. Start payment again.",
          );
        }
        throw new HttpsError(
            "failed-precondition",
            "This checkout is already completing. Refresh the transaction shortly.",
        );
      }

      let session;
      try {
        session = await stripeFormRequest({
          secretKey: stripeSecret,
          path: "/v1/checkout/sessions",
          idempotencyKey: reservation.idempotencyKey,
          fields: reservation.fields,
        });
      } catch (error) {
        if (error && error.details &&
            error.details.stripeRequestDefinitiveFailure === true) {
          await db.runTransaction(async (firestoreTransaction) => {
            const currentSnapshot = await firestoreTransaction.get(transactionRef);
            if (!currentSnapshot.exists) return;
            const currentSale = currentSnapshot.data();
            if (String(currentSale.paymentProviderStatus || "") !==
                  "checkout_creating" ||
                String(currentSale.stripeCheckoutAttemptId || "") !==
                  reservation.attemptId ||
                Number(currentSale.settlementGeneration || 0) !==
                  reservation.settlementGeneration) {
              return;
            }
            firestoreTransaction.set(transactionRef, {
              paymentProviderStatus: "failed",
              stripeCheckoutDefinitiveFailureAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            }, {merge: true});
          });
        }
        throw error;
      }

      const sessionId = String(session.id || "");
      const checkoutUrl = String(session.url || "");
      if (!checkoutUrl.startsWith("https://")) {
        throw new HttpsError(
            "internal",
            "Stripe did not return a valid checkout session.",
        );
      }
      assertMarketplaceCheckoutSessionIdentity({
        sale: reservation.sale,
        session,
        transactionId,
      });
      const finalized = await db.runTransaction(async (firestoreTransaction) => {
        const currentSnapshot = await firestoreTransaction.get(transactionRef);
        if (!currentSnapshot.exists) {
          throw new HttpsError(
              "not-found",
              "This marketplace transaction is unavailable.",
          );
        }
        const currentSale = currentSnapshot.data();
        const currentStatus = String(
            currentSale.paymentProviderStatus || "",
        );
        if (["paid", "processing", "checkout_created"].includes(currentStatus)) {
          assertMarketplaceCheckoutSessionIdentity({
            sale: currentSale,
            session,
            transactionId,
          });
          return {alreadyPaid: currentStatus === "paid"};
        }
        if (currentStatus !== "checkout_creating" ||
            String(currentSale.stripeCheckoutAttemptId || "") !==
              reservation.attemptId ||
            Number(currentSale.settlementGeneration || 0) !==
              reservation.settlementGeneration ||
            !sameStripeCheckoutRequestSnapshot(
                currentSale.stripeCheckoutRequestSnapshot,
                reservation.fields,
            )) {
          throw new HttpsError(
              "aborted",
              "The checkout reservation changed before Stripe returned.",
          );
        }
        firestoreTransaction.set(transactionRef, {
          paymentProviderStatus: "checkout_created",
          stripeCheckoutSessionId: sessionId,
          stripeCheckoutCreatedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {alreadyPaid: false};
      });
      return {
        transactionId,
        checkoutSessionId: sessionId,
        checkoutUrl,
        alreadyCreated: reservation.resumed,
        alreadyPaid: finalized.alreadyPaid,
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
  assertMarketplaceFeeCheckoutSessionIdentity,
  assertMarketplaceCheckoutSessionIdentity,
  createStripeCheckoutCommands,
  hasExternalSettlementState,
  marketplaceCheckoutAttemptId,
  marketplaceCheckoutIdempotencyKey,
  marketplaceCheckoutReservationFromSale,
  marketplaceCheckoutSaleIdentity,
  marketplaceExecutionCurrency,
  requireCheckoutReady,
  requirePlatformFeeBillingReady,
  safeConfiguredUrl,
  safeStripeLogPath,
  sameStripeCheckoutRequestSnapshot,
  stripeCheckoutSessionState,
  stripeCheckoutRequestSnapshot,
  stripeFormRequest,
};
