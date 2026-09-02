"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {CommandPolicyError} = require("./marketplace_command_policy");
const {
  FeatureFlagError,
  loadPhase1FeatureFlags,
  requirePhase1Feature,
} = require("./phase1_feature_flags");
const {
  validateDispatchRequestCancellation,
} = require("./dispatch_request_cancellation_policy");

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

function receiptReference(db, uid, commandName, requestId) {
  const digest = crypto.createHash("sha256")
      .update(`${uid}|${commandName}|${requestId}`)
      .digest("hex");
  return db.collection("marketplace_command_receipts").doc(digest);
}

function translateCommandError(error) {
  if (error instanceof HttpsError) return error;
  if (
    error instanceof AccountSecurityError ||
    error instanceof CommandPolicyError ||
    error instanceof FeatureFlagError
  ) {
    return new HttpsError(error.code, error.message);
  }
  console.error("Dispatch request lifecycle command failed", error);
  return new HttpsError(
      "internal",
      "The Dispatch request action could not be completed.",
  );
}

function createDispatchRequestLifecycleCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const cancelDispatchJob = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request);
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "dispatch");
      await enforceUserRateLimit({db, admin, request, scope: "dispatch"});

      const uid = identity.uid;
      const requestId = requiredId(request.data, "requestId");
      const jobId = requiredId(request.data, "jobId");
      const jobRef = db.collection("dispatch_jobs").doc(jobId);
      const privateJobRef = db.collection("dispatch_job_private").doc(jobId);
      const receiptRef = receiptReference(
          db,
          uid,
          "cancelDispatchJob",
          requestId,
      );

      return await db.runTransaction(async (transaction) => {
        const receipt = await transaction.get(receiptRef);
        if (receipt.exists) return receipt.data().result;

        const jobSnapshot = await transaction.get(jobRef);
        const job = jobSnapshot.exists ? jobSnapshot.data() : null;
        const cancellation = validateDispatchRequestCancellation(
            job,
            uid,
            request.data && request.data.reason,
        );

        if (cancellation.alreadyApplied) {
          const result = {
            jobId,
            revision: Number(job.revision || 1),
            status: "cancelled",
            alreadyApplied: true,
          };
          transaction.create(receiptRef, {
            actorUid: uid,
            command: "cancelDispatchJob",
            result,
            createdAt: FieldValue.serverTimestamp(),
          });
          return result;
        }

        const bids = await transaction.get(
            db.collection("dispatch_bids")
                .where("jobId", "==", jobId)
                .limit(200),
        );
        if (bids.size >= 200) {
          throw new CommandPolicyError(
              "resource-exhausted",
              "This Dispatch request has too many quotes for automatic cancellation.",
          );
        }

        const revision = Number(job.revision || 1) + 1;
        const result = {
          jobId,
          revision,
          status: "cancelled",
          alreadyApplied: false,
        };
        const publicChanges = {
          status: "cancelled",
          dispatchRequestStatus: "cancelled",
          revision,
          cancelledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };
        const privateChanges = {
          revision,
          cancellationReason: cancellation.reason,
          cancelledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };

        transaction.update(jobRef, publicChanges);
        transaction.set(privateJobRef, privateChanges, {merge: true});
        transaction.create(
            jobRef.collection("revisions").doc(String(revision)),
            {
              ...job,
              ...publicChanges,
              event: "request_cancelled",
              actorUid: uid,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
        transaction.set(
            privateJobRef.collection("revisions").doc(String(revision)),
            {
              ...privateChanges,
              event: "request_cancelled",
              actorUid: uid,
              createdAt: FieldValue.serverTimestamp(),
            },
        );

        for (const bid of bids.docs) {
          const bidData = bid.data();
          if (bidData.status !== "pending") continue;
          const bidRevision = Number(bidData.revision || 1) + 1;
          transaction.update(bid.ref, {
            status: "request_cancelled",
            validityStatus: "inactive",
            revision: bidRevision,
            updatedAt: FieldValue.serverTimestamp(),
          });
          transaction.create(
              bid.ref.collection("revisions").doc(String(bidRevision)),
              {
                ...bidData,
                status: "request_cancelled",
                validityStatus: "inactive",
                revision: bidRevision,
                event: "request_cancelled",
                actorUid: uid,
                createdAt: FieldValue.serverTimestamp(),
              },
          );
          const carrierUid = String(bidData.carrierUid || "").trim();
          if (carrierUid && carrierUid !== uid) {
            transaction.set(
                db.collection("users")
                    .doc(carrierUid)
                    .collection("notifications")
                    .doc(`${receiptRef.id}_${carrierUid}`),
                {
                  recipientUid: carrierUid,
                  actorUid: uid,
                  type: "dispatch",
                  jobId,
                  bidId: bid.id,
                  title: "Dispatch request cancelled",
                  body: "The customer cancelled this request before award.",
                  read: false,
                  createdAt: FieldValue.serverTimestamp(),
                },
            );
          }
        }

        transaction.create(receiptRef, {
          actorUid: uid,
          command: "cancelDispatchJob",
          result,
          createdAt: FieldValue.serverTimestamp(),
        });
        return result;
      });
    } catch (error) {
      throw translateCommandError(error);
    }
  };

  return {cancelDispatchJob};
}

module.exports = {createDispatchRequestLifecycleCommands};
