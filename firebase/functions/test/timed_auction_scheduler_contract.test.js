"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = fs.readFileSync(
    path.join(__dirname, "..", "index.js"),
    "utf8",
);

test("timed auction monitor rotates bounded pages past poison records", () => {
  const monitorStart = source.indexOf("exports.monitorTimedAuctions");
  const nextExport = source.indexOf("exports.onPublicListingCreated", monitorStart);
  const helperStart = source.indexOf("async function rotatingTimedAuctionPage");
  assert.notEqual(monitorStart, -1);
  assert.notEqual(nextExport, -1);
  assert.notEqual(helperStart, -1);
  const monitor = source.slice(monitorStart, nextExport);
  const helper = source.slice(helperStart, monitorStart);
  const terminalFilter = monitor.indexOf(
      '.where("auctionStatus", "in", ["live", "scheduled"])',
  );
  const boundedExpiredPage = monitor.indexOf(
      'base.where("auctionEndAt", "<=", now)',
  );
  assert.ok(terminalFilter >= 0);
  assert.ok(boundedExpiredPage > terminalFilter);
  assert.match(helper, /\.orderBy\("auctionEndAt", "asc"\)/u);
  assert.match(helper, /FieldPath\.documentId\(\)/u);
  assert.match(helper, /\.startAfter\(cursorEndAt, String\(cursorListingId\)\)/u);
  assert.match(helper, /if \(page\.empty && hasCursor\)/u);
  assert.match(monitor, /timedAuctionCursorUpdate\(expired, "expired"\)/u);
  assert.match(
      monitor,
      /timedAuctionCursorUpdate\(endingSoon, "endingSoon"\)/u,
  );
  assert.doesNotMatch(
      monitor,
      /if \(!\["live", "scheduled"\]\.includes\(document\.data\(\)\.auctionStatus\)\)/u,
  );
});
