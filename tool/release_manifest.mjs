import {createHash} from "node:crypto";
import {execFileSync} from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  renameSync,
  statSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import {pathToFileURL} from "node:url";

const manifestSchemaVersion = 2;
const controlledEnvironments = new Set(["staging", "production"]);
const appCheckModes = new Set(["disabled", "observe", "enforce"]);
const knownEnvironments = new Set([
  "development",
  "local",
  "local-verification",
  "continuous-integration",
  "test",
  ...controlledEnvironments,
]);

function normalizePath(value) {
  return value.split(path.sep).join("/");
}

function compareText(left, right) {
  if (left < right) return -1;
  if (left > right) return 1;
  return 0;
}

function sha256() {
  return createHash("sha256");
}

export function extractFunctionExports(source) {
  const names = new Set();
  const expression = /\bexports\.([A-Za-z_$][A-Za-z0-9_$]*)\s*=/gu;
  for (const match of source.matchAll(expression)) {
    names.add(match[1]);
  }
  return [...names].sort();
}

export function hashRelativeFiles(root, relativeFiles) {
  const digest = sha256();
  const normalized = [...relativeFiles]
      .map(normalizePath)
      .sort(compareText);
  for (const relativeFile of normalized) {
    const absoluteFile = path.join(root, ...relativeFile.split("/"));
    if (!existsSync(absoluteFile) || !statSync(absoluteFile).isFile()) {
      throw new Error(`Release input is missing: ${relativeFile}`);
    }
    digest.update(relativeFile);
    digest.update("\0");
    digest.update(readFileSync(absoluteFile));
    digest.update("\0");
  }
  return digest.digest("hex");
}

function listFilesRecursively(root, current = root) {
  const files = [];
  const entries = readdirSync(current, {withFileTypes: true})
      .sort((left, right) => compareText(left.name, right.name));
  for (const entry of entries) {
    const absoluteEntry = path.join(current, entry.name);
    if (entry.isDirectory()) {
      files.push(...listFilesRecursively(root, absoluteEntry));
    } else if (entry.isFile()) {
      files.push(normalizePath(path.relative(root, absoluteEntry)));
    }
  }
  return files;
}

export function hashDirectory(directory) {
  if (!existsSync(directory) || !statSync(directory).isDirectory()) {
    throw new Error(`Release artifact directory is missing: ${directory}`);
  }
  const files = listFilesRecursively(directory);
  if (files.length === 0) {
    throw new Error(`Release artifact directory is empty: ${directory}`);
  }
  return {
    fileCount: files.length,
    sha256: hashRelativeFiles(directory, files),
  };
}

