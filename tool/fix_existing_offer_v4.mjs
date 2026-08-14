"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const target = path.join(root, "lib", "marketplace", "oil_gas_marketplace.dart");

let source = fs.readFileSync(target, "utf8");

if (!source.includes("PIPEBUYER_OFFER_SUMMARY_V4")) {
  throw new Error(
    "The local Marketplace file does not contain the V4 offer marker. Use apply_offer_summary_v4.ps1 instead.",
  );
}

if (!source.includes("MarketplaceOfferCommerceSummary(")) {
  throw new Error(
    "The V4 marker exists but MarketplaceOfferCommerceSummary is missing. Stop and inspect the local diff before continuing.",
  );
}

if (!source.includes("import 'marketplace_offer_commerce_summary.dart';")) {
  const anchor = "import 'marketplace_offer_analysis.dart';";
  if (!source.includes(anchor)) {
    throw new Error("marketplace_offer_analysis.dart import is missing.");
  }
  source = source.replace(
    anchor,
    `${anchor}\nimport 'marketplace_offer_commerce_summary.dart';`,
  );
}

// Normalize an earlier local V4 draft that mislabeled per-joint inventory as pieces.
source = source.replace(
  /final unitLabel = basisLower\.contains\('joint'\)\s*\?\s*'pieces'\s*:\s*'units';/,
  `final unitLabel = basisLower.contains('joint')\n                  ? 'joints'\n                  : basisLower.contains('piece') || basisLower.contains('each')\n                      ? 'pieces'\n                      : 'units';`,
);

// Also normalize any partial nested draft that still maps joint -> pieces.
source = source.replace(
  /final unitLabel = basisLower\.contains\('joint'\)\s*\?\s*'pieces'\s*:\s*basisLower\.contains\('piece'\) \|\| basisLower\.contains\('each'\)\s*\?\s*'pieces'\s*:\s*'units';/,
  `final unitLabel = basisLower.contains('joint')\n                  ? 'joints'\n                  : basisLower.contains('piece') || basisLower.contains('each')\n                      ? 'pieces'\n                      : 'units';`,
);

fs.writeFileSync(target, source, "utf8");
console.log("Existing Make Offer V4 patch normalized for validation.");
