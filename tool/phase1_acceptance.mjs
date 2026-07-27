import {createHash} from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import {pathToFileURL} from "node:url";

export const acceptanceJourneyIds = Object.freeze([
  "account-ownership-profile-media",
  "listing-lifecycle",
  "saved-state-recovery",
  "communications-moderation",
  "offers-transactions",
  "auctions-settlement",
  "dispatch-delivery",
  "failure-and-retry",
  "administrator-security",
  "deployment-and-recovery",
]);

export const recoveryControlIds = Object.freeze([
  "hosting-rollback",
  "functions-rules-rollback",
  "firestore-backup-restore",
]);

export const requiredSignoffRoles = Object.freeze([
  "product",
  "engineering",
  "security",
  "trust-and-safety",
  "support",
  "privacy",
  "legal",
]);

const blockingSeverities = new Set(["p0", "critical", "high"]);
const allowedEnvironments = new Set(["staging", "production"]);

function sha256(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

function isFullSha(value) {
  return typeof value === "string" && /^[0-9a-f]{40}$/iu.test(value);
}

function isTimestamp(value) {
  return typeof value === "string" &&
    Number.isFinite(Date.parse(value));
}

function duplicateValues(values) {
  const seen = new Set();
  return values.filter((value) => {
    if (seen.has(value)) return true;
    seen.add(value);
    return false;
  });
}

function validateExactIds(records, expectedIds, label, findings) {
  if (!Array.isArray(records)) {
    findings.push(`${label} must be an array.`);
    return new Map();
  }
  const ids = records.map((record) => record?.id).filter(Boolean);
  for (const duplicate of new Set(duplicateValues(ids))) {
    findings.push(`${label} contains duplicate id ${duplicate}.`);
  }
  for (const expected of expectedIds) {
    if (!ids.includes(expected)) {
      findings.push(`${label} is missing ${expected}.`);
    }
  }
  for (const id of ids) {
    if (!expectedIds.includes(id)) {
      findings.push(`${label} contains unsupported id ${id}.`);
    }
  }
  return new Map(records.filter((record) => record?.id)
      .map((record) => [record.id, record]));
}

function validateEvidenceFiles({
  files,
  evidenceRoot,
  label,
  findings,
  artifacts,
}) {
  if (!Array.isArray(files) || files.length === 0) {
    findings.push(`${label} requires at least one evidence file.`);
    return;
  }
  const root = path.resolve(evidenceRoot);
  for (const relativeFile of files) {
    if (typeof relativeFile !== "string" || relativeFile.trim() === "") {
      findings.push(`${label} contains an invalid evidence path.`);
      continue;
    }
    const resolved = path.resolve(root, relativeFile);
    if (resolved !== root && !resolved.startsWith(`${root}${path.sep}`)) {
      findings.push(`${label} evidence escapes the evidence directory.`);
      continue;
    }
    if (!existsSync(resolved) || !statSync(resolved).isFile()) {
      findings.push(`${label} evidence file is missing: ${relativeFile}.`);
      continue;
    }
    const bytes = readFileSync(resolved);
    if (bytes.length === 0) {
      findings.push(`${label} evidence file is empty: ${relativeFile}.`);
      continue;
    }
    artifacts.push({
      path: path.relative(root, resolved).split(path.sep).join("/"),
      bytes: bytes.length,
      sha256: sha256(bytes),
    });
  }
}

export function evaluateAcceptanceEvidence({
  releaseManifest,
  evidence,
  evidenceRoot,
}) {
  const findings = [];
  const artifacts = [];
  const release = releaseManifest?.release ?? {};
  const environment = release.environment;
  const releaseSha = release.commitSha;

  if (!allowedEnvironments.has(environment)) {
    findings.push("Release manifest must target staging or production.");
  }
  if (!isFullSha(releaseSha)) {
    findings.push("Release manifest must contain a full commit SHA.");
  }
  if (evidence?.schemaVersion !== 1) {
    findings.push("Acceptance evidence schemaVersion must be 1.");
  }
  if (evidence?.environment !== environment) {
    findings.push("Acceptance environment does not match the release manifest.");
  }
  if (evidence?.releaseSha !== releaseSha) {
    findings.push("Acceptance SHA does not match the release manifest.");
  }
  if (!isTimestamp(evidence?.executedAt)) {
    findings.push("Acceptance executedAt must be an ISO timestamp.");
  }

  const journeys = validateExactIds(
      evidence?.journeys,
      acceptanceJourneyIds,
      "journeys",
      findings,
  );
  for (const id of acceptanceJourneyIds) {
    const journey = journeys.get(id);
    if (!journey) continue;
    if (journey.status !== "passed") {
      findings.push(`Journey ${id} has not passed.`);
    }
    if (typeof journey.tester !== "string" || journey.tester.trim().length < 2) {
      findings.push(`Journey ${id} requires a named tester.`);
    }
    validateEvidenceFiles({
      files: journey.evidenceFiles,
      evidenceRoot,
      label: `Journey ${id}`,
      findings,
      artifacts,
    });
  }

  const recovery = validateExactIds(
      evidence?.recovery,
      recoveryControlIds,
      "recovery",
      findings,
  );
  for (const id of recoveryControlIds) {
    const control = recovery.get(id);
    if (!control) continue;
    if (control.status !== "passed") {
      findings.push(`Recovery control ${id} has not passed.`);
    }
    if (!Number.isFinite(control.actualMinutes) || control.actualMinutes < 0) {
      findings.push(`Recovery control ${id} needs measured actualMinutes.`);
    }
    validateEvidenceFiles({
      files: control.evidenceFiles,
      evidenceRoot,
      label: `Recovery control ${id}`,
      findings,
      artifacts,
    });
  }

  const defects = evidence?.defects;
  if (!defects || !isTimestamp(defects.reviewedAt) ||
      typeof defects.reviewedBy !== "string" ||
      defects.reviewedBy.trim().length < 2 || !Array.isArray(defects.items)) {
    findings.push("Defect inventory requires a reviewer, timestamp, and items array.");
  } else {
    for (const defect of defects.items) {
      const severity = `${defect?.severity ?? ""}`.toLowerCase();
      const status = `${defect?.status ?? ""}`.toLowerCase();
      if (blockingSeverities.has(severity) && status !== "closed") {
        findings.push(
            `Blocking defect ${defect?.id ?? "without-id"} remains ${status || "open"}.`,
        );
      }
    }
  }

  const signoffs = validateExactIds(
      evidence?.signoffs,
      requiredSignoffRoles,
      "signoffs",
      findings,
  );
  for (const role of requiredSignoffRoles) {
    const signoff = signoffs.get(role);
    if (!signoff) continue;
    if (signoff.status !== "approved") {
      findings.push(`Sign-off ${role} is not approved.`);
    }
    if (typeof signoff.approvedBy !== "string" ||
        signoff.approvedBy.trim().length < 2 ||
        !isTimestamp(signoff.approvedAt)) {
      findings.push(`Sign-off ${role} requires an approver and timestamp.`);
    }
  }

  const uniqueArtifacts = [...new Map(
      artifacts.map((artifact) => [artifact.path, artifact]),
  ).values()].sort((left, right) => left.path.localeCompare(right.path));

  return {
    schemaVersion: 1,
    ready: findings.length === 0,
    environment,
    releaseSha,
    evaluatedAt: new Date().toISOString(),
    journeyCount: journeys.size,
    recoveryControlCount: recovery.size,
    signoffCount: signoffs.size,
    evidenceArtifacts: uniqueArtifacts,
    findings,
  };
}

function parseArguments(argumentsList) {
  const options = {
    releaseManifest: "build/release-manifest.json",
    evidence: "build/acceptance/phase1-acceptance.json",
    evidenceRoot: "build/acceptance",
    output: "build/acceptance/phase1-readiness.json",
  };
  for (let index = 0; index < argumentsList.length; index += 2) {
    const argument = argumentsList[index];
    const value = argumentsList[index + 1];
    if (!value) throw new Error(`Missing value after ${argument}.`);
    switch (argument) {
      case "--release-manifest": options.releaseManifest = value; break;
      case "--evidence": options.evidence = value; break;
      case "--evidence-root": options.evidenceRoot = value; break;
      case "--output": options.output = value; break;
      default: throw new Error(`Unknown argument: ${argument}`);
    }
  }
  return options;
}

function main(argumentsList) {
  const options = parseArguments(argumentsList);
  const releaseManifest = JSON.parse(readFileSync(options.releaseManifest));
  const evidence = JSON.parse(readFileSync(options.evidence));
  const result = evaluateAcceptanceEvidence({
    releaseManifest,
    evidence,
    evidenceRoot: options.evidenceRoot,
  });
  mkdirSync(path.dirname(path.resolve(options.output)), {recursive: true});
  writeFileSync(options.output, `${JSON.stringify(result, null, 2)}\n`);
  process.stdout.write(
      `Phase 1 readiness: ${result.ready ? "READY" : "BLOCKED"}; ` +
      `${result.findings.length} finding(s).\n`,
  );
  if (!result.ready) process.exitCode = 1;
}

const invokedDirectly = process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (invokedDirectly) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`Phase 1 acceptance failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
