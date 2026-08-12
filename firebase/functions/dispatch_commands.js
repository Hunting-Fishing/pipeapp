"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  AdministratorAuthorizationError,
  isAdministrator,
  requireAdministrator,
} = require("./administrator_authorization");
const {CommandPolicyError} = require("./marketplace_command_policy");
const {
  FeatureFlagError,
  loadPhase1FeatureFlags,
  requirePhase1Feature,
} = require("./phase1_feature_flags");
const {
  rejectClientRouteFields,
  validateDispatchAward,
  validateDispatchJobChange,
  validateDispatchJobInput,
  validateDispatchJobPublish,
  validateDispatchQuote,
  validateDispatchProviderApplication,
  validateDispatchProviderDecision,
  validateDispatchTransactionAction,
} = require("./dispatch_command_policy");
const {
  buildDispatchRouteState,
} = require("./dispatch_routing_policy");

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
  return requireAuthenticatedIdentity(request).uid;
}

function nonEmpty(value) {
  return String(value || "").trim().length > 0;
}

function dispatchSignupCompletion({identity, user, seller, business, privateBusiness}) {
  const accountType = user && user.accountType === "business" ?
    "business" : "personal";
  const fields = accountType === "business" ? [
    business && business.publicName,
    privateBusiness && privateBusiness.legalName,
    business && business.publicPhone,
    business && business.publicEmail,
    business && business.website,
    business && (business.serviceArea || business.serviceAreaLabel),
    privateBusiness && privateBusiness.privateAddress,
    business && business.description,
  ] : [
    user && (user.display_name || seller && seller.displayName),
    user && (user.verifiedPhoneE164 || user.pendingPhoneE164 ||
      user.phone_number) || identity.phoneNumber,
    user && (user.primaryCommunityLocation || user.baseCommunity) ||
      seller && seller.baseCommunity,
    user && user.sellerBio || seller && seller.description,
  ];
  const completed = fields.filter((value) => {
    if (value && typeof value === "object") return true;
    return nonEmpty(value);
  }).length;
  return Math.round(completed / fields.length * 100);
}

