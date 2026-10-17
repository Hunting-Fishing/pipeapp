"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const functionsRoot = path.resolve(__dirname, "..");
const firebaseRoot = path.resolve(functionsRoot, "..");
const readFunction = (file) => fs.readFileSync(
    path.join(functionsRoot, file),
    "utf8",
);

test("listing publication never derives fee class from seller catalog fields", () => {
  const commands = readFunction("marketplace_commands.js");
  assert.doesNotMatch(commands, /canonicalMarketplaceFeeClassification/u);
  assert.match(commands, /revision: 1,/u);
});

test("monetization reads the separate server-only approval document", () => {
  const monetization = readFunction("marketplace_monetization.js");
  assert.match(
      monetization,
      /collection\("marketplace_fee_classifications"\)\.doc\(listingId\)/u,
  );
  assert.match(monetization, /feeClassification: classificationSnapshot/u);
});

test("only the protected administrator callable writes classifications", () => {
  const bootstrap = readFunction("production_bootstrap.js");
  assert.match(
      bootstrap,
      /exports\.setMarketplaceListingFeeClassification = onCall\(\s*protectedCallableOptions/u,
  );
  const rules = fs.readFileSync(
      path.join(firebaseRoot, "firestore.rules"),
      "utf8",
  );
  assert.match(
      rules,
      /match \/marketplace_fee_classifications\/\{listingId\} \{\s*allow read: if isAdmin\(\);\s*allow create, update, delete: if false;/u,
  );
});
