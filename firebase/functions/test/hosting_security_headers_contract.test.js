"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {test} = require("node:test");

const config = JSON.parse(fs.readFileSync(
    path.resolve(__dirname, "..", "..", "..", "firebase.json"),
    "utf8",
));
const blocks = config.hosting.headers;
const headersFor = (source) => {
  const block = blocks.find((entry) => entry.source === source);
  assert.ok(block, `hosting header block ${source} is missing`);
  return Object.fromEntries(block.headers.map(({key, value}) => [key, value]));
};

test("every hosted response carries the baseline security headers", () => {
  const all = headersFor("**");
  assert.equal(all["X-Content-Type-Options"], "nosniff");
  assert.equal(all["Referrer-Policy"], "strict-origin-when-cross-origin");
  assert.match(all["Permissions-Policy"], /geolocation=\(self\)/);
  assert.match(all["Permissions-Policy"], /microphone=\(\)/);
});

test("framing is limited to same origin so Firebase Auth's same-origin iframe keeps working", () => {
  const all = headersFor("**");
  assert.equal(all["X-Frame-Options"], "SAMEORIGIN");
  assert.notEqual(all["X-Frame-Options"], "DENY");
});

test("app shell files stay uncached so releases take effect immediately", () => {
  const shell = headersFor("**/*.@(html|json|js)");
  assert.match(shell["Cache-Control"], /no-store/);
});

test("emulator-only payment secrets can never be committed by accident", () => {
  const ignore = fs.readFileSync(
      path.resolve(__dirname, "..", "..", "..", ".gitignore"),
      "utf8",
  );
  assert.match(ignore, /^firebase\/functions\/\.secret\.local\s*$/m);
});
