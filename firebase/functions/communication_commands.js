"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  CommunicationPolicyError,
  downloadUrlMatchesStoragePath,
  validateMessageInput,
  validateReportInput,
  validateUploadAuthorization,
  validateUploadInput,
} = require("./communication_command_policy");

const REPORT_LABELS = Object.freeze({
  duplicate_listing: "Duplicate listing",
  reused_photos: "Photos reused from another listing",
  fraud_or_scam: "Fraud, scam, or impersonation",
  hate_or_racist_content: "Racist or hateful content",
  vulgar_or_harassing_content: "Vulgar, threatening, or harassing",
  misleading_information: "False or misleading information",
  prohibited_or_unsafe_item: "Prohibited or unsafe item",
  spam: "Spam or commercial abuse",
  other: "Something else",
});

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

function policyError(error) {
  if (error instanceof HttpsError) return error;
  if (error instanceof AccountSecurityError ||
      error instanceof CommunicationPolicyError) {
    return new HttpsError(error.code, error.message);
  }
  console.error("Communication command failed", error);
  return new HttpsError(
      "internal",
      "The communication action could not be completed.",
  );
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      throw policyError(error);
    }
  };
}

function conversationIdFor(firstUid, secondUid, listingId) {
  return `${[firstUid, secondUid].sort().join("_")}_${listingId}`;
}

function receiptReference(db, uid, commandName, requestId) {
  const digest = crypto.createHash("sha256")
      .update(`${uid}|${commandName}|${requestId}`)
      .digest("hex");
  return db.collection("communication_command_receipts").doc(digest);
}

function receiptData(uid, commandName, result, FieldValue) {
  return {
    actorUid: uid,
    command: commandName,
    result,
    createdAt: FieldValue.serverTimestamp(),
  };
}

function profileName(data, fallback) {
  return String(
      data.publicName || data.displayName || data.display_name || fallback,
  ).trim() || fallback;
}

function createCommunicationCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;
  const secured = (scope, handler) => command(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    await enforceUserRateLimit({db, admin, request, scope});
    return handler(request, identity);
  });

  const openMarketplaceConversation = secured(
      "messaging",
      async (request, {uid}) => {
        const listingId = requiredId(request.data, "listingId");
        const requestedParticipantUid = String(
            request.data && request.data.participantUid || "",
        ).trim();
        const offerId = String(request.data && request.data.offerId || "")
            .trim();
        const listingRef = db.collection("public_listings").doc(listingId);
        const listingSnapshot = await listingRef.get();
        if (!listingSnapshot.exists) {
          throw new HttpsError("not-found", "This listing is unavailable.");
        }
        const listing = listingSnapshot.data();
        const sellerUid = String(listing.sellerUid || "");
        if (!sellerUid) {
          throw new HttpsError(
              "failed-precondition",
              "This listing has no available seller.",
          );
        }
        const buyerUid = uid === sellerUid ? requestedParticipantUid : uid;
        if (!buyerUid || buyerUid === sellerUid) {
          throw new HttpsError(
              "permission-denied",
              uid === sellerUid ?
                "Select a valid buyer before opening a conversation." :
                "You cannot message your own listing.",
          );
        }
        const conversationId = conversationIdFor(
            buyerUid,
            sellerUid,
            listingId,
        );
        const conversationRef = db.collection("conversations")
            .doc(conversationId);
        const [businessProfile, personalProfile] = await Promise.all([
          db.collection("public_business_profiles").doc(buyerUid).get(),
          db.collection("public_seller_profiles").doc(buyerUid).get(),
        ]);
        const buyerDisplayName = profileName(
            businessProfile.exists ? businessProfile.data() :
              personalProfile.exists ? personalProfile.data() : {},
            "Marketplace buyer",
        );
        const result = await db.runTransaction(async (transaction) => {
          const conversationSnapshot = await transaction.get(conversationRef);
          let offerSnapshot = null;
          if (uid === sellerUid && !conversationSnapshot.exists) {
            if (!offerId) {
              throw new HttpsError(
                  "failed-precondition",
                  "A valid offer is required to open a new buyer conversation.",
              );
            }
            offerSnapshot = await transaction.get(
                db.collection("offers").doc(requiredId({offerId}, "offerId")),
            );
          }
          if (offerSnapshot && (!offerSnapshot.exists ||
              offerSnapshot.data().listingId !== listingId ||
              offerSnapshot.data().sellerUid !== sellerUid ||
              offerSnapshot.data().buyerUid !== buyerUid)) {
            throw new HttpsError(
                "permission-denied",
                "This offer does not belong to the listing participants.",
            );
          }
          if (!conversationSnapshot.exists) {
            transaction.create(conversationRef, {
              memberUids: [buyerUid, sellerUid].sort(),
              listingId,
              listingTitle: String(listing.title || "Marketplace listing"),
              sellerUid,
              sellerName: String(
                  listing.sellerName || "Marketplace seller",
              ),
              buyerDisplayName,
              openedByUid: uid,
              openedAt: FieldValue.serverTimestamp(),
              messageCount: 0,
              unreadCounts: {[buyerUid]: 0, [sellerUid]: 0},
            });
          }
          return {conversationId};
        });
        return result;
      },
  );

  const markMarketplaceConversationRead = secured(
      "messaging",
      async (request, {uid}) => {
        const conversationId = requiredId(request.data, "conversationId");
        const reference = db.collection("conversations").doc(conversationId);
        return db.runTransaction(async (transaction) => {
          const snapshot = await transaction.get(reference);
          if (!snapshot.exists) return {conversationId, changed: false};
          const conversation = snapshot.data();
          if (!Array.isArray(conversation.memberUids) ||
              !conversation.memberUids.includes(uid)) {
            throw new HttpsError(
                "permission-denied",
                "Only conversation members can mark messages as read.",
            );
          }
          const unreadCounts = {...conversation.unreadCounts || {}};
          const changed = Number(unreadCounts[uid] || 0) !== 0;
          if (changed) {
            unreadCounts[uid] = 0;
            transaction.update(reference, {unreadCounts});
          }
          return {conversationId, changed};
        });
      },
  );

  const authorizeMarketplaceUpload = secured(
      "media",
      async (request, {uid}) => {
        const authorizationId = requiredId(request.data, "requestId");
        const upload = validateUploadInput(request.data || {});
        let targetId;
        if (upload.purpose === "chat_attachment") {
          targetId = requiredId(upload, "conversationId");
          const conversation = await db.collection("conversations")
              .doc(targetId).get();
          if (!conversation.exists ||
              !Array.isArray(conversation.data().memberUids) ||
              !conversation.data().memberUids.includes(uid)) {
            throw new HttpsError(
                "permission-denied",
                "Only conversation members can attach files.",
            );
          }
        } else {
          targetId = requiredId(upload, "reportId");
        }
        const storagePath = upload.purpose === "chat_attachment" ?
          `chat_attachments/${targetId}/${uid}/${authorizationId}` :
          `report_evidence/${uid}/${targetId}/${authorizationId}`;
        const reference = db.collection("media_upload_authorizations")
            .doc(authorizationId);
        const expiresAt = Timestamp.fromMillis(Date.now() + 15 * 60 * 1000);
        const result = await db.runTransaction(async (transaction) => {
          const existing = await transaction.get(reference);
          if (existing.exists) {
            const current = existing.data();
            if (current.ownerUid !== uid || current.storagePath !== storagePath ||
                current.contentType !== upload.contentType ||
                current.sizeBytes !== upload.sizeBytes) {
              throw new HttpsError(
                  "already-exists",
                  "This upload request is already used for another file.",
              );
            }
            return {
              authorizationId,
              storagePath,
              expiresAtMillis: current.expiresAt.toMillis(),
            };
          }
          transaction.create(reference, {
            ownerUid: uid,
            purpose: upload.purpose,
            targetId,
            storagePath,
            contentType: upload.contentType,
            sizeBytes: upload.sizeBytes,
            originalName: upload.originalName,
            status: "authorized",
            expiresAt,
            createdAt: FieldValue.serverTimestamp(),
          });
          return {
            authorizationId,
            storagePath,
            expiresAtMillis: expiresAt.toMillis(),
          };
        });
        return result;
      },
  );

  const confirmMarketplaceUpload = secured(
      "media",
      async (request, {uid}) => {
        const authorizationId = requiredId(
            request.data,
            "authorizationId",
        );
        const url = String(request.data && request.data.url || "").trim();
        if (!url || url.length > 2048) {
          throw new HttpsError(
              "invalid-argument",
              "The uploaded file URL is invalid.",
          );
        }
        const reference = db.collection("media_upload_authorizations")
            .doc(authorizationId);
        return db.runTransaction(async (transaction) => {
          const snapshot = await transaction.get(reference);
          if (!snapshot.exists || snapshot.data().ownerUid !== uid) {
            throw new HttpsError(
                "permission-denied",
                "This upload authorization is unavailable.",
            );
          }
          const authorization = snapshot.data();
          if (!downloadUrlMatchesStoragePath(
              url,
              authorization.storagePath,
          )) {
            throw new HttpsError(
                "permission-denied",
                "The uploaded file URL does not match its authorized path.",
            );
          }
          if (authorization.expiresAt.toMillis() <= Date.now()) {
            throw new HttpsError(
                "failed-precondition",
                "The upload authorization expired. Attach the file again.",
            );
          }
          if (authorization.status === "consumed") {
            throw new HttpsError(
                "failed-precondition",
                "This upload has already been used.",
            );
          }
          if (authorization.status === "uploaded") {
            if (authorization.downloadUrl !== url) {
              throw new HttpsError(
                  "already-exists",
                  "This upload was confirmed with a different file URL.",
              );
            }
            return {authorizationId, storagePath: authorization.storagePath};
          }
          transaction.update(reference, {
            status: "uploaded",
            downloadUrl: url,
            uploadedAt: FieldValue.serverTimestamp(),
          });
          return {authorizationId, storagePath: authorization.storagePath};
        });
      },
  );

  const sendMarketplaceMessage = secured(
      "messaging",
      async (request, {uid}) => {
        const requestId = requiredId(request.data, "requestId");
        const conversationId = requiredId(request.data, "conversationId");
        const input = validateMessageInput(request.data || {});
        const receiptRef = receiptReference(
            db,
            uid,
            "sendMarketplaceMessage",
            requestId,
        );
        const conversationRef = db.collection("conversations")
            .doc(conversationId);
        const messageRef = conversationRef.collection("messages")
            .doc(requestId);
        return db.runTransaction(async (transaction) => {
          const receipt = await transaction.get(receiptRef);
          if (receipt.exists) return receipt.data().result;
          const conversationSnapshot = await transaction.get(conversationRef);
          if (!conversationSnapshot.exists) {
            throw new HttpsError("not-found", "This conversation is unavailable.");
          }
          const conversation = conversationSnapshot.data();
          const members = Array.isArray(conversation.memberUids) ?
            conversation.memberUids.map(String) : [];
          if (!members.includes(uid)) {
            throw new HttpsError(
                "permission-denied",
                "Only conversation members can send messages.",
            );
          }
          const recipientUid = members.find((memberUid) => memberUid !== uid);
          if (!recipientUid) {
            throw new HttpsError(
                "failed-precondition",
                "The conversation recipient is unavailable.",
            );
          }
          let attachment = null;
          let authorizationRef = null;
          if (input.attachment) {
            const authorizationId = requiredId(
                input.attachment,
                "authorizationId",
            );
            authorizationRef = db.collection("media_upload_authorizations")
                .doc(authorizationId);
            const authorizationSnapshot = await transaction.get(
                authorizationRef,
            );
            const authorization = authorizationSnapshot.exists ?
              authorizationSnapshot.data() : null;
            validateUploadAuthorization(authorization, {
              uid,
              purpose: "chat_attachment",
              targetId: conversationId,
              nowMillis: Date.now(),
            });
            if (authorization.downloadUrl !== input.attachment.url) {
              throw new HttpsError(
                  "permission-denied",
                  "The attached file does not match its upload authorization.",
              );
            }
            attachment = {
              type: authorization.contentType.startsWith("image/") ?
                "image" : "document",
              url: authorization.downloadUrl,
              name: input.attachment.name || authorization.originalName,
              storagePath: authorization.storagePath,
              contentType: authorization.contentType,
            };
          }
          const result = {conversationId, messageId: requestId};
          transaction.create(messageRef, {
            senderUid: uid,
            text: input.text,
            ...(attachment ? {attachment} : {}),
            createdAt: FieldValue.serverTimestamp(),
          });
          transaction.update(conversationRef, {
            lastMessage: input.text || "Attachment",
            lastMessageAt: FieldValue.serverTimestamp(),
            messageCount: FieldValue.increment(1),
            [`unreadCounts.${recipientUid}`]: FieldValue.increment(1),
            [`unreadCounts.${uid}`]: 0,
          });
          transaction.create(
              db.collection("users").doc(recipientUid)
                  .collection("notifications").doc(requestId),
              {
                recipientUid,
                actorUid: uid,
                type: "message",
                listingId: conversation.listingId || null,
                conversationId,
                title: "New marketplace message",
                read: false,
                createdAt: FieldValue.serverTimestamp(),
              },
          );
          if (authorizationRef) {
            transaction.update(authorizationRef, {
              status: "consumed",
              consumedBy: "message",
              consumedAt: FieldValue.serverTimestamp(),
            });
          }
          transaction.create(
              receiptRef,
              receiptData(uid, "sendMarketplaceMessage", result, FieldValue),
          );
          return result;
        });
      },
  );

  const submitMarketplaceReport = secured(
      "reporting",
      async (request, {uid}) => {
        const reportId = requiredId(request.data, "requestId");
        const input = validateReportInput(request.data || {});
        if (input.reportedUid === uid) {
          throw new HttpsError(
              "invalid-argument",
              "You cannot report your own account.",
          );
        }
        const reportRef = db.collection("trust_reports").doc(reportId);
        const receiptRef = receiptReference(
            db,
            uid,
            "submitMarketplaceReport",
            reportId,
        );
        return db.runTransaction(async (transaction) => {
          const receipt = await transaction.get(receiptRef);
          if (receipt.exists) return receipt.data().result;
          let targetSnapshot;
          if (input.targetType === "listing") {
            targetSnapshot = await transaction.get(
                db.collection("public_listings")
                    .doc(requiredId(input, "listingId")),
            );
            if (!targetSnapshot.exists ||
                targetSnapshot.data().sellerUid !== input.reportedUid) {
              throw new HttpsError(
                  "permission-denied",
                  "The reported listing does not match this account.",
              );
            }
          } else if (input.targetType === "message") {
            targetSnapshot = await transaction.get(
                db.collection("conversations")
                    .doc(requiredId(input, "conversationId")),
            );
            const members = targetSnapshot.exists &&
                Array.isArray(targetSnapshot.data().memberUids) ?
              targetSnapshot.data().memberUids.map(String) : [];
            if (!members.includes(uid) || !members.includes(input.reportedUid)) {
              throw new HttpsError(
                  "permission-denied",
                  "Only conversation members can report this conversation.",
              );
            }
            if (input.messageId) {
              const messageSnapshot = await transaction.get(
                  db.collection("conversations")
                      .doc(input.conversationId)
                      .collection("messages")
                      .doc(requiredId(input, "messageId")),
              );
              if (!messageSnapshot.exists ||
                  messageSnapshot.data().senderUid !== input.reportedUid) {
                throw new HttpsError(
                    "permission-denied",
                    "The reported message does not match this account.",
                );
              }
            }
          } else if (input.targetType === "offer") {
            targetSnapshot = await transaction.get(
                db.collection("offers").doc(requiredId(input, "offerId")),
            );
            const offer = targetSnapshot.exists ? targetSnapshot.data() : {};
            const participants = [offer.buyerUid, offer.sellerUid].map(String);
            if (!participants.includes(uid) ||
                !participants.includes(input.reportedUid)) {
              throw new HttpsError(
                  "permission-denied",
                  "Only offer participants can report this offer.",
              );
            }
          } else {
            targetSnapshot = await transaction.get(
                db.collection("users").doc(input.reportedUid),
            );
            if (!targetSnapshot.exists) {
              throw new HttpsError(
                  "not-found",
                  "The reported account is unavailable.",
              );
            }
          }
          const evidence = [];
          const authorizationReferences = [];
          for (const submitted of input.attachments) {
            const authorizationId = requiredId(
                submitted,
                "authorizationId",
            );
            const authorizationRef = db
                .collection("media_upload_authorizations")
                .doc(authorizationId);
            const authorizationSnapshot = await transaction.get(
                authorizationRef,
            );
            const authorization = authorizationSnapshot.exists ?
              authorizationSnapshot.data() : null;
            validateUploadAuthorization(authorization, {
              uid,
              purpose: "report_evidence",
              targetId: reportId,
              nowMillis: Date.now(),
            });
            if (authorization.downloadUrl !== submitted.url) {
              throw new HttpsError(
                  "permission-denied",
                  "Report evidence does not match its upload authorization.",
              );
            }
            evidence.push({
              type: "image",
              url: authorization.downloadUrl,
              name: submitted.name || authorization.originalName,
              storagePath: authorization.storagePath,
              contentType: authorization.contentType,
            });
            authorizationReferences.push(authorizationRef);
          }
          const result = {reportId, status: "pending"};
          transaction.create(reportRef, {
            reporterUid: uid,
            reportedUid: input.reportedUid,
            targetType: input.targetType,
            ...(input.listingId ? {listingId: input.listingId} : {}),
            ...(input.conversationId ?
              {conversationId: input.conversationId} : {}),
            ...(input.messageId ? {messageId: input.messageId} : {}),
            ...(input.offerId ? {offerId: input.offerId} : {}),
            reason: input.reason,
            reasonLabel: REPORT_LABELS[input.reason],
            details: input.details,
            attachments: evidence,
            attachmentCount: evidence.length,
            source: "user",
            status: "pending",
            priority: [
              "fraud_or_scam",
              "hate_or_racist_content",
            ].includes(input.reason) ? "high" : "normal",
            createdAt: FieldValue.serverTimestamp(),
          });
          for (const reference of authorizationReferences) {
            transaction.update(reference, {
              status: "consumed",
              consumedBy: "report",
              consumedAt: FieldValue.serverTimestamp(),
            });
          }
          transaction.create(
              receiptRef,
              receiptData(
                  uid,
                  "submitMarketplaceReport",
                  result,
                  FieldValue,
              ),
          );
          return result;
        });
      },
  );

  return {
    authorizeMarketplaceUpload,
    confirmMarketplaceUpload,
    markMarketplaceConversationRead,
    openMarketplaceConversation,
    sendMarketplaceMessage,
    submitMarketplaceReport,
  };
}

async function cleanupExpiredMediaUploadAuthorizations(
    admin,
    batchLimit = 500,
) {
  const db = admin.firestore();
  const expired = await db.collection("media_upload_authorizations")
      .where("expiresAt", "<=", admin.firestore.Timestamp.now())
      .limit(batchLimit)
      .get();
  if (expired.empty) return 0;
  const batch = db.batch();
  for (const document of expired.docs) batch.delete(document.ref);
  await batch.commit();
  return expired.size;
}

module.exports = {
  cleanupExpiredMediaUploadAuthorizations,
  conversationIdFor,
  createCommunicationCommands,
};
