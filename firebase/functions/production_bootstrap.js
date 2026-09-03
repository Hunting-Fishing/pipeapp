"use strict";

// Preserve the complete marketplace function surface and add the MFA-admin
// production-readiness control plane as a thin wrapper.
const coreExports = require("./bootstrap");
Object.assign(exports, coreExports);

const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {HttpsError, onCall} = require("firebase-functions/v2/https");
const {createAdminRuntime} = require("./admin_runtime");
const {protectedCallableOptions} = require("./app_check_config");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {CommandPolicyError} = require("./marketplace_command_policy");
const {
  createPaymentReadinessAdmin,
} = require("./payment_readiness_admin");
const {createMarketplaceFeeAdmin} = require("./marketplace_fee_admin");
const {
  createMarketplaceTaxCompliance,
} = require("./marketplace_tax_compliance");
const {
  createMarketplaceTaxClaimLink,
} = require("./marketplace_tax_claim_link");
const {
  createMarketplaceTaxRegistrationAdmin,
} = require("./marketplace_tax_registration_admin");
const {
  createMarketplaceTaxRecovery,
} = require("./marketplace_tax_recovery");
const {
  createMembershipPlanManagement,
} = require("./membership_plan_management");
const {
  createMembershipProviderStateSync,
} = require("./membership_provider_state_sync");
const {createDispatchCommands} = require("./dispatch_commands");
const {
  adaptDispatchRequestInput,
} = require("./dispatch_request_input_adapter");
const {
  createDispatchFieldRequestCommands,
} = require("./dispatch_field_request_commands");
const {
  createDispatchRequestAttachmentCommands,
} = require("./dispatch_request_attachment_commands");
const {
  createDispatchSubscriptionProviderAccess,
} = require("./dispatch_subscription_provider_access");
const {
  createDispatchRequestLifecycleCommands,
} = require("./dispatch_request_lifecycle_commands");
const {
  createVipSubscriptionCommands,
} = require("./vip_subscription_commands");
const {
  createPolicyAcceptanceCommands,
} = require("./policy_acceptance_commands");
const {
  createNativeMembershipBilling,
} = require("./native_membership_billing");
const {stripeSecretKey} = require("./stripe_marketplace_commands");

const admin = createAdminRuntime();
const readinessAdmin = createPaymentReadinessAdmin(admin);
const marketplaceFeeAdmin = createMarketplaceFeeAdmin();
const marketplaceTaxCompliance = createMarketplaceTaxCompliance(admin);
const marketplaceTaxClaimLink = createMarketplaceTaxClaimLink(admin);
const marketplaceTaxRegistrationAdmin =
  createMarketplaceTaxRegistrationAdmin(admin);
const marketplaceTaxRecovery = createMarketplaceTaxRecovery(admin);
const membershipPlanManagement = createMembershipPlanManagement(admin);
const membershipProviderStateSync = createMembershipProviderStateSync(admin);
const dispatchCommands = createDispatchCommands(admin);
const dispatchFieldRequestCommands = createDispatchFieldRequestCommands(admin);
const dispatchRequestAttachmentCommands =
  createDispatchRequestAttachmentCommands(admin);
const membershipProviderAccess = createDispatchSubscriptionProviderAccess(admin);
const dispatchRequestLifecycleCommands =
  createDispatchRequestLifecycleCommands(admin);
const vipSubscriptionCommands = createVipSubscriptionCommands(admin);
const policyAcceptanceCommands = createPolicyAcceptanceCommands(admin);
const nativeMembershipBilling = createNativeMembershipBilling(admin);
const membershipStripeCallableOptions = Object.freeze({
  ...protectedCallableOptions,
  secrets: [stripeSecretKey.name],
});

async function createVipSubscriptionCheckoutWithProviderGuard(request) {
  await membershipProviderAccess.requireNoBlockingProviderSubscription(request);
  return vipSubscriptionCommands.createVipSubscriptionCheckout(request);
}

function sameStrings(first, second) {
  if (!Array.isArray(first) || !Array.isArray(second) ||
      first.length !== second.length) {
    return false;
  }
  return first.every((value, index) => value === second[index]);
}

