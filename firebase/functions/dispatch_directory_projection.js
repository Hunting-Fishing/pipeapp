"use strict";

const GEOHASH_BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";
const MAX_SEARCH_TOKENS = 80;
const MAX_SERVICE_CODES = 64;
const MAX_SUMMARY_LENGTH = 600;

function plainObject(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function cleanText(value, maxLength = 240) {
  return String(value || "").trim().replace(/\s+/g, " ").slice(0, maxLength);
}

function cleanCode(value) {
  const text = cleanText(value, 96).toLowerCase();
  return /^[a-z0-9][a-z0-9_.:-]*$/.test(text) ? text : "";
}

function cleanCodes(value, limit = MAX_SERVICE_CODES) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.map(cleanCode).filter(Boolean))].sort().slice(0, limit);
}

function cleanStringList(value, {limit = 80, maxLength = 160, upper = false} = {}) {
  if (!Array.isArray(value)) return [];
  const values = value
      .map((item) => cleanText(item, maxLength))
      .filter(Boolean)
      .map((item) => upper ? item.toUpperCase() : item);
  return [...new Set(values)].slice(0, limit);
}

function tokenize(...values) {
  const tokens = new Set();
  const add = (value) => {
    const text = cleanText(value, 1000).toLowerCase();
    for (const token of text.split(/[^a-z0-9]+/g)) {
      if (token.length >= 2 && token.length <= 48) tokens.add(token);
      if (tokens.size >= MAX_SEARCH_TOKENS) return;
    }
  };
  for (const value of values.flat(Infinity)) {
    add(value);
    if (tokens.size >= MAX_SEARCH_TOKENS) break;
  }
  return [...tokens].sort();
}

function coordinateValue(point, field) {
  if (!point) return null;
  const direct = point[field];
  if (Number.isFinite(direct)) return Number(direct);
  const alias = field === "latitude" ? point.lat : point.lng;
  return Number.isFinite(alias) ? Number(alias) : null;
}

function encodeGeohash(latitude, longitude, precision = 6) {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return "";
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return "";
  let latRange = [-90, 90];
  let lonRange = [-180, 180];
  let bit = 0;
  let charValue = 0;
  let even = true;
  let hash = "";

  while (hash.length < precision) {
    const range = even ? lonRange : latRange;
    const value = even ? longitude : latitude;
    const mid = (range[0] + range[1]) / 2;
    if (value >= mid) {
      charValue = (charValue << 1) | 1;
      range[0] = mid;
    } else {
      charValue <<= 1;
      range[1] = mid;
    }
    even = !even;
    bit += 1;
    if (bit === 5) {
      hash += GEOHASH_BASE32[charValue];
      bit = 0;
      charValue = 0;
    }
  }
  return hash;
}

function publicGeography(dispatchProfile = {}) {
  const profile = plainObject(dispatchProfile);
  const home = plainObject(profile.homeLocation);
  const serviceArea = plainObject(profile.serviceArea);
  const point = home.point || serviceArea.center || null;
  const latitude = coordinateValue(point, "latitude");
  const longitude = coordinateValue(point, "longitude");
  const precision = cleanCode(home.precision) || "approximate_1km";

  const geography = {
    mode: cleanCode(serviceArea.mode),
    centerLabel: cleanText(serviceArea.centerLabel || home.label, 200),
    radiusKm: Number.isFinite(Number(serviceArea.radiusKm)) ?
      Math.max(0, Math.min(5000, Number(serviceArea.radiusKm))) : 0,
    countryCodes: cleanStringList(serviceArea.countryCodes, {
      limit: 32,
      maxLength: 4,
      upper: true,
    }),
    regionKeys: cleanStringList(serviceArea.regionKeys, {limit: 120, maxLength: 180}),
    placeKeys: cleanStringList(serviceArea.placeKeys, {limit: 240, maxLength: 180}),
  };

  return {
    mapPoint: latitude == null || longitude == null ? null : point,
    geohash: latitude == null || longitude == null ? "" : encodeGeohash(latitude, longitude, 6),
    publicLocation: {
      label: cleanText(home.label || serviceArea.centerLabel, 200),
      precision,
      source: cleanCode(home.source) || "service_area_center",
    },
    geography,
  };
}

