"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  buildDispatchRouteState,
  createHereTruckRouteRequest,
  parseHereTruckRouteResponse,
  routeInputHash,
  straightLineDistanceKm,
} = require("../dispatch_routing_policy");

const origin = {latitude: 55.1707, longitude: -118.7947};
const destination = {latitude: 55.7596, longitude: -120.2377};

test("server route state labels Haversine distance as an estimate", () => {
  const distance = straightLineDistanceKm(origin, destination);
  assert.ok(distance > 100 && distance < 130);
  const state = buildDispatchRouteState(origin, destination);
  assert.equal(state.routeStatus, "provider_not_configured");
  assert.equal(state.routeProfile, "truck");
  assert.equal(state.distanceSource, "server_straight_line_estimate");
  assert.equal(state.distanceKm, state.straightLineDistanceKm);
  assert.match(state.routeInputHash, /^[a-f0-9]{64}$/);
  assert.equal(JSON.stringify(state).includes("55.1707"), false);
});

test("route input hashes are deterministic and sensitive to vehicle limits", () => {
  const first = routeInputHash(origin, destination, {grossWeightKg: 42000});
  const retry = routeInputHash(origin, destination, {grossWeightKg: 42000});
  const changed = routeInputHash(origin, destination, {grossWeightKg: 50000});
  assert.equal(first, retry);
  assert.notEqual(first, changed);
});

test("HERE requests use truck mode and bounded vehicle parameters", () => {
  const request = new URL(createHereTruckRouteRequest(origin, destination, {
    currentWeightKg: 28000,
    grossWeightKg: 42000,
    heightM: 4.1,
    widthM: 3.2,
    lengthM: 24,
    axleWeightKg: 9000,
  }));
  assert.equal(request.protocol, "https:");
  assert.equal(request.searchParams.get("transportMode"), "truck");
  assert.equal(request.searchParams.get("vehicle[currentWeight]"), "28000");
  assert.equal(request.searchParams.get("vehicle[grossWeight]"), "42000");
  assert.equal(request.searchParams.get("vehicle[height]"), "4.1");
  assert.equal(request.searchParams.has("apiKey"), false);
});

test("HERE route responses combine sections and surface critical notices", () => {
  const result = parseHereTruckRouteResponse({
    routes: [{
      sections: [
        {summary: {length: 100000, duration: 3600}, notices: []},
        {
          summary: {length: 32450, duration: 1800},
          notices: [{severity: "critical", title: "Restricted road"}],
        },
      ],
    }],
  });
  assert.equal(result.routeDistanceKm, 132.5);
  assert.equal(result.routeDurationSeconds, 5400);
  assert.equal(result.routeStatus, "review_required");
  assert.equal(result.routeNoticeCount, 1);
});

test("missing mapped points and empty provider routes fail safely", () => {
  assert.equal(
      buildDispatchRouteState(null, destination).routeStatus,
      "needs_mapped_points",
  );
  assert.throws(
      () => createHereTruckRouteRequest(null, destination),
      /Mapped pickup and delivery/,
  );
  assert.throws(
      () => parseHereTruckRouteResponse({routes: []}),
      /no usable route/,
  );
});
