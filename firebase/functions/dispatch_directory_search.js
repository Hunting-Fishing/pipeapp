"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const geofire = require("geofire-common");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  FeatureFlagError,
  loadPhase1FeatureFlags,
  requirePhase1Feature,
} = require("./phase1_feature_flags");

const MAX_RADIUS_KM = 1000;
const DEFAULT_RESULT_LIMIT = 40;
const MAX_RESULT_LIMIT = 60;
const PER_BOUND_RESULT_LIMIT = 80;
const PER_BOUND_FETCH_LIMIT = PER_BOUND_RESULT_LIMIT + 1;
const MAX_CANDIDATES = 500;
const MAX_QUERY_BOUNDS = 9;

function finiteNumber(data, fieldName, {min, max}) {
  const value = Number(data && data[fieldName]);
  if (!Number.isFinite(value) || value < min || value > max) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} must be between ${min} and ${max}.`,
    );
  }
  return value;
}

function resultLimit(data) {
  if (data == null || data.resultLimit == null || data.resultLimit === "") {
    return DEFAULT_RESULT_LIMIT;
  }
  const value = Number(data.resultLimit);
  if (!Number.isInteger(value) || value < 1 || value > MAX_RESULT_LIMIT) {
    throw new HttpsError(
        "invalid-argument",
        `resultLimit must be between 1 and ${MAX_RESULT_LIMIT}.`,
    );
  }
  return value;
}

function validateRadiusSearchInput(data) {
  return {
    center: [
      finiteNumber(data, "latitude", {min: -90, max: 90}),
      finiteNumber(data, "longitude", {min: -180, max: 180}),
    ],
    radiusKm: finiteNumber(
        data,
        "radiusKm",
        {min: 1, max: MAX_RADIUS_KM},
    ),
    resultLimit: resultLimit(data),
  };
}

function pointCoordinates(point) {
  if (!point || typeof point !== "object") return null;
  const latitude = Number(point.latitude ?? point.lat);
  const longitude = Number(point.longitude ?? point.lng);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return [latitude, longitude];
}

function cleanText(value, maxLength = 600) {
  return String(value || "").trim().replace(/\s+/g, " ").slice(0, maxLength);
}

function cleanStringList(value, limit = 64) {
  if (!Array.isArray(value)) return [];
  return value
      .map((item) => cleanText(item, 180))
      .filter(Boolean)
      .slice(0, limit);
}

function publicDirectoryResult(document, distanceKm) {
  const data = document.data() || {};
  const point = pointCoordinates(data.mapPoint);
  if (!point) return null;
  const publicLocation = data.publicLocation && typeof data.publicLocation === "object" ?
    data.publicLocation : {};
  const publicServiceArea =
    data.publicServiceArea && typeof data.publicServiceArea === "object" ?
      data.publicServiceArea : {};
  return {
    id: cleanText(document.id, 180),
    operatingName: cleanText(data.operatingName || data.companyName, 180),
    publicSummary: cleanText(data.publicSummary),
    website: cleanText(data.website, 260),
    serviceCodes: cleanStringList(data.serviceCodes),
    serviceAreaSummary: cleanText(data.serviceAreaSummary, 260),
    publicLocation: {
      label: cleanText(publicLocation.label, 200),
      precision: cleanText(publicLocation.precision, 64),
      source: cleanText(publicLocation.source, 96),
    },
    publicServiceArea: {
      mode: cleanText(publicServiceArea.mode, 96),
      centerLabel: cleanText(publicServiceArea.centerLabel, 200),
      radiusKm: Number.isFinite(Number(publicServiceArea.radiusKm)) ?
        Number(publicServiceArea.radiusKm) : 0,
      countryCodes: cleanStringList(publicServiceArea.countryCodes, 32),
      regionKeys: cleanStringList(publicServiceArea.regionKeys, 120),
      placeKeys: cleanStringList(publicServiceArea.placeKeys, 240),
    },
    mapPoint: {latitude: point[0], longitude: point[1]},
    availability: cleanText(data.availability, 96),
    businessType: cleanText(data.businessType, 96),
    verified: data.verified === true,
    emergencyCallout: data.emergencyCallout === true,
    remoteSiteCapable: data.remoteSiteCapable === true,
    profileCompleteness: Math.max(
        0,
        Math.min(100, Number(data.profileCompleteness) || 0),
    ),
    distanceKm: Math.round(distanceKm * 10) / 10,
  };
}

async function queryDirectoryRadius({
  db,
  geofireApi = geofire,
  center,
  radiusKm,
  limit = DEFAULT_RESULT_LIMIT,
}) {
  const radiusInM = radiusKm * 1000;
  const bounds = geofireApi.geohashQueryBounds(center, radiusInM);
  if (!Array.isArray(bounds) || bounds.length < 1 ||
      bounds.length > MAX_QUERY_BOUNDS) {
    throw new Error("Geo query bounds were unavailable or exceeded the approved limit.");
  }

  const snapshots = await Promise.all(bounds.map((bound) => {
    if (!Array.isArray(bound) || bound.length !== 2) {
      throw new Error("Geo query bound was invalid.");
    }
    return db.collection("dispatch_directory_entries")
        .orderBy("geohash")
        .startAt(bound[0])
        .endAt(bound[1])
        .limit(PER_BOUND_FETCH_LIMIT)
        .get();
  }));

  let truncated = false;
  const candidates = new Map();
  for (const snapshot of snapshots) {
    const documents = Array.isArray(snapshot.docs) ? snapshot.docs : [];
    if (documents.length >= PER_BOUND_FETCH_LIMIT) truncated = true;
    for (const document of documents.slice(0, PER_BOUND_RESULT_LIMIT)) {
      if (candidates.has(document.id)) continue;
      if (candidates.size >= MAX_CANDIDATES) {
        truncated = true;
        continue;
      }
      candidates.set(document.id, document);
    }
  }

  const matches = [];
  for (const document of candidates.values()) {
    const data = document.data() || {};
    const point = pointCoordinates(data.mapPoint);
    if (!point) continue;
    const distanceKm = geofireApi.distanceBetween(point, center);
    if (!Number.isFinite(distanceKm) || distanceKm > radiusKm) continue;
    const result = publicDirectoryResult(document, distanceKm);
    if (result && result.id && result.operatingName) matches.push(result);
  }
  matches.sort((left, right) =>
    left.distanceKm - right.distanceKm ||
    left.operatingName.localeCompare(right.operatingName));
  if (matches.length > limit) truncated = true;

  return {
    results: matches.slice(0, limit),
    resultCount: Math.min(matches.length, limit),
    candidateCount: candidates.size,
    queryBounds: bounds.length,
    truncated,
  };
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError || error instanceof FeatureFlagError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch Directory radius search failed", error);
      throw new HttpsError(
          "internal",
          "The Directory radius search could not be completed.",
      );
    }
  };
}

function createDispatchDirectorySearch(admin, options = {}) {
  const db = admin.firestore();
  const geofireApi = options.geofireApi || geofire;
  const searchDispatchDirectoryRadius = command(async (request) => {
    requireAuthenticatedIdentity(request);
    const flags = await loadPhase1FeatureFlags(db);
    requirePhase1Feature(flags, "dispatch");
    await enforceUserRateLimit({
      db,
      admin,
      request,
      scope: "directory",
    });
    const input = validateRadiusSearchInput(request.data || {});
    const response = await queryDirectoryRadius({
      db,
      geofireApi,
      center: input.center,
      radiusKm: input.radiusKm,
      limit: input.resultLimit,
    });
    return {
      center: {latitude: input.center[0], longitude: input.center[1]},
      radiusKm: input.radiusKm,
      ...response,
    };
  });
  return {searchDispatchDirectoryRadius};
}

module.exports = {
  DEFAULT_RESULT_LIMIT,
  MAX_CANDIDATES,
  MAX_QUERY_BOUNDS,
  MAX_RADIUS_KM,
  MAX_RESULT_LIMIT,
  PER_BOUND_FETCH_LIMIT,
  PER_BOUND_RESULT_LIMIT,
  createDispatchDirectorySearch,
  pointCoordinates,
  publicDirectoryResult,
  queryDirectoryRadius,
  validateRadiusSearchInput,
};
