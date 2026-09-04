"use strict";

const {CommandPolicyError} = require("./marketplace_command_policy");
const {
  validateDispatchRequestAttachmentReferences,
} = require("./dispatch_request_attachment_policy");

const SERVICE_PATHS = Object.freeze({
  transport_flat_deck: "freight_route",
  transport_step_deck: "freight_route",
  transport_lowboy: "freight_route",
  transport_winch_truck: "freight_route",
  transport_hotshot: "freight_route",
  transport_pipe_hauling: "freight_route",
  transport_heavy_equipment: "freight_route",
  transport_general_freight: "freight_route",
  transport_local_haul: "freight_route",
  transport_long_distance: "freight_route",
  transport_oversize_overweight: "freight_route",
  transport_dangerous_goods: "freight_route",
  pilot_escort_vehicle: "freight_route",
  pilot_lead_car: "freight_route",
  pilot_chase_car: "freight_route",
  pilot_high_pole: "freight_route",
  pilot_route_survey: "freight_route",
  pilot_traffic_control: "freight_route",
  pilot_permit_assistance: "freight_route",
  crane_picker_truck: "field_service",
  crane_crane_truck: "field_service",
  crane_mobile_crane: "field_service",
  crane_knuckle_boom: "field_service",
  crane_telehandler: "field_service",
  crane_forklift: "field_service",
  crane_rigging: "field_service",
  field_grading: "field_service",
  field_road_maintenance: "field_service",
  field_snow_removal: "field_service",
  field_water_truck: "field_service",
  field_vacuum_truck: "field_service",
  field_hydrovac: "field_service",
  field_mobile_mechanic: "field_service",
  field_mobile_welding: "field_service",
  field_tire_service: "field_service",
  field_fuel_lube: "field_service",
  field_towing_recovery: "field_service",
  field_equipment_servicing: "field_service",
  field_labour: "field_service",
  field_site_support: "field_service",
});

const CONTACT_PREFERENCES = new Set(["in_app", "phone", "email"]);

function normalizeServiceCodes(value) {
  if (!Array.isArray(value) || value.length < 1 || value.length > 8) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Choose between one and eight Dispatch services.",
    );
  }
  const unique = [];
  for (const raw of value) {
    const code = String(raw || "").trim();
    if (!Object.prototype.hasOwnProperty.call(SERVICE_PATHS, code)) {
      throw new CommandPolicyError(
          "invalid-argument",
          "One or more selected Dispatch services are not supported.",
      );
    }
    if (!unique.includes(code)) unique.push(code);
  }
  if (unique.length === 0) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Choose at least one Dispatch service.",
    );
  }
  return unique;
}

function deriveRequestPath(serviceCodes) {
  const paths = new Set(serviceCodes.map((code) => SERVICE_PATHS[code]));
  if (paths.has("freight_route") && paths.has("field_service")) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Transportation or pilot work and on-site services need separate requests.",
    );
  }
  return paths.has("freight_route") ? "freight_route" : "field_service";
}

function normalizeContactPreference(value, identity = {}) {
  const preference = String(value || "in_app").trim();
  if (!CONTACT_PREFERENCES.has(preference)) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Choose a valid Dispatch contact preference.",
    );
  }
  if (preference === "phone" && identity.phoneVerified !== true) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Verify a mobile number before choosing phone as the contact preference.",
    );
  }
  if (preference === "email" && identity.emailVerified !== true) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Verify an email address before choosing email as the contact preference.",
    );
  }
  return preference;
}

function adaptDispatchRequestInput(data, identity = {}) {
  const submitted = data && typeof data === "object" ? data : {};
  if (!Object.prototype.hasOwnProperty.call(submitted, "serviceCodes")) {
    return {
      enhanced: false,
      commandData: {...submitted},
      metadata: null,
    };
  }

  const serviceCodes = normalizeServiceCodes(submitted.serviceCodes);
  const requestPath = deriveRequestPath(serviceCodes);
  const submittedPath = String(submitted.requestPath || "").trim();
  if (submittedPath && submittedPath !== requestPath) {
    throw new CommandPolicyError(
        "invalid-argument",
        "The Dispatch request path does not match the selected services.",
    );
  }
  const contactPreference = normalizeContactPreference(
      submitted.contactPreference,
      identity,
  );
  const attachments = validateDispatchRequestAttachmentReferences(
      submitted.attachments,
  );
  const commandData = {...submitted};
  delete commandData.serviceCodes;
  delete commandData.requestPath;
  delete commandData.contactPreference;
  delete commandData.attachments;

  if (requestPath === "field_service") {
    const workSiteLabel = String(commandData.pickupLabel || "").trim();
    if (!workSiteLabel) {
      throw new CommandPolicyError(
          "invalid-argument",
          "Add the work-site location for this service request.",
      );
    }
    // The established command still requires a freight-shaped delivery label.
    // Use the work-site label only as a compatibility value; do not manufacture
    // a second mapped point or the route engine would expose a meaningless 0 km
    // estimate for an on-site service request.
    if (!String(commandData.deliveryLabel || "").trim()) {
      commandData.deliveryLabel = workSiteLabel;
    }
    delete commandData.deliveryPoint;
  }

  return {
    enhanced: true,
    commandData,
    metadata: {
      requestSchemaVersion: 2,
      requestPath,
      routeRelevant: requestPath === "freight_route",
      serviceCodes,
      contactPreference,
      attachments,
    },
  };
}

module.exports = {
  CONTACT_PREFERENCES,
  SERVICE_PATHS,
  adaptDispatchRequestInput,
  deriveRequestPath,
  normalizeContactPreference,
  normalizeServiceCodes,
};
