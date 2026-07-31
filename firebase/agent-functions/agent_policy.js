"use strict";

const supportedOperations = Object.freeze(["status"]);

class AgentPolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "AgentPolicyError";
    this.code = code;
  }
}

function environmentBoolean(environment, name, defaultValue = false) {
  const value = environment[name];
  if (value == null || String(value).trim() === "") return defaultValue;
  return String(value).trim().toLowerCase() === "true";
}

function environmentInteger(environment, name, defaultValue, minimum, maximum) {
  const raw = environment[name];
  if (raw == null || String(raw).trim() === "") return defaultValue;
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    throw new Error(`${name} must be an integer from ${minimum} to ${maximum}.`);
  }
  return value;
}

function loadAgentConfiguration(environment = process.env) {
  const enabled = environmentBoolean(environment, "PIPE_AGENT_ENABLED", false);
  const minInstances = environmentInteger(
      environment,
      "PIPE_AGENT_MIN_INSTANCES",
      0,
      0,
      3,
  );
  const maxInstances = environmentInteger(
      environment,
      "PIPE_AGENT_MAX_INSTANCES",
      3,
      1,
      10,
  );
  if (minInstances > maxInstances) {
    throw new Error("PIPE_AGENT_MIN_INSTANCES cannot exceed the maximum.");
  }
  if (!enabled && minInstances !== 0) {
    throw new Error("A disabled agent must use zero minimum instances.");
  }
  return Object.freeze({enabled, minInstances, maxInstances});
}

function requireAdministratorContext(context) {
  if (!context || !context.auth) {
    throw new AgentPolicyError(
        "unauthenticated",
        "Sign in before using administrator tools.",
    );
  }
  const token = context.auth.token || {};
  const firebase = token.firebase || {};
  if (token.admin !== true || token.role !== "administrator" ||
      typeof firebase.sign_in_second_factor !== "string" ||
      firebase.sign_in_second_factor.trim() === "") {
    throw new AgentPolicyError(
        "permission-denied",
        "Administrator access requires an approved role and MFA session.",
    );
  }
  if (!context.app) {
    throw new AgentPolicyError(
        "failed-precondition",
        "A valid App Check token is required.",
    );
  }
  return context.auth.uid;
}

function normalizeRequest(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new AgentPolicyError("invalid-argument", "A request object is required.");
  }
  const operation = String(data.operation || "").trim();
  if (!supportedOperations.includes(operation)) {
    throw new AgentPolicyError(
        "unimplemented",
        "This administrative operation has not been approved for Phase 2.",
    );
  }
  const requestId = String(data.requestId || "").trim();
  if (!/^[A-Za-z0-9_-]{8,128}$/u.test(requestId)) {
    throw new AgentPolicyError(
        "invalid-argument",
        "Provide a valid requestId between 8 and 128 characters.",
    );
  }
  return Object.freeze({operation, requestId});
}

function createAgentHandler({configuration, writeAudit, now = () => new Date()}) {
  if (!configuration || typeof writeAudit !== "function") {
    throw new Error("Agent handler dependencies are required.");
  }
  return async (data, context) => {
    const administratorUid = requireAdministratorContext(context);
    if (configuration.enabled !== true) {
      throw new AgentPolicyError(
          "failed-precondition",
          "The administrative agent is disabled for this release.",
      );
    }
    const request = normalizeRequest(data);
    const occurredAt = now().toISOString();
    await writeAudit({
      actorUid: administratorUid,
      operation: request.operation,
      requestId: request.requestId,
      occurredAt,
      outcome: "allowed",
    });
    return {
      enabled: true,
      mode: "phase2-foundation",
      operation: request.operation,
      requestId: request.requestId,
      occurredAt,
    };
  };
}

module.exports = {
  AgentPolicyError,
  createAgentHandler,
  environmentBoolean,
  environmentInteger,
  loadAgentConfiguration,
  normalizeRequest,
  requireAdministratorContext,
  supportedOperations,
};
