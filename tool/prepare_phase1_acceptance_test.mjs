import assert from "node:assert/strict";
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {deviceTargetIds} from "./phase1_acceptance.mjs";
import {preparePhase1AcceptanceBundle} from "./prepare_phase1_acceptance.mjs";

const template = JSON.parse(
    readFileSync(new URL("../docs/phase1_acceptance_template.json", import.meta.url)),
);

function manifest(environment = "staging") {
  return {
    schemaVersion: 2,
    release: {
      environment,
      commitSha: "a".repeat(40),
    },
  };
}

test("prepares a pending bundle bound to one controlled release", () => {
  const outputRoot = path.join(mkdtempSync(path.join(os.tmpdir(), "pipe-prep-")), "evidence");
  const result = preparePhase1AcceptanceBundle({
    releaseManifest: manifest(),
    template,
    outputRoot,
    versionName: "1.2.3",
    buildNumber: "42",
    publicBaseUrl: "https://app.pipebuyer.test/company",
  });
  const evidence = JSON.parse(readFileSync(result.evidenceFile));
  assert.equal(evidence.environment, "staging");
  assert.equal(evidence.releaseSha, "a".repeat(40));
  assert.ok(evidence.journeys.every((item) => item.status === "pending"));
  assert.ok(evidence.signoffs.every((item) => item.status === "pending"));
  assert.ok(evidence.mobileRelease.releaseCandidates.every((candidate) =>
    candidate.builtFromSha === "a".repeat(40) &&
    candidate.versionName === "1.2.3" && candidate.buildNumber === "42" &&
    candidate.signatureVerified === false && candidate.storeValidated === false));
  assert.ok(evidence.mobileRelease.deviceRuns.every((device) =>
    device.releaseSha === "a".repeat(40) && device.status === "pending"));
  assert.equal(
      evidence.mobileRelease.storeListings[0].privacyUrl,
      "https://app.pipebuyer.test/company/privacy",
  );
  assert.ok(existsSync(result.checklistFile));
  for (const id of deviceTargetIds) {
    assert.ok(existsSync(path.join(outputRoot, "devices", id)), id);
  }
});

test("refuses unsafe release metadata and public URLs", () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "pipe-prep-invalid-"));
  const prepare = (overrides = {}) => preparePhase1AcceptanceBundle({
    releaseManifest: manifest(),
    template,
    outputRoot: path.join(root, `${Math.random()}`),
    versionName: "1.0.0",
    buildNumber: "1",
    ...overrides,
  });
  assert.throws(
      () => prepare({releaseManifest: manifest("local-verification")}),
      /staging or production/u,
  );
  assert.throws(() => prepare({versionName: "version one"}), /semantic version/u);
  assert.throws(() => prepare({buildNumber: "0"}), /positive integer/u);
  assert.throws(
      () => prepare({publicBaseUrl: "http://localhost:7357"}),
      /must use HTTPS/u,
  );
});

test("never overwrites an existing acceptance bundle", () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "pipe-prep-existing-"));
  const outputRoot = path.join(root, "acceptance");
  const input = {
    releaseManifest: manifest("production"),
    template,
    outputRoot,
    versionName: "2.0.0",
    buildNumber: "7",
  };
  preparePhase1AcceptanceBundle(input);
  const evidencePath = path.join(outputRoot, "phase1-acceptance.json");
  const original = readFileSync(evidencePath, "utf8");
  assert.throws(() => preparePhase1AcceptanceBundle(input), /refusing to overwrite/u);
  writeFileSync(path.join(outputRoot, "unrelated.txt"), "retained");
  assert.equal(readFileSync(evidencePath, "utf8"), original);
});
