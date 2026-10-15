import assert from "node:assert/strict";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import {fileURLToPath} from "node:url";

import {
  createReleaseMarker,
  parseAndValidateReleaseMarker,
  serializeReleaseMarker,
  validateReleaseMarkerFile,
  validateReleaseMarkerResponse,
  writeReleaseMarker,
} from "./release_marker.mjs";

const repositoryRoot = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    "..",
);
const releaseSha = "a".repeat(40);

function fixtureRoot() {
  const root = mkdtempSync(path.join(os.tmpdir(), "pipe-release-marker-"));
  mkdirSync(path.join(root, "build", "web"), {recursive: true});
  writeFileSync(path.join(root, "pubspec.yaml"), [
    "name: pipe_app",
    "version: 1.0.5+6",
    "",
  ].join("\n"));
  writeFileSync(
      path.join(root, "build", "web", "index.html"),
      "<!doctype html><title>Pipe Buyer</title>\n",
  );
  return root;
}

test("release marker bytes are deterministic and contain only public identity", () => {
  const marker = createReleaseMarker({
    environment: "Production",
    releaseSha: releaseSha.toUpperCase(),
    version: "1.0.5+6",
  });
  assert.deepEqual(marker, {
    schemaVersion: 1,
    environment: "production",
    version: "1.0.5+6",
    releaseSha,
  });
  const expected = [
    "{",
    '  "schemaVersion": 1,',
    '  "environment": "production",',
    '  "version": "1.0.5+6",',
    `  "releaseSha": "${releaseSha}"`,
    "}",
    "",
  ].join("\n");
  assert.equal(serializeReleaseMarker(marker), expected);
  assert.equal(serializeReleaseMarker(marker), serializeReleaseMarker(marker));
  assert.doesNotMatch(expected, /generated|token|secret|timestamp/iu);
});

test("marker is written into the Firebase public root after the web build", () => {
  const root = fixtureRoot();
  const result = writeReleaseMarker({
    root,
    environment: "production",
    releaseSha,
  });
  const expectedPath = path.join(root, "build", "web", "pipe-release.json");
  assert.equal(result.output, expectedPath);
  assert.deepEqual(validateReleaseMarkerFile({
    root,
    environment: "production",
    releaseSha,
  }), result.marker);
  assert.notEqual(
      readFileSync(expectedPath, "utf8"),
      readFileSync(path.join(root, "build", "web", "index.html"), "utf8"),
  );
});

test("invalid or stale release identities fail closed", () => {
  assert.throws(
      () => createReleaseMarker({
        environment: "production",
        releaseSha: "short",
        version: "1.0.5+6",
      }),
      /full 40-character Git commit/u,
  );
  assert.throws(
      () => parseAndValidateReleaseMarker(
          serializeReleaseMarker(createReleaseMarker({
            environment: "staging",
            releaseSha,
            version: "1.0.5+6",
          })),
          {
            environment: "production",
            releaseSha,
            version: "1.0.5+6",
          },
      ),
      /environment mismatch/u,
  );
  assert.throws(
      () => parseAndValidateReleaseMarker(JSON.stringify({
        ...createReleaseMarker({
          environment: "production",
          releaseSha,
          version: "1.0.5+6",
        }),
        deployedAtUtc: "not-deterministic",
      }), {
        environment: "production",
        releaseSha,
        version: "1.0.5+6",
      }),
      /fields must be exactly/u,
  );
});

test("HTML SPA fallbacks are rejected before release identity parsing", () => {
  assert.throws(
      () => validateReleaseMarkerResponse({
        status: 200,
        contentType: "text/html; charset=utf-8",
        body: "<!doctype html><title>Pipe Buyer</title>",
        environment: "production",
        releaseSha,
        version: "1.0.5+6",
      }),
      /SPA index fallback is not acceptable/u,
  );
});

test("Firebase hosting keeps security headers and the SPA rewrite", () => {
  const firebase = JSON.parse(readFileSync(
      path.join(repositoryRoot, "firebase.json"),
      "utf8",
  ));
  assert.equal(firebase.hosting.public, "build/web");
  assert.deepEqual(firebase.hosting.rewrites.at(-1), {
    source: "**",
    destination: "/index.html",
  });
  const jsonHeader = firebase.hosting.headers.find(
      (entry) => entry.source === "**/*.@(html|json|js)",
  );
  assert.ok(jsonHeader, "HTML/JSON/JavaScript cache-control header is required.");
  assert.deepEqual(jsonHeader.headers, [{
    key: "Cache-Control",
    value: "max-age=0, no-cache, no-store, must-revalidate",
  }]);
  const securityHeader = firebase.hosting.headers.find(
      (entry) => entry.source === "**",
  );
  assert.ok(securityHeader, "Global security headers are required.");
  assert.ok(securityHeader.headers.some(
      (entry) => entry.key === "X-Content-Type-Options" &&
        entry.value === "nosniff",
  ));
});

test("every Firebase Hosting deploy generates the marker after its web build", () => {
  const workflowDirectory = path.join(repositoryRoot, ".github", "workflows");
  const candidates = [
    ...readdirSync(workflowDirectory)
        .filter((name) => /\.ya?ml$/u.test(name))
        .map((name) => path.join(workflowDirectory, name)),
    ...readdirSync(path.join(repositoryRoot, "tool"))
        .filter((name) => name.endsWith(".ps1"))
        .map((name) => path.join(repositoryRoot, "tool", name)),
  ];
  const hostingDeployers = candidates.filter((file) => {
    const source = readFileSync(file, "utf8");
    return /--only[^\r\n]*\bhosting\b/u.test(source) &&
      /(?:firebase|firebase-tools)[^\r\n]*deploy/u.test(source);
  });
  assert.ok(hostingDeployers.length >= 6, "Expected known Hosting deploy paths.");

  for (const file of hostingDeployers) {
    const source = readFileSync(file, "utf8");
    const buildIndex = source.indexOf("flutter build web");
    const markerIndex = source.indexOf("tool/release_marker.mjs", buildIndex);
    const hostingDeployIndex = source.search(/--only[^\r\n]*\bhosting\b/u);
    assert.ok(buildIndex >= 0, `${file} must build Flutter web before deploy.`);
    assert.ok(
        markerIndex > buildIndex,
        `${file} must generate pipe-release.json after Flutter build.`,
    );
    assert.ok(
        markerIndex < hostingDeployIndex,
        `${file} must generate pipe-release.json before Firebase deploy.`,
    );
  }
});

test("canonical deployment verifies and retains the exact live marker", () => {
  const workflow = readFileSync(
      path.join(repositoryRoot, ".github", "workflows", "deploy.yml"),
      "utf8",
  );
  const deployIndex = workflow.indexOf("firebase deploy");
  const verifyIndex = workflow.indexOf("--verify-url", deployIndex);
  assert.ok(deployIndex >= 0, "Canonical Firebase deployment step is required.");
  assert.ok(
      verifyIndex > deployIndex,
      "Canonical deployment must verify the live marker after deploy.",
  );
  assert.match(
      workflow,
      /build\/web\/pipe-release\.json/u,
      "Release evidence must retain the generated marker.",
  );
});
