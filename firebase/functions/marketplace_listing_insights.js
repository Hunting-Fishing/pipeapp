"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {isAdministrator} = require("./administrator_authorization");
const {
  loadPhase1FeatureFlags,
  requirePhase1Feature,
} = require("./phase1_feature_flags");
const {lifecycleMillis} = require("./marketplace_listing_lifecycle");

function normalizedText(value) {
  return String(value || "").trim().toLowerCase();
}

function numericValue(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function nonNegativeCount(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(0, Math.round(parsed)) : 0;
}

function safePercent(numerator, denominator) {
  const top = Number(numerator);
  const bottom = Number(denominator);
  if (!Number.isFinite(top) || !Number.isFinite(bottom) || bottom <= 0) {
    return null;
  }
  return Math.round((top / bottom * 100) * 10) / 10;
}

function normalizedPriceBasis(value) {
  const basis = normalizedText(value);
  if (basis.includes("total") || basis.includes("lot")) return "total";
  if (basis.includes("joint") || basis.includes("piece") ||
      basis.includes("item") || basis.includes("unit")) return "unit";
  return basis;
}

function tokensFor(listing) {
  const stored = Array.isArray(listing && listing.searchTokens) ?
    listing.searchTokens : [];
  const fallback = [
    listing && listing.title,
    listing && listing.category,
    listing && listing.productType,
    listing && listing.brand,
    listing && listing.model,
    listing && listing.pipeSize,
    listing && listing.nearestTown,
    listing && listing.region,
  ].filter(Boolean).join(" ").split(/[^a-zA-Z0-9/.-]+/);
  return new Set([...stored, ...fallback]
      .map(normalizedText)
      .filter((value) => value.length > 1));
}

function comparableListingScore(source, candidate) {
  if (!source || !candidate) return 0;
  if (normalizedText(source.category) !== normalizedText(candidate.category)) {
    return 0;
  }
  let score = 20;
  const equals = (field, points) => {
    const left = normalizedText(source[field]);
    const right = normalizedText(candidate[field]);
    if (left && right && left === right) score += points;
  };
  equals("productType", 35);
  equals("transactionType", 5);
  equals("brand", 10);
  equals("model", 10);
  equals("pipeSize", 10);
  equals("condition", 3);
  equals("region", 5);
  if (normalizedPriceBasis(source.priceBasis) &&
      normalizedPriceBasis(source.priceBasis) ===
        normalizedPriceBasis(candidate.priceBasis)) {
    score += 2;
  }
  const sourceTokens = tokensFor(source);
  const candidateTokens = tokensFor(candidate);
  if (sourceTokens.size && candidateTokens.size) {
    let overlap = 0;
    for (const token of sourceTokens) {
      if (candidateTokens.has(token)) overlap += 1;
    }
    score += Math.min(10, overlap * 2);
  }
  return Math.min(100, score);
}

function median(values) {
  const sorted = values
      .map(Number)
      .filter((value) => Number.isFinite(value))
      .sort((a, b) => a - b);
  if (!sorted.length) return null;
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ?
    sorted[middle] :
    (sorted[middle - 1] + sorted[middle]) / 2;
}

function engagementSignal({views, saves, messages, offers}) {
  if (views < 10) {
    return {
      code: "building",
      label: "Building signal",
      strong: false,
      message: "This listing does not have enough view activity yet for a reliable engagement pattern. Keep the listing accurate and let more buyer traffic accumulate.",
    };
  }

  const offerRate = safePercent(offers, views) || 0;
  const messageRate = safePercent(messages, views) || 0;
  const saveRate = safePercent(saves, views) || 0;
  if (offers >= 3 || offerRate >= 3 || messages >= 6 || messageRate >= 6) {
    return {
      code: "strong",
      label: "Strong buyer signal",
      strong: true,
      message: "This listing is generating meaningful buyer actions. Keep availability, pricing and response details current while interest is active.",
    };
  }
  if (offers >= 1 || messages >= 2 || saves >= 3 ||
      messageRate >= 2 || saveRate >= 4) {
    return {
      code: "developing",
      label: "Developing buyer signal",
      strong: false,
      message: "Buyers are taking follow-up actions beyond viewing. Monitor messages, saves and offers before making major listing changes.",
    };
  }
  return {
    code: "limited",
    label: "Limited follow-through",
    strong: false,
    message: "The listing is receiving views but few downstream actions. Review the first photo, title, price basis, specifications and transportation details.",
  };
}

function buildEngagementAnalytics(listing) {
  const views = nonNegativeCount(listing.viewCount);
  const saves = nonNegativeCount(listing.saveCount);
  const shares = nonNegativeCount(listing.shareCount);
  const messages = nonNegativeCount(listing.messageCount);
  const offers = nonNegativeCount(
      listing.offerCount == null ? listing.pendingOfferCount : listing.offerCount,
  );
  const actions = saves + messages + offers;
  return {
    views,
    saves,
    shares,
    messages,
    offers,
    actions,
    saveRatePercent: safePercent(saves, views),
    messageRatePercent: safePercent(messages, views),
    offerRatePercent: safePercent(offers, views),
    actionRatePercent: safePercent(actions, views),
    signal: engagementSignal({views, saves, messages, offers}),
  };
}

function compactComparable(id, data, score) {
  return {
    listingId: id,
    title: String(data.title || "Marketplace listing").slice(0, 180),
    category: String(data.category || "").slice(0, 120),
    productType: String(data.productType || "").slice(0, 120),
    condition: String(data.condition || "").slice(0, 120),
    price: numericValue(data.price),
    priceBasis: String(data.priceBasis || "").slice(0, 80),
    publicLocationName: String(
        data.publicLocationName || data.nearestTown || "",
    ).slice(0, 160),
    thumbnailUrl: String(data.thumbnailUrl || "").slice(0, 2000),
    similarityScore: score,
  };
}

function buildMarketplaceListingInsights({listing, candidates, nowMillis}) {
  const now = Number.isFinite(nowMillis) ? nowMillis : Date.now();
  const sourceBasis = normalizedPriceBasis(listing.priceBasis);
  const sourcePrice = numericValue(listing.price);
  const scored = candidates
      .filter((candidate) => candidate && candidate.id !== listing.id)
      .filter((candidate) => candidate.data.status === "active")
      .filter((candidate) => candidate.data.transactionType !== "Auction")
      .map((candidate) => ({
        ...candidate,
        score: comparableListingScore(listing, candidate.data),
      }))
      .filter((candidate) => candidate.score >= 30)
      .sort((a, b) => b.score - a.score)
      .slice(0, 12);

  const priceComparables = scored.filter((candidate) => {
    const price = numericValue(candidate.data.price);
    return price != null && price > 0 &&
      normalizedPriceBasis(candidate.data.priceBasis) === sourceBasis;
  });
  const comparablePrices = priceComparables.map(
      (candidate) => numericValue(candidate.data.price),
  ).filter((value) => value != null);
  const medianPrice = median(comparablePrices);
  const lowPrice = comparablePrices.length ? Math.min(...comparablePrices) : null;
  const highPrice = comparablePrices.length ? Math.max(...comparablePrices) : null;
  const priceDeltaPercent = sourcePrice != null && sourcePrice > 0 &&
      medianPrice != null && medianPrice > 0 ?
    Math.round(((sourcePrice - medianPrice) / medianPrice * 100) * 10) / 10 :
    null;

  const engagement = buildEngagementAnalytics(listing);
  const suggestions = [];
  const status = normalizedText(listing.status);
  if (status === "expired") {
    suggestions.push({
      code: "renew",
      priority: "high",
      title: "Renew if the inventory is still available",
      detail: "This listing completed its 30-day Marketplace period. Renewing keeps the same listing history and starts a new 30-day active period.",
    });
  }

  const photoCount = Number(listing.mediaPhotoCount ||
      (Array.isArray(listing.imageUrls) ? listing.imageUrls.length : 0));
  if (photoCount < 3) {
    suggestions.push({
      code: "photos",
      priority: "medium",
      title: "Add more listing photos",
      detail: "Listings with multiple clear angles are easier for buyers to evaluate before messaging the seller.",
    });
  }

  const description = String(listing.description || "").trim();
  if (description.length < 120) {
    suggestions.push({
      code: "details",
      priority: "medium",
      title: "Add more specifications",
      detail: "Include dimensions, condition, inspection information, loading details and other buyer-relevant specifications that you can verify.",
    });
  }

  if (sourcePrice != null && sourcePrice > 0 &&
      medianPrice != null && priceComparables.length >= 3) {
    const deltaPercent = (sourcePrice - medianPrice) / medianPrice * 100;
    if (deltaPercent >= 15) {
      suggestions.push({
        code: "price_high",
        priority: "high",
        title: "Review the asking price against comparable listings",
        detail: `Your asking price is about ${Math.round(deltaPercent)}% above the median of ${priceComparables.length} similar active listings using the same pricing basis. Condition and specifications may justify the difference.`,
      });
    } else if (deltaPercent <= -15) {
      suggestions.push({
        code: "price_low",
        priority: "medium",
        title: "Your asking price is below comparable listings",
        detail: `Your asking price is about ${Math.abs(Math.round(deltaPercent))}% below the comparable median. Confirm the quantity, condition and pricing basis before changing it.`,
      });
    }
  }

  if (engagement.views >= 20 && engagement.offers === 0) {
    suggestions.push({
      code: "views_no_offers",
      priority: "medium",
      title: "Views are not converting into offers yet",
      detail: "Consider reviewing price, photos, specifications, offer flexibility and transportation details before renewing.",
    });
  }
  if (engagement.views >= 40 && engagement.saves === 0) {
    suggestions.push({
      code: "views_no_saves",
      priority: "medium",
      title: "Buyer views are not producing saves yet",
      detail: "Check the lead photo, title, condition wording, price basis and location summary so buyers can understand the listing quickly.",
    });
  }
  if (engagement.messages >= 3 && engagement.offers === 0) {
    suggestions.push({
      code: "messages_no_offers",
      priority: "medium",
      title: "Buyer conversations have not reached an offer yet",
      detail: "Make sure quantity, loading, inspection, pickup timing and transportation expectations are clear in the listing and Deal Room.",
    });
  }
  if (engagement.saves > 0 && status === "expired") {
    suggestions.push({
      code: "saved_interest",
      priority: "high",
      title: "Buyers previously saved this listing",
      detail: `${engagement.saves} saved-listing signal${engagement.saves === 1 ? "" : "s"} remain attached to this listing. Renewing the same listing preserves that marketplace history.`,
    });
  }

  const createdAt = lifecycleMillis(listing.createdAt);
  const ageDays = createdAt == null ? null :
    Math.max(0, Math.floor((now - createdAt) / (24 * 60 * 60 * 1000)));

  return {
    sampleCount: scored.length,
    comparablePricing: {
      sampleCount: priceComparables.length,
      median: medianPrice,
      low: lowPrice,
      high: highPrice,
      priceBasis: sourceBasis,
      listingPrice: sourcePrice,
      deltaFromMedianPercent: priceDeltaPercent,
    },
    engagement: {
      ...engagement,
      ageDays,
    },
    similarListings: scored.slice(0, 6).map(
        (candidate) => compactComparable(
            candidate.id,
            candidate.data,
            candidate.score,
        ),
    ),
    suggestions: suggestions.slice(0, 6),
    disclaimer: "Marketplace analytics only. Comparable listings and engagement signals use seller-provided data and Pipe Buyer activity counters. They are not an appraisal, valuation, certified weight, legal determination, or guarantee of sale price or buyer demand.",
  };
}

function createMarketplaceListingInsights(admin) {
  const db = admin.firestore();

  async function getMarketplaceListingInsights(request) {
    const identity = requireAuthenticatedIdentity(request);
    const uid = identity.uid;
    const flags = await loadPhase1FeatureFlags(db);
    requirePhase1Feature(flags, "marketplace");
    await enforceUserRateLimit({
      db,
      admin,
      request,
      scope: "marketplace",
    });
    const listingId = String(request.data && request.data.listingId || "").trim();
    if (!listingId || listingId.length > 180 || listingId.includes("/")) {
      throw new HttpsError("invalid-argument", "Listing identifier is invalid.");
    }
    const listingSnapshot = await db.collection("public_listings")
        .doc(listingId)
        .get();
    if (!listingSnapshot.exists) {
      throw new HttpsError("not-found", "This listing is unavailable.");
    }
    const listing = {...listingSnapshot.data(), id: listingId};
    if (String(listing.sellerUid || "") !== uid && !isAdministrator(request)) {
      throw new HttpsError(
          "permission-denied",
          "Only the listing owner can view seller recommendations.",
      );
    }
    const category = String(listing.category || "").trim();
    const query = category ?
      db.collection("public_listings")
          .where("category", "==", category)
          .limit(80) :
      db.collection("public_listings").limit(80);
    const snapshot = await query.get();
    const candidates = snapshot.docs.map((document) => ({
      id: document.id,
      data: document.data(),
    }));
    return {
      listingId,
      generatedAt: Date.now(),
      ...buildMarketplaceListingInsights({
        listing,
        candidates,
        nowMillis: Date.now(),
      }),
    };
  }

  return {getMarketplaceListingInsights};
}

module.exports = {
  buildEngagementAnalytics,
  buildMarketplaceListingInsights,
  comparableListingScore,
  engagementSignal,
  createMarketplaceListingInsights,
  median,
  normalizedPriceBasis,
  safePercent,
};
