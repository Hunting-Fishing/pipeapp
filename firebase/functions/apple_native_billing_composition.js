"use strict";

const {
  createAppleStoreServerEnvironment,
  fetchVerifiedAppleSubscriptionEntitlement,
} = require("./apple_store_server_client");
const {
  createAppStoreServerNotificationHttpHandler,
  createAppStoreServerNotificationProcessor,
  createFirestoreNotificationEventStore,
  createNativeMembershipOwnerResolver,
} = require("./apple_store_server_notifications");
const {
  appleIapIssuerId,
  appleIapKeyId,
  appleIapPrivateKey,
  appleSandboxAccountAllowed,
  applyNativeEntitlement,
  beginNativeMembershipReconciliation,
  clearExpiredNativeEntitlement,
  nativeBillingReadiness,
} = require("./native_membership_billing");

const NATIVE_BILLING_CONFIGURATION_COLLECTION = "platform_configuration";
const NATIVE_BILLING_CONFIGURATION_DOCUMENT = "native_membership_billing";
const APPLE_PRODUCTION_NOTIFICATION_GATE_FIELD =
  "appleProductionNotificationMutationsEnabled";
const APPLE_SANDBOX_NOTIFICATION_GATE_FIELD =
  "appleSandboxNotificationMutationsEnabled";
const APPLE_IAP_SECRET_NAMES = Object.freeze([
  appleIapPrivateKey.name,
  appleIapKeyId.name,
  appleIapIssuerId.name,
]);

function normalizePrivateKey(value) {
  return String(value || "").replace(/\\n/g, "\n").trim();
}

function readAppleIapCredentials() {
  return {
    privateKey: normalizePrivateKey(appleIapPrivateKey.value()),
    keyId: appleIapKeyId.value(),
    issuerId: appleIapIssuerId.value(),
  };
}

function normalizedAppleEnvironment(value) {
  const environment = String(value || "").trim().toLowerCase();
  if (environment === "production") return "Production";
  if (environment === "sandbox") return "Sandbox";
  throw new TypeError("Apple notification environment is invalid.");
}

function notificationMutationGateField(environment) {
  return normalizedAppleEnvironment(environment) === "Production" ?
    APPLE_PRODUCTION_NOTIFICATION_GATE_FIELD :
    APPLE_SANDBOX_NOTIFICATION_GATE_FIELD;
}

async function appleNotificationMutationEnabled({db, environment}) {
  if (!db || typeof db.collection !== "function") {
    throw new TypeError("Apple notification mutation gate is not configured.");
  }
  const normalizedEnvironment = normalizedAppleEnvironment(environment);
  const snapshot = await db.collection(NATIVE_BILLING_CONFIGURATION_COLLECTION)
      .doc(NATIVE_BILLING_CONFIGURATION_DOCUMENT).get();
  const configuration = snapshot.exists ? snapshot.data() : {};
  const readiness = nativeBillingReadiness(configuration);
  if (!readiness.enabled || !readiness.appleEnabled) return false;
  if (normalizedEnvironment === "Sandbox" &&
      !readiness.appleSandboxEnabled) return false;
  return configuration[notificationMutationGateField(normalizedEnvironment)] === true;
}

function requireCompositionAdmin(admin) {
  if (!admin || typeof admin.firestore !== "function" ||
      !admin.firestore.FieldValue || !admin.firestore.Timestamp ||
      !admin.auth || typeof admin.auth !== "function") {
    throw new TypeError("Apple notification composition is not configured.");
  }
  return admin.firestore();
}

function createAppleServerNotificationComposition({
  admin,
  environment,
  credentials = null,
  createServerEnvironment = createAppleStoreServerEnvironment,
  fetchSubscriptionEntitlement = fetchVerifiedAppleSubscriptionEntitlement,
  loadMutationGate = appleNotificationMutationEnabled,
}) {
  const db = requireCompositionAdmin(admin);
  const expectedEnvironment = normalizedAppleEnvironment(environment);
  const resolvedCredentials = credentials || readAppleIapCredentials();
  const serverEnvironment = createServerEnvironment({
    environment: expectedEnvironment,
    privateKey: normalizePrivateKey(resolvedCredentials.privateKey),
    keyId: String(resolvedCredentials.keyId || "").trim(),
    issuerId: String(resolvedCredentials.issuerId || "").trim(),
  });
  if (!serverEnvironment || !serverEnvironment.apiClient ||
      !serverEnvironment.verifier) {
    throw new TypeError("Apple server environment is not configured.");
  }

  const eventStore = createFirestoreNotificationEventStore({db, admin});
  const resolveOwnerByAccountToken = createNativeMembershipOwnerResolver({db});
  const authorizeOwnerForEnvironment = async ({uid, expectedEnvironment: value}) => {
    if (normalizedAppleEnvironment(value) !== expectedEnvironment) return false;
    if (expectedEnvironment === "Production") return true;
    return appleSandboxAccountAllowed(admin, uid);
  };
  const mutationEnabled = async () => loadMutationGate({
    db,
    environment: expectedEnvironment,
  });
  const beginReconciliation = ({uid}) =>
    beginNativeMembershipReconciliation({db, admin, uid});
  const loadProviderState = async (uid) => {
    const snapshot = await db.collection("native_membership_provider_state")
        .doc(uid).get();
    return snapshot.exists ? snapshot.data() : null;
  };
  const reconcileSubscription = ({originalTransactionId, accountToken}) =>
    fetchSubscriptionEntitlement({
      apiClient: serverEnvironment.apiClient,
      verifier: serverEnvironment.verifier,
      originalTransactionId,
      expectedAccountToken: accountToken,
      expectedEnvironment,
    });
  const applyEntitlement = (value) => applyNativeEntitlement({
    db,
    admin,
    ...value,
  });
  const clearEntitlement = (value) => clearExpiredNativeEntitlement({
    db,
    admin,
    ...value,
  });

  const processNotification = createAppStoreServerNotificationProcessor({
    expectedEnvironment,
    verifier: serverEnvironment.verifier,
    eventStore,
    resolveOwnerByAccountToken,
    authorizeOwnerForEnvironment,
    mutationEnabled,
    beginReconciliation,
    loadProviderState,
    reconcileSubscription,
    applyNativeEntitlement: applyEntitlement,
    clearExpiredNativeEntitlement: clearEntitlement,
  });
  const httpHandler = createAppStoreServerNotificationHttpHandler({
    processNotification,
  });

  return Object.freeze({
    environment: expectedEnvironment,
    apiClient: serverEnvironment.apiClient,
    verifier: serverEnvironment.verifier,
    processNotification,
    httpHandler,
    secretNames: APPLE_IAP_SECRET_NAMES,
  });
}

function createAppleSandboxServerNotificationComposition(options) {
  return createAppleServerNotificationComposition({
    ...options,
    environment: "Sandbox",
  });
}

function createAppleProductionServerNotificationComposition(options) {
  return createAppleServerNotificationComposition({
    ...options,
    environment: "Production",
  });
}

module.exports = {
  APPLE_IAP_SECRET_NAMES,
  APPLE_PRODUCTION_NOTIFICATION_GATE_FIELD,
  APPLE_SANDBOX_NOTIFICATION_GATE_FIELD,
  NATIVE_BILLING_CONFIGURATION_COLLECTION,
  NATIVE_BILLING_CONFIGURATION_DOCUMENT,
  appleNotificationMutationEnabled,
  createAppleProductionServerNotificationComposition,
  createAppleSandboxServerNotificationComposition,
  createAppleServerNotificationComposition,
  notificationMutationGateField,
  normalizedAppleEnvironment,
  readAppleIapCredentials,
};
