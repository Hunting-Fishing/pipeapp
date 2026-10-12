"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {test} = require("node:test");

const html = fs.readFileSync(
    path.resolve(__dirname, "..", "..", "..", "web", "index.html"),
    "utf8",
);
const viewport = html.match(/<meta[^>]*name="viewport"[^>]*>/);

test("the web shell declares a responsive viewport", () => {
  assert.ok(viewport, "viewport meta tag is missing");
  assert.match(viewport[0], /width=device-width/);
  assert.match(viewport[0], /initial-scale=1(\.0)?/);
});

test("the web shell never blocks pinch-zoom (WCAG 1.4.4 Resize Text)", () => {
  assert.ok(viewport, "viewport meta tag is missing");
  assert.equal(/user-scalable\s*=\s*(no|0)/i.test(viewport[0]), false);
  assert.equal(/maximum-scale\s*=\s*1(\.0)?(?![0-9])/i.test(viewport[0]), false);
});
