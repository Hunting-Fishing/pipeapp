"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const appleLibrary = require("@apple/app-store-server-library");
const {
  APPLE_BUNDLE_ID,
  APPLE_ENTITLED_STATUSES,
  appleNativeMembershipProduct,
  appleTransactionEntitlement,
} = require("./native_membership_policy");

const APPLE_APP_ID = 6795847447;
const APPLE_ROOT_DIRECTORY = path.join(__dirname, "certs", "apple");
const PINNED_APPLE_ROOT_CERTIFICATES = Object.freeze([
  Object.freeze({
    fileName: "AppleRootCA-G2.cer",
    sha256: "c2b9b042dd57830e7d117dac55ac8ae19407d38e41d88f3215bc3a890444a050",
  }),
  Object.freeze({
    fileName: "AppleRootCA-G3.cer",
    sha256: "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179",
  }),
]);

class AppleStoreServerValidationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "AppleStoreServerValidationError";
    this.code = code;
  }
}

function normalizeAppleEnvironment(value, library = appleLibrary) {
  const environment = String(value || "").trim().toLowerCase();
  if (environment === "production") return library.Environment.PRODUCTION;
  if (environment === "sandbox") return library.Environment.SANDBOX;
  return "";
}

function normalizeAccountToken(value) {
  const token = String(value || "").trim().toLowerCase();
  return /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
      .test(token) ? token : "";
}

function loadPinnedAppleRootCertificates({
  directory = APPLE_ROOT_DIRECTORY,
  readFileSync = fs.readFileSync,
} = {}) {
  return PINNED_APPLE_ROOT_CERTIFICATES.map(({fileName, sha256}) => {
    const certificate = readFileSync(path.join(directory, fileName));
    const actualHash = crypto.createHash("sha256").update(certificate).digest("hex");
    if (actualHash !== sha256) {
      throw new AppleStoreServerValidationError(
          "apple_root_hash_mismatch",
          `Pinned Apple root certificate hash mismatch: ${fileName}`,
      );
    }
    return certificate;
  });
}

function createAppleStoreServerEnvironment({
  environment,
  privateKey,
  keyId,
  issuerId,
  rootCertificates = loadPinnedAppleRootCertificates(),
  enableOnlineChecks = true,
  library = appleLibrary,
}) {
  const normalizedEnvironment = normalizeAppleEnvironment(environment, library);
  const signingKey = String(privateKey || "").trim();
  const normalizedKeyId = String(keyId || "").trim();
  const normalizedIssuerId = String(issuerId || "").trim();
  if (!normalizedEnvironment || !signingKey || !normalizedKeyId ||
      !normalizedIssuerId) {
    throw new AppleStoreServerValidationError(
        "apple_configuration_invalid",
        "Apple server credentials and environment must be configured.",
    );
  }
  if (!Array.isArray(rootCertificates) || rootCertificates.length < 2 ||
      rootCertificates.some((certificate) => !Buffer.isBuffer(certificate))) {
    throw new AppleStoreServerValidationError(
        "apple_roots_invalid",
        "Apple root certificates are unavailable.",
    );
  }
  const appAppleId = normalizedEnvironment === library.Environment.PRODUCTION ?
    APPLE_APP_ID : undefined;
  return {
    environment: normalizedEnvironment,
    apiClient: new library.AppStoreServerAPIClient(
        signingKey,
        normalizedKeyId,
        normalizedIssuerId,
        APPLE_BUNDLE_ID,
        normalizedEnvironment,
    ),
    verifier: new library.SignedDataVerifier(
        rootCertificates,
        enableOnlineChecks === true,
        normalizedEnvironment,
        APPLE_BUNDLE_ID,
        appAppleId,
    ),
  };
}

function verifiedTransactionIdentity(payload, expectedAccountToken) {
  if (!payload || typeof payload !== "object") return null;
  const accountToken = normalizeAccountToken(expectedAccountToken);
  if (!accountToken || normalizeAccountToken(payload.appAccountToken) !== accountToken) {
    return null;
  }
  if (String(payload.bundleId || "") !== APPLE_BUNDLE_ID) return null;
  if (!appleNativeMembershipProduct(payload.productId)) return null;
  if (String(payload.inAppOwnershipType || "") !== "PURCHASED") return null;
  if (Number(payload.revocationDate || 0) > 0) return null;
  const transactionId = String(payload.transactionId || "").trim();
  const originalTransactionId = String(payload.originalTransactionId || "").trim();
  if (!transactionId || !originalTransactionId) return null;
  return {transactionId, originalTransactionId};
}

