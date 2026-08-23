import assert from "node:assert/strict";
import {mkdtempSync, mkdirSync, writeFileSync} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  collectFunctionExports,
  extractFunctionExports,
  extractLocalExportReexports,
  hashDirectory,
  hashRelativeFiles,
  isValidPublicSupportEmail,
  parseBooleanFlag,
  readFunctionSources,
  resolveFunctionEntrypoint,
  validateReleaseInputs,
} from "./release_manifest.mjs";

test("function exports are unique and sorted", () => {
  const exports = extractFunctionExports(`
    exports.zeta = handler();
    exports.alpha = handler();
    exports.zeta = replacement();
  `);
  assert.deepEqual(exports, ["alpha", "zeta"]);
});

test("local Object.assign export re-exports are detected", () => {
  const source = `
    const coreExports = require("./index");
    const unrelated = require("./other");
    Object.assign(exports, coreExports);
    void unrelated;
  `;
  assert.deepEqual(extractLocalExportReexports(source), ["./index"]);
});

test("all configured Function codebases are release inputs", () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "pipe-function-sources-"));
  writeFileSync(path.join(root, "firebase.json"), JSON.stringify({
    functions: [
      {source: "firebase/functions", codebase: "marketplace"},
      {source: "firebase/agent-functions", codebase: "functions"},
    ],
  }));
  assert.deepEqual(readFunctionSources(root), [
    {source: "firebase/functions", codebase: "marketplace"},
    {source: "firebase/agent-functions", codebase: "functions"},
  ]);
});

test("Function inventory follows package main plus explicit local re-exports", () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "pipe-function-entrypoint-"));
  const source = path.join(root, "firebase", "functions");
  mkdirSync(source, {recursive: true});
  writeFileSync(path.join(source, "package.json"), JSON.stringify({
    main: "bootstrap.js",
  }));
  writeFileSync(path.join(source, "bootstrap.js"), `
    const coreExports = require("./index");
    Object.assign(exports, coreExports);
    exports.actual = true;
  `);
  writeFileSync(path.join(source, "index.js"), `
    exports.legacy = true;
    exports.shared = true;
  `);
  const entrypoint = resolveFunctionEntrypoint(root, "firebase/functions");
  assert.equal(entrypoint, "bootstrap.js");
  assert.deepEqual(
      collectFunctionExports(root, "firebase/functions", entrypoint),
      ["actual", "legacy", "shared"],
  );
});

test("Function entrypoints cannot escape their configured source", () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "pipe-function-escape-"));
  const source = path.join(root, "firebase", "functions");
  mkdirSync(source, {recursive: true});
  writeFileSync(path.join(source, "package.json"), JSON.stringify({
    main: "../outside.js",
  }));
  writeFileSync(path.join(root, "firebase", "outside.js"), "exports.bad = true;\n");
  assert.throws(
      () => resolveFunctionEntrypoint(root, "firebase/functions"),
      /Invalid Firebase Functions entrypoint/u,
  );
});

test("file and directory hashes are deterministic and content-sensitive", () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "pipe-release-manifest-"));
  mkdirSync(path.join(root, "nested"));
  writeFileSync(path.join(root, "b.txt"), "second");
  writeFileSync(path.join(root, "nested", "a.txt"), "first");

  const direct = hashRelativeFiles(root, ["nested/a.txt", "b.txt"]);
  const reversed = hashRelativeFiles(root, ["b.txt", "nested/a.txt"]);
  const directory = hashDirectory(root);

  assert.equal(direct, reversed);
  assert.equal(directory.sha256, direct);
  assert.equal(directory.fileCount, 2);

  writeFileSync(path.join(root, "b.txt"), "changed");
  assert.notEqual(hashDirectory(root).sha256, direct);
});

test("controlled environments require an explicit Firebase project", () => {
  assert.throws(
      () => validateReleaseInputs({
        environment: "production",
        releaseSha: "a".repeat(40),
        firebaseProjectId: "",
        publicSupportEmail: "support@pipebuyer.com",
      }),
      /PIPE_FIREBASE_PROJECT_ID/u,
  );
  assert.doesNotThrow(() => validateReleaseInputs({
    environment: "staging",
    releaseSha: "b".repeat(40),
    firebaseProjectId: "pipe-staging",
    publicSupportEmail: "support@pipebuyer.com",
    appCheckMode: "disabled",
  }));
});

