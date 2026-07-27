import assert from "node:assert/strict";
import {mkdtempSync, mkdirSync, writeFileSync} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  acceptanceJourneyIds,
  evaluateAcceptanceEvidence,
  recoveryControlIds,
  requiredSignoffRoles,
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
  return {
    root,
    releaseManifest: {
      release: {environment: "staging", commitSha: releaseSha},
    },
    evidence: {
      schemaVersion: 1,
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
  assert.equal(
      result.evidenceArtifacts.length,
      acceptanceJourneyIds.length + recoveryControlIds.length,
  );
  assert.match(result.evidenceArtifacts[0].sha256, /^[0-9a-f]{64}$/u);
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
