"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  AccountVerificationPolicyError,
  requireVerificationReadiness,
  validateVerificationDecision,
} = require("./account_verification_policy");

function requiredId(data, fieldName) {
  const value = String(data && data[fieldName] || "").trim();
  if (!value || value.length > 180 || value.includes("/")) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} is missing or invalid.`,
    );
  }
  return value;
}

function commandError(error) {
  if (error instanceof HttpsError) return error;
  if (error instanceof AccountSecurityError ||
      error instanceof AdministratorAuthorizationError ||
      error instanceof AccountVerificationPolicyError) {
    return new HttpsError(error.code, error.message);
  }
  console.error("Account verification command failed", error);
  return new HttpsError(
      "internal",
      "The account verification action could not be completed.",
  );
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      throw commandError(error);
    }
  };
}

function receiptId(actorUid, commandName, requestId) {
  return crypto.createHash("sha256")
      .update(`${actorUid}|${commandName}|${requestId}`)
      .digest("hex");
}

function createAccountVerificationCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function notifyAdministrators(userUid, revision, displayName) {
    const roles = await db.collection("administrator_roles")
        .where("active", "==", true)
        .get();
    if (roles.empty) {
      console.warn(
          `Verification ${userUid} submitted without an active administrator`,
      );
      return;
    }
    const batch = db.batch();
    for (const role of roles.docs) {
      const notificationRef = db.collection("users").doc(role.id)
          .collection("notifications")
          .doc(`verification-${userUid}-${revision}`);
      batch.set(notificationRef, {
        recipientUid: role.id,
        type: "account_verification_submitted",
        title: "Account verification ready for review",
        message: `${displayName} submitted account verification evidence.`,
        userUid,
        revision,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      }, {merge: false});
    }
    await batch.commit();
  }

  const submitAccountVerification = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    await enforceUserRateLimit({
      db,
      admin,
      request,
      scope: "account",
    });
    const requestId = requiredId(request.data, "requestId");
    const userRef = db.collection("users").doc(identity.uid);
    const sellerProfileRef = db.collection("public_seller_profiles")
        .doc(identity.uid);
    const businessProfileRef = db.collection("public_business_profiles")
        .doc(identity.uid);
    const [userSnapshot, sellerSnapshot, businessSnapshot] =
      await Promise.all([
        userRef.get(),
        sellerProfileRef.get(),
        businessProfileRef.get(),
      ]);
    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "Complete your account profile first.");
    }
    const user = userSnapshot.data();
    const sellerProfile = sellerSnapshot.exists ? sellerSnapshot.data() : {};
    const businessProfile = businessSnapshot.exists ?
      businessSnapshot.data() : {};
    const readiness = requireVerificationReadiness({
      identity,
      user,
      sellerProfile,
      businessProfile,
    });
    const verificationRef = db.collection("verification_requests")
        .doc(identity.uid);
    const receiptRef = db.collection("account_verification_command_receipts")
        .doc(receiptId(identity.uid, "submit", requestId));

    const result = await db.runTransaction(async (transaction) => {
      const [receiptSnapshot, verificationSnapshot] = await Promise.all([
        transaction.get(receiptRef),
        transaction.get(verificationRef),
      ]);
      if (receiptSnapshot.exists) return receiptSnapshot.data().result;
      const current = verificationSnapshot.exists ?
        verificationSnapshot.data() : {};
      if (current.status === "approved") {
        const approved = {
          status: "approved",
          revision: Number(current.revision || 1),
          submitted: false,
        };
        transaction.create(receiptRef, {
          actorUid: identity.uid,
          command: "submitAccountVerification",
          result: approved,
          createdAt: FieldValue.serverTimestamp(),
        });
        return approved;
      }
      if (current.status === "pending") {
        const pending = {
          status: "pending",
          revision: Number(current.revision || 1),
          submitted: false,
        };
        transaction.create(receiptRef, {
          actorUid: identity.uid,
          command: "submitAccountVerification",
          result: pending,
          createdAt: FieldValue.serverTimestamp(),
        });
        return pending;
      }
      const revision = Number(current.revision || 0) + 1;
      const evidence = {
        accountType: readiness.accountType,
        displayName: readiness.displayName,
        photoUrl: String(sellerProfile.photoUrl || ""),
        approvedTagIds: Array.isArray(sellerProfile.approvedTagIds) ?
          sellerProfile.approvedTagIds.slice(0, 30) : [],
        businessDescription: readiness.accountType === "business" ?
          String(businessProfile.description || "") : null,
        serviceAreaLabel: readiness.accountType === "business" ?
          String(businessProfile.serviceAreaLabel || "") : null,
        checks: readiness.checks,
      };
      const submitted = {status: "pending", revision, submitted: true};
      transaction.set(verificationRef, {
        userUid: identity.uid,
        accountType: readiness.accountType,
        displayName: readiness.displayName,
        status: "pending",
        revision,
        evidence,
        emailOwnershipVerified: true,
        phoneOwnershipVerified: true,
        requestedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        reviewedAt: FieldValue.delete(),
        reviewedByUid: FieldValue.delete(),
        reviewReason: FieldValue.delete(),
      }, {merge: true});
      transaction.create(
          db.collection("verification_review_events")
              .doc(`${identity.uid}-${revision}-submitted`),
          {
            userUid: identity.uid,
            revision,
            event: "submitted",
            actorUid: identity.uid,
            status: "pending",
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(receiptRef, {
        actorUid: identity.uid,
        command: "submitAccountVerification",
        result: submitted,
        createdAt: FieldValue.serverTimestamp(),
      });
      return submitted;
    });
    if (result.submitted) {
      await notifyAdministrators(
          identity.uid,
          result.revision,
          readiness.displayName,
      );
    }
    return result;
  });

  const reviewAccountVerification = command(async (request) => {
    const administratorUid = requireAdministrator(request);
    await enforceUserRateLimit({
      db,
      admin,
      request,
      scope: "administration",
    });
    const userUid = requiredId(request.data, "userUid");
    const requestId = requiredId(request.data, "requestId");
    const {decision, reason} = validateVerificationDecision(request.data);
    if (decision === "approved") {
      const userRecord = await admin.auth().getUser(userUid);
      if (userRecord.disabled || userRecord.emailVerified !== true ||
          !String(userRecord.phoneNumber || "").startsWith("+")) {
        throw new HttpsError(
            "failed-precondition",
            "Approval requires a current verified email and mobile number.",
        );
      }
    }
    const verificationRef = db.collection("verification_requests").doc(userUid);
    const userRef = db.collection("users").doc(userUid);
    const receiptRef = db.collection("account_verification_command_receipts")
        .doc(receiptId(administratorUid, "review", requestId));
    const result = await db.runTransaction(async (transaction) => {
      const [receiptSnapshot, verificationSnapshot, userSnapshot] =
        await Promise.all([
          transaction.get(receiptRef),
          transaction.get(verificationRef),
          transaction.get(userRef),
        ]);
      if (receiptSnapshot.exists) return receiptSnapshot.data().result;
      if (!verificationSnapshot.exists || !userSnapshot.exists) {
        throw new HttpsError(
            "not-found",
            "This verification request is no longer available.",
        );
      }
      const verification = verificationSnapshot.data();
      if (verification.status !== "pending") {
        throw new HttpsError(
            "failed-precondition",
            "This verification request has already been reviewed.",
        );
      }
      const revision = Number(verification.revision || 1);
      const reviewed = {status: decision, revision, userUid};
      transaction.update(verificationRef, {
        status: decision,
        reviewReason: reason,
        reviewedByUid: administratorUid,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, {
        accountVerified: decision === "approved",
        accountVerificationStatus: decision,
        accountVerificationRevision: revision,
        accountVerificationReviewVersion: 1,
        accountVerificationReviewedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(
          db.collection("verification_review_events")
              .doc(`${userUid}-${revision}-${decision}`),
          {
            userUid,
            revision,
            event: decision,
            status: decision,
            reason,
            actorUid: administratorUid,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.set(
          userRef.collection("notifications")
              .doc(`verification-${revision}-${decision}`),
          {
            recipientUid: userUid,
            type: "account_verification_reviewed",
            title: decision === "approved" ?
              "Account verification approved" :
              decision === "changes_requested" ?
                "Account verification needs changes" :
                "Account verification was not approved",
            message: reason,
            status: decision,
            revision,
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(receiptRef, {
        actorUid: administratorUid,
        command: "reviewAccountVerification",
        result: reviewed,
        createdAt: FieldValue.serverTimestamp(),
      });
      return reviewed;
    });
    return result;
  });

  return {reviewAccountVerification, submitAccountVerification};
}

module.exports = {createAccountVerificationCommands};
