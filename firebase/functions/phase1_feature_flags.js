"use strict";

class FeatureFlagError extends Error {
  constructor(feature) {
    super(`The ${feature} feature is not currently available.`);
    this.name = "FeatureFlagError";
    this.code = "failed-precondition";
    this.feature = feature;
  }
}

const featureNames = Object.freeze([
  "marketplace",
  "wantedAds",
  "offers",
  "auctions",
  "dispatch",
  "paidFeatures",
  "regulatedListings",
]);

const safeDefaults = Object.freeze({
  marketplace: true,
  wantedAds: true,
  offers: true,
  auctions: false,
  dispatch: false,
  paidFeatures: false,
  regulatedListings: false,
});

function normalizePhase1FeatureFlags(data, defaults = safeDefaults) {
  const source = data && typeof data === "object" ? data : {};
  const normalized = {};
  for (const feature of featureNames) {
    normalized[feature] = typeof source[feature] === "boolean" ?
      source[feature] :
      defaults[feature] === true;
  }
  normalized.revision = Number.isSafeInteger(Number(source.revision)) ?
    Math.max(0, Number(source.revision)) :
    0;
  return normalized;
}

async function loadPhase1FeatureFlags(db) {
  const snapshot = await db.collection("platform_configuration")
      .doc("phase1_features")
      .get();
  return normalizePhase1FeatureFlags(
      snapshot.exists ? snapshot.data() : null,
  );
}

function requirePhase1Feature(flags, feature) {
  if (!featureNames.includes(feature) || flags[feature] !== true) {
    throw new FeatureFlagError(feature);
  }
}

module.exports = {
  FeatureFlagError,
  featureNames,
  loadPhase1FeatureFlags,
  normalizePhase1FeatureFlags,
  requirePhase1Feature,
  safeDefaults,
};
