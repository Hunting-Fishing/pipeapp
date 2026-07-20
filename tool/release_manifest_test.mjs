import assert from "node:assert/strict";
import {mkdtempSync, mkdirSync, writeFileSync} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  extractFunctionExports,
  hashDirectory,
  hashRelativeFiles,
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
      }),
      /PIPE_FIREBASE_PROJECT_ID/u,
  );
  assert.doesNotThrow(() => validateReleaseInputs({
    environment: "staging",
    releaseSha: "b".repeat(40),
    firebaseProjectId: "pipe-staging",
  }));
});

test("unknown environments and abbreviated commits are rejected", () => {
  assert.throws(
      () => validateReleaseInputs({
        environment: "produciton",
        releaseSha: "c".repeat(40),
        firebaseProjectId: "pipe-production",
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
