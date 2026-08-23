import {execFileSync} from "node:child_process";
import {existsSync, readFileSync} from "node:fs";
import path from "node:path";
import {pathToFileURL} from "node:url";

function normalize(value) {
  return value.split(path.sep).join("/");
}

function git(root, args) {
  return execFileSync("git", args, {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
}

function gitShow(root, revision, relativePath) {
  return git(root, ["show", `${revision}:${normalize(relativePath)}`]);
}

function extractFunctionExports(source) {
  const names = new Set();
  const expression = /\bexports\.([A-Za-z_$][A-Za-z0-9_$]*)\s*=/gu;
  for (const match of source.matchAll(expression)) names.add(match[1]);
  return [...names].sort();
}

function extractLocalReexports(source) {
  const bindings = new Map();
  const requires = /\bconst\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*require\(\s*["'](\.\/[^"']+)["']\s*\)\s*;/gu;
  for (const match of source.matchAll(requires)) bindings.set(match[1], match[2]);
  const modules = new Set();
  const assignments = /\bObject\.assign\(\s*exports\s*,\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*\)/gu;
  for (const match of source.matchAll(assignments)) {
    const target = bindings.get(match[1]);
    if (target) modules.add(target);
  }
  return [...modules].sort();
}

function readJsonAtRevision(root, revision, relativePath) {
  return JSON.parse(gitShow(root, revision, relativePath));
}

function configuredFunctionSources(root, revision) {
  const firebase = readJsonAtRevision(root, revision, "firebase.json");
  const configured = Array.isArray(firebase.functions) ? firebase.functions : [firebase.functions];
  return configured.map((entry) => ({
    source: normalize(String(entry?.source || "").trim()),
    codebase: String(entry?.codebase || "default").trim(),
  }));
}

function packageEntrypointAtRevision(root, revision, source) {
  let packageJson = null;
  try {
    packageJson = readJsonAtRevision(root, revision, `${source}/package.json`);
  } catch {
    packageJson = null;
  }
  return normalize(String(packageJson?.main || "index.js").trim());
}

function collectFunctionExportsAtRevision(root, revision, source, entrypoint) {
  const names = new Set();
  const visited = new Set();

  function visit(relativeFile) {
    const normalized = normalize(relativeFile);
    if (visited.has(normalized)) return;
    if (normalized === ".." || normalized.startsWith("../") || normalized.includes("/../")) {
      throw new Error(`Function export traversal escaped ${source}: ${normalized}`);
    }
    visited.add(normalized);
    const sourceText = gitShow(root, revision, `${source}/${normalized}`);
    for (const name of extractFunctionExports(sourceText)) names.add(name);
    for (const modulePath of extractLocalReexports(sourceText)) {
      const baseDirectory = path.posix.dirname(normalized);
      let child = path.posix.normalize(path.posix.join(baseDirectory, modulePath));
      if (!path.posix.extname(child)) child += ".js";
      visit(child);
    }
  }

  visit(entrypoint);
  return [...names].sort();
}

export function functionInventoryAtRevision(root, revision = "HEAD") {
  const inventory = {};
  for (const entry of configuredFunctionSources(root, revision)) {
    const entrypoint = packageEntrypointAtRevision(root, revision, entry.source);
    inventory[entry.codebase] = collectFunctionExportsAtRevision(
        root,
        revision,
        entry.source,
        entrypoint,
    );
  }
  return inventory;
}

function currentText(root, relativePath) {
  const full = path.join(root, ...normalize(relativePath).split("/"));
  if (!existsSync(full)) throw new Error(`Compatibility source missing: ${relativePath}`);
  return readFileSync(full, "utf8");
}

export function routeInventoryFromSource(source) {
  const routes = new Set();
  const expression = /FFRoute\(\s*name:\s*([^,]+),\s*path:\s*([^,]+),/gsu;
  for (const match of source.matchAll(expression)) {
    const name = match[1].replace(/\s+/gu, " ").trim();
    const routePath = match[2].replace(/\s+/gu, " ").trim();
    routes.add(`${name} :: ${routePath}`);
  }
  return [...routes].sort();
}

export function routeInventoryAtRevision(root, revision = "HEAD") {
  return routeInventoryFromSource(
      gitShow(root, revision, "lib/flutter_flow/nav/nav.dart"),
  );
}

export function currentRouteInventory(root) {
  return routeInventoryFromSource(
      currentText(root, "lib/flutter_flow/nav/nav.dart"),
  );
}

function currentFunctionInventory(root) {
  const firebase = JSON.parse(currentText(root, "firebase.json"));
  const configured = Array.isArray(firebase.functions) ? firebase.functions : [firebase.functions];
  const inventory = {};

  for (const entry of configured) {
    const source = normalize(String(entry?.source || "").trim());
    const codebase = String(entry?.codebase || "default").trim();
    const packagePath = path.join(root, ...source.split("/"), "package.json");
    const packageJson = existsSync(packagePath) ? JSON.parse(readFileSync(packagePath, "utf8")) : {};
    const entrypoint = normalize(String(packageJson.main || "index.js").trim());
    const names = new Set();
    const visited = new Set();

    function visit(relativeFile) {
      const normalized = normalize(relativeFile);
      if (visited.has(normalized)) return;
      if (normalized === ".." || normalized.startsWith("../") || normalized.includes("/../")) {
        throw new Error(`Function export traversal escaped ${source}: ${normalized}`);
      }
      visited.add(normalized);
      const sourceText = currentText(root, `${source}/${normalized}`);
      for (const name of extractFunctionExports(sourceText)) names.add(name);
      for (const modulePath of extractLocalReexports(sourceText)) {
        const baseDirectory = path.posix.dirname(normalized);
        let child = path.posix.normalize(path.posix.join(baseDirectory, modulePath));
        if (!path.posix.extname(child)) child += ".js";
        visit(child);
      }
    }

    visit(entrypoint);
    inventory[codebase] = [...names].sort();
  }
  return inventory;
}

function missingMembers(before, after) {
  const afterSet = new Set(after);
  return before.filter((value) => !afterSet.has(value));
}

export function compareCompatibilitySurface(root, baselineRevision = "HEAD") {
  const beforeRoutes = routeInventoryAtRevision(root, baselineRevision);
  const afterRoutes = currentRouteInventory(root);
  const beforeFunctions = functionInventoryAtRevision(root, baselineRevision);
  const afterFunctions = currentFunctionInventory(root);
  const missingRoutes = missingMembers(beforeRoutes, afterRoutes);
  const missingFunctions = [];

  for (const [codebase, names] of Object.entries(beforeFunctions)) {
    if (!(codebase in afterFunctions)) {
      missingFunctions.push(`${codebase}:<codebase removed>`);
      continue;
    }
    for (const name of missingMembers(names, afterFunctions[codebase])) {
      missingFunctions.push(`${codebase}:${name}`);
    }
  }

  return {
    passed: missingRoutes.length === 0 && missingFunctions.length === 0,
    baselineRevision,
    before: {
      routeCount: beforeRoutes.length,
      functionCount: Object.values(beforeFunctions).flat().length,
    },
    after: {
      routeCount: afterRoutes.length,
      functionCount: Object.values(afterFunctions).flat().length,
    },
    missingRoutes,
    missingFunctions,
  };
}

function main() {
  const root = path.resolve(process.argv[2] || process.cwd());
  const baselineRevision = String(
      process.argv[3] || process.env.PIPE_COMPATIBILITY_BASELINE || "HEAD",
  ).trim();
  const result = compareCompatibilitySurface(root, baselineRevision);
  if (!result.passed) {
    console.error(`Autonomous compatibility preservation failed against ${baselineRevision}.`);
    for (const route of result.missingRoutes) console.error(`  missing route: ${route}`);
    for (const name of result.missingFunctions) console.error(`  missing Function: ${name}`);
    process.exitCode = 1;
    return;
  }
  console.log(`Autonomous compatibility preservation passed against ${baselineRevision}.`);
  console.log(`  Routes    : ${result.after.routeCount} (baseline ${result.before.routeCount})`);
  console.log(`  Functions : ${result.after.functionCount} (baseline ${result.before.functionCount})`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main();
}
