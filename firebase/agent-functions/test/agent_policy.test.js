"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  AgentPolicyError,
  createAgentHandler,
  loadAgentConfiguration,
  normalizeRequest,
  requireAdministratorContext,
} = require("../agent_policy");

const approvedContext = {
  app: {appId: "phase2-test-app"},
  auth: {
    uid: "approved-admin",
    token: {
      admin: true,
      role: "administrator",
      firebase: {sign_in_second_factor: "phone"},
    },
  },
};

test("configuration is disabled and cold by default", () => {
  assert.deepEqual(loadAgentConfiguration({}), {
    enabled: false,
    minInstances: 0,
    maxInstances: 3,
  });
  assert.throws(
      () => loadAgentConfiguration({PIPE_AGENT_MIN_INSTANCES: "1"}),
      /disabled agent must use zero/u,
  );
  assert.throws(
      () => loadAgentConfiguration({PIPE_AGENT_MAX_INSTANCES: "20"}),
      /integer from 1 to 10/u,
  );
});

test("authorization requires admin role, MFA, and App Check", () => {
  assert.equal(requireAdministratorContext(approvedContext), "approved-admin");
  for (const context of [
    {},
    {auth: {uid: "user", token: {}}},
    {auth: approvedContext.auth},
  ]) {
    assert.throws(
        () => requireAdministratorContext(context),
        (error) => error instanceof AgentPolicyError,
    );
  }
});

test("only bounded, approved operations are accepted", () => {
  assert.deepEqual(normalizeRequest({
    operation: "status",
    requestId: "request_1234",
  }), {operation: "status", requestId: "request_1234"});
  assert.throws(
      () => normalizeRequest({operation: "deleteAll", requestId: "request_1234"}),
      (error) => error.code === "unimplemented",
  );
  assert.throws(
      () => normalizeRequest({operation: "status", requestId: "short"}),
      (error) => error.code === "invalid-argument",
  );
});

test("disabled execution fails closed after authorization", async () => {
  const handler = createAgentHandler({
    configuration: loadAgentConfiguration({}),
    writeAudit: async () => assert.fail("audit must not run"),
  });
  await assert.rejects(
      () => handler({operation: "status", requestId: "request_1234"}, approvedContext),
      (error) => error.code === "failed-precondition",
  );
});

test("enabled status execution is audited and deterministic", async () => {
  const audits = [];
  const handler = createAgentHandler({
    configuration: loadAgentConfiguration({PIPE_AGENT_ENABLED: "true"}),
    writeAudit: async (event) => audits.push(event),
    now: () => new Date("2026-07-31T00:00:00.000Z"),
  });
  const result = await handler(
      {operation: "status", requestId: "request_1234"},
      approvedContext,
  );
  assert.equal(result.mode, "phase2-foundation");
  assert.equal(result.occurredAt, "2026-07-31T00:00:00.000Z");
  assert.deepEqual(audits, [{
    actorUid: "approved-admin",
    operation: "status",
    requestId: "request_1234",
    occurredAt: "2026-07-31T00:00:00.000Z",
    outcome: "allowed",
  }]);
});
