import {createHash} from "node:crypto";
import {
  closeSync,
  existsSync,
  mkdirSync,
  openSync,
  readSync,
  readFileSync,
  realpathSync,
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

export const releaseCandidateIds = Object.freeze([
  "android-aab",
  "ios-ipa",
]);

export const storeListingIds = Object.freeze([
  "google-play",
  "apple-app-store",
]);

export const privacyReviewIds = Object.freeze([
  "google-play-data-safety",
  "apple-app-privacy",
  "linked-sdk-inventory",
]);

export const deviceTargetIds = Object.freeze([
  "android-compact-phone",
  "android-current-phone",
  "android-tablet",
  "ios-compact-phone",
  "ios-current-phone",
  "ios-tablet",
  "web-mobile-chromium",
  "web-desktop-chromium",
  "web-mobile-safari",
  "web-desktop-safari",
]);

export const mobileScenarioIds = Object.freeze([
  "install-upgrade-launch",
  "account-profile-avatar",
  "listing-camera-gallery",
  "messaging-attachments",
  "offer-auction-dispatch",
  "denied-permission-recovery",
  "offline-slow-retry",
  "expired-session-recovery",
  "assistive-technology",
  "large-text-orientation",
  "deep-link-notification",
]);

export const webScenarioIds = Object.freeze([
  "account-profile-avatar",
  "listing-media",
  "messaging-attachments",
  "offer-auction-dispatch",
  "offline-slow-retry",
  "expired-session-recovery",
  "assistive-technology",
  "keyboard-only",
  "large-text-responsive-layout",
  "deep-link-notification",
]);

const blockingSeverities = new Set(["p0", "critical", "high"]);
const allowedEnvironments = new Set(["staging", "production"]);

function hashFile(resolved) {
  const digest = createHash("sha256");
  const buffer = Buffer.allocUnsafe(1024 * 1024);
  const descriptor = openSync(resolved, "r");
  let bytes = 0;
  try {
    while (true) {
      const count = readSync(descriptor, buffer, 0, buffer.length, null);
      if (count === 0) break;
      digest.update(buffer.subarray(0, count));
      bytes += count;
    }
  } finally {
    closeSync(descriptor);
  }
  return {bytes, sha256: digest.digest("hex")};
}

function isFullSha(value) {
  return typeof value === "string" && /^[0-9a-f]{40}$/iu.test(value);
}

function isTimestamp(value) {
  return typeof value === "string" &&
    Number.isFinite(Date.parse(value));
}

function isPublicHttpsUrl(value) {
  if (typeof value !== "string" || value.trim() !== value) return false;
  try {
    const url = new URL(value);
    const hostname = url.hostname.toLowerCase().replace(/^\[|\]$/gu, "");
    const ipv4 = hostname.split(".").map((part) => Number(part));
    const isIpv4 = ipv4.length === 4 && ipv4.every((part) =>
      Number.isInteger(part) && part >= 0 && part <= 255);
    const privateIpv4 = isIpv4 && (
      ipv4[0] === 0 || ipv4[0] === 10 || ipv4[0] === 127 ||
      (ipv4[0] === 169 && ipv4[1] === 254) ||
      (ipv4[0] === 172 && ipv4[1] >= 16 && ipv4[1] <= 31) ||
      (ipv4[0] === 192 && ipv4[1] === 168) || ipv4[0] >= 224
    );
    const privateIpv6 = hostname === "::1" || hostname === "::" ||
      /^f[cd][0-9a-f]{2}:/u.test(hostname) || /^fe[89ab][0-9a-f]:/u.test(hostname);
    return url.protocol === "https:" && hostname.length > 0 &&
      hostname !== "localhost" && hostname !== "127.0.0.1" &&
      !hostname.endsWith(".local") && hostname.includes(".") &&
      !privateIpv4 && !privateIpv6 && !url.username && !url.password &&
      hostname !== "example.com" && !hostname.endsWith(".example.com") &&
      !value.toLowerCase().includes("replace_with");
  } catch (_) {
    return false;
  }
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
  const canonicalRoot = existsSync(root) ? realpathSync(root) : root;
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
    if (!existsSync(resolved)) {
      findings.push(`${label} evidence file is missing: ${relativeFile}.`);
      continue;
    }
    const canonicalFile = realpathSync(resolved);
    if (canonicalFile !== canonicalRoot &&
        !canonicalFile.startsWith(`${canonicalRoot}${path.sep}`)) {
      findings.push(`${label} evidence resolves outside the evidence directory.`);
      continue;
    }
    if (!statSync(canonicalFile).isFile()) {
      findings.push(`${label} evidence is not a regular file: ${relativeFile}.`);
      continue;
    }
    const digest = hashFile(canonicalFile);
    if (digest.bytes === 0) {
      findings.push(`${label} evidence file is empty: ${relativeFile}.`);
      continue;
    }
    artifacts.push({
      path: path.relative(root, resolved).split(path.sep).join("/"),
      ...digest,
    });
  }
}

