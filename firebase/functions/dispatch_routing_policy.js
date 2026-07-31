"use strict";

const crypto = require("node:crypto");

const ROUTE_VERSION = 1;
const EARTH_RADIUS_KM = 6371.0088;
const HERE_ROUTING_ENDPOINT = "https://router.hereapi.com/v8/routes";

function coordinate(point, key) {
  if (!point || point[key] == null) return null;
  const value = Number(point[key]);
  return Number.isFinite(value) ? value : null;
}

function normalizedPoint(point) {
  const latitude = coordinate(point, "latitude");
  const longitude = coordinate(point, "longitude");
  if (
    latitude == null || longitude == null ||
    latitude < -90 || latitude > 90 ||
    longitude < -180 || longitude > 180
  ) return null;
  return {latitude, longitude};
}

function rounded(value, places = 1) {
  const scale = 10 ** places;
  return Math.round(value * scale) / scale;
}

function straightLineDistanceKm(origin, destination) {
  const from = normalizedPoint(origin);
  const to = normalizedPoint(destination);
  if (!from || !to) return null;
  const radians = (degrees) => degrees * Math.PI / 180;
  const lat1 = radians(from.latitude);
  const lat2 = radians(to.latitude);
  const deltaLat = radians(to.latitude - from.latitude);
  const deltaLon = radians(to.longitude - from.longitude);
  const a = Math.sin(deltaLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLon / 2) ** 2;
  return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function routeInputHash(origin, destination, vehicle = {}) {
  const from = normalizedPoint(origin);
  const to = normalizedPoint(destination);
  if (!from || !to) return null;
  const payload = {
    origin: [rounded(from.latitude, 5), rounded(from.longitude, 5)],
    destination: [rounded(to.latitude, 5), rounded(to.longitude, 5)],
    vehicle: {
      currentWeightKg: Number(vehicle.currentWeightKg || 0),
      grossWeightKg: Number(vehicle.grossWeightKg || 0),
      heightM: Number(vehicle.heightM || 0),
      widthM: Number(vehicle.widthM || 0),
      lengthM: Number(vehicle.lengthM || 0),
      axleWeightKg: Number(vehicle.axleWeightKg || 0),
    },
    version: ROUTE_VERSION,
  };
  return crypto.createHash("sha256").update(JSON.stringify(payload)).digest("hex");
}

/**
 * Creates the server-owned route state persisted on a public Dispatch job.
 * Exact coordinates are intentionally excluded from the returned object.
 */
function buildDispatchRouteState(origin, destination, options = {}) {
  const directDistance = straightLineDistanceKm(origin, destination);
  if (directDistance == null) {
    return {
      routeStatus: "needs_mapped_points",
      routeProfile: "truck",
      routeProvider: "not_configured",
      routeVersion: ROUTE_VERSION,
    };
  }
  const providerConfigured = options.providerConfigured === true;
  return {
    routeStatus: providerConfigured ? "pending_provider" : "provider_not_configured",
    routeProfile: "truck",
    routeProvider: providerConfigured ? "here" : "not_configured",
    routeVersion: ROUTE_VERSION,
    straightLineDistanceKm: rounded(directDistance),
    distanceKm: rounded(directDistance),
    distanceSource: "server_straight_line_estimate",
    routeInputHash: routeInputHash(origin, destination, options.vehicle),
  };
}

function addPositiveVehicleParameter(params, name, value, divisor = 1) {
  const number = Number(value);
  if (Number.isFinite(number) && number > 0) {
    params.set(`vehicle[${name}]`, String(rounded(number / divisor, 3)));
  }
}

/** Builds a HERE truck-routing request without ever embedding an API key. */
function createHereTruckRouteRequest(origin, destination, vehicle = {}) {
  const from = normalizedPoint(origin);
  const to = normalizedPoint(destination);
  if (!from || !to) throw new Error("Mapped pickup and delivery points are required.");
  const url = new URL(HERE_ROUTING_ENDPOINT);
  url.searchParams.set("transportMode", "truck");
  url.searchParams.set("routingMode", "fast");
  url.searchParams.set("origin", `${from.latitude},${from.longitude}`);
  url.searchParams.set("destination", `${to.latitude},${to.longitude}`);
  url.searchParams.set("return", "summary");
  addPositiveVehicleParameter(url.searchParams, "currentWeight", vehicle.currentWeightKg);
  addPositiveVehicleParameter(url.searchParams, "grossWeight", vehicle.grossWeightKg);
  addPositiveVehicleParameter(url.searchParams, "height", vehicle.heightM);
  addPositiveVehicleParameter(url.searchParams, "width", vehicle.widthM);
  addPositiveVehicleParameter(url.searchParams, "length", vehicle.lengthM);
  addPositiveVehicleParameter(url.searchParams, "weightPerAxle", vehicle.axleWeightKg);
  return url.toString();
}

function parseHereTruckRouteResponse(payload) {
  const route = payload && Array.isArray(payload.routes) ? payload.routes[0] : null;
  if (!route || !Array.isArray(route.sections) || route.sections.length === 0) {
    throw new Error("The truck routing provider returned no usable route.");
  }
  let lengthMetres = 0;
  let durationSeconds = 0;
  const notices = [
    ...(Array.isArray(payload.notices) ? payload.notices : []),
    ...(Array.isArray(route.notices) ? route.notices : []),
  ];
  for (const section of route.sections) {
    const length = Number(section && section.summary && section.summary.length);
    const duration = Number(section && section.summary && section.summary.duration);
    if (!Number.isFinite(length) || length < 0) {
      throw new Error("The truck routing provider returned an invalid distance.");
    }
    lengthMetres += length;
    if (Number.isFinite(duration) && duration >= 0) durationSeconds += duration;
    if (Array.isArray(section.notices)) notices.push(...section.notices);
  }
  const hasCriticalNotice = notices.some((notice) =>
    ["critical", "error"].includes(String(notice && notice.severity || "").toLowerCase()),
  );
  return {
    routeStatus: hasCriticalNotice ? "review_required" : "ready",
    routeProfile: "truck",
    routeProvider: "here",
    routeVersion: ROUTE_VERSION,
    routeDistanceKm: rounded(lengthMetres / 1000),
    routeDurationSeconds: Math.round(durationSeconds),
    routeNoticeCount: notices.length,
  };
}

module.exports = {
  HERE_ROUTING_ENDPOINT,
  ROUTE_VERSION,
  buildDispatchRouteState,
  createHereTruckRouteRequest,
  normalizedPoint,
  parseHereTruckRouteResponse,
  routeInputHash,
  straightLineDistanceKm,
};