function environmentMatches(value, expectedEnvironment) {
  return String(value || "").toLowerCase() ===
    String(expectedEnvironment || "").toLowerCase();
}

async function verifyAppleTransaction({
  verifier,
  signedTransactionInfo,
  expectedAccountToken,
  expectedEnvironment,
}) {
  if (!verifier || typeof verifier.verifyAndDecodeTransaction !== "function") {
    throw new AppleStoreServerValidationError(
        "apple_verifier_unavailable",
        "Apple signed-data verification is unavailable.",
    );
  }
  const signedValue = String(signedTransactionInfo || "").trim();
  if (!signedValue) {
    throw new AppleStoreServerValidationError(
        "apple_transaction_missing",
        "Apple signed transaction information is missing.",
    );
  }
  const payload = await verifier.verifyAndDecodeTransaction(signedValue);
  const identity = verifiedTransactionIdentity(payload, expectedAccountToken);
  if (!identity || !environmentMatches(payload.environment, expectedEnvironment)) {
    throw new AppleStoreServerValidationError(
        "apple_transaction_mismatch",
        "Apple transaction identity did not match the expected account.",
    );
  }
  return {payload, ...identity};
}

async function verifiedAppleStatusEntitlement({
  statusResponse,
  verifier,
  expectedAccountToken,
  expectedEnvironment,
  expectedOriginalTransactionId = "",
  nowMillis = Date.now(),
}) {
  if (!statusResponse || String(statusResponse.bundleId || "") !== APPLE_BUNDLE_ID ||
      !environmentMatches(statusResponse.environment, expectedEnvironment)) {
    throw new AppleStoreServerValidationError(
        "apple_status_mismatch",
        "Apple subscription status did not match this app and environment.",
    );
  }
  if (String(expectedEnvironment).toLowerCase() === "production" &&
      Number(statusResponse.appAppleId) !== APPLE_APP_ID) {
    throw new AppleStoreServerValidationError(
        "apple_app_id_mismatch",
        "Apple subscription status did not match this app identifier.",
    );
  }

  let selected = null;
  const expectedOriginal = String(expectedOriginalTransactionId || "").trim();
  for (const group of Array.isArray(statusResponse.data) ? statusResponse.data : []) {
    const transactions = Array.isArray(group && group.lastTransactions) ?
      group.lastTransactions : [];
    for (const item of transactions) {
      const status = Number(item && item.status || 0);
      if (!APPLE_ENTITLED_STATUSES.has(status)) continue;
      const verified = await verifyAppleTransaction({
        verifier,
        signedTransactionInfo: item && item.signedTransactionInfo,
        expectedAccountToken,
        expectedEnvironment,
      });
      if (expectedOriginal && verified.originalTransactionId !== expectedOriginal) {
        continue;
      }
      if (item.originalTransactionId &&
          String(item.originalTransactionId) !== verified.originalTransactionId) {
        throw new AppleStoreServerValidationError(
            "apple_original_transaction_mismatch",
            "Apple subscription status contained inconsistent transaction data.",
        );
      }

      let renewal = {};
      const signedRenewalInfo = String(item && item.signedRenewalInfo || "").trim();
      if (signedRenewalInfo) {
        renewal = await verifier.verifyAndDecodeRenewalInfo(signedRenewalInfo);
        if (!environmentMatches(renewal.environment, expectedEnvironment) ||
            (renewal.originalTransactionId &&
             String(renewal.originalTransactionId) !== verified.originalTransactionId)) {
          throw new AppleStoreServerValidationError(
              "apple_renewal_mismatch",
              "Apple renewal information did not match the subscription.",
          );
        }
      }

      const entitlementPayload = {...verified.payload};
      if (status === 4) {
        entitlementPayload.expiresDate = Math.max(
            Number(entitlementPayload.expiresDate || 0),
            Number(renewal.gracePeriodExpiresDate || 0),
        );
      }
      const entitlement = appleTransactionEntitlement(
          entitlementPayload,
          expectedAccountToken,
          nowMillis,
      );
      if (!entitlement) continue;
      const pendingProduct = appleNativeMembershipProduct(renewal.autoRenewProductId);
      const pendingProductId = pendingProduct &&
        pendingProduct.productId !== entitlement.productId ?
        pendingProduct.productId : "";
      const candidate = {
        ...entitlement,
        status: status === 4 ? "grace_period" : "active",
        autoRenewEnabled: Number(renewal.autoRenewStatus || 0) === 1,
        pendingProductId,
      };
      if (!selected || candidate.expiresAtMillis > selected.expiresAtMillis) {
        selected = candidate;
      }
    }
  }
  return selected;
}

