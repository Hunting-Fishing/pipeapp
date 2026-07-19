"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {CommandPolicyError} = require("./marketplace_command_policy");
const {
  validateDispatchAward,
  validateDispatchQuote,
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

function requireAuth(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to continue.");
  }
  return uid;
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof CommandPolicyError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch command failed", error);
      throw new HttpsError(
          "internal",
          "The Dispatch action could not be completed.",
      );
    }
  };
}

function receiptReference(db, uid, commandName, requestId) {
  const digest = crypto.createHash("sha256")
      .update(`${uid}|${commandName}|${requestId}`)
      .digest("hex");
  return db.collection("marketplace_command_receipts").doc(digest);
}

function createDispatchCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  const submitDispatchQuote = command(async (request) => {
    const uid = requireAuth(request);
    const requestId = requiredId(request.data, "requestId");
    const jobId = requiredId(request.data, "jobId");
    const vehicleId = requiredId(request.data, "vehicleId");
    const receiptRef = receiptReference(
        db,
        uid,
        "submitDispatchQuote",
        requestId,
    );
    const jobRef = db.collection("dispatch_jobs").doc(jobId);
    const carrierRef = db.collection("dispatch_carriers").doc(uid);
    const vehicleRef = carrierRef.collection("vehicles").doc(vehicleId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const jobSnapshot = await transaction.get(jobRef);
      const carrierSnapshot = await transaction.get(carrierRef);
      const vehicleSnapshot = await transaction.get(vehicleRef);
      const quotes = await transaction.get(
          db.collection("dispatch_bids")
              .where("jobId", "==", jobId)
              .limit(200),
      );
      if (quotes.size >= 200) {
        throw new CommandPolicyError(
            "resource-exhausted",
            "This Dispatch job has reached its carrier quote limit.",
        );
      }
      const existingMatches = quotes.docs.filter(
          (candidate) =>
            candidate.data().carrierUid === uid &&
            candidate.data().status === "pending",
      );
      if (existingMatches.length > 1) {
        throw new CommandPolicyError(
            "failed-precondition",
            "Duplicate carrier quotes require administrator review.",
        );
      }
      const existingSnapshot = existingMatches[0] || null;
      const existingBid = existingSnapshot ? existingSnapshot.data() : null;
      const job = jobSnapshot.exists ? jobSnapshot.data() : null;
      const carrier =
        carrierSnapshot.exists ? carrierSnapshot.data() : null;
      const vehicle =
        vehicleSnapshot.exists ? vehicleSnapshot.data() : null;
      const now = Timestamp.now();
      const quote = validateDispatchQuote({
        job,
        carrier,
        vehicle,
        existingBid,
        actorUid: uid,
        data: {...request.data, jobId},
        now,
      });
      const bidRef = existingSnapshot ?
        existingSnapshot.ref :
        db.collection("dispatch_bids").doc(requestId);
      const revision = existingBid ?
        Number(existingBid.revision || 1) + 1 :
        1;
      const carrierName =
        String(carrier.operatingName || carrier.companyName ||
          "Dispatch carrier").slice(0, 160);
      const vehicleName =
        String(vehicle.name || vehicle.vehicleType ||
          "Fleet vehicle").slice(0, 160);
      const values = {
        jobId,
        carrierUid: uid,
        carrierName,
        amount: quote.amount,
        note: quote.note,
        availableDate: Timestamp.fromMillis(quote.availableDate),
        vehicleId,
        vehicleName,
        status: "pending",
        revision,
        updatedAt: FieldValue.serverTimestamp(),
        ...(existingBid ? {} : {
          createdAt: FieldValue.serverTimestamp(),
        }),
      };
      const result = {
        bidId: bidRef.id,
        jobId,
        revision,
        created: !existingBid,
      };

      if (existingBid) {
        transaction.update(bidRef, values);
      } else {
        transaction.create(bidRef, values);
        transaction.update(jobRef, {
          bidCount: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.create(
          bidRef.collection("revisions").doc(String(revision)),
          {
            ...values,
            event: existingBid ? "quote_updated" : "quote_submitted",
            actorUid: uid,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.set(
          db.collection("users")
              .doc(job.createdByUid)
              .collection("notifications")
              .doc(receiptRef.id),
          {
            recipientUid: job.createdByUid,
            actorUid: uid,
            type: "dispatch",
            jobId,
            bidId: bidRef.id,
            title: existingBid ?
              "Carrier quote revised" :
              "New carrier quote received",
            body: existingBid ?
              `${carrierName} updated their Dispatch quote.` :
              `${carrierName} quoted for ${String(job.title || "your job")}.`,
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(receiptRef, {
        actorUid: uid,
        command: "submitDispatchQuote",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });

  const awardDispatchQuote = command(async (request) => {
    const uid = requireAuth(request);
    const requestId = requiredId(request.data, "requestId");
    const jobId = requiredId(request.data, "jobId");
    const bidId = requiredId(request.data, "bidId");
    const receiptRef = receiptReference(
        db,
        uid,
        "awardDispatchQuote",
        requestId,
    );
    const jobRef = db.collection("dispatch_jobs").doc(jobId);
    const bidRef = db.collection("dispatch_bids").doc(bidId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const jobSnapshot = await transaction.get(jobRef);
      const bidSnapshot = await transaction.get(bidRef);
      const bids = await transaction.get(
          db.collection("dispatch_bids")
              .where("jobId", "==", jobId)
              .limit(200),
      );
      if (bids.size >= 200) {
        throw new CommandPolicyError(
            "resource-exhausted",
            "This Dispatch job has too many quotes for automatic award.",
        );
      }
      const jobData = jobSnapshot.exists ? jobSnapshot.data() : null;
      const job = jobData ? {...jobData, id: jobId} : null;
      const bid = bidSnapshot.exists ? bidSnapshot.data() : null;
      const awarded = validateDispatchAward(job, bid, uid);
      const revision = Number(job.revision || 1) + 1;
      const result = {
        jobId,
        bidId,
        carrierUid: awarded.carrierUid,
        amount: awarded.amount,
      };

      transaction.update(jobRef, {
        status: "awarded",
        awardedBidId: bidId,
        awardedCarrierUid: awarded.carrierUid,
        awardedAmount: awarded.amount,
        revision,
        awardedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(jobRef.collection("revisions").doc(String(revision)), {
        ...jobData,
        status: "awarded",
        awardedBidId: bidId,
        awardedCarrierUid: awarded.carrierUid,
        awardedAmount: awarded.amount,
        revision,
        event: "carrier_awarded",
        actorUid: uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      for (const candidate of bids.docs) {
        const candidateData = candidate.data();
        if (candidateData.status !== "pending") continue;
        const selected = candidate.id === bidId;
        const bidRevision = Number(candidateData.revision || 1) + 1;
        const status = selected ? "awarded" : "not_selected";
        transaction.update(candidate.ref, {
          status,
          revision: bidRevision,
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(
            candidate.ref.collection("revisions").doc(String(bidRevision)),
            {
              ...candidateData,
              status,
              revision: bidRevision,
              event: selected ? "quote_awarded" : "quote_archived",
              actorUid: uid,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
      }
      transaction.set(
          db.collection("users")
              .doc(awarded.carrierUid)
              .collection("notifications")
              .doc(receiptRef.id),
          {
            recipientUid: awarded.carrierUid,
            actorUid: uid,
            type: "dispatch",
            jobId,
            bidId,
            title: "Your carrier quote was accepted",
            body: "Open Dispatch to review the awarded job.",
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(receiptRef, {
        actorUid: uid,
        command: "awardDispatchQuote",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });

  return {awardDispatchQuote, submitDispatchQuote};
}

module.exports = {createDispatchCommands};
