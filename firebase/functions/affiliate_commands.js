"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function normalizeReferralCode(value) {
  const code = String(value || "").trim().toUpperCase();
  if (!/^PB[A-Z0-9]{10}$/.test(code)) {
    throw new HttpsError("invalid-argument", "The Pipe Buyer referral code is invalid.");
  }
  return code;
}

function referralCodeForUid(uid) {
  const digest = crypto.createHash("sha256").update(`pipe-buyer-affiliate|${uid}`)
      .digest("hex").slice(0, 10).toUpperCase();
  return `PB${digest}`;
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Affiliate command failed", error);
      throw new HttpsError("internal", "The affiliate action could not be completed.");
    }
  };
}

function createAffiliateCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const ensureAffiliateCode = command(async (request) => {
    const uid = requireAuth(request);
    await enforceUserRateLimit({db, admin, request, scope: "account"});
    const code = referralCodeForUid(uid);
    const profileRef = db.collection("affiliate_profiles").doc(uid);
    const codeRef = db.collection("affiliate_codes").doc(code);

    await db.runTransaction(async (transaction) => {
      const profileSnapshot = await transaction.get(profileRef);
      const codeSnapshot = await transaction.get(codeRef);
      if (profileSnapshot.exists) {
        const existingCode = String(profileSnapshot.data().code || "");
        if (existingCode && existingCode !== code) {
          throw new HttpsError(
              "failed-precondition",
              "This account already has a different referral code.",
          );
        }
      }
      if (codeSnapshot.exists && codeSnapshot.data().ownerUid !== uid) {
        throw new HttpsError(
            "already-exists",
            "The generated referral code is unexpectedly unavailable.",
        );
      }
      transaction.set(profileRef, {
        ownerUid: uid,
        code,
        active: true,
        commissionModel: "direct_one_level",
        marketplaceShareBps: 2000,
        subscriptionShareBps: 2000,
        updatedAt: FieldValue.serverTimestamp(),
        ...(profileSnapshot.exists ? {} : {
          createdAt: FieldValue.serverTimestamp(),
        }),
      }, {merge: true});
      transaction.set(codeRef, {
        ownerUid: uid,
        code,
        active: true,
        updatedAt: FieldValue.serverTimestamp(),
        ...(codeSnapshot.exists ? {} : {
          createdAt: FieldValue.serverTimestamp(),
        }),
      }, {merge: true});
    });

    return {code};
  });

  const claimAffiliateReferral = command(async (request) => {
    const uid = requireAuth(request);
    await enforceUserRateLimit({db, admin, request, scope: "account"});
    const code = normalizeReferralCode(request.data && request.data.code);
    const codeRef = db.collection("affiliate_codes").doc(code);
    const relationshipRef = db.collection("affiliate_relationships").doc(uid);

    return db.runTransaction(async (transaction) => {
      const codeSnapshot = await transaction.get(codeRef);
      const relationshipSnapshot = await transaction.get(relationshipRef);
      if (!codeSnapshot.exists || codeSnapshot.data().active !== true) {
        throw new HttpsError("not-found", "This referral code is not active.");
      }
      const referrerUid = String(codeSnapshot.data().ownerUid || "").trim();
      if (!referrerUid) {
        throw new HttpsError("failed-precondition", "This referral code has no owner.");
      }
      if (referrerUid === uid) {
        throw new HttpsError("failed-precondition", "An account cannot refer itself.");
      }
      if (relationshipSnapshot.exists) {
        const relationship = relationshipSnapshot.data();
        if (relationship.referrerUid === referrerUid) {
          return {
            referredUid: uid,
            referrerUid,
            code,
            alreadyClaimed: true,
          };
        }
        throw new HttpsError(
            "failed-precondition",
            "A referral relationship is already attached to this account.",
        );
      }
      transaction.create(relationshipRef, {
        referredUid: uid,
        referrerUid,
        code,
        model: "direct_one_level",
        appliesToFutureActivityOnly: true,
        claimedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(db.collection("affiliate_profiles").doc(referrerUid), {
        referredAccountCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        referredUid: uid,
        referrerUid,
        code,
        alreadyClaimed: false,
      };
    });
  });

  return {
    claimAffiliateReferral,
    ensureAffiliateCode,
  };
}

module.exports = {
  createAffiliateCommands,
  normalizeReferralCode,
  referralCodeForUid,
};