async function fetchVerifiedAppleSubscriptionEntitlement({
  apiClient,
  verifier,
  originalTransactionId,
  expectedAccountToken,
  expectedEnvironment,
  nowMillis = Date.now(),
}) {
  const originalId = String(originalTransactionId || "").trim();
  if (!apiClient || typeof apiClient.getAllSubscriptionStatuses !== "function" ||
      !originalId) {
    throw new AppleStoreServerValidationError(
        "apple_subscription_request_invalid",
        "Apple subscription status cannot be requested safely.",
    );
  }
  const statusResponse = await apiClient.getAllSubscriptionStatuses(originalId);
  return verifiedAppleStatusEntitlement({
    statusResponse,
    verifier,
    expectedAccountToken,
    expectedEnvironment,
    expectedOriginalTransactionId: originalId,
    nowMillis,
  });
}

async function fetchVerifiedAppleCurrentEntitlement({
  apiClient,
  verifier,
  transactionId,
  expectedAccountToken,
  expectedEnvironment,
  nowMillis = Date.now(),
}) {
  const requestedTransactionId = String(transactionId || "").trim();
  if (!apiClient || typeof apiClient.getTransactionInfo !== "function" ||
      !requestedTransactionId) {
    throw new AppleStoreServerValidationError(
        "apple_transaction_request_invalid",
        "Apple transaction information cannot be requested safely.",
    );
  }
  const response = await apiClient.getTransactionInfo(requestedTransactionId);
  const verified = await verifyAppleTransaction({
    verifier,
    signedTransactionInfo: response && response.signedTransactionInfo,
    expectedAccountToken,
    expectedEnvironment,
  });
  return fetchVerifiedAppleSubscriptionEntitlement({
    apiClient,
    verifier,
    originalTransactionId: verified.originalTransactionId,
    expectedAccountToken,
    expectedEnvironment,
    nowMillis,
  });
}

function isAppleTransactionNotFound(error, library = appleLibrary) {
  const value = Number(error && error.apiError);
  return value === Number(library.APIError.TRANSACTION_ID_NOT_FOUND) ||
    value === Number(library.APIError.ORIGINAL_TRANSACTION_ID_NOT_FOUND);
}

function isRetryableAppleVerificationError(error, library = appleLibrary) {
  return error && Number(error.status) ===
    Number(library.VerificationStatus.RETRYABLE_VERIFICATION_FAILURE);
}

function isAppleVerificationError(error, library = appleLibrary) {
  return error instanceof library.VerificationException ||
    (error && Number.isInteger(error.status) &&
     Object.values(library.VerificationStatus).includes(error.status));
}

module.exports = {
  APPLE_APP_ID,
  APPLE_ROOT_DIRECTORY,
  AppleStoreServerValidationError,
  PINNED_APPLE_ROOT_CERTIFICATES,
  createAppleStoreServerEnvironment,
  fetchVerifiedAppleCurrentEntitlement,
  fetchVerifiedAppleSubscriptionEntitlement,
  isAppleVerificationError,
  isAppleTransactionNotFound,
  isRetryableAppleVerificationError,
  loadPinnedAppleRootCertificates,
  normalizeAccountToken,
  normalizeAppleEnvironment,
  verifiedAppleStatusEntitlement,
  verifyAppleTransaction,
  verifiedTransactionIdentity,
};
