"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");

function blockDocumentId(blockerUid, blockedUid) {
  return crypto.createHash("sha256")
      .update(`${blockerUid}|${blockedUid}`)
      .digest("hex");
}

function normalizeConversationMembers(conversation) {
  return Array.isArray(conversation && conversation.memberUids) ?
    conversation.memberUids.map(String).filter(Boolean) : [];
}

function mapError(error) {
  if (error instanceof HttpsError) return error;
  if (error instanceof AccountSecurityError) {
    return new HttpsError(error.code, error.message);
  }
  console.error("Marketplace user block command failed", error);
  return new HttpsError("internal", "The safety setting could not be updated.");
}

function createMarketplaceUserBlockCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function conversationPair(conversationId, uid) {
    const normalized = String(conversationId || "").trim();
    if (!normalized || normalized.length > 180 || normalized.includes("/")) {
      throw new HttpsError("invalid-argument", "Conversation is missing or invalid.");
    }
    const snapshot = await db.collection("conversations").doc(normalized).get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "This conversation is unavailable.");
    }
    const members = normalizeConversationMembers(snapshot.data());
    if (!members.includes(uid)) {
      throw new HttpsError(
          "permission-denied",
          "Only conversation members can change this safety setting.",
      );
    }
    const otherUid = members.find((memberUid) => memberUid !== uid);
    if (!otherUid) {
      throw new HttpsError(
          "failed-precondition",
          "The other conversation member is unavailable.",
      );
    }
    return {conversationId: normalized, viewerUid: uid, otherUid};
  }

  async function statusFor(viewerUid, otherUid) {
    const viewerBlockRef = db.collection("marketplace_user_blocks")
        .doc(blockDocumentId(viewerUid, otherUid));
    const otherBlockRef = db.collection("marketplace_user_blocks")
        .doc(blockDocumentId(otherUid, viewerUid));
    const [viewerBlock, otherBlock] = await Promise.all([
      viewerBlockRef.get(),
      otherBlockRef.get(),
    ]);
    const blockedByViewer = viewerBlock.exists && viewerBlock.data().active === true;
    const blockedViewer = otherBlock.exists && otherBlock.data().active === true;
    return {
      blocked: blockedByViewer || blockedViewer,
      blockedByViewer,
      blockedViewer,
    };
  }

  const readMarketplaceUserBlockStatus = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request);
      await enforceUserRateLimit({
        db,
        admin,
        request,
        scope: "messaging",
      });
      const pair = await conversationPair(
          request.data && request.data.conversationId,
          identity.uid,
      );
      return {
        conversationId: pair.conversationId,
        otherUid: pair.otherUid,
        ...await statusFor(pair.viewerUid, pair.otherUid),
      };
    } catch (error) {
      throw mapError(error);
    }
  };

  const setMarketplaceUserBlocked = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request);
      await enforceUserRateLimit({
        db,
        admin,
        request,
        scope: "messaging",
      });
      const pair = await conversationPair(
          request.data && request.data.conversationId,
          identity.uid,
      );
      const blocked = request.data && request.data.blocked;
      if (typeof blocked !== "boolean") {
        throw new HttpsError("invalid-argument", "Blocked must be true or false.");
      }
      const reference = db.collection("marketplace_user_blocks")
          .doc(blockDocumentId(pair.viewerUid, pair.otherUid));
      await reference.set({
        blockerUid: pair.viewerUid,
        blockedUid: pair.otherUid,
        active: blocked,
        conversationId: pair.conversationId,
        updatedAt: FieldValue.serverTimestamp(),
        ...(blocked ? {blockedAt: FieldValue.serverTimestamp()} :
          {unblockedAt: FieldValue.serverTimestamp()}),
      }, {merge: true});
      return {
        conversationId: pair.conversationId,
        otherUid: pair.otherUid,
        ...await statusFor(pair.viewerUid, pair.otherUid),
      };
    } catch (error) {
      throw mapError(error);
    }
  };

  async function requireConversationMessagingAllowed(request) {
    const identity = requireAuthenticatedIdentity(request);
    const pair = await conversationPair(
        request.data && request.data.conversationId,
        identity.uid,
    );
    const status = await statusFor(pair.viewerUid, pair.otherUid);
    if (status.blocked) {
      throw new HttpsError(
          "permission-denied",
          status.blockedByViewer ?
            "Unblock this member before sending another message." :
            "Messaging is unavailable because this member blocked the conversation.",
      );
    }
    return pair;
  }

  return {
    readMarketplaceUserBlockStatus,
    setMarketplaceUserBlocked,
    requireConversationMessagingAllowed,
    blockDocumentId,
  };
}

module.exports = {
  blockDocumentId,
  createMarketplaceUserBlockCommands,
  normalizeConversationMembers,
};
