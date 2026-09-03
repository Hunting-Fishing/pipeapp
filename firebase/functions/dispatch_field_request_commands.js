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
  rejectClientRouteFields,
  validateDispatchJobInput,
} = require("./dispatch_command_policy");

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

function pointValue(admin, point) {
  return point ?
    new admin.firestore.GeoPoint(point.latitude, point.longitude) :
    null;
}

function boundedPrivateText(value, label, maximum) {
  const text = String(value || "").trim();
  if (text.length > maximum) {
    throw new CommandPolicyError(
        "invalid-argument",
        `${label} is too long.`,
    );
  }
  return text;
}

function translateCommandError(error) {
  if (error instanceof HttpsError) return error;
  if (error instanceof AccountSecurityError ||
      error instanceof CommandPolicyError ||
      error instanceof FeatureFlagError) {
    return new HttpsError(error.code, error.message);
  }
  console.error("Dispatch field request command failed", error);
  return new HttpsError(
      "internal",
      "The field-service request could not be completed.",
  );
}

function fieldPrivateLocation(data) {
  return {
    workSiteAddress: boundedPrivateText(
        data && data.workSiteAddress,
        "Work-site address",
        500,
    ),
    workSiteNearestTown: boundedPrivateText(
        data && data.workSiteNearestTown,
        "Work-site nearest town",
        160,
    ),
    workSiteRegion: boundedPrivateText(
        data && data.workSiteRegion,
        "Work-site region",
        160,
    ),
    workSitePostalCode: boundedPrivateText(
        data && data.workSitePostalCode,
        "Work-site postal code",
        40,
    ),
    workSiteCountry: boundedPrivateText(
        data && data.workSiteCountry,
        "Work-site country",
        100,
    ),
    workSiteAccessNotes: boundedPrivateText(
        data && data.workSiteAccessNotes,
        "Work-site access notes",
        1500,
    ),
  };
}

function createDispatchFieldRequestCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  async function secured(request, handler) {
    const identity = requireAuthenticatedIdentity(request);
    const flags = await loadPhase1FeatureFlags(db);
    requirePhase1Feature(flags, "dispatch");
    await enforceUserRateLimit({db, admin, request, scope: "dispatch"});
    return handler(identity);
  }

  async function createFieldServiceRequest(request, metadata) {
    try {
      return await secured(request, async ({uid}) => {
        if (!metadata || metadata.requestPath !== "field_service" ||
            metadata.routeRelevant !== false) {
          throw new CommandPolicyError(
              "invalid-argument",
              "The field-service request metadata is invalid.",
          );
        }
        rejectClientRouteFields(request.data);
        const requestId = requiredId(request.data, "requestId");
        const jobId = requiredId(request.data, "jobId");
        const now = Timestamp.now();
        const input = validateDispatchJobInput(request.data, now);
        if (input.listingId) {
          throw new CommandPolicyError(
              "failed-precondition",
              "Field-service requests must be created from Request Service or a provider conversation.",
          );
        }
        const privateLocation = fieldPrivateLocation(request.data);
        const jobRef = db.collection("dispatch_jobs").doc(jobId);
        const privateRef = db.collection("dispatch_job_private").doc(jobId);
        const receiptRef = receiptReference(
            db,
            uid,
            "createDispatchJob",
            requestId,
        );

        return db.runTransaction(async (transaction) => {
          const receipt = await transaction.get(receiptRef);
          if (receipt.exists) return receipt.data().result;

          const publicValues = {
            createdByUid: uid,
            title: input.title,
            pickupLabel: input.pickupLabel,
            deliveryLabel: "",
            truckingDate: Timestamp.fromMillis(input.truckingDate),
            loadDetails: input.loadDetails,
            listingId: null,
            offerId: null,
            sourceType: input.sourceType,
            estimatedWeightKg: input.estimatedWeightKg,
            catalogWeightKg: input.catalogWeightKg,
            weightSource: input.weightSource,
            locationPrivacyVersion: 2,
            requestSchemaVersion: metadata.requestSchemaVersion,
            requestPath: "field_service",
            routeRelevant: false,
            serviceCodes: metadata.serviceCodes,
            status: "draft",
            dispatchRequestStatus: "service_request_received",
            bidCount: 0,
            revision: 1,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          };
          const privateValues = {
            createdByUid: uid,
            ...(input.pickupPoint ? {
              pickupPoint: pointValue(admin, input.pickupPoint),
            } : {}),
            ...privateLocation,
            requestSchemaVersion: metadata.requestSchemaVersion,
            contactPreference: metadata.contactPreference,
            revision: 1,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          };
          const result = {
            jobId,
            revision: 1,
            status: "draft",
            dispatchRequestStatus: "service_request_received",
          };

          transaction.create(jobRef, publicValues);
          transaction.create(privateRef, privateValues);
          transaction.create(jobRef.collection("revisions").doc("1"), {
            ...publicValues,
            event: "service_request_received",
            actorUid: uid,
          });
          transaction.create(privateRef.collection("revisions").doc("1"), {
            ...privateValues,
            event: "service_request_received",
            actorUid: uid,
          });
          transaction.create(receiptRef, {
            actorUid: uid,
            command: "createDispatchJob",
            result,
            createdAt: FieldValue.serverTimestamp(),
          });
          return result;
        });
      });
    } catch (error) {
      throw translateCommandError(error);
    }
  }

  async function updateFieldServiceRequest(request) {
    try {
      return await secured(request, async ({uid}) => {
        const requestId = requiredId(request.data, "requestId");
        const jobId = requiredId(request.data, "jobId");
        const jobRef = db.collection("dispatch_jobs").doc(jobId);
        const privateRef = db.collection("dispatch_job_private").doc(jobId);
        const receiptRef = receiptReference(
            db,
            uid,
            "updateDispatchFieldRequest",
            requestId,
        );

        return db.runTransaction(async (transaction) => {
          const [receipt, jobSnapshot, privateSnapshot] = await Promise.all([
            transaction.get(receiptRef),
            transaction.get(jobRef),
            transaction.get(privateRef),
          ]);
          if (receipt.exists) return receipt.data().result;
          if (!jobSnapshot.exists || !privateSnapshot.exists) {
            throw new CommandPolicyError(
                "not-found",
                "This field-service request is unavailable.",
            );
          }
          const job = jobSnapshot.data() || {};
          const privateJob = privateSnapshot.data() || {};
          if (job.createdByUid !== uid || privateJob.createdByUid !== uid) {
            throw new CommandPolicyError(
                "permission-denied",
                "Only the request owner can edit this field-service request.",
            );
          }
          if (job.requestPath !== "field_service" || job.status !== "draft") {
            throw new CommandPolicyError(
                "failed-precondition",
                "This field-service request is no longer editable here.",
            );
          }

          const compatibilityInput = validateDispatchJobInput({
            ...job,
            ...request.data,
            pickupLabel: job.pickupLabel,
            deliveryLabel: job.pickupLabel,
            truckingDate: request.data.truckingDate,
            loadDetails: request.data.loadDetails,
          }, Timestamp.now());
          const revision = Number(job.revision || 1) + 1;
          const publicChanges = {
            title: compatibilityInput.title,
            truckingDate: Timestamp.fromMillis(compatibilityInput.truckingDate),
            loadDetails: compatibilityInput.loadDetails,
            revision,
            updatedAt: FieldValue.serverTimestamp(),
          };
          const privateChanges = {
            revision,
            updatedAt: FieldValue.serverTimestamp(),
          };
          const result = {
            jobId,
            revision,
            status: "draft",
            dispatchRequestStatus: "service_request_received",
          };

          transaction.update(jobRef, publicChanges);
          transaction.set(privateRef, privateChanges, {merge: true});
          transaction.create(
              jobRef.collection("revisions").doc(String(revision)),
              {
                ...job,
                ...publicChanges,
                event: "service_request_updated",
                actorUid: uid,
                createdAt: FieldValue.serverTimestamp(),
              },
          );
          transaction.set(
              privateRef.collection("revisions").doc(String(revision)),
              {
                ...privateJob,
                ...privateChanges,
                event: "service_request_updated",
                actorUid: uid,
                createdAt: FieldValue.serverTimestamp(),
              },
          );
          transaction.create(receiptRef, {
            actorUid: uid,
            command: "updateDispatchFieldRequest",
            result,
            createdAt: FieldValue.serverTimestamp(),
          });
          return result;
        });
      });
    } catch (error) {
      throw translateCommandError(error);
    }
  }

  return {
    createFieldServiceRequest,
    updateFieldServiceRequest,
  };
}

module.exports = {
  createDispatchFieldRequestCommands,
  fieldPrivateLocation,
};
