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
const {stripeFormRequest} = require("./stripe_checkout_commands");
const {taxBillingPrepared} = require("./pending_tax_policy");
const {
  effectiveMembershipPlan,
  membershipPlanCatalog,
  membershipPlanChangeKind,
  membershipPlanMetadata,
  requestedMembershipPlan,
  subscriptionItem,
  subscriptionMembershipPlan,
} = require("./membership_plan_policy");

const TERMINAL_PROVIDER_STATUSES = new Set(["canceled", "incomplete_expired"]);

function providerSubscriptionId(state, uid) {
  if (!state || state.ownerUid !== uid) return "";
  const id = String(state.subscriptionId || "").trim();
  const status = String(state.providerStatus || "unknown").trim();
  if (!id.startsWith("sub_") || TERMINAL_PROVIDER_STATUSES.has(status)) return "";
  return id;
}

function uniqueBlockingSubscriptionId({dispatchProvider, vipProvider, uid}) {
  const ids = new Set([
    providerSubscriptionId(dispatchProvider, uid),
    providerSubscriptionId(vipProvider, uid),
  ].filter(Boolean));
  if (ids.size > 1) {
    throw new HttpsError(
        "failed-precondition",
        "More than one active membership subscription was found. Pipe Buyer support must reconcile billing before another plan change.",
    );
  }
  return ids.size === 1 ? [...ids][0] : "";
}

function requirePlanManagementReady(readiness) {
  if (!readiness ||
      readiness.stripeMode !== "production" ||
      readiness.stripeSubscriptionsEnabled !== true ||
      readiness.stripeVipSubscriptionsEnabled !== true ||
      readiness.stripeWebhookVerified !== true ||
      readiness.stripeReconciliationReady !== true ||
      !taxBillingPrepared(readiness)) {
    throw new HttpsError(
        "failed-precondition",
        "Membership plan changes are temporarily unavailable.",
    );
  }
}

function subscriptionPeriodBounds(subscription) {
  const current = subscriptionItem(subscription);
  const start = Number(current && current.item && current.item.current_period_start ||
    subscription && subscription.current_period_start || 0);
  const end = Number(current && current.item && current.item.current_period_end ||
    subscription && subscription.current_period_end || 0);
  if (!Number.isFinite(start) || !Number.isFinite(end) || start <= 0 || end <= start) {
    throw new HttpsError(
        "failed-precondition",
        "Stripe did not return a valid paid membership period.",
    );
  }
  return {start, end};
}

function subscriptionScheduleId(subscription) {
  const schedule = subscription && subscription.schedule;
  if (typeof schedule === "string") return schedule.startsWith("sub_sched_") ? schedule : "";
  const id = String(schedule && schedule.id || "");
  return id.startsWith("sub_sched_") ? id : "";
}

function scheduleOwnedByPipeBuyer(schedule, uid, subscriptionId) {
  const metadata = schedule && schedule.metadata || {};
  const scheduleSubscription = typeof (schedule && schedule.subscription) === "string" ?
    schedule.subscription : String(schedule && schedule.subscription && schedule.subscription.id || "");
  return scheduleSubscription === subscriptionId &&
    metadata.app === "pipe_buyer" &&
    metadata.purpose === "membership_plan_change" &&
    metadata.ownerUid === uid;
}

function planStatusPayload({currentPlan, transition}) {
  const pending = transition && transition.status === "scheduled" ? transition : null;
  return {
    currentPlan: currentPlan.id,
    currentTier: currentPlan.tier,
    currentLabel: currentPlan.label,
    paid: currentPlan.id !== "free",
    pendingPlan: pending ? String(pending.targetPlan || "") : "",
    pendingEffectiveAtMillis: pending ? Number(pending.effectiveAtMillis || 0) || null : null,
  };
}

function transitionStateData({uid, subscriptionId, currentPlan, targetPlan, status, effectiveAtMillis, stripeScheduleId = ""}) {
  return {
    ownerUid: uid,
    subscriptionId,
    fromPlan: currentPlan.id,
    targetPlan: targetPlan.id,
    status,
    effectiveAtMillis: effectiveAtMillis || null,
    stripeScheduleId: stripeScheduleId || null,
  };
}

