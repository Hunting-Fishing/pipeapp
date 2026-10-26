"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {loadPhase1FeatureFlags} = require("./phase1_feature_flags");
const {
  loadProviderReadiness,
  safeConfiguredUrl,
  stripeFormRequest,
  stripeSecretKey,
} = require("./stripe_marketplace_commands");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {
  automaticTaxEnabled,
  taxCollectionStatus,
} = require("./pending_tax_policy");
const {requireSubscriptionReady} = require("./dispatch_subscription_commands");
const {
  GlobalPaymentPolicyError,
  appendCheckoutReturnParams,
  assertCountryPayableWithStripe,
  extractCheckoutSettlementAmounts,
} = require("./global_payment_policy");
const {buildPublicEntry, normalizeLogoUrl, text} = require("./yellow_pages_policy");

const PRIVATE_COMPANIES = "yellow_pages_companies";
const PUBLIC_ENTRIES = "yellow_pages_public_entries";
const LISTING_REQUESTS = "yellow_pages_listing_requests";
const YP_CHECKOUT_SESSIONS = "yellow_pages_checkout_sessions";

const YELLOW_PAGES_PAID_TIERS = new Set(["paid_verified", "featured_platinum"]);
const YELLOW_PAGES_BILLING_INTERVALS = new Set(["monthly", "yearly"]);

function normalizeYellowPagesBillingInterval(value) {
  const clean = String(value || "").trim().toLowerCase();
  if (clean === "month" || clean === "monthly") return "monthly";
  if (clean === "year" || clean === "yearly" || clean === "annual") return "yearly";
  return "yearly";
}

function resolveYellowPagesPriceSpec(
    tier,
    billingInterval,
    config = stripeMarketplaceConfig,
) {
  const cleanTier = String(tier || "").trim().toLowerCase();
  const interval = normalizeYellowPagesBillingInterval(billingInterval);
  const products = config.products || {};
  if (cleanTier === "paid_verified") {
    return interval === "monthly" ?
      products.yellowPagesVerifiedProMonthly :
      products.yellowPagesVerifiedProYearly;
  }
  if (cleanTier === "featured_platinum") {
    return interval === "monthly" ?
      products.yellowPagesFeaturedMonthly :
      products.yellowPagesFeaturedYearly;
  }
  return null;
}

function yellowPagesPlanForPriceId(priceId, config = stripeMarketplaceConfig) {
  const cleanPriceId = String(priceId || "").trim();
  if (!cleanPriceId.startsWith("price_")) return null;
  const products = config.products || {};
  const candidates = [
    products.yellowPagesVerifiedProMonthly,
    products.yellowPagesVerifiedProYearly,
    products.yellowPagesFeaturedMonthly,
    products.yellowPagesFeaturedYearly,
  ].filter(Boolean);
  const matched = candidates.find((p) => p.priceId === cleanPriceId);
  if (!matched) return null;
  return {
    priceId: matched.priceId,
    productId: matched.productId,
    directoryTier: matched.directoryTier,
    billingInterval: matched.billingInterval === "year" ? "yearly" : "monthly",
    planCode: matched.planCode,
    unitAmountMinor: matched.unitAmountMinor,
    cadUnitAmountMinor: matched.cadUnitAmountMinor,
  };
}

function extractStripeId(value, prefix) {
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.startsWith(prefix) ? trimmed : "";
  }
  const id = String((value && value.id) || "").trim();
  return id.startsWith(prefix) ? id : "";
}

function invoiceYellowPagesPlan(invoice, config = stripeMarketplaceConfig) {
  const lines = invoice && invoice.lines && invoice.lines.data;
  if (!Array.isArray(lines)) return null;
  for (const line of lines) {
    const priceCandidates = [
      extractStripeId(line && line.price, "price_"),
      extractStripeId(
          line &&
          line.pricing &&
          line.pricing.price_details &&
          line.pricing.price_details.price,
          "price_",
      ),
      extractStripeId(line && line.plan, "price_"),
    ];
    for (const candidate of priceCandidates) {
      const plan = yellowPagesPlanForPriceId(candidate, config);
      if (plan) return {plan, line};
    }
  }
  return null;
}