function buildDispatchDirectoryEntry({businessId, publicBusiness, carrier}) {
  const business = plainObject(publicBusiness);
  const carrierData = plainObject(carrier);
  const profile = plainObject(business.dispatchProfile);
  const activeProvider = cleanCode(carrierData.status) === "active" &&
    carrierData.availableForHire !== false;
  if (!activeProvider) return null;

  const operatingName = cleanText(profile.operatingName || business.publicName, 180);
  const serviceCodes = cleanCodes(profile.serviceCodes);
  const serviceAreaSummary = cleanText(
      profile.serviceAreaLabel || business.serviceAreaLabel,
      260,
  );
  if (!operatingName || serviceCodes.length === 0 || !serviceAreaSummary) return null;

  const availability = cleanCode(profile.availability) || "unavailable";
  const businessType = cleanCode(profile.businessType) || "other";
  const description = cleanText(profile.description || business.description, MAX_SUMMARY_LENGTH);
  const website = cleanText(profile.website || business.website, 260);
  const geography = publicGeography(profile);
  const capabilityTokens = [
    ...serviceCodes.map((code) => `service:${code}`),
    `business_type:${businessType}`,
    `availability:${availability}`,
    ...(profile.emergencyCallout === true ? ["emergency_callout"] : []),
    ...(profile.remoteSiteCapable === true ? ["remote_site"] : []),
  ];

  return {
    schemaVersion: 1,
    companyId: cleanText(businessId, 180),
    companyName: operatingName,
    operatingName,
    serviceCodes,
    capabilityTokens: [...new Set(capabilityTokens)].sort(),
    searchTokens: tokenize(
        operatingName,
        description,
        serviceAreaSummary,
        businessType,
        availability,
        serviceCodes,
        geography.geography.countryCodes,
        geography.geography.regionKeys,
        geography.geography.placeKeys,
    ),
    publicLocation: geography.publicLocation,
    serviceAreaSummary,
    publicServiceArea: geography.geography,
    ...(geography.mapPoint ? {mapPoint: geography.mapPoint} : {}),
    ...(geography.geohash ? {geohash: geography.geohash} : {}),
    availability,
    businessType,
    verified: false,
    emergencyCallout: profile.emergencyCallout === true,
    remoteSiteCapable: profile.remoteSiteCapable === true,
    publicSummary: description,
    website,
    profileCompleteness: Math.max(
        0,
        Math.min(100, Number(profile.profileCompleteness) || 0),
    ),
  };
}

function createDispatchDirectoryProjection(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function syncCompany(companyId) {
    const id = cleanText(companyId, 180);
    if (!id || id.includes("/")) throw new Error("Invalid Dispatch directory company id.");
    const publicRef = db.collection("public_business_profiles").doc(id);
    const carrierRef = db.collection("dispatch_carriers").doc(id);
    const directoryRef = db.collection("dispatch_directory_entries").doc(id);
    const [publicSnapshot, carrierSnapshot] = await Promise.all([
      publicRef.get(),
      carrierRef.get(),
    ]);

    if (!publicSnapshot.exists || !carrierSnapshot.exists) {
      await directoryRef.delete().catch((error) => {
        if (error && error.code !== 5) throw error;
      });
      return {companyId: id, published: false, reason: "source_missing"};
    }

    const entry = buildDispatchDirectoryEntry({
      businessId: id,
      publicBusiness: publicSnapshot.data() || {},
      carrier: carrierSnapshot.data() || {},
    });
    if (!entry) {
      await directoryRef.delete().catch((error) => {
        if (error && error.code !== 5) throw error;
      });
      return {companyId: id, published: false, reason: "not_directory_ready"};
    }

    await directoryRef.set({
      ...entry,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: false});
    return {companyId: id, published: true};
  }

  return {syncCompany};
}

module.exports = {
  buildDispatchDirectoryEntry,
  cleanCodes,
  createDispatchDirectoryProjection,
  encodeGeohash,
  publicGeography,
  tokenize,
};