async function requireActiveDispatchAccount(db, uid) {
  const snapshot = await db.collection("dispatch_carriers").doc(uid).get();
  if (!snapshot.exists || snapshot.data().status !== "active") {
    throw new HttpsError(
        "failed-precondition",
        "Join Dispatch before viewing or posting Dispatch opportunities.",
    );
  }
  return snapshot.data();
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (
        error instanceof AccountSecurityError ||
        error instanceof AdministratorAuthorizationError ||
        error instanceof CommandPolicyError
      ) {
        throw new HttpsError(error.code, error.message);
      }
      if (error instanceof FeatureFlagError) {
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

function pointValue(admin, point) {
  return point ?
    new admin.firestore.GeoPoint(point.latitude, point.longitude) :
    null;
}

function createJobValues(admin, input, uid) {
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;
  const routeState = buildDispatchRouteState(
      input.pickupPoint,
      input.deliveryPoint,
      {providerConfigured: false},
  );
  return {
    createdByUid: uid,
    title: input.title,
    pickupLabel: input.pickupLabel,
    deliveryLabel: input.deliveryLabel,
    truckingDate: Timestamp.fromMillis(input.truckingDate),
    loadDetails: input.loadDetails,
    listingId: input.listingId,
    offerId: null,
    sourceType: input.sourceType,
    estimatedWeightKg: input.estimatedWeightKg,
    catalogWeightKg: input.catalogWeightKg,
    weightSource: input.weightSource,
    ...routeState,
    ...(input.deliveryNearestTown ? {
      deliveryNearestTown: input.deliveryNearestTown,
    } : {}),
    ...(input.deliveryRegion ? {
      deliveryRegion: input.deliveryRegion,
    } : {}),
    ...(input.deliveryCountry ? {
      deliveryCountry: input.deliveryCountry,
    } : {}),
    locationPrivacyVersion: 1,
    status: "open",
    dispatchRequestStatus: "accepting_carrier_bids",
    bidCount: 0,
    revision: 1,
    publishedAt: FieldValue.serverTimestamp(),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

function createJobPrivateValues(admin, input, uid) {
  const FieldValue = admin.firestore.FieldValue;
  return {
    createdByUid: uid,
    ...(input.pickupPoint ? {
      pickupPoint: pointValue(admin, input.pickupPoint),
    } : {}),
    ...(input.deliveryPoint ? {
      deliveryPoint: pointValue(admin, input.deliveryPoint),
    } : {}),
    ...(input.deliveryAddress ? {
      deliveryAddress: input.deliveryAddress,
    } : {}),
    ...(input.deliveryPostalCode ? {
      deliveryPostalCode: input.deliveryPostalCode,
    } : {}),
    ...(input.deliveryAccessNotes ? {
      deliveryAccessNotes: input.deliveryAccessNotes,
    } : {}),
    locationPrivacyVersion: 1,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

function createDispatchCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;
  const dispatchCommand = (handler) => command(async (request) => {
    const flags = await loadPhase1FeatureFlags(db);
    requirePhase1Feature(flags, "dispatch");
    await enforceUserRateLimit({db, admin, request, scope: "dispatch"});
    return handler(request);
  });

  const providerServiceAreaValue = (serviceArea) => ({
    ...serviceArea,
    center: pointValue(admin, serviceArea.center),
    places: serviceArea.places.map((place) => ({
      ...place,
      ...(place.point ? {point: pointValue(admin, place.point)} : {}),
    })),
  });

  const submitDispatchProviderApplication = dispatchCommand(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    const requestId = requiredId(request.data, "requestId");
    const profile = validateDispatchProviderApplication(request.data, identity);
    const [userSnapshot, sellerSnapshot, businessSnapshot, privateBusinessSnapshot] =
      await Promise.all([
        db.collection("users").doc(identity.uid).get(),
        db.collection("public_seller_profiles").doc(identity.uid).get(),
        db.collection("public_business_profiles").doc(identity.uid).get(),
        db.collection("business_private").doc(identity.uid).get(),
      ]);
    const completion = dispatchSignupCompletion({
      identity,
      user: userSnapshot.exists ? userSnapshot.data() : {},
      seller: sellerSnapshot.exists ? sellerSnapshot.data() : {},
      business: businessSnapshot.exists ? businessSnapshot.data() : {},
      privateBusiness: privateBusinessSnapshot.exists ? privateBusinessSnapshot.data() : {},
    });
    if (completion < 70) {
      throw new HttpsError(
          "failed-precondition",
          `Complete at least 70% of your Pipe Buyer profile before joining Dispatch. Current completion: ${completion}%.`,
      );
    }
    const carrierRef = db.collection("dispatch_carriers").doc(identity.uid);
    const receiptRef = receiptReference(
        db, identity.uid, "submitDispatchProviderApplication", requestId,
    );
    return db.runTransaction(async (transaction) => {
      const [receipt, carrierSnapshot] = await Promise.all([
        transaction.get(receiptRef),
        transaction.get(carrierRef),
      ]);
      if (receipt.exists) return receipt.data().result;
      const current = carrierSnapshot.exists ? carrierSnapshot.data() : {};
      const revision = Number(current.signupRevision || current.reviewRevision || 0) + 1;
      const result = {
        providerUid: identity.uid,
        status: "active",
        revision,
        submitted: true,
        profileCompletion: completion,
      };
      const verifiedContactMethod = identity.email && identity.phoneNumber ?
        "email_and_phone" : identity.email ? "email" : "phone";
      transaction.set(carrierRef, {
        ownerUid: identity.uid,
        ...profile,
        serviceArea: providerServiceAreaValue(profile.serviceArea),
        phone: profile.phoneE164,
        status: "active",
        availableForHire: true,
        signupVersion: 2,
        signupRevision: revision,
        profileCompletionAtSignup: completion,
        verifiedContactMethod,
        privacyVersion: 3,
        joinedAt: current.joinedAt || FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        providerReviewVersion: FieldValue.delete(),
        reviewReason: FieldValue.delete(),
        reviewedAt: FieldValue.delete(),
        reviewedByUid: FieldValue.delete(),
        ...(carrierSnapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      }, {merge: true});
      transaction.create(
          db.collection("dispatch_provider_review_events")
              .doc(`${identity.uid}-${revision}-joined`),
          {
            providerUid: identity.uid,
            revision,
            event: "joined",
            status: "active",
            actorUid: identity.uid,
            profileCompletion: completion,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(receiptRef, {
        actorUid: identity.uid,
        command: "submitDispatchProviderApplication",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });

  const reviewDispatchProvider = dispatchCommand(async (request) => {
    const administratorUid = requireAdministrator(request);
    const providerUid = requiredId(request.data, "providerUid");
    const requestId = requiredId(request.data, "requestId");
    const {decision, reason} = validateDispatchProviderDecision(request.data);
    const carrierRef = db.collection("dispatch_carriers").doc(providerUid);
    const receiptRef = receiptReference(
        db,
        administratorUid,
        "reviewDispatchProvider",
        requestId,
    );
    return db.runTransaction(async (transaction) => {
      const [receipt, carrierSnapshot] = await Promise.all([
        transaction.get(receiptRef),
        transaction.get(carrierRef),
      ]);
      if (receipt.exists) return receipt.data().result;
      if (!carrierSnapshot.exists) {
        throw new HttpsError(
            "not-found",
            "This Dispatch provider application is no longer available.",
        );
      }
      const carrier = carrierSnapshot.data();
      const currentStatus = String(carrier.status || "");
      const reviewable = currentStatus === "pending_review" ||
        (decision === "suspended" && currentStatus === "active");
      if (!reviewable) {
        throw new HttpsError(
            "failed-precondition",
            "This Dispatch provider application is not awaiting that decision.",
        );
      }
      const revision = Number(carrier.reviewRevision || 1);
      const status = decision === "approved" ? "active" : decision;
      const result = {providerUid, status, revision};
      transaction.update(carrierRef, {
        status,
        availableForHire: status === "active",
        providerReviewVersion: status === "active" ? 1 : FieldValue.delete(),
        reviewReason: reason,
        reviewedByUid: administratorUid,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(
          db.collection("dispatch_provider_review_events")
              .doc(`${providerUid}-${revision}-${status}`),
          {
            providerUid,
            revision,
            event: status,
            status,
            reason,
            actorUid: administratorUid,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.set(
          db.collection("users").doc(providerUid).collection("notifications")
              .doc(`dispatch-provider-${revision}-${status}`),
          {
            recipientUid: providerUid,
            type: "dispatch_provider_reviewed",
            title: status === "active" ?
              "Dispatch provider approved" :
              `Dispatch provider ${status.replaceAll("_", " ")}`,
            message: reason,
            providerUid,
            revision,
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(receiptRef, {
        actorUid: administratorUid,
        command: "reviewDispatchProvider",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });

  const createDispatchJob = dispatchCommand(async (request) => {
    const uid = requireAuth(request);
    await requireActiveDispatchAccount(db, uid);
    rejectClientRouteFields(request.data);
    const requestId = requiredId(request.data, "requestId");
    const jobId = requiredId(request.data, "jobId");
    const receiptRef = receiptReference(
        db,
        uid,
        "createDispatchJob",
        requestId,
    );
    const jobRef = db.collection("dispatch_jobs").doc(jobId);
    const privateJobRef = db.collection("dispatch_job_private").doc(jobId);
    const now = Timestamp.now();
    let input = validateDispatchJobInput(request.data, now);
    const listingRef = input.listingId ?
      db.collection("public_listings").doc(input.listingId) :
      null;
    const listingLocationRef = input.listingId ?
      db.collection("listing_private_locations").doc(input.listingId) :
      null;

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = listingRef ?
        await transaction.get(listingRef) :
        null;
      const listingLocationSnapshot = listingLocationRef ?
        await transaction.get(listingLocationRef) :
        null;
      if (listingRef && !listingSnapshot.exists) {
        throw new CommandPolicyError(
            "not-found",
            "The listing for this Dispatch request is unavailable.",
        );
      }
      if (listingSnapshot) {
        const listing = listingSnapshot.data();
        if (listing.status !== "active") {
          throw new CommandPolicyError(
              "failed-precondition",
              "This listing is no longer accepting Dispatch requests.",
          );
        }
        const isAuction = listing.transactionType === "Auction";
        if (
          (input.sourceType === "auction" && !isAuction) ||
          (input.sourceType === "marketplace" && isAuction)
        ) {
          throw new CommandPolicyError(
              "failed-precondition",
              "The Dispatch request does not match the listing type.",
          );
        }
      }
      if (listingLocationSnapshot && listingLocationSnapshot.exists) {
        const exactPickup = listingLocationSnapshot.data().exactGeoPoint;
        if (exactPickup) input = {...input, pickupPoint: exactPickup};
      }
      const values = createJobValues(admin, input, uid);
      const privateValues = {
        ...createJobPrivateValues(admin, input, uid),
        createdAt: FieldValue.serverTimestamp(),
      };
      const result = {jobId, revision: 1, status: "open"};
      transaction.create(jobRef, values);
      transaction.create(privateJobRef, privateValues);
      transaction.create(jobRef.collection("revisions").doc("1"), {
        ...values,
        event: "request_created",
        actorUid: uid,
      });
      transaction.create(privateJobRef.collection("revisions").doc("1"), {
        ...privateValues,
        event: "request_created",
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

  const updateDispatchJob = dispatchCommand(async (request) => {
    const uid = requireAuth(request);
    rejectClientRouteFields(request.data);
    const requestId = requiredId(request.data, "requestId");
    const jobId = requiredId(request.data, "jobId");
    const receiptRef = receiptReference(
        db,
        uid,
        "updateDispatchJob",
        requestId,
    );
    const jobRef = db.collection("dispatch_jobs").doc(jobId);
    const privateJobRef = db.collection("dispatch_job_private").doc(jobId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const jobSnapshot = await transaction.get(jobRef);
      const job = jobSnapshot.exists ? jobSnapshot.data() : null;
      const privateJobSnapshot = await transaction.get(privateJobRef);
      const privateJob = privateJobSnapshot.exists ?
        privateJobSnapshot.data() : {};
      const now = Timestamp.now();
      validateDispatchJobChange(job, uid, now);
      const input = validateDispatchJobInput({
        ...job,
        ...privateJob,
        ...request.data,
        truckingDate: request.data.truckingDate,
      }, now);
      const bids = await transaction.get(
          db.collection("dispatch_bids")
              .where("jobId", "==", jobId)
              .limit(200),
      );
      if (bids.size >= 200) {
        throw new CommandPolicyError(
            "resource-exhausted",
            "This Dispatch job has too many quotes for automatic revision.",
        );
      }
      const revision = Number(job.revision || 1) + 1;
      const routeState = buildDispatchRouteState(
          input.pickupPoint,
          input.deliveryPoint,
          {providerConfigured: false},
      );
      const changes = {
        title: input.title,
        pickupLabel: input.pickupLabel,
        deliveryLabel: input.deliveryLabel,
        truckingDate: Timestamp.fromMillis(input.truckingDate),
        loadDetails: input.loadDetails,
        estimatedWeightKg: input.estimatedWeightKg,
        ...routeState,
        revision,
        updatedAt: FieldValue.serverTimestamp(),
      };
      const privateChanges = {
        ...createJobPrivateValues(admin, input, uid),
        revision,
      };
      const result = {jobId, revision, status: job.status};
      transaction.update(jobRef, changes);
      transaction.set(privateJobRef, privateChanges, {merge: true});
      transaction.create(
          jobRef.collection("revisions").doc(String(revision)),
          {
            ...job,
            ...changes,
            event: "request_updated",
            actorUid: uid,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.set(
          privateJobRef.collection("revisions").doc(String(revision)),
          {
            ...privateChanges,
            event: "request_updated",
            actorUid: uid,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      for (const bid of bids.docs) {
        const bidData = bid.data();
        const carrierUid = String(bidData.carrierUid || "");
        if (bidData.status !== "pending" || !carrierUid || carrierUid === uid) {
          continue;
        }
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
              title: "Dispatch request updated",
              body: "Review the revised route, date, distance, or load details.",
              read: false,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
      }
      transaction.create(receiptRef, {
        actorUid: uid,
        command: "updateDispatchJob",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });

  const publishDispatchJob = dispatchCommand(async (request) => {
    const uid = requireAuth(request);
    const requestId = requiredId(request.data, "requestId");
    const jobId = requiredId(request.data, "jobId");
    const receiptRef = receiptReference(
        db,
        uid,
        "publishDispatchJob",
        requestId,
    );
    const jobRef = db.collection("dispatch_jobs").doc(jobId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const snapshot = await transaction.get(jobRef);
      const job = snapshot.exists ? snapshot.data() : null;
      validateDispatchJobPublish(job, uid);
      const revision = Number(job.revision || 1) + 1;
      const result = {jobId, revision, status: "open"};
      const changes = {
        status: "open",
        dispatchRequestStatus: "accepting_carrier_bids",
        revision,
        publishedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };
      transaction.update(jobRef, changes);
      transaction.create(
          jobRef.collection("revisions").doc(String(revision)),
          {
            ...job,
            ...changes,
            event: "request_published",
            actorUid: uid,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(receiptRef, {
        actorUid: uid,
        command: "publishDispatchJob",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });

  const submitDispatchQuote = dispatchCommand(async (request) => {
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
    const membershipRef = db.collection("dispatch_memberships").doc(uid);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const jobSnapshot = await transaction.get(jobRef);
      const carrierSnapshot = await transaction.get(carrierRef);
      const vehicleSnapshot = await transaction.get(vehicleRef);
      const membershipSnapshot = await transaction.get(membershipRef);
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
      const membership =
        membershipSnapshot.exists ? membershipSnapshot.data() : null;
      const now = Timestamp.now();
      const quote = validateDispatchQuote({
        job,
        carrier,
        membership,
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

  const awardDispatchQuote = dispatchCommand(async (request) => {
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
    const dispatchRef = db.collection("dispatch_transactions").doc(jobId);

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
      const dispatchSnapshot = await transaction.get(dispatchRef);
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
      if (dispatchSnapshot.exists) {
        throw new CommandPolicyError(
            "failed-precondition",
            "This Dispatch job already has an active transaction.",
        );
      }
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
      const dispatchValues = {
        jobId,
        customerUid: uid,
        carrierUid: awarded.carrierUid,
        bidId,
        amount: awarded.amount,
        currency: job.currency || "CAD",
        vehicleId: bid.vehicleId || null,
        vehicleName: bid.vehicleName || null,
        status: "awarded",
        proposedAvailableDate: bid.availableDate || null,
        requestedTruckingDate: job.truckingDate || null,
        scheduledDate: null,
        revision: 1,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };
      transaction.create(dispatchRef, dispatchValues);
      transaction.create(dispatchRef.collection("revisions").doc("1"), {
        ...dispatchValues,
        event: "carrier_awarded",
        actorUid: uid,
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

  const updateDispatchTransaction = dispatchCommand(async (request) => {
    const uid = requireAuth(request);
    const requestId = requiredId(request.data, "requestId");
    const jobId = requiredId(request.data, "jobId");
    const action = requiredId(request.data, "action");
    const receiptRef = receiptReference(
        db,
        uid,
        "updateDispatchTransaction",
        requestId,
    );
    const jobRef = db.collection("dispatch_jobs").doc(jobId);
    const dispatchRef = db.collection("dispatch_transactions").doc(jobId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const jobSnapshot = await transaction.get(jobRef);
      const dispatchSnapshot = await transaction.get(dispatchRef);
      const jobData = jobSnapshot.exists ? jobSnapshot.data() : null;
      const job = jobData ? {...jobData, id: jobId} : null;
      const dispatchTransaction = dispatchSnapshot.exists ?
        dispatchSnapshot.data() : null;
      const bidId = String(dispatchTransaction && dispatchTransaction.bidId || "");
      const bidRef = bidId ? db.collection("dispatch_bids").doc(bidId) : null;
      const bidSnapshot = bidRef ? await transaction.get(bidRef) : null;
      if (!bidSnapshot || !bidSnapshot.exists) {
        throw new CommandPolicyError(
            "failed-precondition",
            "The awarded carrier quote is unavailable for this Dispatch job.",
        );
      }
      const transition = validateDispatchTransactionAction({
        job,
        dispatchTransaction,
        actorUid: uid,
        action,
        data: request.data || {},
        now: Timestamp.now(),
        administrator: isAdministrator(request),
      });
      const currentRevision = Number(dispatchTransaction.revision || 1);
      const result = {
        jobId,
        status: transition.status,
        revision: transition.alreadyApplied ?
          currentRevision : currentRevision + 1,
      };
      if (transition.alreadyApplied) {
        transaction.create(receiptRef, {
          actorUid: uid,
          command: "updateDispatchTransaction",
          result,
          createdAt: FieldValue.serverTimestamp(),
        });
        return result;
      }
      const revision = currentRevision + 1;
      const sensitiveChanges = {
        status: transition.status,
        revision,
        lastAction: action,
        lastActionByUid: uid,
        ...(transition.scheduledDate ? {
          scheduledDate: Timestamp.fromMillis(transition.scheduledDate),
        } : {}),
        ...(transition.proofOfDelivery ? {
          proofOfDelivery: transition.proofOfDelivery,
          deliveredAt: FieldValue.serverTimestamp(),
        } : {}),
        ...(transition.reason ? {reason: transition.reason} : {}),
        ...(action === "accept_award" ? {
          acceptedAt: FieldValue.serverTimestamp(),
        } : {}),
        ...(action === "start_transit" ? {
          inTransitAt: FieldValue.serverTimestamp(),
        } : {}),
        ...(transition.status === "closed" ? {
          closedAt: FieldValue.serverTimestamp(),
        } : {}),
        ...(transition.status === "cancelled" ? {
          cancelledAt: FieldValue.serverTimestamp(),
        } : {}),
        ...(transition.status === "disputed" ? {
          disputedAt: FieldValue.serverTimestamp(),
        } : {}),
        updatedAt: FieldValue.serverTimestamp(),
      };
      transaction.update(dispatchRef, sensitiveChanges);
      transaction.create(
          dispatchRef.collection("revisions").doc(String(revision)),
          {
            event: action,
            actorUid: uid,
            actorRole: transition.actorRole,
            status: transition.status,
            revision,
            ...(transition.scheduledDate ? {
              scheduledDate: Timestamp.fromMillis(transition.scheduledDate),
            } : {}),
            ...(transition.proofOfDelivery ? {
              proofOfDelivery: transition.proofOfDelivery,
            } : {}),
            ...(transition.reason ? {reason: transition.reason} : {}),
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      const publicStatus = transition.status === "closed" ?
        "completed" : transition.status;
      transaction.update(jobRef, {
        status: publicStatus,
        dispatchRequestStatus: transition.status,
        updatedAt: FieldValue.serverTimestamp(),
        ...(transition.status === "closed" ? {
          completedAt: FieldValue.serverTimestamp(),
        } : {}),
      });
      const bidData = bidSnapshot.data();
      const bidRevision = Number(bidData.revision || 1) + 1;
      const publicBidStatus = transition.status === "closed" ?
        "completed" : transition.status;
      transaction.update(bidRef, {
        status: publicBidStatus,
        fulfillmentStatus: transition.status,
        revision: bidRevision,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(
          bidRef.collection("revisions").doc(String(bidRevision)),
          {
            ...bidData,
            status: publicBidStatus,
            fulfillmentStatus: transition.status,
            revision: bidRevision,
            event: action,
            actorUid: uid,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      if (transition.status === "disputed") {
        transaction.set(db.collection("dispatch_disputes").doc(jobId), {
          jobId,
          customerUid: dispatchTransaction.customerUid,
          carrierUid: dispatchTransaction.carrierUid,
          openedByUid: uid,
          reason: transition.reason,
          status: "open",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else if (action === "admin_resolve") {
        transaction.set(db.collection("dispatch_disputes").doc(jobId), {
          status: "resolved",
          resolution: transition.status,
          resolutionNote: transition.reason,
          resolvedByUid: uid,
          resolvedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      const participants = [
        dispatchTransaction.customerUid,
        dispatchTransaction.carrierUid,
      ].filter((participantUid) => participantUid && participantUid !== uid);
      for (const recipientUid of participants) {
        transaction.set(
            db.collection("users").doc(recipientUid)
                .collection("notifications").doc(receiptRef.id),
            {
              recipientUid,
              actorUid: uid,
              type: "dispatch",
              jobId,
              title: transition.status === "closed" ?
                "Dispatch job completed" : transition.status === "disputed" ?
                  "Dispatch job disputed" : transition.status === "cancelled" ?
                    "Dispatch job cancelled" :
                    `Dispatch job ${transition.status.replaceAll("_", " ")}`,
              read: false,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
      }
      transaction.create(receiptRef, {
        actorUid: uid,
        command: "updateDispatchTransaction",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });


  const createDispatchPilotRequest = dispatchCommand(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    const requestId = requiredId(request.data, "requestId");
    await requireActiveDispatchAccount(db, identity.uid);
    const textField = (field, maximum) => {
      const value = String(request.data && request.data[field] || "").trim();
      if (!value || value.length > maximum) {
        throw new HttpsError(
            "invalid-argument",
            `${field} is required and must be ${maximum} characters or fewer.`,
        );
      }
      return value;
    };
    const pickupLabel = textField("pickupLabel", 500);
    const deliveryLabel = textField("deliveryLabel", 500);
    const details = textField("details", 2000);
    const requestedDate = Number(request.data && request.data.requestedDate);
    const nowMillis = Date.now();
    if (!Number.isInteger(requestedDate) ||
        requestedDate < nowMillis - 24 * 60 * 60 * 1000 ||
        requestedDate > nowMillis + 730 * 24 * 60 * 60 * 1000) {
      throw new HttpsError(
          "invalid-argument",
          "Pilot service date must be within the next two years.",
      );
    }
    const pilotVehicles = await db.collectionGroup("vehicles")
        .where("pilotTruck", "==", true)
        .limit(200)
        .get();
    const candidateUids = [...new Set(pilotVehicles.docs
        .filter((vehicle) => vehicle.data().available !== false)
        .map((vehicle) => vehicle.ref.parent.parent && vehicle.ref.parent.parent.id)
        .filter((uid) => uid && uid !== identity.uid))];
    const carrierSnapshots = candidateUids.length > 0 ?
      await db.getAll(...candidateUids.map((uid) =>
        db.collection("dispatch_carriers").doc(uid))) : [];
    const recipients = carrierSnapshots
        .filter((snapshot) => snapshot.exists &&
          snapshot.data().status === "active" &&
          snapshot.data().availableForHire !== false)
        .map((snapshot) => snapshot.id)
        .slice(0, 200);
    const requestRef = db.collection("dispatch_pilot_requests").doc(requestId);
    const receiptRef = receiptReference(
        db, identity.uid, "createDispatchPilotRequest", requestId,
    );
    const result = {
      requestId,
      notifiedPilotProviders: recipients.length,
      status: "open",
    };
    await db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return;
      transaction.create(requestRef, {
        requesterUid: identity.uid,
        pickupLabel,
        deliveryLabel,
        details,
        requestedDate: Timestamp.fromMillis(requestedDate),
        status: "open",
        schemaVersion: 1,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      for (const recipientUid of recipients) {
        transaction.set(
            db.collection("users").doc(recipientUid)
                .collection("notifications")
                .doc(`pilot-${requestId}`),
            {
              recipientUid,
              actorUid: identity.uid,
              type: "dispatch",
              pilotRequestId: requestId,
              title: "Pilot service requested",
              body: `${pickupLabel} → ${deliveryLabel}. Open Dispatch Pilot services for details.`,
              read: false,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
      }
      transaction.create(receiptRef, {
        actorUid: identity.uid,
        command: "createDispatchPilotRequest",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
    });
    return result;
  });

  return {
    awardDispatchQuote,
    createDispatchJob,
    createDispatchPilotRequest,
    reviewDispatchProvider,
    publishDispatchJob,
    submitDispatchQuote,
    submitDispatchProviderApplication,
    updateDispatchTransaction,
    updateDispatchJob,
  };
}

module.exports = {createDispatchCommands};