function subscriptionYellowPagesPlan(
    subscription,
    config = stripeMarketplaceConfig,
) {
  const items = subscription && subscription.items && subscription.items.data;
  if (Array.isArray(items)) {
    for (const item of items) {
      const priceId = extractStripeId(item && item.price, "price_");
      const plan = yellowPagesPlanForPriceId(priceId, config);
      if (plan) return plan;
    }
  }
  const meta = (subscription && subscription.metadata) || {};
  if (meta.billingType === "yellow_pages_subscription" && meta.directoryTier) {
    const spec = resolveYellowPagesPriceSpec(
        meta.directoryTier,
        meta.billingInterval,
        config,
    );
    if (spec) return yellowPagesPlanForPriceId(spec.priceId, config);
  }
  return null;
}

function fallbackPeriodSeconds(billingInterval) {
  return billingInterval === "monthly" ?
    32 * 24 * 60 * 60 :
    366 * 24 * 60 * 60;
}

function createYellowPagesBilling(admin, config = stripeMarketplaceConfig) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  async function reconcileCompanyPublicProjection(companyId) {
    if (!companyId || companyId.includes("/")) return;
    const companyRef = db.collection(PRIVATE_COMPANIES).doc(companyId);
    const publicRef = db.collection(PUBLIC_ENTRIES).doc(companyId);
    await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(companyRef);
      if (!snap.exists) {
        transaction.delete(publicRef);
        return;
      }
      const company = snap.data() || {};
      const entry = buildPublicEntry(company, companyId, FieldValue.serverTimestamp());
      if (entry) transaction.set(publicRef, entry);
      else transaction.delete(publicRef);
    });
  }

  async function resolveRequestAndCompany({requestId, subscriptionId, companyId}) {
    let resolvedReqRef = null;
    let resolvedReqData = null;
    if (requestId && !requestId.includes("/")) {
      const snap = await db.collection(LISTING_REQUESTS).doc(requestId).get();
      if (snap.exists) {
        resolvedReqRef = snap.ref;
        resolvedReqData = snap.data() || {};
      }
    }
    if (!resolvedReqRef && subscriptionId) {
      const bySub = await db.collection(LISTING_REQUESTS)
          .where("stripeSubscriptionId", "==", subscriptionId)
          .limit(1)
          .get();
      if (!bySub.empty) {
        resolvedReqRef = bySub.docs[0].ref;
        resolvedReqData = bySub.docs[0].data() || {};
      }
    }

    let resolvedCompanyId = text(
        companyId ||
        (resolvedReqData &&
          (resolvedReqData.resolvedCompanyId || resolvedReqData.claimedCompanyId)),
        200,
    );
    if (!resolvedCompanyId && subscriptionId) {
      const compBySub = await db.collection(PRIVATE_COMPANIES)
          .where("stripeSubscriptionId", "==", subscriptionId)
          .limit(1)
          .get();
      if (!compBySub.empty) {
        resolvedCompanyId = compBySub.docs[0].id;
      }
    }
    return {
      reqRef: resolvedReqRef,
      reqData: resolvedReqData,
      companyId: resolvedCompanyId || null,
    };
  }

  const createYellowPagesListingCheckout = async (request) => {
    try {
      if (!request || !request.auth || !request.auth.uid) {
        throw new HttpsError(
            "unauthenticated",
            "Sign in to start Oilfield Directory checkout.",
        );
      }
      const uid = request.auth.uid;
      await enforceUserRateLimit({db, admin, request, scope: "account"});

      const data = request.data || {};
      const requestId = text(data.requestId, 200);
      if (!requestId || requestId.includes("/")) {
        throw new HttpsError(
            "invalid-argument",
            "A valid directory listing requestId is required.",
        );
      }

      const [flags, readinessSnapshot, reqSnapshot, userSnapshot] =
        await Promise.all([
          loadPhase1FeatureFlags(db),
          db.collection("platform_configuration")
              .doc("payment_provider_readiness")
              .get(),
          db.collection(LISTING_REQUESTS).doc(requestId).get(),
          db.collection("users").doc(uid).get(),
        ]);

      if (flags.paidFeatures !== true) {
        throw new HttpsError(
            "failed-precondition",
            "Paid directory checkout is not enabled right now. Your listing request is saved for review.",
        );
      }
      if (!reqSnapshot.exists) {
        throw new HttpsError("not-found", "Directory listing request not found.");
      }
      const reqData = reqSnapshot.data() || {};
      if (String(reqData.submitterUid || "") !== uid) {
        throw new HttpsError(
            "permission-denied",
            "Only the business submitter can start checkout for this listing request.",
        );
      }

      const requestedTier = text(
          data.requestedTier || reqData.requestedTier,
          40,
      ).toLowerCase();
      if (!YELLOW_PAGES_PAID_TIERS.has(requestedTier)) {
        throw new HttpsError(
            "invalid-argument",
            "Basic Verified listings are free and do not require Stripe Checkout.",
        );
      }

      const billingInterval = normalizeYellowPagesBillingInterval(
          data.billingInterval || reqData.billingInterval || "yearly",
      );
      const priceSpec = resolveYellowPagesPriceSpec(
          requestedTier,
          billingInterval,
          config,
      );
      if (!priceSpec || !priceSpec.priceId) {
        throw new HttpsError(
            "failed-precondition",
            "Stripe pricing for this Oilfield Directory tier is not configured.",
        );
      }

      assertCountryPayableWithStripe(
          reqData.countryCode,
          `${reqData.regionCode || ""} ${reqData.city || ""}`,
      );

      const readinessData = readinessSnapshot.exists ?
        readinessSnapshot.data() : {};
      const readiness = {
        ...(await loadProviderReadiness(db)),
        stripeSubscriptionsEnabled:
          readinessData.stripeSubscriptionsEnabled === true,
        stripeTaxRegistrationPending:
          readinessData.stripeTaxRegistrationPending === true,
        stripeTaxPendingBillingApproved:
          readinessData.stripeTaxPendingBillingApproved === true,
      };
      requireSubscriptionReady(readiness);

      const secretKey = stripeSecretKey.value();
      if (!secretKey) {
        throw new HttpsError("failed-precondition", "Stripe is not configured.");
      }

      if (reqData.paymentStatus === "paid") {
        return {
          requestId,
          alreadyPaid: true,
          requestedTier,
          billingInterval,
        };
      }

      const existingSessionId = text(reqData.stripeCheckoutSessionId, 200);
      if (
        existingSessionId.startsWith("cs_") &&
        reqData.requestedPriceId === priceSpec.priceId &&
        reqData.billingInterval === billingInterval
      ) {
        try {
          const existingSession = await stripeFormRequest({
            secretKey,
            path: `/v1/checkout/sessions/${encodeURIComponent(existingSessionId)}`,
            method: "GET",
          });
          if (
            existingSession &&
            existingSession.status === "open" &&
            String(existingSession.url || "").startsWith("https://")
          ) {
            return {
              requestId,
              checkoutSessionId: existingSessionId,
              checkoutUrl: String(existingSession.url),
              requestedTier,
              billingInterval,
              currency: String(existingSession.currency || "").toUpperCase(),
              alreadyCreated: true,
            };
          }
        } catch (_) {
          // Fall through and create a fresh Checkout Session if expired/unavailable.
        }
      }

      const countryCode = String(reqData.countryCode || "").trim().toUpperCase();
      const requestedCurrency = String(data.currency || "").trim().toUpperCase();
      const checkoutCurrency =
        requestedCurrency === "CAD" || (!requestedCurrency && countryCode === "CA") ?
          "cad" :
          "usd";

      const userData = userSnapshot.exists ? userSnapshot.data() || {} : {};
      const existingCustomerId = extractStripeId(
          reqData.stripeCustomerId || userData.stripeCustomerId,
          "cus_",
      );
      const customerEmail = text(
          reqData.email ||
          (request.auth.token && request.auth.token.email) ||
          userData.email,
          254,
      );

      const baseSuccessUrl = safeConfiguredUrl(
          readiness.checkoutSuccessUrl,
          "Stripe Checkout success URL",
      );
      const baseCancelUrl = safeConfiguredUrl(
          readiness.checkoutCancelUrl,
          "Stripe Checkout cancel URL",
      );
      const successUrl = appendCheckoutReturnParams(baseSuccessUrl, {
        flow: "yellow_pages",
        requestId,
        tier: requestedTier,
      });
      const cancelUrl = appendCheckoutReturnParams(baseCancelUrl, {
        flow: "yellow_pages",
        requestId,
        tier: requestedTier,
      });

      const collectionStatus = taxCollectionStatus(readiness);
      const autoTax = automaticTaxEnabled(readiness);
      const attemptNumber = Math.max(1, Number(reqData.checkoutAttempt || 0) + 1);
      const companyId = text(
          reqData.resolvedCompanyId || reqData.claimedCompanyId,
          200,
      );

      const checkout = await stripeFormRequest({
        secretKey,
        path: "/v1/checkout/sessions",
        idempotencyKey: `pipebuyer-yp-checkout-${requestId}-${priceSpec.planCode}-${attemptNumber}`,
        fields: {
          mode: "subscription",
          currency: checkoutCurrency,
          success_url: successUrl,
          cancel_url: cancelUrl,
          client_reference_id: requestId,
          ...(existingCustomerId ? {
            customer: existingCustomerId,
            "customer_update[address]": "auto",
            "customer_update[name]": "auto",
          } : (customerEmail ? {customer_email: customerEmail} : {})),
          billing_address_collection: "required",
          allow_promotion_codes: "true",
          "automatic_tax[enabled]": autoTax ? "true" : "false",
          "tax_id_collection[enabled]": "true",
          "adaptive_pricing[enabled]": "true",
          "phone_number_collection[enabled]": "true",
          "line_items[0][price]": priceSpec.priceId,
          "line_items[0][quantity]": 1,
          "metadata[billingType]": "yellow_pages_subscription",
          "metadata[pipeBuyerUid]": uid,
          "metadata[yellowPagesRequestId]": requestId,
          ...(companyId ? {"metadata[yellowPagesCompanyId]": companyId} : {}),
          "metadata[directoryTier]": requestedTier,
          "metadata[billingInterval]": billingInterval,
          "metadata[planCode]": priceSpec.planCode,
          "metadata[countryCode]": countryCode,
          "metadata[taxCollectionStatus]": collectionStatus,
          "subscription_data[metadata][billingType]": "yellow_pages_subscription",
          "subscription_data[metadata][pipeBuyerUid]": uid,
          "subscription_data[metadata][yellowPagesRequestId]": requestId,
          ...(companyId ? {
            "subscription_data[metadata][yellowPagesCompanyId]": companyId,
          } : {}),
          "subscription_data[metadata][directoryTier]": requestedTier,
          "subscription_data[metadata][billingInterval]": billingInterval,
          "subscription_data[metadata][planCode]": priceSpec.planCode,
          "subscription_data[metadata][countryCode]": countryCode,
          "subscription_data[metadata][taxCollectionStatus]": collectionStatus,
        },
      });

      const sessionId = String(checkout.id || "");
      const checkoutUrl = String(checkout.url || "");
      if (!sessionId.startsWith("cs_") || !checkoutUrl.startsWith("https://")) {
        throw new HttpsError(
            "internal",
            "Stripe did not return a valid Oilfield Directory checkout session.",
        );
      }

      await Promise.all([
        reqSnapshot.ref.set({
          requestedTier,
          billingInterval,
          requestedPriceId: priceSpec.priceId,
          requestedPlanCode: priceSpec.planCode,
          checkoutCurrency: checkoutCurrency.toUpperCase(),
          paymentStatus: "checkout_created",
          stripeCheckoutSessionId: sessionId,
          checkoutAttempt: attemptNumber,
          taxCollectionStatus: collectionStatus,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}),
        db.collection(YP_CHECKOUT_SESSIONS).doc(sessionId).set({
          uid,
          requestId,
          companyId: companyId || null,
          directoryTier: requestedTier,
          billingInterval,
          priceId: priceSpec.priceId,
          planCode: priceSpec.planCode,
          checkoutCurrency: checkoutCurrency.toUpperCase(),
          status: "created",
          taxCollectionStatus: collectionStatus,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}),
      ]);

      return {
        requestId,
        checkoutSessionId: sessionId,
        checkoutUrl,
        requestedTier,
        billingInterval,
        currency: checkoutCurrency.toUpperCase(),
        alreadyCreated: false,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof GlobalPaymentPolicyError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Yellow Pages checkout creation failed", error);
      throw new HttpsError(
          "internal",
          "Oilfield Directory checkout could not be started.",
      );
    }
  };

  const createYellowPagesBillingPortalSession = async (request) => {
    try {
      if (!request || !request.auth || !request.auth.uid) {
        throw new HttpsError(
            "unauthenticated",
            "Sign in to manage Oilfield Directory billing.",
        );
      }
      const uid = request.auth.uid;
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const data = request.data || {};
      const requestId = text(data.requestId, 200);
      const companyId = text(data.companyId, 200);

      let stripeCustomerId = "";
      if (requestId && !requestId.includes("/")) {
        const reqSnap = await db.collection(LISTING_REQUESTS).doc(requestId).get();
        if (reqSnap.exists && reqSnap.data().submitterUid === uid) {
          stripeCustomerId = extractStripeId(reqSnap.data().stripeCustomerId, "cus_");
        }
      }
      if (!stripeCustomerId && companyId && !companyId.includes("/")) {
        const compSnap = await db.collection(PRIVATE_COMPANIES).doc(companyId).get();
        if (compSnap.exists && compSnap.data().claimedByUid === uid) {
          stripeCustomerId = extractStripeId(compSnap.data().stripeCustomerId, "cus_");
        }
      }
      if (!stripeCustomerId) {
        const paidReq = await db.collection(LISTING_REQUESTS)
            .where("submitterUid", "==", uid)
            .limit(10)
            .get();
        for (const doc of paidReq.docs) {
          const cid = extractStripeId(doc.data().stripeCustomerId, "cus_");
          if (cid) {
            stripeCustomerId = cid;
            break;
          }
        }
      }
      if (!stripeCustomerId) {
        throw new HttpsError(
            "failed-precondition",
            "No active Stripe billing profile was found for your directory listings.",
        );
      }

      const readinessSnapshot = await db.collection("platform_configuration")
          .doc("payment_provider_readiness")
          .get();
      const readinessData = readinessSnapshot.exists ?
        readinessSnapshot.data() : {};
      const readiness = await loadProviderReadiness(db);
      const returnUrl = appendCheckoutReturnParams(
          safeConfiguredUrl(
              readiness.checkoutSuccessUrl,
              "Billing Portal return URL",
          ),
          {flow: "yellow_pages"},
      );
      const portalConfigId = text(
          readinessData.stripeDispatchPortalConfigurationId,
          120,
      );

      const portal = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/billing_portal/sessions",
        fields: {
          customer: stripeCustomerId,
          return_url: returnUrl,
          ...(portalConfigId.startsWith("bpc_") ? {
            configuration: portalConfigId,
          } : {}),
        },
      });
      const portalUrl = String(portal.url || "");
      if (!portalUrl.startsWith("https://")) {
        throw new HttpsError(
            "internal",
            "Stripe did not return a valid Billing Portal session.",
        );
      }
      return {url: portalUrl};
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Yellow Pages billing portal failed", error);
      throw new HttpsError(
          "internal",
          "Oilfield Directory billing management could not be opened.",
      );
    }
  };

  async function handleYellowPagesCheckoutCompleted(session) {
    const meta = (session && session.metadata) || {};
    if (meta.billingType !== "yellow_pages_subscription") return false;

    const sessionId = String(session.id || "");
    const requestId = text(
        meta.yellowPagesRequestId || session.client_reference_id,
        200,
    );
    const subscriptionId = extractStripeId(session.subscription, "sub_");
    const customerId = extractStripeId(session.customer, "cus_");
    const directoryTier = YELLOW_PAGES_PAID_TIERS.has(meta.directoryTier) ?
      meta.directoryTier :
      "paid_verified";
    const billingInterval = normalizeYellowPagesBillingInterval(
        meta.billingInterval,
    );
    const isPaid = session.payment_status === "paid";
    const amounts = extractCheckoutSettlementAmounts(session);
    const provisionalPaidThrough = isPaid ?
      Timestamp.fromMillis(
          Date.now() + fallbackPeriodSeconds(billingInterval) * 1000,
      ) :
      null;

    if (sessionId.startsWith("cs_")) {
      await db.collection(YP_CHECKOUT_SESSIONS).doc(sessionId).set({
        status: isPaid ? "paid" : "processing",
        stripeSubscriptionId: subscriptionId || null,
        stripeCustomerId: customerId || null,
        settlementCurrency: amounts.settlementCurrency,
        settlementSubtotalMinor: amounts.settlementSubtotalMinor,
        settlementTotalMinor: amounts.settlementTotalMinor,
        presentmentCurrency: amounts.presentmentCurrency,
        presentmentTotalMinor: amounts.presentmentTotalMinor,
        adaptivePricingApplied: amounts.adaptivePricingApplied,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    const {reqRef, reqData, companyId} = await resolveRequestAndCompany({
      requestId,
      subscriptionId,
      companyId: meta.yellowPagesCompanyId,
    });

    if (reqRef) {
      await reqRef.set({
        paymentStatus: isPaid ? "paid" : "processing",
        requestedTier: directoryTier,
        billingInterval,
        stripeCheckoutSessionId: sessionId || null,
        ...(subscriptionId ? {stripeSubscriptionId: subscriptionId} : {}),
        ...(customerId ? {stripeCustomerId: customerId} : {}),
        ...(provisionalPaidThrough ? {paidThrough: provisionalPaidThrough} : {}),
        ...(isPaid ? {paidAt: FieldValue.serverTimestamp()} : {}),
        settlementCurrency: amounts.settlementCurrency,
        settlementTotalMinor: amounts.settlementTotalMinor,
        presentmentCurrency: amounts.presentmentCurrency,
        presentmentTotalMinor: amounts.presentmentTotalMinor,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    if (isPaid && companyId) {
      const reqLogo = normalizeLogoUrl(reqData && reqData.logoUrl);
      await db.collection(PRIVATE_COMPANIES).doc(companyId).set({
        listingTier: directoryTier,
        billingStatus: "paid",
        billingInterval,
        ...(reqLogo ? {logoUrl: reqLogo} : {}),
        ...(provisionalPaidThrough ? {paidThrough: provisionalPaidThrough} : {}),
        ...(subscriptionId ? {stripeSubscriptionId: subscriptionId} : {}),
        ...(customerId ? {stripeCustomerId: customerId} : {}),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await reconcileCompanyPublicProjection(companyId);
    }
    return true;
  }

  async function handleYellowPagesCheckoutFailed(session) {
    const meta = (session && session.metadata) || {};
    if (meta.billingType !== "yellow_pages_subscription") return false;
    const sessionId = String(session.id || "");
    const requestId = text(
        meta.yellowPagesRequestId || session.client_reference_id,
        200,
    );
    if (sessionId.startsWith("cs_")) {
      await db.collection(YP_CHECKOUT_SESSIONS).doc(sessionId).set({
        status: "payment_failed",
        paymentFailedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    if (requestId && !requestId.includes("/")) {
      await db.collection(LISTING_REQUESTS).doc(requestId).set({
        paymentStatus: "payment_failed",
        paymentFailedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return true;
  }

  async function handleYellowPagesInvoicePaid(invoice) {
    const matched = invoiceYellowPagesPlan(invoice, config);
    const subDetailsMeta =
      (invoice &&
        invoice.parent &&
        invoice.parent.subscription_details &&
        invoice.parent.subscription_details.metadata) ||
      (invoice && invoice.subscription_details && invoice.subscription_details.metadata) ||
      {};
    const invoiceMeta = (invoice && invoice.metadata) || {};
    const combinedMeta = {...subDetailsMeta, ...invoiceMeta};

    if (!matched && combinedMeta.billingType !== "yellow_pages_subscription") {
      return false;
    }

    const plan = matched ?
      matched.plan :
      {
        directoryTier: YELLOW_PAGES_PAID_TIERS.has(combinedMeta.directoryTier) ?
          combinedMeta.directoryTier :
          "paid_verified",
        billingInterval: normalizeYellowPagesBillingInterval(
            combinedMeta.billingInterval,
        ),
        planCode: combinedMeta.planCode || "",
        priceId: "",
      };

    const subscriptionId = extractStripeId(
        invoice.subscription ||
        (invoice.parent &&
          invoice.parent.subscription_details &&
          invoice.parent.subscription_details.subscription),
        "sub_",
    );
    const customerId = extractStripeId(invoice.customer, "cus_");
    const linePeriodEnd = Number(
        (matched &&
          matched.line &&
          matched.line.period &&
          matched.line.period.end) ||
        invoice.period_end ||
        0,
    );
    const paidThroughMillis = linePeriodEnd > 0 ?
      linePeriodEnd * 1000 :
      Date.now() + fallbackPeriodSeconds(plan.billingInterval) * 1000;
    const paidThrough = Timestamp.fromMillis(paidThroughMillis);

    const {reqRef, reqData, companyId} = await resolveRequestAndCompany({
      requestId: combinedMeta.yellowPagesRequestId,
      subscriptionId,
      companyId: combinedMeta.yellowPagesCompanyId,
    });

    if (reqRef) {
      await reqRef.set({
        paymentStatus: "paid",
        requestedTier: plan.directoryTier,
        billingInterval: plan.billingInterval,
        paidThrough,
        ...(subscriptionId ? {stripeSubscriptionId: subscriptionId} : {}),
        ...(customerId ? {stripeCustomerId: customerId} : {}),
        lastInvoiceId: String(invoice.id || ""),
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    if (companyId) {
      const reqLogo = normalizeLogoUrl(reqData && reqData.logoUrl);
      await db.collection(PRIVATE_COMPANIES).doc(companyId).set({
        listingTier: plan.directoryTier,
        billingStatus: "paid",
        billingInterval: plan.billingInterval,
        paidThrough,
        ...(reqLogo ? {logoUrl: reqLogo} : {}),
        ...(subscriptionId ? {stripeSubscriptionId: subscriptionId} : {}),
        ...(customerId ? {stripeCustomerId: customerId} : {}),
        lastInvoiceId: String(invoice.id || ""),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await reconcileCompanyPublicProjection(companyId);
    }

    const invoiceId = String(invoice.id || "");
    if (invoiceId.startsWith("in_")) {
      await db.collection("financial_ledgers")
          .doc(`yellow_pages_${invoiceId}`)
          .set({
            ledgerType: "yellow_pages_subscription",
            invoiceId,
            stripeSubscriptionId: subscriptionId || null,
            stripeCustomerId: customerId || null,
            uid: combinedMeta.pipeBuyerUid || (reqData && reqData.submitterUid) || null,
            yellowPagesRequestId: reqRef ? reqRef.id : (combinedMeta.yellowPagesRequestId || null),
            yellowPagesCompanyId: companyId || null,
            directoryTier: plan.directoryTier,
            billingInterval: plan.billingInterval,
            currency: String(invoice.currency || "usd").toUpperCase(),
            subtotalMinor: Number(invoice.subtotal || 0),
            taxMinor: Number(invoice.tax || 0),
            totalPaidMinor: Number(invoice.amount_paid || 0),
            paidThrough,
            createdAt: FieldValue.serverTimestamp(),
          }, {merge: true});
    }

    return true;
  }

  async function handleYellowPagesInvoicePaymentFailed(invoice) {
    const matched = invoiceYellowPagesPlan(invoice, config);
    const subDetailsMeta =
      (invoice &&
        invoice.parent &&
        invoice.parent.subscription_details &&
        invoice.parent.subscription_details.metadata) ||
      (invoice && invoice.subscription_details && invoice.subscription_details.metadata) ||
      {};
    if (!matched && subDetailsMeta.billingType !== "yellow_pages_subscription") {
      return false;
    }
    const subscriptionId = extractStripeId(
        invoice.subscription ||
        (invoice.parent &&
          invoice.parent.subscription_details &&
          invoice.parent.subscription_details.subscription),
        "sub_",
    );
    const {reqRef, companyId} = await resolveRequestAndCompany({
      requestId: subDetailsMeta.yellowPagesRequestId,
      subscriptionId,
      companyId: subDetailsMeta.yellowPagesCompanyId,
    });
    if (reqRef) {
      await reqRef.set({
        paymentStatus: "past_due",
        lastPaymentFailedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    if (companyId) {
      await db.collection(PRIVATE_COMPANIES).doc(companyId).set({
        subscriptionPaymentState: "past_due",
        lastPaymentFailedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return true;
  }

  async function handleYellowPagesSubscriptionLifecycle(subscription, eventType) {
    const plan = subscriptionYellowPagesPlan(subscription, config);
    const meta = (subscription && subscription.metadata) || {};
    if (!plan && meta.billingType !== "yellow_pages_subscription") {
      return false;
    }
    const subscriptionId = extractStripeId(subscription, "sub_");
    const customerId = extractStripeId(subscription && subscription.customer, "cus_");
    const status = String((subscription && subscription.status) || "").toLowerCase();
    const periodEndSec = Number(
        (subscription && subscription.current_period_end) ||
        (subscription &&
          subscription.items &&
          subscription.items.data &&
          subscription.items.data[0] &&
          subscription.items.data[0].current_period_end) ||
        0,
    );
    const paidThrough = periodEndSec > 0 ?
      Timestamp.fromMillis(periodEndSec * 1000) :
      null;
    const isDeleted =
      eventType === "customer.subscription.deleted" ||
      status === "canceled" ||
      status === "unpaid" ||
      status === "incomplete_expired";
    const isActive = status === "active" || status === "trialing";
    const directoryTier = plan ?
      plan.directoryTier :
      (YELLOW_PAGES_PAID_TIERS.has(meta.directoryTier) ?
        meta.directoryTier :
        "paid_verified");

    const {reqRef, companyId} = await resolveRequestAndCompany({
      requestId: meta.yellowPagesRequestId,
      subscriptionId,
      companyId: meta.yellowPagesCompanyId,
    });

    if (reqRef) {
      await reqRef.set({
        stripeSubscriptionId: subscriptionId || null,
        ...(customerId ? {stripeCustomerId: customerId} : {}),
        stripeSubscriptionStatus: status,
        cancelAtPeriodEnd: Boolean(subscription && subscription.cancel_at_period_end),
        ...(paidThrough ? {paidThrough} : {}),
        ...(isDeleted ? {paymentStatus: "canceled"} : (isActive ? {paymentStatus: "paid"} : {})),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    if (companyId) {
      const updates = {
        stripeSubscriptionId: subscriptionId || null,
        ...(customerId ? {stripeCustomerId: customerId} : {}),
        stripeSubscriptionStatus: status,
        cancelAtPeriodEnd: Boolean(subscription && subscription.cancel_at_period_end),
        ...(paidThrough ? {paidThrough} : {}),
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (isDeleted) {
        updates.billingStatus = "unpaid";
      } else if (isActive) {
        updates.billingStatus = "paid";
        updates.listingTier = directoryTier;
      }
      await db.collection(PRIVATE_COMPANIES).doc(companyId).set(
          updates,
          {merge: true},
      );
      await reconcileCompanyPublicProjection(companyId);
    }

    return true;
  }

  return {
    createYellowPagesBillingPortalSession,
    createYellowPagesListingCheckout,
    handleYellowPagesCheckoutCompleted,
    handleYellowPagesCheckoutFailed,
    handleYellowPagesInvoicePaid,
    handleYellowPagesInvoicePaymentFailed,
    handleYellowPagesSubscriptionLifecycle,
  };
}

module.exports = {
  YELLOW_PAGES_BILLING_INTERVALS,
  YELLOW_PAGES_PAID_TIERS,
  createYellowPagesBilling,
  invoiceYellowPagesPlan,
  normalizeYellowPagesBillingInterval,
  resolveYellowPagesPriceSpec,
  subscriptionYellowPagesPlan,
  yellowPagesPlanForPriceId,
};