function git(root, args) {
  return execFileSync("git", args, {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

function trackedFunctionFiles(root) {
  const output = execFileSync(
      "git",
      ["ls-files", "-z", "--", "firebase/functions"],
      {
        cwd: root,
        encoding: "buffer",
        stdio: ["ignore", "pipe", "pipe"],
      },
  );
  return output.toString("utf8")
      .split("\0")
      .filter(Boolean)
      .filter((file) => !normalizePath(file).includes("/node_modules/"));
}

export function validateReleaseInputs({
  environment,
  releaseSha,
  firebaseProjectId,
  appCheckMode = "disabled",
  workingTreeClean = true,
}) {
  if (!knownEnvironments.has(environment)) {
    throw new Error(`Unsupported release environment: ${environment}`);
  }
  if (!/^[0-9a-f]{40}$/iu.test(releaseSha)) {
    throw new Error("Release SHA must be a full 40-character Git commit.");
  }
  if (controlledEnvironments.has(environment) && !firebaseProjectId) {
    throw new Error(
        `PIPE_FIREBASE_PROJECT_ID is required for ${environment}.`,
    );
  }
  if (!appCheckModes.has(appCheckMode)) {
    throw new Error(`Unsupported App Check mode: ${appCheckMode}`);
  }
  if (environment === "production" && appCheckMode !== "enforce") {
    throw new Error("Production releases require App Check enforce mode.");
  }
  if (controlledEnvironments.has(environment) && !workingTreeClean) {
    throw new Error(
        `${environment} release manifests require a clean working tree.`,
    );
  }
}

export function createReleaseManifest({
  root,
  environment,
  releaseSha,
  firebaseProjectId,
  appCheckMode = "disabled",
  requireWeb,
}) {
  const workingTreeClean = git(
      root,
      ["status", "--porcelain", "--untracked-files=no"],
  ).length === 0;
  validateReleaseInputs({
    environment,
    releaseSha,
    firebaseProjectId,
    appCheckMode,
    workingTreeClean,
  });

  const actualSha = git(root, ["rev-parse", "HEAD"]);
  if (actualSha.toLowerCase() !== releaseSha.toLowerCase()) {
    throw new Error(
        `Checked-out commit ${actualSha} does not match ${releaseSha}.`,
    );
  }

  const functionFiles = trackedFunctionFiles(root);
  if (functionFiles.length === 0) {
    throw new Error("No tracked Firebase Functions source files were found.");
  }
  const functionIndex = readFileSync(
      path.join(root, "firebase", "functions", "index.js"),
      "utf8",
  );
  const expectedFunctions = extractFunctionExports(functionIndex);
  if (expectedFunctions.length === 0) {
    throw new Error("No Firebase Function exports were found.");
  }

  const webDirectory = path.join(root, "build", "web");
  const webArtifact = existsSync(webDirectory) ?
    hashDirectory(webDirectory) :
    null;
  if (requireWeb && webArtifact == null) {
    throw new Error("The verified build/web artifact is required.");
  }

  const rulesFiles = [
    "firebase/firestore.rules",
    "firebase/storage.rules",
    "firebase/firestore.indexes.json",
  ];

  return {
    schemaVersion: manifestSchemaVersion,
    generatedAt: new Date().toISOString(),
    release: {
      environment,
      commitSha: actualSha,
      repository: process.env.GITHUB_REPOSITORY || "local",
      workflowRunId: process.env.GITHUB_RUN_ID || "local",
    },
    firebase: {
      projectId: firebaseProjectId || "not-assigned",
      configSha256: hashRelativeFiles(root, ["firebase.json"]),
      rulesSha256: hashRelativeFiles(root, rulesFiles),
      firestoreRulesSha256: hashRelativeFiles(
          root,
          ["firebase/firestore.rules"],
      ),
      storageRulesSha256: hashRelativeFiles(
          root,
          ["firebase/storage.rules"],
      ),
      indexesSha256: hashRelativeFiles(
          root,
          ["firebase/firestore.indexes.json"],
      ),
      functionsSourceSha256: hashRelativeFiles(root, functionFiles),
      expectedFunctions,
      expectedFunctionCount: expectedFunctions.length,
    },
    security: {
      appCheck: {
        mode: appCheckMode,
        clientRequired: appCheckMode !== "disabled",
        callableEnforcement: appCheckMode === "enforce",
      },
    },
    webArtifact,
    toolchain: {
      flutter: process.env.PIPE_FLUTTER_VERSION || "3.44.6",
      node: process.version,
    },
  };
}

function parseArguments(argumentsList) {
  const options = {
    root: process.cwd(),
    environment: process.env.PIPE_ENV || "local-verification",
    releaseSha: process.env.PIPE_RELEASE_SHA || "",
    firebaseProjectId: process.env.PIPE_FIREBASE_PROJECT_ID || "",
    appCheckMode: process.env.PIPE_APP_CHECK_MODE || "disabled",
    output: "build/release-manifest.json",
    requireWeb: false,
  };
  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (argument === "--require-web") {
      options.requireWeb = true;
      continue;
    }
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
      case "--firebase-project":
        options.firebaseProjectId = value;
        break;
      case "--app-check-mode":
        options.appCheckMode = value;
        break;
      case "--output":
        options.output = value;
        break;
      default:
        throw new Error(`Unknown argument: ${argument}`);
    }
    index += 1;
  }
  return options;
}

function writeManifest(options) {
  const root = path.resolve(options.root);
  const releaseSha = options.releaseSha || git(root, ["rev-parse", "HEAD"]);
  const manifest = createReleaseManifest({
    root,
    environment: options.environment.trim().toLowerCase(),
    releaseSha,
    firebaseProjectId: options.firebaseProjectId.trim(),
    appCheckMode: options.appCheckMode.trim().toLowerCase(),
    requireWeb: options.requireWeb,
  });
  const output = path.resolve(root, options.output);
  mkdirSync(path.dirname(output), {recursive: true});
  const temporaryOutput = `${output}.tmp`;
  writeFileSync(temporaryOutput, `${JSON.stringify(manifest, null, 2)}\n`);
  renameSync(temporaryOutput, output);
  process.stdout.write(
      `Release manifest written to ${normalizePath(path.relative(root, output))}\n`,
  );
  process.stdout.write(
      `Functions: ${manifest.firebase.expectedFunctionCount}; ` +
      `web files: ${manifest.webArtifact?.fileCount ?? 0}\n`,
  );
}

const invokedDirectly = process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (invokedDirectly) {
  try {
    writeManifest(parseArguments(process.argv.slice(2)));
  } catch (error) {
    process.stderr.write(`Release manifest failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
