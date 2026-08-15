"use strict";

import fs from "node:fs";
import path from "node:path";

const root = process.cwd();

function read(rel) {
  return fs.readFileSync(path.join(root, rel), "utf8");
}

function write(rel, text) {
  fs.writeFileSync(path.join(root, rel), text, "utf8");
  console.log(`patched: ${rel}`);
}

function patchAccountHub() {
  const rel = "lib/marketplace/marketplace_account_hub.dart";
  let text = read(rel);
  const bad = "listingTitle: String(data['title'] ?? 'Marketplace listing'),";
  const good = "listingTitle: '${data['title'] ?? 'Marketplace listing'}',";
  const count = text.split(bad).length - 1;
  if (count > 0) {
    text = text.split(bad).join(good);
    console.log(`fixed: ${count} invalid Dart String constructor call(s)`);
  }
  if (!text.includes(good)) {
    throw new Error("Expected smart-suggestion listingTitle wiring was not found.");
  }
  write(rel, text);
}

function patchRemovedHomeHeroHelper() {
  const rel = "lib/marketplace/oil_gas_marketplace.dart";
  let text = read(rel);
  const startMarker = "class _HeroDiscoveryChip extends StatelessWidget {";
  const nextMarker = "class _HomeQuickActions extends StatelessWidget {";
  const start = text.indexOf(startMarker);
  if (start >= 0) {
    const next = text.indexOf(nextMarker, start);
    if (next < 0) {
      throw new Error("Could not locate _HomeQuickActions after _HeroDiscoveryChip.");
    }
    text = text.slice(0, start) + text.slice(next);
    console.log("removed: obsolete _HeroDiscoveryChip after Home hero replacement");
  }
  if (text.includes(startMarker)) {
    throw new Error("_HeroDiscoveryChip removal did not complete.");
  }
  write(rel, text);
}

patchAccountHub();
patchRemovedHomeHeroHelper();
console.log("Lifecycle Dart analyzer cleanup completed.");
