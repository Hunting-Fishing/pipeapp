import assert from "node:assert/strict";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  acceptanceJourneyIds,
  deviceTargetIds,
  evaluateAcceptanceEvidence,
  mobileScenarioIds,
  privacyReviewIds,
  recoveryControlIds,
  releaseCandidateIds,
  requiredSignoffRoles,
  storeListingIds,
  webScenarioIds,
} from "./phase1_acceptance.mjs";

function fixture() {
  const root = mkdtempSync(path.join(os.tmpdir(), "pipe-acceptance-"));
  mkdirSync(path.join(root, "journeys"));
  mkdirSync(path.join(root, "recovery"));
  const releaseSha = "a".repeat(40);
  const journeys = acceptanceJourneyIds.map((id) => {
    const evidenceFile = `journeys/${id}.txt`;
    writeFileSync(path.join(root, evidenceFile), `passed ${id}`);
    return {
      id,
      status: "passed",
      tester: "Test Operator",
      evidenceFiles: [evidenceFile],
    };
  });
  const recovery = recoveryControlIds.map((id) => {
    const evidenceFile = `recovery/${id}.txt`;
    writeFileSync(path.join(root, evidenceFile), `passed ${id}`);
    return {
      id,
      status: "passed",
      actualMinutes: 12,
      evidenceFiles: [evidenceFile],
    };
  });
  mkdirSync(path.join(root, "mobile"));
  mkdirSync(path.join(root, "stores"));
  mkdirSync(path.join(root, "privacy"));
  mkdirSync(path.join(root, "devices"));
  const releaseCandidates = releaseCandidateIds.map((id) => {
    const isAndroid = id === "android-aab";
    const artifactFile = `mobile/${id}${isAndroid ? ".aab" : ".ipa"}`;
    const validationFile = `mobile/${id}-validation.txt`;
    writeFileSync(path.join(root, artifactFile), `signed ${id}`);
    writeFileSync(path.join(root, validationFile), `validated ${id}`);
    return {
      id,
      status: "passed",
      platform: isAndroid ? "android" : "ios",
      applicationId: "Pipe.Buyerapp",
      builtFromSha: releaseSha,
      versionName: "1.0.0",
      buildNumber: "1",
      signatureVerified: true,
      storeValidated: true,
      artifactFile,
      evidenceFiles: [validationFile],
    };
  });
  const storeListings = storeListingIds.map((id) => {
    const screenshotFiles = Array.from({length: 4}, (_, index) => {
      const file = `stores/${id}-screenshot-${index + 1}.png`;
      writeFileSync(path.join(root, file), `screenshot ${id} ${index + 1}`);
      return file;
    });
    const evidenceFile = `stores/${id}-review.txt`;
    writeFileSync(path.join(root, evidenceFile), `reviewed ${id}`);
    return {
      id,
      status: "passed",
      reviewedBy: "Store Release Owner",
      reviewedAt: "2026-07-27T12:00:00.000Z",
      supportUrl: "https://pipebuyer.com/support",
      privacyUrl: "https://pipebuyer.com/privacy",
      termsUrl: "https://pipebuyer.com/terms",
      accountDeletionUrl: "https://pipebuyer.com/account-deletion",
      screenshotFiles,
      evidenceFiles: [evidenceFile],
    };
  });
  const privacyReviews = privacyReviewIds.map((id) => {
    const evidenceFile = `privacy/${id}.txt`;
    writeFileSync(path.join(root, evidenceFile), `reviewed ${id}`);
    return {
      id,
      status: "passed",
      reviewedBy: "Privacy Owner",
      reviewedAt: "2026-07-27T12:00:00.000Z",
      evidenceFiles: [evidenceFile],
    };
  });
  const deviceRuns = deviceTargetIds.map((id) => {
    const isWeb = id.startsWith("web-");
    const platform = id.startsWith("android-") ? "android" :
      id.startsWith("ios-") ? "ios" : "web";
    const evidenceFile = `devices/${id}.txt`;
    writeFileSync(path.join(root, evidenceFile), `passed ${id}`);
    return {
      id,
      status: "passed",
      platform,
      releaseSha,
      ...(isWeb ? {} : {
        releaseCandidateId: platform === "android" ? "android-aab" : "ios-ipa",
      }),
      tester: "Device Test Operator",
      deviceModel: id.replaceAll("-", " "),
      osVersion: "current supported",
      assistiveTechnology: platform === "android" ? "TalkBack" :
        platform === "ios" ? "VoiceOver" : "Keyboard and screen reader",
      executedAt: "2026-07-27T12:00:00.000Z",
      scenarios: (isWeb ? webScenarioIds : mobileScenarioIds).map((scenarioId) => ({
        id: scenarioId,
        status: "passed",
      })),
      evidenceFiles: [evidenceFile],
    };
  });
  return {
    root,
    releaseManifest: {
      release: {environment: "staging", commitSha: releaseSha},
    },
    evidence: {
      schemaVersion: 2,
      environment: "staging",
      releaseSha,
      executedAt: "2026-07-27T12:00:00.000Z",
      journeys,
      recovery,
      defects: {
        reviewedAt: "2026-07-27T12:00:00.000Z",
        reviewedBy: "Release Manager",
        items: [{id: "P1-12", severity: "medium", status: "open"}],
      },
      signoffs: requiredSignoffRoles.map((id) => ({
        id,
        status: "approved",
        approvedBy: `${id} owner`,
        approvedAt: "2026-07-27T12:00:00.000Z",
      })),
      mobileRelease: {
        releaseCandidates,
        storeListings,
        privacyReviews,
        deviceRuns,
      },
    },
  };
}

