"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const workflow = fs.readFileSync(
    path.resolve(__dirname, "..", "..", "..", ".github", "workflows", "deploy.yml"),
    "utf8",
);

test("production deployment fails closed unless App Check is enforced", () => {
  assert.match(
      workflow,
      /\[\[ "\$PIPE_ENV" == "production" && "\$PIPE_APP_CHECK_MODE" != "enforce" \]\]/u,
  );
  assert.match(
      workflow,
      /Production releases require app_check_mode=enforce/u,
  );
});

test("deployment materializes the project-specific Functions environment", () => {
  assert.match(
      workflow,
      /firebase\/functions\/\.env\.\$\{PIPE_FIREBASE_PROJECT_ID\}/u,
  );
  assert.match(workflow, /PIPE_ENFORCE_APP_CHECK=%s/u);
  assert.match(
      workflow,
      /Functions App Check deployment option was not persisted/u,
  );
});
