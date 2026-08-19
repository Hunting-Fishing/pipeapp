"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {test} = require("node:test");

const functionsRoot = path.resolve(__dirname, "..");
const firebaseRoot = path.resolve(functionsRoot, "..");
const rules = fs.readFileSync(path.join(firebaseRoot, "firestore.rules"), "utf8");
const indexSource = fs.readFileSync(path.join(functionsRoot, "index.js"), "utf8");
const packageJson = JSON.parse(fs.readFileSync(path.join(functionsRoot, "package.json"), "utf8"));

test("Directory entries are readable to signed-in Dispatch users and never client writable", () => {
  const match = rules.match(
      /match \/dispatch_directory_entries\/\{companyId\} \{([\s\S]*?)\n    \}/,
  );
  assert.ok(match, "dispatch_directory_entries rules block is missing");
  const block = match[1];
  assert.match(block, /allow read: if phase1FeatureEnabled\('dispatch'\) && signedIn\(\);/);
  assert.match(block, /allow create, update, delete: if false;/);
  assert.equal(block.includes("owns(companyId)"), false);
  assert.equal(block.includes("isAdmin()"), false);
});

test("both public profile and authoritative carrier status changes refresh the Directory", () => {
  assert.match(indexSource, /createDispatchDirectoryProjection/);
  assert.match(indexSource, /public_business_profiles\/\{companyId\}/);
  assert.match(indexSource, /dispatch_carriers\/\{companyId\}/);
  assert.match(indexSource, /dispatchDirectoryProjection\.syncCompany\(event\.params\.companyId\)/);
});

test("standard function syntax gate includes the Directory projection module", () => {
  assert.match(
      packageJson.scripts.check,
      /node --check dispatch_directory_projection\.js/,
  );
});