test("complete evidence for one release SHA is accepted", () => {
  const data = fixture();
  const result = evaluateAcceptanceEvidence({
    releaseManifest: data.releaseManifest,
    evidence: data.evidence,
    evidenceRoot: data.root,
  });
  assert.equal(result.ready, true);
  assert.deepEqual(result.findings, []);
  assert.equal(result.journeyCount, acceptanceJourneyIds.length);
  assert.equal(result.recoveryControlCount, recoveryControlIds.length);
  assert.equal(result.signoffCount, requiredSignoffRoles.length);
  assert.equal(result.candidateCount, releaseCandidateIds.length);
  assert.equal(result.storeListingCount, storeListingIds.length);
  assert.equal(result.privacyReviewCount, privacyReviewIds.length);
  assert.equal(result.deviceTargetCount, deviceTargetIds.length);
  assert.equal(
      result.evidenceArtifacts.length,
      acceptanceJourneyIds.length + recoveryControlIds.length +
        (releaseCandidateIds.length * 2) +
        (storeListingIds.length * 5) +
        privacyReviewIds.length + deviceTargetIds.length,
  );
  assert.match(result.evidenceArtifacts[0].sha256, /^[0-9a-f]{64}$/u);
});

test("unsigned artifacts, insecure policy URLs, and missing devices fail closed", () => {
  const data = fixture();
  data.evidence.mobileRelease.releaseCandidates[0].signatureVerified = false;
  data.evidence.mobileRelease.storeListings[0].privacyUrl =
    "https://192.168.1.10/privacy";
  data.evidence.mobileRelease.deviceRuns.pop();
  const result = evaluateAcceptanceEvidence({
    releaseManifest: data.releaseManifest,
    evidence: data.evidence,
    evidenceRoot: data.root,
  });
  assert.equal(result.ready, false);
  assert.ok(result.findings.some((finding) => finding.includes("signature")));
  assert.ok(result.findings.some((finding) => finding.includes("privacyUrl")));
  assert.ok(result.findings.some((finding) =>
    finding.includes("web-desktop-safari")));
});

test("device acceptance requires every scenario and release binding", () => {
  const data = fixture();
  const run = data.evidence.mobileRelease.deviceRuns[0];
  run.releaseSha = "b".repeat(40);
  run.scenarios.pop();
  const result = evaluateAcceptanceEvidence({
    releaseManifest: data.releaseManifest,
    evidence: data.evidence,
    evidenceRoot: data.root,
  });
  assert.equal(result.ready, false);
  assert.ok(result.findings.some((finding) =>
    finding.includes("not bound to the release SHA")));
  assert.ok(result.findings.some((finding) =>
    finding.includes("deep-link-notification")));
});

test("release mismatch, missing approval, and blocking defects fail closed", () => {
  const data = fixture();
  data.evidence.releaseSha = "b".repeat(40);
  data.evidence.journeys[0].status = "failed";
  data.evidence.signoffs.pop();
  data.evidence.defects.items.push({
    id: "SEC-1",
    severity: "critical",
    status: "open",
  });
  const result = evaluateAcceptanceEvidence({
    releaseManifest: data.releaseManifest,
    evidence: data.evidence,
    evidenceRoot: data.root,
  });
  assert.equal(result.ready, false);
  assert.ok(result.findings.some((finding) => finding.includes("SHA")));
  assert.ok(result.findings.some((finding) => finding.includes("has not passed")));
  assert.ok(result.findings.some((finding) => finding.includes("SEC-1")));
  assert.ok(result.findings.some((finding) => finding.includes("legal")));
});

test("evidence cannot escape its controlled directory", () => {
  const data = fixture();
  data.evidence.journeys[0].evidenceFiles = ["../outside.txt"];
  const result = evaluateAcceptanceEvidence({
    releaseManifest: data.releaseManifest,
    evidence: data.evidence,
    evidenceRoot: data.root,
  });
  assert.equal(result.ready, false);
  assert.ok(result.findings.some((finding) => finding.includes("escapes")));
});

test("canonical evidence paths cannot escape through a directory link", () => {
  const data = fixture();
  const outside = mkdtempSync(path.join(os.tmpdir(), "pipe-outside-"));
  writeFileSync(path.join(outside, "outside.txt"), "not controlled evidence");
  symlinkSync(outside, path.join(data.root, "linked-outside"), "junction");
  data.evidence.journeys[0].evidenceFiles = ["linked-outside/outside.txt"];
  const result = evaluateAcceptanceEvidence({
    releaseManifest: data.releaseManifest,
    evidence: data.evidence,
    evidenceRoot: data.root,
  });
  assert.equal(result.ready, false);
  assert.ok(result.findings.some((finding) =>
    finding.includes("resolves outside")));
});

test("operator template stays synchronized with the release evidence contract", () => {
  const template = JSON.parse(readFileSync(
      path.join("docs", "phase1_acceptance_template.json"),
      "utf8",
  ));
  assert.equal(template.schemaVersion, 2);
  assert.deepEqual(template.journeys.map(({id}) => id), acceptanceJourneyIds);
  assert.deepEqual(template.recovery.map(({id}) => id), recoveryControlIds);
  assert.deepEqual(template.signoffs.map(({id}) => id), requiredSignoffRoles);
  assert.deepEqual(
      template.mobileRelease.releaseCandidates.map(({id}) => id),
      releaseCandidateIds,
  );
  assert.deepEqual(
      template.mobileRelease.storeListings.map(({id}) => id),
      storeListingIds,
  );
  assert.deepEqual(
      template.mobileRelease.privacyReviews.map(({id}) => id),
      privacyReviewIds,
  );
  assert.deepEqual(
      template.mobileRelease.deviceRuns.map(({id}) => id),
      deviceTargetIds,
  );
});
