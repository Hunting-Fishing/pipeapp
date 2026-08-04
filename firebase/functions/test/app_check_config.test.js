"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  environmentBoolean,
  enforceAppCheck,
  protectedCallableOptions,
} = require("../app_check_config");

test("App Check enforcement follows the deploy-time boolean with a safe parser default", () => {
  assert.equal(
    enforceAppCheck,
    environmentBoolean("PIPE_ENFORCE_APP_CHECK", false),
  );
  assert.equal(environmentBoolean("PIPE_TEST_MISSING_FLAG"), false);
  process.env.PIPE_TEST_BOOLEAN = "true";
  assert.equal(environmentBoolean("PIPE_TEST_BOOLEAN"), true);
  process.env.PIPE_TEST_BOOLEAN = "false";
  assert.equal(environmentBoolean("PIPE_TEST_BOOLEAN", true), false);
  delete process.env.PIPE_TEST_BOOLEAN;
  assert.equal(protectedCallableOptions.enforceAppCheck, enforceAppCheck);
  assert.equal(Object.isFrozen(protectedCallableOptions), true);
});
