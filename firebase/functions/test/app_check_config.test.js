"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  enforceAppCheck,
  protectedCallableOptions,
} = require("../app_check_config");

test("App Check enforcement is a deploy-time boolean with a safe default", () => {
  assert.equal(enforceAppCheck.name, "PIPE_ENFORCE_APP_CHECK");
  assert.equal(enforceAppCheck.options.default, false);
  assert.equal(protectedCallableOptions.enforceAppCheck, enforceAppCheck);
  assert.equal(Object.isFrozen(protectedCallableOptions), true);
});