function validateNamedReview(record, label, findings) {
  if (record?.status !== "passed") {
    findings.push(`${label} has not passed.`);
  }
  if (typeof record?.reviewedBy !== "string" ||
      record.reviewedBy.trim().length < 2 ||
      !isTimestamp(record?.reviewedAt)) {
    findings.push(`${label} requires a named reviewer and timestamp.`);
  }
}

function validateMobileReleaseEvidence({evidence, evidenceRoot, findings,
  artifacts, releaseSha}) {
  const mobile = evidence?.mobileRelease;
  if (!mobile || typeof mobile !== "object") {
    findings.push("mobileRelease evidence is required.");
    return {candidateCount: 0, storeListingCount: 0, privacyReviewCount: 0,
      deviceTargetCount: 0};
  }

  const candidates = validateExactIds(
      mobile.releaseCandidates,
      releaseCandidateIds,
      "mobileRelease.releaseCandidates",
      findings,
  );
  const candidateRequirements = {
    "android-aab": {platform: "android", extension: ".aab"},
    "ios-ipa": {platform: "ios", extension: ".ipa"},
  };
  for (const id of releaseCandidateIds) {
    const candidate = candidates.get(id);
    if (!candidate) continue;
    const requirement = candidateRequirements[id];
    if (candidate.status !== "passed") {
      findings.push(`Release candidate ${id} has not passed.`);
    }
    if (candidate.platform !== requirement.platform) {
      findings.push(`Release candidate ${id} has the wrong platform.`);
    }
    if (candidate.applicationId !== "Pipe.Buyerapp") {
      findings.push(`Release candidate ${id} has an unapproved application id.`);
    }
    if (candidate.builtFromSha !== releaseSha) {
      findings.push(`Release candidate ${id} is not bound to the release SHA.`);
    }
    if (typeof candidate.versionName !== "string" ||
        !/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/u.test(candidate.versionName)) {
      findings.push(`Release candidate ${id} needs a semantic version name.`);
    }
    if (typeof candidate.buildNumber !== "string" ||
        !/^[1-9]\d*$/u.test(candidate.buildNumber)) {
      findings.push(`Release candidate ${id} needs a positive build number.`);
    }
    if (candidate.signatureVerified !== true) {
      findings.push(`Release candidate ${id} signature is not verified.`);
    }
    if (candidate.storeValidated !== true) {
      findings.push(`Release candidate ${id} store validation has not passed.`);
    }
    if (typeof candidate.artifactFile !== "string" ||
        !candidate.artifactFile.toLowerCase().endsWith(requirement.extension)) {
      findings.push(`Release candidate ${id} requires a ${requirement.extension} artifact.`);
    }
    if (!Array.isArray(candidate.evidenceFiles) ||
        candidate.evidenceFiles.length === 0) {
      findings.push(`Release candidate ${id} requires signature and store-validation evidence.`);
    }
    validateEvidenceFiles({
      files: [candidate.artifactFile, ...(candidate.evidenceFiles || [])],
      evidenceRoot,
      label: `Release candidate ${id}`,
      findings,
      artifacts,
    });
  }

  const stores = validateExactIds(
      mobile.storeListings,
      storeListingIds,
      "mobileRelease.storeListings",
      findings,
  );
  for (const id of storeListingIds) {
    const store = stores.get(id);
    if (!store) continue;
    validateNamedReview(store, `Store listing ${id}`, findings);
    for (const field of ["supportUrl", "privacyUrl", "termsUrl",
      "accountDeletionUrl"]) {
      if (!isPublicHttpsUrl(store[field])) {
        findings.push(`Store listing ${id} requires a public HTTPS ${field}.`);
      }
    }
    if (!Array.isArray(store.screenshotFiles) ||
        store.screenshotFiles.length < 4) {
      findings.push(`Store listing ${id} requires at least four screenshots.`);
    }
    if (!Array.isArray(store.evidenceFiles) || store.evidenceFiles.length === 0) {
      findings.push(`Store listing ${id} requires console-review evidence.`);
    }
    validateEvidenceFiles({
      files: [...(store.screenshotFiles || []), ...(store.evidenceFiles || [])],
      evidenceRoot,
      label: `Store listing ${id}`,
      findings,
      artifacts,
    });
  }

  const privacy = validateExactIds(
      mobile.privacyReviews,
      privacyReviewIds,
      "mobileRelease.privacyReviews",
      findings,
  );
  for (const id of privacyReviewIds) {
    const review = privacy.get(id);
    if (!review) continue;
    validateNamedReview(review, `Privacy review ${id}`, findings);
    validateEvidenceFiles({
      files: review.evidenceFiles,
      evidenceRoot,
      label: `Privacy review ${id}`,
      findings,
      artifacts,
    });
  }

  const devices = validateExactIds(
      mobile.deviceRuns,
      deviceTargetIds,
      "mobileRelease.deviceRuns",
      findings,
  );
  for (const id of deviceTargetIds) {
    const run = devices.get(id);
    if (!run) continue;
    const isWeb = id.startsWith("web-");
    const expectedPlatform = id.startsWith("android-") ? "android" :
      id.startsWith("ios-") ? "ios" : "web";
    if (run.status !== "passed") {
      findings.push(`Device target ${id} has not passed.`);
    }
    if (run.platform !== expectedPlatform) {
      findings.push(`Device target ${id} has the wrong platform.`);
    }
    if (run.releaseSha !== releaseSha) {
      findings.push(`Device target ${id} is not bound to the release SHA.`);
    }
    if (typeof run.tester !== "string" || run.tester.trim().length < 2 ||
        typeof run.deviceModel !== "string" || run.deviceModel.trim().length < 2 ||
        typeof run.osVersion !== "string" || run.osVersion.trim().length < 1 ||
        typeof run.assistiveTechnology !== "string" ||
        run.assistiveTechnology.trim().length < 2 || !isTimestamp(run.executedAt)) {
      findings.push(`Device target ${id} requires tester, device, OS, assistive technology, and timestamp.`);
    }
    if (!isWeb) {
      const expectedArtifact = expectedPlatform === "android" ?
        "android-aab" : "ios-ipa";
      if (run.releaseCandidateId !== expectedArtifact) {
        findings.push(`Device target ${id} is not tied to ${expectedArtifact}.`);
      }
    }
    const scenarios = validateExactIds(
        run.scenarios,
        isWeb ? webScenarioIds : mobileScenarioIds,
        `Device target ${id} scenarios`,
        findings,
    );
    for (const scenarioId of (isWeb ? webScenarioIds : mobileScenarioIds)) {
      if (scenarios.get(scenarioId)?.status !== "passed") {
        findings.push(`Device target ${id} scenario ${scenarioId} has not passed.`);
      }
    }
    validateEvidenceFiles({
      files: run.evidenceFiles,
      evidenceRoot,
      label: `Device target ${id}`,
      findings,
      artifacts,
    });
  }

  return {
    candidateCount: candidates.size,
    storeListingCount: stores.size,
    privacyReviewCount: privacy.size,
    deviceTargetCount: devices.size,
  };
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
  if (evidence?.schemaVersion !== 2) {
    findings.push("Acceptance evidence schemaVersion must be 2.");
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

  const mobileRelease = validateMobileReleaseEvidence({
    evidence,
    evidenceRoot,
    findings,
    artifacts,
    releaseSha,
  });

  const uniqueArtifacts = [...new Map(
      artifacts.map((artifact) => [artifact.path, artifact]),
  ).values()].sort((left, right) => left.path.localeCompare(right.path));

  return {
    schemaVersion: 2,
    ready: findings.length === 0,
    environment,
    releaseSha,
    evaluatedAt: new Date().toISOString(),
    journeyCount: journeys.size,
    recoveryControlCount: recovery.size,
    signoffCount: signoffs.size,
    ...mobileRelease,
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
