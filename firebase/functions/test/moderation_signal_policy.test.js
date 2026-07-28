"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  MAX_RELATED_LISTINGS,
  MAX_MESSAGE_EVIDENCE_CHARACTERS,
  classifyMessageSafety,
  duplicateListingMediaEvidence,
  duplicateListingMediaItems,
  messageContentEvidence,
  validImageHashes,
} = require("../moderation_signal_policy");

test("duplicate evidence includes only another listing with an exact hash", () => {
  const first = "a".repeat(64);
  const second = "b".repeat(64);
  const evidence = duplicateListingMediaEvidence({
    listingId: "current",
    imageHashes: [first, second],
    matches: [
      {id: "current", imageHashes: [first]},
      {id: "different-photo", imageHashes: ["c".repeat(64)]},
      {id: "duplicate", imageHashes: [second]},
    ],
  });

  assert.deepEqual(evidence.duplicateListingIds, ["duplicate"]);
  assert.deepEqual(evidence.matchedImageHashes, [second]);
});

test("duplicate evidence is normalized, deduplicated, and bounded", () => {
  const hash = "A".repeat(64);
  const matches = Array.from({length: MAX_RELATED_LISTINGS + 10}, (_, index) => ({
    id: `listing-${index}`,
    imageHashes: [hash],
  }));
  const evidence = duplicateListingMediaEvidence({
    listingId: "current",
    imageHashes: [hash, hash, "unsafe"],
    matches,
  });

  assert.equal(validImageHashes([hash, hash, "unsafe"]).length, 1);
  assert.equal(evidence.duplicateListingIds.length, MAX_RELATED_LISTINGS);
  assert.deepEqual(evidence.matchedImageHashes, [hash.toLowerCase()]);
});

test("message safety identifies review signals without a decision", () => {
  assert.deepEqual(
      classifyMessageSafety("Send a gift card off-platform."),
      {signals: ["possible_payment_fraud"], priority: "normal"},
  );
  assert.deepEqual(
      classifyMessageSafety("I will attack you and your crew."),
      {signals: ["possible_threat"], priority: "high"},
  );
  assert.deepEqual(
      classifyMessageSafety("That racial group is inferior and filthy."),
      {
        signals: ["possible_hate_or_racist_content"],
        priority: "normal",
      },
  );
  assert.deepEqual(
      classifyMessageSafety("The pipe is ready for pickup tomorrow."),
      {signals: [], priority: "normal"},
  );
});

test("duplicate media evidence includes bounded reviewable listing photos", () => {
  const hash = "d".repeat(64);
  const evidence = duplicateListingMediaEvidence({
    listingId: "current",
    imageHashes: [hash],
    matches: [{id: "related", imageHashes: [hash]}],
  });
  assert.deepEqual(duplicateListingMediaItems({
    listingId: "current",
    listing: {
      title: "Current listing",
      imageHashes: [hash],
      imageUrls: ["https://storage.test/current.jpg"],
    },
    matches: [{
      id: "related",
      title: "Related listing",
      imageHashes: [hash],
      imageUrls: ["https://storage.test/related.jpg"],
    }],
    evidence,
  }), [
    {
      listingId: "current",
      listingTitle: "Current listing",
      matchedImageHash: hash,
      photoUrl: "https://storage.test/current.jpg",
    },
    {
      listingId: "related",
      listingTitle: "Related listing",
      matchedImageHash: hash,
      photoUrl: "https://storage.test/related.jpg",
    },
  ]);
});

test("message evidence is reviewable, unicode safe, and bounded", () => {
  const longMessage = `Payment instruction ${"🚚".repeat(600)}`;
  const evidence = messageContentEvidence(longMessage);
  assert.equal(Array.from(evidence.excerpt).length,
      MAX_MESSAGE_EVIDENCE_CHARACTERS);
  assert.equal(evidence.characterCount, Array.from(longMessage).length);
  assert.equal(evidence.truncated, true);
  assert.equal(evidence.excerpt.endsWith("\ud83d"), false);
});

test("automated review intake is bounded, indexed, and human controlled", () => {
  const functionsRoot = path.join(__dirname, "..");
  const indexSource = fs.readFileSync(
      path.join(functionsRoot, "index.js"),
      "utf8",
  );
  const indexes = fs.readFileSync(
      path.join(functionsRoot, "..", "firestore.indexes.json"),
      "utf8",
  );

  assert.match(
      indexSource,
      /where\("imageHashes", "array-contains-any", hashes\)[\s\S]{0,80}\.limit\(100\)/,
  );
  assert.match(indexSource, /humanReviewRequired: true/);
  assert.match(indexSource, /automaticEnforcement: false/);
  assert.match(indexSource, /if \(existing\.exists\) return false/);
  assert.match(
      indexes,
      /"fieldPath": "sellerUid"[\s\S]{0,120}"fieldPath": "imageHashes"[\s\S]{0,80}"arrayConfig": "CONTAINS"/,
  );
});
