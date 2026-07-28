import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import {pathToFileURL} from "node:url";

import {
  acceptanceJourneyIds,
  deviceTargetIds,
  privacyReviewIds,
  recoveryControlIds,
  requiredSignoffRoles,
  storeListingIds,
} from "./phase1_acceptance.mjs";

const controlledEnvironments = new Set(["staging", "production"]);
const semanticVersion = /^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/u;
const fullCommitSha = /^[0-9a-f]{40}$/u;

function requireString(value, label) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${label} is required.`);
  }
  return value.trim();
}

function normalizePublicBaseUrl(value) {
  if (!value) return null;
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error("Public base URL must be a valid HTTPS URL.");
  }
  const hostname = url.hostname.toLowerCase();
  if (url.protocol !== "https:" || !hostname ||
      hostname === "localhost" || hostname.endsWith(".localhost") ||
      hostname === "example.com" || hostname.endsWith(".example.com")) {
    throw new Error(
        "Public base URL must use HTTPS and cannot be localhost or an example domain.",
    );
  }
  url.pathname = url.pathname.replace(/\/+$/u, "");
  url.search = "";
  url.hash = "";
  return url;
}

function publicUrl(baseUrl, suffix) {
  const normalized = new URL(baseUrl.href);
  normalized.pathname = `${normalized.pathname}/${suffix}`.replace(/\/{2,}/gu, "/");
  return normalized.href.replace(/\/$/u, "");
}

function checklist({environment, releaseSha, versionName, buildNumber}) {
  const section = (title, ids) => [
    `## ${title}`,
    "",
    ...ids.map((id) => `- [ ] \`${id}\``),
    "",
  ];
  return [
    "# Pipe Buyer Phase 1 acceptance evidence",
    "",
    `- Environment: \`${environment}\``,
    `- Release SHA: \`${releaseSha}\``,
    `- Version: \`${versionName}+${buildNumber}\``,
    "- Status: preparation only; no item is credited until real evidence is attached and validated",
    "",
    ...section("Product journeys", acceptanceJourneyIds),
    ...section("Recovery controls", recoveryControlIds),
    ...section("Store listings", storeListingIds),
    ...section("Privacy reviews", privacyReviewIds),
    ...section("Device and browser runs", deviceTargetIds),
    ...section("Required approvals", requiredSignoffRoles),
    "## Final validation",
    "",
    "Run from the repository root after every pending field and evidence path has been completed:",
    "",
    "```powershell",
    "node tool/phase1_acceptance.mjs `",
    "  --release-manifest build/release-manifest.json `",
    "  --evidence build/acceptance/phase1-acceptance.json `",
    "  --evidence-root build/acceptance `",
    "  --output build/acceptance/phase1-readiness.json",
    "```",
    "",
    "A blocked result is expected until all real launch evidence and approvals exist.",
    "",
  ].join("\n");
}