test("App Check rollout modes are explicit and production fails closed", () => {
  for (const appCheckMode of ["disabled", "observe", "enforce"]) {
    assert.doesNotThrow(() => validateReleaseInputs({
      environment: "staging",
      releaseSha: "d".repeat(40),
      firebaseProjectId: "pipe-staging",
      publicSupportEmail: "support@pipebuyer.com",
      appCheckMode,
    }));
  }
  assert.throws(
      () => validateReleaseInputs({
        environment: "production",
        releaseSha: "e".repeat(40),
        firebaseProjectId: "pipe-production",
        publicSupportEmail: "support@pipebuyer.com",
        appCheckMode: "observe",
      }),
      /require App Check enforce mode/u,
  );
  assert.doesNotThrow(() => validateReleaseInputs({
    environment: "production",
    releaseSha: "f".repeat(40),
    firebaseProjectId: "pipe-production",
    publicSupportEmail: "support@pipebuyer.com",
    appCheckMode: "enforce",
  }));
  assert.throws(
      () => validateReleaseInputs({
        environment: "staging",
        releaseSha: "0".repeat(40),
        firebaseProjectId: "pipe-staging",
        publicSupportEmail: "support@pipebuyer.com",
        appCheckMode: "almost",
      }),
      /Unsupported App Check mode/u,
  );
});

test("client feature build approvals parse only exact booleans", () => {
  assert.equal(parseBooleanFlag(true), true);
  assert.equal(parseBooleanFlag(false), false);
  assert.equal(parseBooleanFlag("true"), true);
  assert.equal(parseBooleanFlag("FALSE"), false);
  assert.throws(() => parseBooleanFlag("yes", "dispatch"), /exactly true or false/u);
});

test("release validation accepts independent explicit feature build approvals", () => {
  assert.doesNotThrow(() => validateReleaseInputs({
    environment: "production",
    releaseSha: "9".repeat(40),
    firebaseProjectId: "pipe-production",
    publicSupportEmail: "support@pipebuyer.com",
    appCheckMode: "enforce",
    dispatchBuildEnabled: true,
    paidFeaturesBuildEnabled: true,
  }));
  assert.doesNotThrow(() => validateReleaseInputs({
    environment: "staging",
    releaseSha: "8".repeat(40),
    firebaseProjectId: "pipe-staging",
    publicSupportEmail: "support@pipebuyer.com",
    appCheckMode: "disabled",
    dispatchBuildEnabled: false,
    paidFeaturesBuildEnabled: true,
  }));
  assert.throws(() => validateReleaseInputs({
    environment: "staging",
    releaseSha: "7".repeat(40),
    firebaseProjectId: "pipe-staging",
    publicSupportEmail: "support@pipebuyer.com",
    dispatchBuildEnabled: "true",
  }), /build approvals must be boolean/u);
});

test("controlled release manifests reject uncommitted tracked source", () => {
  assert.throws(
      () => validateReleaseInputs({
        environment: "staging",
        releaseSha: "1".repeat(40),
        firebaseProjectId: "pipe-staging",
        publicSupportEmail: "support@pipebuyer.com",
        appCheckMode: "disabled",
        workingTreeClean: false,
      }),
      /require a clean working tree/u,
  );
  assert.doesNotThrow(() => validateReleaseInputs({
    environment: "local-verification",
    releaseSha: "2".repeat(40),
    firebaseProjectId: "",
    appCheckMode: "disabled",
    workingTreeClean: false,
  }));
});

test("unknown environments and abbreviated commits are rejected", () => {
  assert.throws(
      () => validateReleaseInputs({
        environment: "produciton",
        releaseSha: "c".repeat(40),
        firebaseProjectId: "pipe-production",
        publicSupportEmail: "support@pipebuyer.com",
      }),
      /Unsupported release environment/u,
  );
  assert.throws(
      () => validateReleaseInputs({
        environment: "development",
        releaseSha: "abc123",
        firebaseProjectId: "",
      }),
      /full 40-character Git commit/u,
  );
});

test("controlled manifests require a valid public support address", () => {
  assert.equal(isValidPublicSupportEmail("support@pipebuyer.com"), true);
  for (const value of ["", "support at pipebuyer.com", "user@example",
    "user@@example.com", "user@-example.com"]) {
    assert.equal(isValidPublicSupportEmail(value), false, value);
  }
  assert.throws(
      () => validateReleaseInputs({
        environment: "production",
        releaseSha: "3".repeat(40),
        firebaseProjectId: "pipe-production",
        publicSupportEmail: "",
        appCheckMode: "enforce",
      }),
      /PIPE_PUBLIC_SUPPORT_EMAIL/u,
  );
});
