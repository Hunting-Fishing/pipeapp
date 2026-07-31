"use strict";

const {
  MAXIMUM_WANTED_CANDIDATES,
  MAXIMUM_WANTED_MATCHES_PER_LISTING,
  publicListingSnapshot,
  scoreWantedMatch,
  wantedMatchId,
} = require("./wanted_matching_policy");

function createWantedMatching(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function candidateDocuments(listing) {
    const wanted = listing.transactionType === "Wanted / Seeking";
    if (!wanted && listing.transactionType !== "For Sale") return [];
    if (listing.status !== "active" || !String(listing.category || "")) {
      return [];
    }
    const counterpartType = wanted ? "For Sale" : "Wanted / Seeking";
    const snapshot = await db.collection("public_listings")
        .where("status", "==", "active")
        .where("transactionType", "==", counterpartType)
        .where("category", "==", listing.category)
        .orderBy("createdAt", "desc")
        .limit(MAXIMUM_WANTED_CANDIDATES)
        .get();
    return snapshot.docs;
  }

  async function persistMatch({
    wantedId,
    supplyId,
    source = "listing_created",
    backfillRunId = "",
  }) {
    const matchId = wantedMatchId(wantedId, supplyId);
    const matchRef = db.collection("wanted_matches").doc(matchId);
    const wantedRef = db.collection("public_listings").doc(wantedId);
    const supplyRef = db.collection("public_listings").doc(supplyId);
    return db.runTransaction(async (transaction) => {
      const existing = await transaction.get(matchRef);
      if (existing.exists) return false;
      const wantedSnapshot = await transaction.get(wantedRef);
      const supplySnapshot = await transaction.get(supplyRef);
      if (!wantedSnapshot.exists || !supplySnapshot.exists) return false;
      const wanted = wantedSnapshot.data();
      const supply = supplySnapshot.data();
      const analysis = scoreWantedMatch(wanted, supply);
      if (!analysis) return false;
      const wantedOwnerUid = String(wanted.sellerUid || "");
      const sellerUid = String(supply.sellerUid || "");
      if (!wantedOwnerUid || !sellerUid) return false;

      transaction.create(matchRef, {
        wantedListingId: wantedId,
        supplyListingId: supplyId,
        wantedOwnerUid,
        sellerUid,
        status: "suggested",
        wantedOwnerState: "suggested",
        sellerState: "suggested",
        contactRecorded: false,
        revision: 1,
        source: source === "backfill" ? "backfill" : "listing_created",
        ...(source === "backfill" && backfillRunId ? {backfillRunId} : {}),
        ...analysis,
        wanted: publicListingSnapshot(wanted),
        supply: publicListingSnapshot(supply),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(matchRef.collection("events").doc("1"), {
        actorRole: "system",
        action: "matched",
        state: "suggested",
        status: "suggested",
        revision: 1,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(wantedRef, {
        matchCount: FieldValue.increment(1),
        lastMatchedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
          db.collection("users").doc(wantedOwnerUid)
              .collection("notifications").doc(`wanted-${matchId}`),
          {
            recipientUid: wantedOwnerUid,
            actorUid: sellerUid,
            type: "wanted_match",
            title: "A listing may match your wanted ad",
            body: String(supply.title || "Matching Marketplace listing")
                .slice(0, 240),
            listingId: supplyId,
            wantedListingId: wantedId,
            wantedMatchId: matchId,
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.set(
          db.collection("users").doc(sellerUid)
              .collection("notifications").doc(`wanted-interest-${matchId}`),
          {
            recipientUid: sellerUid,
            actorUid: wantedOwnerUid,
            type: "wanted_interest",
            title: "A wanted ad may match your listing",
            body: String(wanted.title || "Matching wanted ad").slice(0, 240),
            listingId: wantedId,
            supplyListingId: supplyId,
            wantedMatchId: matchId,
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      return true;
    });
  }

  async function planListingMatches(listingId, listing) {
    const candidates = await candidateDocuments(listing);
    const wantedCreated = listing.transactionType === "Wanted / Seeking";
    const planned = candidates.map((candidate) => {
      const wanted = wantedCreated ? listing : candidate.data();
      const supply = wantedCreated ? candidate.data() : listing;
      const analysis = scoreWantedMatch(wanted, supply);
      return analysis ? {
        wantedId: wantedCreated ? listingId : candidate.id,
        supplyId: wantedCreated ? candidate.id : listingId,
        score: analysis.score,
      } : null;
    }).filter(Boolean).sort((left, right) => right.score - left.score)
        .slice(0, MAXIMUM_WANTED_MATCHES_PER_LISTING);

    return {candidates: candidates.length, planned};
  }

  async function processListingCreated(listingId, listing, options = {}) {
    const plan = await planListingMatches(listingId, listing);
    const results = await Promise.all(plan.planned.map((match) =>
      persistMatch({...match, ...options}),
    ));
    const created = results.filter(Boolean).length;
    return {
      candidates: plan.candidates,
      planned: plan.planned.length,
      created,
      createdMatchIds: plan.planned
          .filter((_match, index) => results[index])
          .map((match) => wantedMatchId(match.wantedId, match.supplyId)),
    };
  }

  return {persistMatch, planListingMatches, processListingCreated};
}

module.exports = {createWantedMatching};