export function preparePhase1AcceptanceBundle({
  releaseManifest,
  template,
  outputRoot,
  versionName,
  buildNumber,
  publicBaseUrl,
}) {
  const environment = requireString(
      releaseManifest?.release?.environment,
      "Release-manifest environment",
  ).toLowerCase();
  if (!controlledEnvironments.has(environment)) {
    throw new Error("Acceptance bundles require a staging or production release manifest.");
  }
  const releaseSha = requireString(
      releaseManifest?.release?.commitSha,
      "Release-manifest commit SHA",
  ).toLowerCase();
  if (!fullCommitSha.test(releaseSha)) {
    throw new Error("Release-manifest commit SHA must be 40 lowercase hexadecimal characters.");
  }
  const normalizedVersion = requireString(versionName, "Version name");
  if (!semanticVersion.test(normalizedVersion)) {
    throw new Error("Version name must be a semantic version such as 1.0.0.");
  }
  const normalizedBuild = requireString(`${buildNumber ?? ""}`, "Build number");
  if (!/^\d+$/u.test(normalizedBuild) || Number(normalizedBuild) <= 0) {
    throw new Error("Build number must be a positive integer.");
  }
  if (template?.schemaVersion !== 2) {
    throw new Error("Phase 1 acceptance template schema version 2 is required.");
  }

  const resolvedRoot = path.resolve(outputRoot);
  const evidenceFile = path.join(resolvedRoot, "phase1-acceptance.json");
  const checklistFile = path.join(resolvedRoot, "EVIDENCE_CHECKLIST.md");
  if (existsSync(evidenceFile) || existsSync(checklistFile)) {
    throw new Error(
        `Acceptance bundle already exists at ${resolvedRoot}; refusing to overwrite evidence.`,
    );
  }

  const evidence = structuredClone(template);
  evidence.environment = environment;
  evidence.releaseSha = releaseSha;
  for (const candidate of evidence.mobileRelease.releaseCandidates) {
    candidate.builtFromSha = releaseSha;
    candidate.versionName = normalizedVersion;
    candidate.buildNumber = normalizedBuild;
  }
  for (const device of evidence.mobileRelease.deviceRuns) {
    device.releaseSha = releaseSha;
  }

  const normalizedBaseUrl = normalizePublicBaseUrl(publicBaseUrl);
  if (normalizedBaseUrl) {
    for (const store of evidence.mobileRelease.storeListings) {
      store.supportUrl = publicUrl(normalizedBaseUrl, "support");
      store.privacyUrl = publicUrl(normalizedBaseUrl, "privacy");
      store.termsUrl = publicUrl(normalizedBaseUrl, "terms");
      store.accountDeletionUrl = publicUrl(normalizedBaseUrl, "account-deletion");
    }
  }

  const directories = [
    "journeys",
    "recovery",
    "mobile",
    "stores/google-play",
    "stores/apple-app-store",
    "privacy",
    "defects",
    "signoffs",
    ...deviceTargetIds.map((id) => `devices/${id}`),
  ];
  for (const directory of directories) {
    mkdirSync(path.join(resolvedRoot, directory), {recursive: true});
  }
  writeFileSync(evidenceFile, `${JSON.stringify(evidence, null, 2)}\n`, {
    flag: "wx",
  });
  writeFileSync(
      checklistFile,
      checklist({
        environment,
        releaseSha,
        versionName: normalizedVersion,
        buildNumber: normalizedBuild,
      }),
      {flag: "wx"},
  );
  return {evidenceFile, checklistFile, environment, releaseSha};
}

function parseArguments(argumentsList) {
  const options = {
    releaseManifest: "build/release-manifest.json",
    template: "docs/phase1_acceptance_template.json",
    outputRoot: "build/acceptance",
    versionName: "",
    buildNumber: "",
    publicBaseUrl: "",
  };
  for (let index = 0; index < argumentsList.length; index += 2) {
    const argument = argumentsList[index];
    const value = argumentsList[index + 1];
    if (!value) throw new Error(`Missing value after ${argument}.`);
    switch (argument) {
      case "--release-manifest": options.releaseManifest = value; break;
      case "--template": options.template = value; break;
      case "--output-root": options.outputRoot = value; break;
      case "--version-name": options.versionName = value; break;
      case "--build-number": options.buildNumber = value; break;
      case "--public-base-url": options.publicBaseUrl = value; break;
      default: throw new Error(`Unknown argument: ${argument}`);
    }
  }
  return options;
}

function main(argumentsList) {
  const options = parseArguments(argumentsList);
  const result = preparePhase1AcceptanceBundle({
    releaseManifest: JSON.parse(readFileSync(options.releaseManifest)),
    template: JSON.parse(readFileSync(options.template)),
    outputRoot: options.outputRoot,
    versionName: options.versionName,
    buildNumber: options.buildNumber,
    publicBaseUrl: options.publicBaseUrl,
  });
  process.stdout.write(
      `Prepared ${result.environment} acceptance bundle for ${result.releaseSha}.\n` +
      `Evidence: ${result.evidenceFile}\nChecklist: ${result.checklistFile}\n`,
  );
}

const invokedDirectly = process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (invokedDirectly) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`Phase 1 acceptance preparation failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
