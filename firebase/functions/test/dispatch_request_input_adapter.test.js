"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  adaptDispatchRequestInput,
  deriveRequestPath,
  normalizeServiceCodes,
} = require("../dispatch_request_input_adapter");

test("server derives freight path from transportation and pilot services", () => {
  assert.equal(deriveRequestPath(["transport_pipe_hauling"]), "freight_route");
  assert.equal(deriveRequestPath(["pilot_route_survey"]), "freight_route");
  assert.equal(
      deriveRequestPath(["field_vacuum_truck", "transport_flat_deck"]),
      "freight_route",
  );
});

test("server derives field-service path from crane and field services", () => {
  assert.equal(deriveRequestPath(["crane_picker_truck"]), "field_service");
  assert.equal(deriveRequestPath(["field_vacuum_truck"]), "field_service");
});

test("unknown or excessive service codes fail closed", () => {
  assert.throws(
      () => normalizeServiceCodes(["unknown_service"]),
      (error) => error && error.code === "invalid-argument",
  );
  assert.throws(
      () => normalizeServiceCodes(Array(9).fill("field_vacuum_truck")),
      (error) => error && error.code === "invalid-argument",
  );
});

test("legacy clients pass through unchanged", () => {
  const input = {jobId: "job-1", pickupLabel: "A", deliveryLabel: "B"};
  assert.deepEqual(adaptDispatchRequestInput(input), {
    enhanced: false,
    commandData: input,
    metadata: null,
  });
});

test("field service uses a work-site label without manufacturing a route point", () => {
  const result = adaptDispatchRequestInput({
    serviceCodes: ["field_vacuum_truck"],
    requestPath: "field_service",
    contactPreference: "in_app",
    pickupLabel: "Lease 12-34",
    pickupPoint: {latitude: 55.1, longitude: -117.2},
    deliveryLabel: "",
    deliveryPoint: {latitude: 55.1, longitude: -117.2},
  });
  assert.equal(result.metadata.requestPath, "field_service");
  assert.equal(result.metadata.routeRelevant, false);
  assert.deepEqual(result.metadata.serviceCodes, ["field_vacuum_truck"]);
  assert.equal(result.commandData.deliveryLabel, "Lease 12-34");
  assert.equal("deliveryPoint" in result.commandData, false);
  assert.equal("serviceCodes" in result.commandData, false);
});

test("contact preferences require the selected verified account contact", () => {
  assert.throws(
      () => adaptDispatchRequestInput({
        serviceCodes: ["field_mobile_mechanic"],
        pickupLabel: "Lease",
        contactPreference: "phone",
      }, {phoneNumber: "+17805550123", phoneVerified: false}),
      (error) => error && error.code === "failed-precondition",
  );
  assert.throws(
      () => adaptDispatchRequestInput({
        serviceCodes: ["field_mobile_mechanic"],
        pickupLabel: "Lease",
        contactPreference: "email",
      }, {email: "member@example.com", emailVerified: false}),
      (error) => error && error.code === "failed-precondition",
  );
  const phone = adaptDispatchRequestInput({
    serviceCodes: ["field_mobile_mechanic"],
    pickupLabel: "Lease",
    contactPreference: "phone",
  }, {
    phoneNumber: "+17805550123",
    phoneVerified: true,
  });
  assert.equal(phone.metadata.contactPreference, "phone");
  const email = adaptDispatchRequestInput({
    serviceCodes: ["field_mobile_mechanic"],
    pickupLabel: "Lease",
    contactPreference: "email",
  }, {
    email: "member@example.com",
    emailVerified: true,
  });
  assert.equal(email.metadata.contactPreference, "email");
});

test("client cannot contradict server-derived request path", () => {
  assert.throws(
      () => adaptDispatchRequestInput({
        serviceCodes: ["field_vacuum_truck"],
        requestPath: "freight_route",
        pickupLabel: "Lease",
      }),
      (error) => error && error.code === "invalid-argument",
  );
});