async function stampDispatchRequestMetadata(jobId, metadata) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const jobRef = db.collection("dispatch_jobs").doc(jobId);
  const privateRef = db.collection("dispatch_job_private").doc(jobId);
  await db.runTransaction(async (transaction) => {
    const [jobSnapshot, privateSnapshot] = await Promise.all([
      transaction.get(jobRef),
      transaction.get(privateRef),
    ]);
    if (!jobSnapshot.exists || !privateSnapshot.exists) {
      throw new HttpsError(
          "failed-precondition",
          "The Dispatch request could not be finalized.",
      );
    }
    const job = jobSnapshot.data() || {};
    const privateJob = privateSnapshot.data() || {};
    if (Number(job.requestSchemaVersion || 0) >= 2) {
      const samePublic = job.requestPath === metadata.requestPath &&
        job.routeRelevant === metadata.routeRelevant &&
        sameStrings(job.serviceCodes, metadata.serviceCodes);
      const samePrivate =
        privateJob.contactPreference === metadata.contactPreference;
      if (!samePublic || !samePrivate) {
        throw new HttpsError(
            "already-exists",
            "This Dispatch request identifier is already used with different service details.",
        );
      }
      return;
    }

    const publicMetadata = {
      requestSchemaVersion: metadata.requestSchemaVersion,
      requestPath: metadata.requestPath,
      routeRelevant: metadata.routeRelevant,
      serviceCodes: metadata.serviceCodes,
    };
    const privateMetadata = {
      requestSchemaVersion: metadata.requestSchemaVersion,
      contactPreference: metadata.contactPreference,
    };
    transaction.set(jobRef, {
      ...publicMetadata,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.set(jobRef.collection("revisions").doc("1"),
        publicMetadata, {merge: true});
    transaction.set(privateRef, {
      ...privateMetadata,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.set(privateRef.collection("revisions").doc("1"),
        privateMetadata, {merge: true});
  });
}

async function createDispatchJobWithRequestAdapter(request) {
  let adapted;
  let identity;
  try {
    identity = requireAuthenticatedIdentity(request);
    adapted = adaptDispatchRequestInput(request.data || {}, identity);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (error instanceof AccountSecurityError || error instanceof CommandPolicyError) {
      throw new HttpsError(error.code, error.message);
    }
    throw error;
  }

  if (adapted.enhanced && adapted.metadata &&
      adapted.metadata.requestPath === "field_service") {
    const result = await dispatchFieldRequestCommands.createFieldServiceRequest(
        {...request, data: adapted.commandData},
        adapted.metadata,
    );
    const jobId = String(result && result.jobId ||
      request.data && request.data.jobId || "").trim();
    await dispatchRequestAttachmentCommands.finalizeDispatchRequestAttachments({
      uid: identity.uid,
      jobId,
      attachments: adapted.metadata.attachments,
    });
    return result;
  }

  const result = await dispatchCommands.createDispatchJob({
    ...request,
    data: adapted.commandData,
  });
  if (adapted.enhanced && adapted.metadata) {
    const jobId = String(result && result.jobId ||
      request.data && request.data.jobId || "").trim();
    if (!jobId || jobId.includes("/")) {
      throw new HttpsError(
          "internal",
          "The Dispatch request identifier is unavailable.",
      );
    }
    await stampDispatchRequestMetadata(jobId, adapted.metadata);
    await dispatchRequestAttachmentCommands.finalizeDispatchRequestAttachments({
      uid: identity.uid,
      jobId,
      attachments: adapted.metadata.attachments,
    });
  }
  return result;
}

exports.getPaymentProviderReadiness = onCall(
    protectedCallableOptions,
    readinessAdmin.getPaymentProviderReadiness,
);

exports.setPaymentProviderReadiness = onCall(
    protectedCallableOptions,
    readinessAdmin.setPaymentProviderReadiness,
);

exports.getMarketplaceFeeCatalog = onCall(
    protectedCallableOptions,
    marketplaceFeeAdmin.getMarketplaceFeeCatalog,
);

exports.getMarketplaceTaxProfile = onCall(
    protectedCallableOptions,
    marketplaceTaxCompliance.getMarketplaceTaxProfile,
);

exports.updateMarketplaceTaxProfile = onCall(
    protectedCallableOptions,
    marketplaceTaxCompliance.updateMarketplaceTaxProfile,
);

exports.submitMarketplaceTaxExemptionClaim = onCall(
    protectedCallableOptions,
    async (request) => {
      const result = await marketplaceTaxCompliance
          .submitMarketplaceTaxExemptionClaim(request);
      const transactionId = String(
          request.data && request.data.transactionId || "",
      ).trim();
      const claimId = String(result && result.claimId || "").trim();
      if (transactionId && claimId) {
        await marketplaceTaxClaimLink.attachMarketplaceTaxExemptionClaim({
          ...request,
          data: {transactionId, claimId},
        });
      }
      return result;
    },
);

exports.attachMarketplaceTaxExemptionClaim = onCall(
    protectedCallableOptions,
    marketplaceTaxClaimLink.attachMarketplaceTaxExemptionClaim,
);

exports.getMarketplaceTaxComplianceAdmin = onCall(
    protectedCallableOptions,
    marketplaceTaxCompliance.getMarketplaceTaxComplianceAdmin,
);

exports.reviewMarketplaceTaxExemptionClaim = onCall(
    protectedCallableOptions,
    marketplaceTaxCompliance.reviewMarketplaceTaxExemptionClaim,
);

exports.getMarketplaceTaxRegistrationAdmin = onCall(
    protectedCallableOptions,
    marketplaceTaxRegistrationAdmin.getMarketplaceTaxRegistrationAdmin,
);

exports.reviewMarketplaceTaxRegistration = onCall(
    protectedCallableOptions,
    marketplaceTaxRegistrationAdmin.reviewMarketplaceTaxRegistration,
);

exports.getMarketplaceTaxRecoveryAdmin = onCall(
    protectedCallableOptions,
    marketplaceTaxRecovery.getMarketplaceTaxRecoveryAdmin,
);

exports.createMarketplaceTaxRecoveryCase = onCall(
    protectedCallableOptions,
    marketplaceTaxRecovery.createMarketplaceTaxRecoveryCase,
);

exports.resolveMarketplaceTaxRecoveryCase = onCall(
    protectedCallableOptions,
    marketplaceTaxRecovery.resolveMarketplaceTaxRecoveryCase,
);

exports.getMembershipPlanStatus = onCall(
    protectedCallableOptions,
    membershipPlanManagement.getMembershipPlanStatus,
);

exports.changeMembershipPlan = onCall(
    membershipStripeCallableOptions,
    membershipPlanManagement.changeMembershipPlan,
);

// Override the legacy freight-shaped create callable without changing its
// public name or authoritative command. R4 metadata is server-derived and
// retry-safe, while legacy clients continue to pass through unchanged.
exports.createDispatchJob = onCall(
    protectedCallableOptions,
    policyAcceptanceCommands.requireCurrentPolicies(
        createDispatchJobWithRequestAdapter,
    ),
);

exports.updateDispatchFieldRequest = onCall(
    protectedCallableOptions,
    policyAcceptanceCommands.requireCurrentPolicies(
        dispatchFieldRequestCommands.updateFieldServiceRequest,
    ),
);

exports.authorizeDispatchRequestUpload = onCall(
    protectedCallableOptions,
    policyAcceptanceCommands.requireCurrentPolicies(
        dispatchRequestAttachmentCommands.authorizeDispatchRequestUpload,
    ),
);

exports.cancelDispatchJob = onCall(
    protectedCallableOptions,
    policyAcceptanceCommands.requireCurrentPolicies(
        dispatchRequestLifecycleCommands.cancelDispatchJob,
    ),
);

// Override bootstrap's VIP checkout with the same cross-provider guard already
// used by Dispatch checkout. This prevents a second Stripe subscription and,
// once native store billing is active, prevents Stripe/store overlap as well.
exports.createVipSubscriptionCheckout = onCall(
    membershipStripeCallableOptions,
    policyAcceptanceCommands.requireCurrentPolicies(
        createVipSubscriptionCheckoutWithProviderGuard,
    ),
);

// This readiness/bootstrap endpoint has no store credentials and is safe to
// deploy before App Store Connect / Play Console enrollment. The mutation and
// reconciliation handlers remain unexported until their Secret Manager values
// are provisioned and an explicit native-billing activation is approved.
exports.getNativeMembershipBillingStatus = onCall(
    protectedCallableOptions,
    nativeMembershipBilling.getNativeMembershipBillingStatus,
);

exports.onDispatchMembershipProviderTerminalSync = onDocumentUpdated(
    "dispatch_subscription_provider_state/{uid}",
    membershipProviderStateSync.onDispatchProviderUpdated,
);

exports.onVipMembershipProviderTerminalSync = onDocumentUpdated(
    "vip_subscription_provider_state/{uid}",
    membershipProviderStateSync.onVipProviderUpdated,
);
