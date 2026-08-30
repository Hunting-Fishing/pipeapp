"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");

const MEMBERSHIP_PLAN_IDS = Object.freeze([
  "free",
  "dispatch_monthly",
  "dispatch_yearly",
  "vip_monthly",
]);

const MEMBERSHIP_PLAN_RANK = Object.freeze({
  free: 0,
  dispatch_monthly: 1,
  dispatch_yearly: 1,
  vip_monthly: 2,
});

function membershipPlanCatalog() {
  const products = stripeMarketplaceConfig.products;
  return Object.freeze({
    free: Object.freeze({
      id: "free",
      tier: "free",
      rank: 0,
      billingType: "free",
      priceId: "",
      interval: "",
      label: "Free",
    }),
    dispatch_monthly: Object.freeze({
      id: "dispatch_monthly",
      tier: "dispatch",
      rank: 1,
      billingType: "dispatch_subscription",
      dispatchPlan: "monthly",
      priceId: String(products.dispatchMonthlyCad.priceId || ""),
      interval: "month",
      label: "Monthly",
    }),
    dispatch_yearly: Object.freeze({
      id: "dispatch_yearly",
      tier: "dispatch",
      rank: 1,
      billingType: "dispatch_subscription",
      dispatchPlan: "yearly",
      priceId: String(products.dispatchYearlyCad.priceId || ""),
      interval: "year",
      label: "Yearly",
    }),
    vip_monthly: Object.freeze({
      id: "vip_monthly",
      tier: "vip",
      rank: 2,
      billingType: "vip_subscription",
      vipPlan: "monthly",
      priceId: String(products.vipMonthlyCad.priceId || ""),
      interval: "month",
      label: "VIP",
    }),
  });
}

function requestedMembershipPlan(value) {
  const planId = String(value || "").trim().toLowerCase();
  if (!MEMBERSHIP_PLAN_IDS.includes(planId)) {
    throw new HttpsError("invalid-argument", "The requested membership plan is invalid.");
  }
  return membershipPlanCatalog()[planId];
}

function membershipPlanForPriceId(value) {
  const priceId = String(value || "").trim();
  if (!priceId.startsWith("price_")) return null;
  for (const plan of Object.values(membershipPlanCatalog())) {
    if (plan.priceId && plan.priceId === priceId) return plan;
  }
  return null;
}

function subscriptionItem(subscription) {
  const items = subscription && subscription.items && subscription.items.data;
  if (!Array.isArray(items) || items.length !== 1) return null;
  const item = items[0];
  const itemId = String(item && item.id || "").trim();
  const priceId = typeof (item && item.price) === "string" ?
    item.price : String(item && item.price && item.price.id || "").trim();
  if (!itemId.startsWith("si_") || !priceId.startsWith("price_")) return null;
  return {item, itemId, priceId};
}

function subscriptionMembershipPlan(subscription) {
  const current = subscriptionItem(subscription);
  return current ? membershipPlanForPriceId(current.priceId) : null;
}

function membershipPlanMetadata(plan, uid) {
  if (!plan || plan.id === "free") return {};
  return {
    billingType: plan.billingType,
    pipeBuyerUid: String(uid || ""),
    ...(plan.tier === "dispatch" ? {
      dispatchPlan: plan.dispatchPlan,
      vipPlan: "",
    } : {
      vipPlan: plan.vipPlan,
      dispatchPlan: "",
    }),
  };
}

function membershipPlanChangeKind(currentPlan, targetPlan) {
  if (!currentPlan || !targetPlan) return "invalid";
  if (currentPlan.id === targetPlan.id) return "same";
  if (targetPlan.id === "free") return "cancel";
  if (currentPlan.id === "free") return "new_checkout";
  if (targetPlan.rank > currentPlan.rank) return "upgrade_now";
  return "change_at_period_end";
}

function paidMembershipCurrent(membership, nowMillis = Date.now()) {
  if (!membership || membership.active !== true) return false;
  const value = membership.currentPeriodEnd;
  const endMillis = value && typeof value.toMillis === "function" ?
    value.toMillis() : value instanceof Date ? value.getTime() : Number(value || 0);
  return Number.isFinite(endMillis) && endMillis > nowMillis;
}

function effectiveMembershipPlan({vipMembership, dispatchMembership, nowMillis = Date.now()}) {
  if (paidMembershipCurrent(vipMembership, nowMillis)) {
    return membershipPlanCatalog().vip_monthly;
  }
  if (paidMembershipCurrent(dispatchMembership, nowMillis)) {
    const plan = String(dispatchMembership.plan || "").trim().toLowerCase();
    return plan === "yearly" ?
      membershipPlanCatalog().dispatch_yearly :
      membershipPlanCatalog().dispatch_monthly;
  }
  return membershipPlanCatalog().free;
}

module.exports = {
  MEMBERSHIP_PLAN_IDS,
  MEMBERSHIP_PLAN_RANK,
  effectiveMembershipPlan,
  membershipPlanCatalog,
  membershipPlanChangeKind,
  membershipPlanForPriceId,
  membershipPlanMetadata,
  paidMembershipCurrent,
  requestedMembershipPlan,
  subscriptionItem,
  subscriptionMembershipPlan,
};
