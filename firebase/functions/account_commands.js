"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  phoneRegistryKey,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");

function commandError(error) {
  if (error instanceof HttpsError) return error;
  if (error instanceof AccountSecurityError) {
    return new HttpsError(error.code, error.message);
  }
  console.error("Account command failed", error);
  return new HttpsError(
      "internal",
      "The account verification service could not complete the request.",
  );
}

function createAccountCommands(admin) {
  const db = admin.firestore();
  const {FieldValue} = admin.firestore;

  const syncAccountVerification = async (request) => {
    try {
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const identity = requireAuthenticatedIdentity(request, {
        requireEmail: false,
        requirePhone: false,
        allowUnverified: true,
      });
      const userRef = db.collection("users").doc(identity.uid);
      const registryKey = identity.phoneVerified ?
        phoneRegistryKey(identity.phoneNumber) : null;
      const registryRef = registryKey ?
        db.collection("account_phone_registry").doc(registryKey) : null;

      const result = await db.runTransaction(async (transaction) => {
        const userSnapshot = await transaction.get(userRef);
        const previousRegistryKey = String(
            userSnapshot.data() && userSnapshot.data().phoneRegistryKey || "",
        );
        const registrySnapshot = registryRef ?
          await transaction.get(registryRef) : null;
        if (
          registrySnapshot &&
          registrySnapshot.exists &&
          registrySnapshot.data().uid !== identity.uid
        ) {
          throw new AccountSecurityError(
              "already-exists",
              "This mobile number is already connected to another account. " +
              "Use account recovery instead of creating a second account.",
          );
        }

        if (previousRegistryKey && previousRegistryKey !== registryKey) {
          const previousRef = db.collection("account_phone_registry")
              .doc(previousRegistryKey);
          const previousSnapshot = await transaction.get(previousRef);
          if (
            previousSnapshot.exists &&
            previousSnapshot.data().uid === identity.uid
          ) {
            transaction.delete(previousRef);
          }
        }

        if (registryRef) {
          transaction.set(registryRef, {
            uid: identity.uid,
            phoneE164: identity.phoneNumber,
            verificationSource: "firebase_auth",
            verifiedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }

        transaction.set(userRef, {
          uid: identity.uid,
          email: identity.email || null,
          emailOwnershipVerified: identity.emailVerified,
          phoneOwnershipVerified: identity.phoneVerified,
          verifiedPhoneE164: identity.phoneVerified ?
            identity.phoneNumber : FieldValue.delete(),
          phoneE164: identity.phoneVerified ?
            identity.phoneNumber : FieldValue.delete(),
          phoneRegistryKey: registryKey || FieldValue.delete(),
          accountVerificationVersion: 1,
          verificationSyncedAt: FieldValue.serverTimestamp(),
          ...(identity.emailVerified ?
            {emailVerifiedAt: FieldValue.serverTimestamp()} : {}),
          ...(identity.phoneVerified ?
            {phoneVerifiedAt: FieldValue.serverTimestamp()} : {}),
        }, {merge: true});

        return {
          emailVerified: identity.emailVerified,
          phoneVerified: identity.phoneVerified,
        };
      });

      return result;
    } catch (error) {
      throw commandError(error);
    }
  };

  return {syncAccountVerification};
}

module.exports = {createAccountCommands};