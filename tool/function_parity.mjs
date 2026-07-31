import {existsSync, readFileSync, writeFileSync} from "node:fs";
import path from "node:path";
import {pathToFileURL} from "node:url";

function sortedUnique(values) {
  return [...new Set(values)].sort();
}

function difference(left, right) {
  const rightSet = new Set(right);
  return left.filter((value) => !rightSet.has(value));
}

export function compareFunctionInventory({
  manifest,
  inventory,
  projectId,
  codebase = "marketplace",
}) {
  const manifestProject = manifest?.firebase?.projectId;
  const expectedByCodebase = manifest?.firebase?.expectedFunctionsByCodebase;
  const expected = expectedByCodebase &&
    Array.isArray(expectedByCodebase[codebase]) ?
    expectedByCodebase[codebase] : manifest?.firebase?.expectedFunctions;
  if (!Array.isArray(expected) || expected.length === 0) {
    throw new Error("Release manifest has no expected Firebase Functions.");
  }
  if (!projectId || manifestProject !== projectId) {
    throw new Error(
        `Manifest project '${manifestProject || "missing"}' does not match ` +
        `'${projectId || "missing"}'.`,
    );
  }
  if (!Array.isArray(inventory?.result)) {
    throw new Error("Firebase Functions inventory has no result array.");
  }

  const relevant = inventory.result.filter((entry) =>
    entry && entry.codebase === codebase,
  );
  const deployed = sortedUnique(relevant.map((entry) => entry.id)
      .filter((name) => typeof name === "string" && name.length > 0));
  const inactive = sortedUnique(relevant
      .filter((entry) => entry.state !== "ACTIVE")
      .map((entry) => entry.id));
  const normalizedExpected = sortedUnique(expected);
  const missing = difference(normalizedExpected, deployed);
  const unexpected = difference(deployed, normalizedExpected);
  const passed = missing.length === 0 && unexpected.length === 0 &&
    inactive.length === 0;

  return {
    projectId,
    codebase,
    expectedCount: normalizedExpected.length,
    deployedCount: deployed.length,
    expected: normalizedExpected,
    deployed,
    missing,
    unexpected,
    inactive,
    passed,
  };
}

function readJson(file, description) {
  const absolute = path.resolve(file);
  if (!existsSync(absolute)) {
    throw new Error(`${description} does not exist: ${file}`);
  }
  try {
    return JSON.parse(readFileSync(absolute, "utf8"));
  } catch (error) {
    throw new Error(`${description} is not valid JSON: ${error.message}`);
  }
}

function parseArguments(argumentsList) {
  const options = {
    manifest: "build/release-manifest.json",
    inventory: "build/deployed-functions.json",
    projectId: process.env.PIPE_FIREBASE_PROJECT_ID || "",
    codebase: "marketplace",
    output: "build/function-parity.json",
  };
  for (let index = 0; index < argumentsList.length; index += 2) {
    const argument = argumentsList[index];
    const value = argumentsList[index + 1];
    if (!value) throw new Error(`Missing value after ${argument}.`);
    switch (argument) {
      case "--manifest":
        options.manifest = value;
        break;
      case "--inventory":
        options.inventory = value;
        break;
      case "--project":
        options.projectId = value;
        break;
      case "--codebase":
        options.codebase = value;
        break;
      case "--output":
        options.output = value;
        break;
      default:
        throw new Error(`Unknown argument: ${argument}`);
    }
  }
  return options;
}

function run(options) {
  const result = compareFunctionInventory({
    manifest: readJson(options.manifest, "Release manifest"),
    inventory: readJson(options.inventory, "Functions inventory"),
    projectId: options.projectId,
    codebase: options.codebase,
  });
  const output = path.resolve(options.output);
  writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  if (!result.passed) {
    throw new Error(
        `Function parity failed: ${result.missing.length} missing, ` +
        `${result.unexpected.length} unexpected, ` +
        `${result.inactive.length} inactive.`,
    );
  }
}

const invokedDirectly = process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (invokedDirectly) {
  try {
    run(parseArguments(process.argv.slice(2)));
  } catch (error) {
    process.stderr.write(`Function parity failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
