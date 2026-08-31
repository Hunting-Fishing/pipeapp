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
  safeConfiguredUrl,
  stripeFormRequest,
} = require("./stripe_checkout_commands");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {
  resolveSubscriptionPromotionCode,
} = require("./subscription_promotion_resolver");
const {
  automaticTaxEnabled,
  taxBillingPrepared,
  taxCollectionStatus,
} = require("./pending_tax_policy");

const VIP_CHECKOUT_CREATION_LEASE_MS = 2 * 60 * 1000;
const VIP_CHECKOUT_FALLBACK_EXPIRY_MS = 24 * 60 * 60 * 1000;
const VIP_CHECKOUT_CONFIGURATION_VERSION = 2;

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function selectedVipPlan(value) {
  const plan = String(value || "monthly").trim().toLowerCase();
  if (plan !== "monthly") {
    throw new HttpsError(
        "invalid-argument",
        "The Pipe Buyer VIP subscription plan is invalid.",
    );
  }
  return plan;
}

function requireVipSubscriptionReady(readiness) {
  if (!readiness.stripeSubscriptionsEnabled ||
      !readiness.stripeVipSubscriptionsEnabled ||
      readiness.stripeMode !== "production" ||
      readiness.stripeWebhookVerified !== true ||
      readiness.stripeReconciliationReady !== true ||
      !taxBillingPrepared(readiness)) {
    throw new HttpsError(
        "failed-precondition",
        "Pipe Buyer VIP subscription checkout is not enabled yet.",
    );
  }
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

function vipMembershipIsCurrent(membership, nowMillis = Date.now()) {
  if (!membership || membership.active !== true) return false;
  return timestampMillis(membership.currentPeriodEnd) > nowMillis;
}

function reusableVipCheckoutState(
    state,
    nowMillis = Date.now(),
    promotionCodeId = "",
) {
  if (!state || state.plan !== "monthly" || state.status !== "created") {
    return false;
  }
  if (state.checkoutConfigurationVersion !== VIP_CHECKOUT_CONFIGURATION_VERSION) {
    return false;
  }
  if (String(state.promotionCodeId || "") !== String(promotionCodeId || "")) {
    return false;
  }
  if (timestampMillis(state.expiresAt) <= nowMillis) return false;
  return String(state.checkoutSessionId || "").startsWith("cs_") &&
    String(state.checkoutUrl || "").startsWith("https://");
}

function vipCheckoutAttemptKey(uid, attemptNumber) {
  return `pipebuyer-vip-${uid}-attempt-${attemptNumber}`;
}

function providerStateBlocksCheckout(providerState, uid) {
  if (!providerState || providerState.ownerUid !== uid) return false;
  return providerState.blocksNewCheckout === true &&
    String(providerState.subscriptionId || "").startsWith("sub_");
}

function createVipSubscriptionCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  const createVipSubscriptionCheckout = async (request) => {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "marketplace");
      requirePhase1Feature(flags, "paidFeatures");

      const readinessSnapshot = await db.collection("platform_configuration")
          .doc("payment_provider_readiness").get();
      const readinessData = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const readiness = {
        ...(await loadProviderReadiness(db)),
        stripeSubscriptionsEnabled: readinessData.stripeSubscriptionsEnabled === true,
        stripeVipSubscriptionsEnabled:
          readinessData.stripeVipSubscriptionsEnabled === true,
        stripeTaxRegistrationPending:
          readinessData.stripeTaxRegistrationPending === true,
        stripeTaxPendingBillingApproved:
          readinessData.stripeTaxPendingBillingApproved === true,
        checkoutSuccessUrl: String(readinessData.checkoutSuccessUrl || ""),
        checkoutCancelUrl: String(readinessData.checkoutCancelUrl || ""),
      };
      requireVipSubscriptionReady(readiness);

      const plan = selectedVipPlan(request.data && request.data.plan);
      const price = stripeMarketplaceConfig.products.vipMonthlyCad;
      const priceId = String(price && price.priceId || "");
      const productId = String(price && price.productId || "");
      if (!priceId.startsWith("price_") || !productId.startsWith("prod_")) {
        throw new HttpsError(
            "failed-precondition",
            "Pipe Buyer VIP pricing is not configured.",
        );
      }
      const requestedPromotionCode = String(
          request.data && request.data.promotionCode || "",
      ).trim();
      const secretKey = stripeSecretKey.value();
      const promotion = requestedPromotionCode ?
        await resolveSubscriptionPromotionCode({
          secretKey,
          code: requestedPromotionCode,
          existingSubscriber: false,
          productId,
          productLabel: "Pipe Buyer VIP membership",
        }) : null;
      const promotionCodeId = promotion ? promotion.id : "";
      const allowPromotionCodes = !promotionCodeId;
      const collectionStatus = taxCollectionStatus(readiness);
      const successUrl = safeConfiguredUrl(
          readiness.checkoutSuccessUrl,
          "Stripe Checkout success URL",
      );
      const cancelUrl = safeConfiguredUrl(
          readiness.checkoutCancelUrl,
          "Stripe Checkout cancel URL",
      );

      const stateRef = db.collection("vip_subscription_checkout_state").doc(uid);
      const membershipRef = db.collection("vip_memberships").doc(uid);
      const providerStateRef = db.collection("vip_subscription_provider_state").doc(uid);
      const nowMillis = Date.now();
      const reservation = await db.runTransaction(async (transaction) => {
        const [stateSnapshot, membershipSnapshot, providerSnapshot] =
          await Promise.all([
            transaction.get(stateRef),
            transaction.get(membershipRef),
            transaction.get(providerStateRef),
          ]);
        const state = stateSnapshot.exists ? stateSnapshot.data() : {};
        const membership = membershipSnapshot.exists ? membershipSnapshot.data() : null;
        const providerState = providerSnapshot.exists ? providerSnapshot.data() : null;

        if (vipMembershipIsCurrent(membership, nowMillis)) {
          throw new HttpsError(
              "failed-precondition",
              "Your Pipe Buyer VIP membership is already active.",
          );
        }
        if (providerStateBlocksCheckout(providerState, uid)) {
          throw new HttpsError(
              "failed-precondition",
              "A Pipe Buyer VIP subscription already exists for this account.",
          );
        }
        if (reusableVipCheckoutState(state, nowMillis, promotionCodeId)) {
          return {
            reuse: true,
            checkoutSessionId: String(state.checkoutSessionId),
            checkoutUrl: String(state.checkoutUrl),
            attemptNumber: Number(state.attemptNumber || 1),
          };
        }

        const stateExpiry = timestampMillis(state.expiresAt);
        const leaseExpiry = timestampMillis(state.leaseExpiresAt);
        if (state.status === "creating" && stateExpiry > nowMillis) {
          if (String(state.promotionCodeId || "") !== promotionCodeId) {
            throw new HttpsError(
                "failed-precondition",
                "A different VIP checkout is already being prepared. Retry shortly before changing the promo code.",
            );
          }
          const attemptNumber = Math.max(1, Number(state.attemptNumber || 1));
          if (leaseExpiry > nowMillis) return {busy: true, attemptNumber};
          transaction.set(stateRef, {
            leaseExpiresAt: Timestamp.fromMillis(
                nowMillis + VIP_CHECKOUT_CREATION_LEASE_MS,
            ),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          return {attemptNumber};
        }

        const previousAttempt = Number(state.attemptNumber || 0);
        const attemptNumber = Number.isSafeInteger(previousAttempt) &&
          previousAttempt >= 0 ? previousAttempt + 1 : 1;
        transaction.set(stateRef, {
          ownerUid: uid,
          plan,
          priceId,
          status: "creating",
          checkoutConfigurationVersion: VIP_CHECKOUT_CONFIGURATION_VERSION,
          promotionCodeId: promotionCodeId || null,
          promotionCodeEntryAllowed: allowPromotionCodes,
          attemptNumber,
          checkoutSessionId: FieldValue.delete(),
          checkoutUrl: FieldValue.delete(),
          leaseExpiresAt: Timestamp.fromMillis(
              nowMillis + VIP_CHECKOUT_CREATION_LEASE_MS,
          ),
          expiresAt: Timestamp.fromMillis(
              nowMillis + VIP_CHECKOUT_FALLBACK_EXPIRY_MS,
          ),
          updatedAt: FieldValue.serverTimestamp(),
          ...(stateSnapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
        }, {merge: true});
        return {attemptNumber};
      });

      if (reservation.reuse) {
        return {
          checkoutSessionId: reservation.checkoutSessionId,
          checkoutUrl: reservation.checkoutUrl,
          plan,
          promotionCodeApplied: Boolean(promotionCodeId),
          promotionCode: promotion ? promotion.code : "",
          promotionCodeSummary: promotion ? promotion.summary : "",
          promotionCodeEntryAllowed: allowPromotionCodes,
          taxCollectionStatus: collectionStatus,
          alreadyCreated: true,
        };
      }
      if (reservation.busy) {
        throw new HttpsError(
            "resource-exhausted",
            "Pipe Buyer VIP checkout is already being started. Retry shortly.",
        );
      }

      let checkout;
      try {
        checkout = await stripeFormRequest({
          secretKey,
          path: "/v1/checkout/sessions",
          idempotencyKey: vipCheckoutAttemptKey(uid, reservation.attemptNumber),
          fields: {
            mode: "subscription",
            success_url: successUrl,
            cancel_url: cancelUrl,
            client_reference_id: uid,
            billing_address_collection: "required",
            allow_promotion_codes: allowPromotionCodes ? "true" : "false",
            "automatic_tax[enabled]": automaticTaxEnabled(readiness) ? "true" : "false",
            "line_items[0][price]": priceId,
            "line_items[0][quantity]": 1,
            ...(promotionCodeId ? {
              "discounts[0][promotion_code]": promotionCodeId,
            } : {}),
            "metadata[billingType]": "vip_subscription",
            "metadata[pipeBuyerUid]": uid,
            "metadata[vipPlan]": plan,
            "metadata[taxCollectionStatus]": collectionStatus,
            "metadata[checkoutAttempt]": String(reservation.attemptNumber),
            ...(promotionCodeId ? {
              "metadata[promotionCodeId]": promotionCodeId,
            } : {}),
            "subscription_data[metadata][billingType]": "vip_subscription",
            "subscription_data[metadata][pipeBuyerUid]": uid,
            "subscription_data[metadata][vipPlan]": plan,
            "subscription_data[metadata][taxCollectionStatus]": collectionStatus,
            ...(promotionCodeId ? {
              "subscription_data[metadata][promotionCodeId]": promotionCodeId,
            } : {}),
          },
        });
      } catch (error) {
        if (promotionCodeId && error instanceof HttpsError) {
          throw new HttpsError(
              error.code,
              "That promo code could not be applied to VIP checkout. Check its eligibility and try again.",
          );
        }
        throw error;
      }
      const sessionId = String(checkout.id || "");
      const checkoutUrl = String(checkout.url || "");
      if (!sessionId.startsWith("cs_") || !checkoutUrl.startsWith("https://")) {
        throw new HttpsError(
            "internal",
            "Stripe did not return a valid Pipe Buyer VIP checkout.",
        );
      }
      const providerExpiryMillis = Number(checkout.expires_at || 0) * 1000;
      const expiresAtMillis = Number.isFinite(providerExpiryMillis) &&
        providerExpiryMillis > nowMillis ? providerExpiryMillis :
        nowMillis + VIP_CHECKOUT_FALLBACK_EXPIRY_MS;
      await Promise.all([
        db.collection("vip_subscription_checkout_sessions").doc(sessionId).set({
          uid,
          plan,
          priceId,
          promotionCodeId: promotionCodeId || null,
          promotionCodeEntryAllowed: allowPromotionCodes,
          checkoutConfigurationVersion: VIP_CHECKOUT_CONFIGURATION_VERSION,
          taxCollectionStatus: collectionStatus,
          taxExposureReviewRequired: collectionStatus === "registration_pending",
          automaticTaxEnabled: automaticTaxEnabled(readiness),
          checkoutAttempt: reservation.attemptNumber,
          status: "created",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }),
        stateRef.set({
          ownerUid: uid,
          plan,
          priceId,
          status: "created",
          checkoutConfigurationVersion: VIP_CHECKOUT_CONFIGURATION_VERSION,
          promotionCodeId: promotionCodeId || null,
          promotionCodeEntryAllowed: allowPromotionCodes,
          attemptNumber: reservation.attemptNumber,
          checkoutSessionId: sessionId,
          checkoutUrl,
          leaseExpiresAt: FieldValue.delete(),
          expiresAt: Timestamp.fromMillis(expiresAtMillis),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}),
      ]);
      return {
        checkoutSessionId: sessionId,
        checkoutUrl,
        plan,
        promotionCodeApplied: Boolean(promotionCodeId),
        promotionCode: promotion ? promotion.code : "",
        promotionCodeSummary: promotion ? promotion.summary : "",
        promotionCodeEntryAllowed: allowPromotionCodes,
        taxCollectionStatus: collectionStatus,
        alreadyCreated: false,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Pipe Buyer VIP subscription checkout failed", error);
      throw new HttpsError(
          "internal",
          "Pipe Buyer VIP subscription checkout could not be started.",
      );
    }
  };

  return {createVipSubscriptionCheckout};
}

module.exports = {
  VIP_CHECKOUT_CONFIGURATION_VERSION,
  VIP_CHECKOUT_CREATION_LEASE_MS,
  VIP_CHECKOUT_FALLBACK_EXPIRY_MS,
  createVipSubscriptionCommands,
  providerStateBlocksCheckout,
  requireVipSubscriptionReady,
  reusableVipCheckoutState,
  selectedVipPlan,
  timestampMillis,
  vipCheckoutAttemptKey,
  vipMembershipIsCurrent,
};