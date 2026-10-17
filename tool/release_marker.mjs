import {
  existsSync,
  readFileSync,
  renameSync,
  statSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import {pathToFileURL} from "node:url";

export const releaseMarkerFileName = "pipe-release.json";

const releaseMarkerSchemaVersion = 1;
const knownEnvironments = new Set([
  "development",
  "local",
  "local-verification",
  "continuous-integration",
  "test",
  "staging",
  "production",
]);
const fullCommitSha = /^[0-9a-f]{40}$/iu;
const appVersion = /^\d+\.\d+\.\d+\+\d+$/u;
const releaseMarkerKeys = [
  "environment",
  "releaseSha",
  "schemaVersion",
  "version",
];

function normalizedEnvironment(value) {
  return String(value || "").trim().toLowerCase();
}

function normalizedReleaseSha(value) {
  return String(value || "").trim().toLowerCase();
}

function validateIdentity({environment, releaseSha, version}) {
  if (!knownEnvironments.has(environment)) {
    throw new Error(`Unsupported release environment: ${environment}`);
  }
  if (!fullCommitSha.test(releaseSha)) {
    throw new Error("Release SHA must be a full 40-character Git commit.");
  }
  if (!appVersion.test(version)) {
    throw new Error(
        "Release version must use the major.minor.patch+build form.",
    );
  }
}

export function readAppVersion(root) {
  const pubspecPath = path.join(root, "pubspec.yaml");
  if (!existsSync(pubspecPath) || !statSync(pubspecPath).isFile()) {
    throw new Error(`pubspec.yaml is missing from ${root}.`);
  }
  const pubspec = readFileSync(pubspecPath, "utf8").replaceAll("\r\n", "\n");
  const match = /^version:\s*([^\s#]+)\s*(?:#.*)?$/mu.exec(pubspec);
  if (!match) {
    throw new Error("pubspec.yaml must declare a top-level version.");
  }
  const version = match[1];
  if (!appVersion.test(version)) {
    throw new Error(
        "pubspec.yaml version must use the major.minor.patch+build form.",
    );
  }
  return version;
}

export function createReleaseMarker({environment, releaseSha, version}) {
  const normalized = {
    environment: normalizedEnvironment(environment),
    releaseSha: normalizedReleaseSha(releaseSha),
    version: String(version || "").trim(),
  };
  validateIdentity(normalized);
  return {
    schemaVersion: releaseMarkerSchemaVersion,
    environment: normalized.environment,
    version: normalized.version,
    releaseSha: normalized.releaseSha,
  };
}

export function serializeReleaseMarker(marker) {
  return `${JSON.stringify(marker, null, 2)}\n`;
}

export function parseAndValidateReleaseMarker(
    body,
    {environment, releaseSha, version},
) {
  const expected = createReleaseMarker({environment, releaseSha, version});
  let marker;
  try {
    marker = JSON.parse(body);
  } catch {
    throw new Error(
        "Release marker is not valid JSON; the SPA index fallback may have " +
        "been served.",
    );
  }
  if (marker == null || Array.isArray(marker) || typeof marker !== "object") {
    throw new Error("Release marker must be a JSON object.");
  }
  const actualKeys = Object.keys(marker).sort();
  if (JSON.stringify(actualKeys) !== JSON.stringify(releaseMarkerKeys)) {
    throw new Error(
        `Release marker fields must be exactly: ${releaseMarkerKeys.join(", ")}.`,
    );
  }
  for (const key of releaseMarkerKeys) {
    if (marker[key] !== expected[key]) {
      throw new Error(
          `Release marker ${key} mismatch: expected ${expected[key]}, ` +
          `received ${marker[key]}.`,
      );
    }
  }
  return marker;
}

export function validateReleaseMarkerResponse({
  status,
  contentType,
  body,
  environment,
  releaseSha,
  version,
}) {
  if (status !== 200) {
    throw new Error(`Release marker returned HTTP ${status}.`);
  }
  const normalizedContentType = String(contentType || "").toLowerCase();
  if (!normalizedContentType.includes("application/json")) {
    throw new Error(
        `Release marker returned ${contentType || "no Content-Type"}; ` +
        "the SPA index fallback is not acceptable.",
    );
  }
  return parseAndValidateReleaseMarker(body, {
    environment,
    releaseSha,
    version,
  });
}

export function writeReleaseMarker({
  root,
  environment,
  releaseSha,
  output = path.join("build", "web", releaseMarkerFileName),
}) {
  const resolvedRoot = path.resolve(root);
  const resolvedOutput = path.resolve(resolvedRoot, output);
  const outputDirectory = path.dirname(resolvedOutput);
  if (!existsSync(outputDirectory) || !statSync(outputDirectory).isDirectory()) {
    throw new Error(
        `Web build output directory is missing: ${outputDirectory}`,
    );
  }
  const marker = createReleaseMarker({
    environment,
    releaseSha,
    version: readAppVersion(resolvedRoot),
  });
  const temporaryOutput = `${resolvedOutput}.tmp`;
  writeFileSync(temporaryOutput, serializeReleaseMarker(marker), "utf8");
  renameSync(temporaryOutput, resolvedOutput);
  return {marker, output: resolvedOutput};
}

export function validateReleaseMarkerFile({
  root,
  environment,
  releaseSha,
  file = path.join("build", "web", releaseMarkerFileName),
}) {
  const resolvedRoot = path.resolve(root);
  const resolvedFile = path.resolve(resolvedRoot, file);
  if (!existsSync(resolvedFile) || !statSync(resolvedFile).isFile()) {
    throw new Error(`Release marker is missing: ${resolvedFile}`);
  }
  return parseAndValidateReleaseMarker(readFileSync(resolvedFile, "utf8"), {
    environment,
    releaseSha,
    version: readAppVersion(resolvedRoot),
  });
}

function wait(delayMilliseconds) {
  return new Promise((resolve) => setTimeout(resolve, delayMilliseconds));
}

export async function verifyReleaseMarkerUrl({
  url,
  environment,
  releaseSha,
  version,
  attempts = 6,
  retryDelayMilliseconds = 3000,
  fetchImplementation = globalThis.fetch,
}) {
  if (typeof fetchImplementation !== "function") {
    throw new Error("This Node runtime does not provide fetch().");
  }
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetchImplementation(url, {
        headers: {
          "Cache-Control": "no-cache",
          "Pragma": "no-cache",
        },
        redirect: "follow",
        signal: AbortSignal.timeout(15000),
      });
      const body = await response.text();
      return validateReleaseMarkerResponse({
        status: response.status,
        contentType: response.headers.get("content-type"),
        body,
        environment,
        releaseSha,
        version,
      });
    } catch (error) {
      lastError = error;
      if (attempt < attempts) await wait(retryDelayMilliseconds);
    }
  }
  throw new Error(
      `Release marker verification failed after ${attempts} attempts: ` +
      lastError.message,
  );
}

function parseArguments(argumentsList) {
  const options = {
    root: process.cwd(),
    environment: process.env.PIPE_ENV || "local-verification",
    releaseSha: process.env.PIPE_RELEASE_SHA || "",
    output: path.join("build", "web", releaseMarkerFileName),
    verifyUrl: "",
  };
  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    const value = argumentsList[index + 1];
    if (!value) throw new Error(`Missing value after ${argument}.`);
    switch (argument) {
      case "--root":
        options.root = value;
        break;
      case "--environment":
        options.environment = value;
        break;
      case "--release-sha":
        options.releaseSha = value;
        break;
      case "--output":
        options.output = value;
        break;
      case "--verify-url":
        options.verifyUrl = value;
        break;
      default:
        throw new Error(`Unknown argument: ${argument}`);
    }
    index += 1;
  }
  return options;
}

async function run(options) {
  const root = path.resolve(options.root);
  if (options.verifyUrl) {
    const marker = await verifyReleaseMarkerUrl({
      url: options.verifyUrl,
      environment: options.environment,
      releaseSha: options.releaseSha,
      version: readAppVersion(root),
    });
    process.stdout.write(
        `Verified ${options.verifyUrl}: ${marker.releaseSha}\n`,
    );
    return;
  }
  const result = writeReleaseMarker({
    root,
    environment: options.environment,
    releaseSha: options.releaseSha,
    output: options.output,
  });
  process.stdout.write(
      `Release marker written to ${path.relative(root, result.output)}\n`,
  );
}

const invokedDirectly = process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (invokedDirectly) {
  try {
    await run(parseArguments(process.argv.slice(2)));
  } catch (error) {
    process.stderr.write(`Release marker failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