function createMembershipPlanManagement(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function loadMembershipState(uid) {
    const [dispatchMembershipSnapshot, vipMembershipSnapshot,
      dispatchProviderSnapshot, vipProviderSnapshot, transitionSnapshot] =
      await Promise.all([
        db.collection("dispatch_memberships").doc(uid).get(),
        db.collection("vip_memberships").doc(uid).get(),
        db.collection("dispatch_subscription_provider_state").doc(uid).get(),
        db.collection("vip_subscription_provider_state").doc(uid).get(),
        db.collection("membership_plan_transitions").doc(uid).get(),
      ]);
    const dispatchMembership = dispatchMembershipSnapshot.exists ? dispatchMembershipSnapshot.data() : null;
    const vipMembership = vipMembershipSnapshot.exists ? vipMembershipSnapshot.data() : null;
    const dispatchProvider = dispatchProviderSnapshot.exists ? dispatchProviderSnapshot.data() : null;
    const vipProvider = vipProviderSnapshot.exists ? vipProviderSnapshot.data() : null;
    const transition = transitionSnapshot.exists ? transitionSnapshot.data() : null;
    const currentPlan = effectiveMembershipPlan({dispatchMembership, vipMembership});
    return {dispatchMembership, vipMembership, dispatchProvider, vipProvider, transition, currentPlan};
  }

  async function getMembershipPlanStatus(request) {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const state = await loadMembershipState(identity.uid);
      return planStatusPayload(state);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Membership plan status failed", error);
      throw new HttpsError("internal", "Membership plan status could not be loaded.");
    }
  }

  async function retrieveSchedule(secretKey, scheduleId) {
    return stripeFormRequest({
      secretKey,
      path: `/v1/subscription_schedules/${encodeURIComponent(scheduleId)}`,
      method: "GET",
    });
  }

  async function releaseOwnedSchedule({secretKey, subscription, uid, subscriptionId}) {
    const scheduleId = subscriptionScheduleId(subscription);
    if (!scheduleId) return;
    const schedule = await retrieveSchedule(secretKey, scheduleId);
    if (!scheduleOwnedByPipeBuyer(schedule, uid, subscriptionId)) {
      throw new HttpsError(
          "failed-precondition",
          "This Stripe subscription already has a billing schedule that Pipe Buyer will not overwrite automatically.",
      );
    }
    await stripeFormRequest({
      secretKey,
      path: `/v1/subscription_schedules/${encodeURIComponent(scheduleId)}/release`,
      fields: {},
    });
  }

  async function schedulePaidPlanChange({secretKey, uid, subscription, subscriptionId, currentPlan, targetPlan}) {
    await releaseOwnedSchedule({secretKey, subscription, uid, subscriptionId});
    const refreshed = await stripeFormRequest({
      secretKey,
      path: `/v1/subscriptions/${encodeURIComponent(subscriptionId)}`,
      method: "GET",
    });
    const current = subscriptionItem(refreshed);
    const period = subscriptionPeriodBounds(refreshed);
    if (!current || current.priceId !== currentPlan.priceId) {
      throw new HttpsError("failed-precondition", "Stripe membership pricing changed before the plan update could be scheduled.");
    }
    const created = await stripeFormRequest({
      secretKey,
      path: "/v1/subscription_schedules",
      idempotencyKey: `pipebuyer-plan-schedule-${subscriptionId}-${current.priceId}-${targetPlan.priceId}-${period.start}`,
      fields: {from_subscription: subscriptionId},
    });
    const scheduleId = String(created.id || "");
    if (!scheduleId.startsWith("sub_sched_")) {
      throw new HttpsError("internal", "Stripe did not create a valid membership plan schedule.");
    }
    const currentMetadata = membershipPlanMetadata(currentPlan, uid);
    const targetMetadata = membershipPlanMetadata(targetPlan, uid);
    const fields = {
      end_behavior: "release",
      "metadata[app]": "pipe_buyer",
      "metadata[purpose]": "membership_plan_change",
      "metadata[ownerUid]": uid,
      "metadata[targetPlan]": targetPlan.id,
      "phases[0][start_date]": period.start,
      "phases[0][end_date]": period.end,
      "phases[0][items][0][price]": current.priceId,
      "phases[0][items][0][quantity]": 1,
      "phases[0][proration_behavior]": "none",
      "phases[0][metadata][billingType]": currentMetadata.billingType,
      "phases[0][metadata][pipeBuyerUid]": uid,
      "phases[0][metadata][dispatchPlan]": currentMetadata.dispatchPlan || "",
      "phases[0][metadata][vipPlan]": currentMetadata.vipPlan || "",
      "phases[1][start_date]": period.end,
      "phases[1][duration][interval]": targetPlan.interval,
      "phases[1][duration][interval_count]": 1,
      "phases[1][items][0][price]": targetPlan.priceId,
      "phases[1][items][0][quantity]": 1,
      "phases[1][proration_behavior]": "none",
      "phases[1][metadata][billingType]": targetMetadata.billingType,
      "phases[1][metadata][pipeBuyerUid]": uid,
      "phases[1][metadata][dispatchPlan]": targetMetadata.dispatchPlan || "",
      "phases[1][metadata][vipPlan]": targetMetadata.vipPlan || "",
    };
    const updated = await stripeFormRequest({
      secretKey,
      path: `/v1/subscription_schedules/${encodeURIComponent(scheduleId)}`,
      idempotencyKey: `pipebuyer-plan-schedule-config-${scheduleId}-${targetPlan.id}`,
      fields,
    });
    if (String(updated.id || "") !== scheduleId) {
      throw new HttpsError("internal", "Stripe did not confirm the membership plan schedule.");
    }
    return {scheduleId, effectiveAtMillis: period.end * 1000};
  }

  async function changeMembershipPlan(request) {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "paidFeatures");
      const targetPlan = requestedMembershipPlan(request.data && request.data.targetPlan);
      const readinessSnapshot = await db.collection("platform_configuration")
          .doc("payment_provider_readiness").get();
      const data = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const readiness = {
        ...(await loadProviderReadiness(db)),
        stripeSubscriptionsEnabled: data.stripeSubscriptionsEnabled === true,
        stripeVipSubscriptionsEnabled: data.stripeVipSubscriptionsEnabled === true,
        stripeTaxRegistrationPending: data.stripeTaxRegistrationPending === true,
        stripeTaxPendingBillingApproved: data.stripeTaxPendingBillingApproved === true,
      };
      requirePlanManagementReady(readiness);

      const state = await loadMembershipState(identity.uid);
      const currentPlan = state.currentPlan;
      const kind = membershipPlanChangeKind(currentPlan, targetPlan);
      if (kind === "same") {
        return {...planStatusPayload(state), changed: false, effective: "already_selected"};
      }
      if (kind === "new_checkout") {
        throw new HttpsError(
            "failed-precondition",
            "Choose the paid plan from Pipe Buyer first so the initial purchase can use secure checkout.",
        );
      }

      const subscriptionId = uniqueBlockingSubscriptionId({
        dispatchProvider: state.dispatchProvider,
        vipProvider: state.vipProvider,
        uid: identity.uid,
      });
      if (!subscriptionId) {
        throw new HttpsError("failed-precondition", "No Stripe membership subscription is available to change.");
      }
      const secretKey = stripeSecretKey.value();
      let subscription = await stripeFormRequest({
        secretKey,
        path: `/v1/subscriptions/${encodeURIComponent(subscriptionId)}?expand%5B%5D=discounts`,
        method: "GET",
      });
      const metadata = subscription.metadata || {};
      if (String(metadata.pipeBuyerUid || "") !== identity.uid) {
        throw new HttpsError("permission-denied", "Stripe membership ownership could not be verified.");
      }
      const stripeCurrentPlan = subscriptionMembershipPlan(subscription);
      if (!stripeCurrentPlan || stripeCurrentPlan.id !== currentPlan.id) {
        throw new HttpsError(
            "failed-precondition",
            "Pipe Buyer and Stripe membership state are not aligned yet. Refresh before changing plans.",
        );
      }
      const current = subscriptionItem(subscription);
      if (!current) {
        throw new HttpsError("failed-precondition", "Stripe returned an unsupported membership subscription shape.");
      }

      const transitionRef = db.collection("membership_plan_transitions").doc(identity.uid);
      if (kind === "cancel") {
        await releaseOwnedSchedule({secretKey, subscription, uid: identity.uid, subscriptionId});
        subscription = await stripeFormRequest({
          secretKey,
          path: `/v1/subscriptions/${encodeURIComponent(subscriptionId)}`,
          idempotencyKey: `pipebuyer-plan-free-${subscriptionId}-${current.priceId}`,
          fields: {cancel_at_period_end: "true"},
        });
        const period = subscriptionPeriodBounds(subscription);
        const transition = transitionStateData({
          uid: identity.uid,
          subscriptionId,
          currentPlan,
          targetPlan,
          status: "scheduled",
          effectiveAtMillis: period.end * 1000,
        });
        await transitionRef.set({...transition, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
        return {
          currentPlan: currentPlan.id,
          targetPlan: targetPlan.id,
          changed: true,
          effective: "period_end",
          effectiveAtMillis: period.end * 1000,
        };
      }

      if (kind === "upgrade_now") {
        await releaseOwnedSchedule({secretKey, subscription, uid: identity.uid, subscriptionId});
        const targetMetadata = membershipPlanMetadata(targetPlan, identity.uid);
        subscription = await stripeFormRequest({
          secretKey,
          path: `/v1/subscriptions/${encodeURIComponent(subscriptionId)}`,
          idempotencyKey: `pipebuyer-plan-upgrade-${subscriptionId}-${current.priceId}-${targetPlan.priceId}`,
          fields: {
            "items[0][id]": current.itemId,
            "items[0][price]": targetPlan.priceId,
            "items[0][quantity]": 1,
            proration_behavior: "always_invoice",
            payment_behavior: "error_if_incomplete",
            cancel_at_period_end: "false",
            discounts: "",
            "metadata[billingType]": targetMetadata.billingType,
            "metadata[pipeBuyerUid]": identity.uid,
            "metadata[dispatchPlan]": targetMetadata.dispatchPlan || "",
            "metadata[vipPlan]": targetMetadata.vipPlan || "",
          },
        });
        if (subscriptionMembershipPlan(subscription)?.id !== targetPlan.id) {
          throw new HttpsError("internal", "Stripe did not confirm the membership upgrade.");
        }
        await transitionRef.set({
          ...transitionStateData({
            uid: identity.uid,
            subscriptionId,
            currentPlan,
            targetPlan,
            status: "provider_confirmed_waiting_for_invoice",
          }),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {
          currentPlan: currentPlan.id,
          targetPlan: targetPlan.id,
          changed: true,
          effective: "after_payment_confirmation",
        };
      }

      const scheduled = await schedulePaidPlanChange({
        secretKey,
        uid: identity.uid,
        subscription,
        subscriptionId,
        currentPlan,
        targetPlan,
      });
      await transitionRef.set({
        ...transitionStateData({
          uid: identity.uid,
          subscriptionId,
          currentPlan,
          targetPlan,
          status: "scheduled",
          effectiveAtMillis: scheduled.effectiveAtMillis,
          stripeScheduleId: scheduled.scheduleId,
        }),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        currentPlan: currentPlan.id,
        targetPlan: targetPlan.id,
        changed: true,
        effective: "period_end",
        effectiveAtMillis: scheduled.effectiveAtMillis,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Membership plan change failed", {
        code: String(error && error.code || "").slice(0, 80),
      });
      throw new HttpsError("internal", "Membership plan could not be changed.");
    }
  }

  return {changeMembershipPlan, getMembershipPlanStatus};
}

module.exports = {
  TERMINAL_PROVIDER_STATUSES,
  createMembershipPlanManagement,
  planStatusPayload,
  providerSubscriptionId,
  requirePlanManagementReady,
  scheduleOwnedByPipeBuyer,
  subscriptionPeriodBounds,
  subscriptionScheduleId,
  transitionStateData,
  uniqueBlockingSubscriptionId,
};
