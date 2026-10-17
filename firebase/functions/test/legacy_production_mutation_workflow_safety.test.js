const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const repositoryRoot = path.resolve(__dirname, "../../..");
const workflowDirectory = path.join(repositoryRoot, ".github", "workflows");
const safetyHoldName = "Intentional production safety hold";
const safetyHoldMessage =
  "Historical production mutation workflow is intentionally disabled.";

const legacyProductionMutators = [
  "bootstrap-stripe-webhook.yml",
  "activate-dispatch-portal-production-20260830.yml",
  "activate-live-billing-pending-tax.yml",
  "activate-vip-monthly-production-20260829.yml",
  "complete-marketplace-payment-activation-20260829.yml",
  "complete-stripe-live-alignment-custom-header-2026-08-29.yml",
  "complete-stripe-live-alignment-final-2026-08-29.yml",
  "finalize-live-billing-activation.yml",
  "retry-live-billing-activation.yml",
  "retry-vip-monthly-production-activation-20260829.yml",
  "release-stripe-live-alignment-2026-08-29.yml",
  "retry-stripe-live-alignment-after-test-fix-2026-08-29.yml",
  "finish-stripe-live-alignment-after-invoker-fix-2026-08-29.yml",
  "release-vip-monthly-live-20260829.yml",
  "release-marketplace-payments-live-20260829.yml",
  "release-subscription-ui-live-20260829.yml",
  "deploy-payment-backend-safe.yml",
  "deploy-payment-readiness-control.yml",
  "sync-stripe-production-secret.yml",
];

for (const workflowName of legacyProductionMutators) {
  test(`${workflowName} fails at its first step under the production safety hold`, () => {
    const source = fs.readFileSync(
      path.join(workflowDirectory, workflowName),
      "utf8",
    );
    const stepsIndex = source.indexOf("    steps:");
    const holdIndex = source.indexOf(safetyHoldName, stepsIndex);

    assert.notEqual(stepsIndex, -1, "workflow must declare job steps");
    assert.ok(holdIndex > stepsIndex, "safety hold must follow the steps key");
    assert.match(source, new RegExp(safetyHoldMessage.replace(".", "\\.")));
    assert.match(
      source.slice(stepsIndex, holdIndex + safetyHoldName.length),
      /steps:\r?\n      - name: Intentional production safety hold/u,
      "safety hold must be the first workflow step",
    );
    assert.match(
      source.slice(holdIndex),
      /Intentional production safety hold[\s\S]*?\n          exit 1(?:\r?\n|$)/u,
      "safety hold must explicitly fail before later steps can mutate state",
    );
  });
}

test("the dated launch audit is visibly superseded for payment activation", () => {
  const audit = fs.readFileSync(
    path.join(
      repositoryRoot,
      "docs",
      "PIPE_BUYER_LAUNCH_READINESS_AUDIT_2026-08-30.md",
    ),
    "utf8",
  );

  assert.match(audit, /SUPERSEDED FOR PAYMENT ACTIVATION/u);
  assert.match(audit, /must not be used to enable production billing/u);
});
