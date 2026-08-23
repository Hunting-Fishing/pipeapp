import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import {mkdtempSync, mkdirSync, writeFileSync} from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  compareCompatibilitySurface,
  functionInventoryAtRevision,
  routeInventoryFromSource,
} from "./autonomous_compatibility.mjs";

function git(root, args) {
  execFileSync("git", args, {cwd: root, stdio: "ignore"});
}

function fixture() {
  const root = mkdtempSync(path.join(os.tmpdir(), "pipe-compatibility-"));
  mkdirSync(path.join(root, "lib", "flutter_flow", "nav"), {recursive: true});
  mkdirSync(path.join(root, "firebase", "functions"), {recursive: true});
  mkdirSync(path.join(root, "firebase", "agent-functions"), {recursive: true});
  writeFileSync(path.join(root, "firebase.json"), JSON.stringify({
    functions: [
      {source: "firebase/functions", codebase: "marketplace"},
      {source: "firebase/agent-functions", codebase: "functions"},
    ],
  }));
  writeFileSync(path.join(root, "firebase", "functions", "package.json"), JSON.stringify({main: "bootstrap.js"}));
  writeFileSync(path.join(root, "firebase", "functions", "bootstrap.js"), `
    const core = require("./index");
    Object.assign(exports, core);
    exports.createCheckout = true;
  `);
  writeFileSync(path.join(root, "firebase", "functions", "index.js"), `
    exports.createOffer = true;
    exports.acceptOffer = true;
  `);
  writeFileSync(path.join(root, "firebase", "agent-functions", "package.json"), JSON.stringify({main: "index.js"}));
  writeFileSync(path.join(root, "firebase", "agent-functions", "index.js"), "exports.agent = true;\n");
  writeFileSync(path.join(root, "lib", "flutter_flow", "nav", "nav.dart"), `
    final routes = [
      FFRoute(name: 'home', path: '/', builder: homeBuilder),
      FFRoute(name: 'listing', path: '/listings/:id', builder: listingBuilder),
    ];
  `);
  git(root, ["init"]);
  git(root, ["config", "user.email", "compatibility@example.invalid"]);
  git(root, ["config", "user.name", "Compatibility Test"]);
  git(root, ["add", "-A"]);
  git(root, ["commit", "-m", "baseline"]);
  return root;
}

test("route parser records stable name/path signatures", () => {
  assert.deepEqual(routeInventoryFromSource(`
    FFRoute(
      name: MarketplaceDeepLinks.listingRouteName,
      path: '/listings/:listingId',
      builder: listingBuilder,
    ),
  `), ["MarketplaceDeepLinks.listingRouteName :: '/listings/:listingId'"]);
});

test("Function inventory follows production re-export chain", () => {
  const root = fixture();
  assert.deepEqual(functionInventoryAtRevision(root), {
    marketplace: ["acceptOffer", "createCheckout", "createOffer"],
    functions: ["agent"],
  });
});

test("additive routes and Functions preserve compatibility", () => {
  const root = fixture();
  writeFileSync(path.join(root, "firebase", "functions", "index.js"), `
    exports.createOffer = true;
    exports.acceptOffer = true;
    exports.counterOffer = true;
  `);
  writeFileSync(path.join(root, "lib", "flutter_flow", "nav", "nav.dart"), `
    final routes = [
      FFRoute(name: 'home', path: '/', builder: homeBuilder),
      FFRoute(name: 'listing', path: '/listings/:id', builder: listingBuilder),
      FFRoute(name: 'wanted', path: '/wanted', builder: wantedBuilder),
    ];
  `);
  const result = compareCompatibilitySurface(root);
  assert.equal(result.passed, true);
  assert.deepEqual(result.missingRoutes, []);
  assert.deepEqual(result.missingFunctions, []);
});

test("removing a route fails compatibility preservation", () => {
  const root = fixture();
  writeFileSync(path.join(root, "lib", "flutter_flow", "nav", "nav.dart"), `
    final routes = [
      FFRoute(name: 'home', path: '/', builder: homeBuilder),
    ];
  `);
  const result = compareCompatibilitySurface(root);
  assert.equal(result.passed, false);
  assert.deepEqual(result.missingRoutes, ["'listing' :: '/listings/:id'"]);
});

test("removing a production Function fails compatibility preservation", () => {
  const root = fixture();
  writeFileSync(path.join(root, "firebase", "functions", "index.js"), `
    exports.createOffer = true;
  `);
  const result = compareCompatibilitySurface(root);
  assert.equal(result.passed, false);
  assert.deepEqual(result.missingFunctions, ["marketplace:acceptOffer"]);
});

test("removing an entire Function codebase fails closed", () => {
  const root = fixture();
  writeFileSync(path.join(root, "firebase.json"), JSON.stringify({
    functions: [{source: "firebase/functions", codebase: "marketplace"}],
  }));
  const result = compareCompatibilitySurface(root);
  assert.equal(result.passed, false);
  assert.deepEqual(result.missingFunctions, ["functions:<codebase removed>"]);
});
