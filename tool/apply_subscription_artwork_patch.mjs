"use strict";

import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const target = path.join(root, "lib", "marketplace", "marketplace_vip_access.dart");

function replaceOnce(source, search, replacement, label) {
  const first = source.indexOf(search);
  if (first < 0) throw new Error(`Subscription artwork anchor missing: ${label}`);
  if (source.indexOf(search, first + search.length) >= 0) {
    throw new Error(`Subscription artwork anchor ambiguous: ${label}`);
  }
  return source.slice(0, first) + replacement + source.slice(first + search.length);
}

let source = fs.readFileSync(target, "utf8");
if (!source.includes("marketplace_subscription_artwork.dart")) {
  source = replaceOnce(
    source,
    "import 'industrial_icon_assets.dart';",
    "import 'industrial_icon_assets.dart';\nimport 'marketplace_subscription_artwork.dart';",
    "import",
  );
}
if (!source.includes("// PIPEBUYER_SUBSCRIPTION_ARTWORK_V1")) {
  source = replaceOnce(
    source,
    `                child: Center(
                  child: IndustrialAssetIcon(
                    label: artworkLabel,
                    size: 112,
                    borderRadius: 12,
                    fallback: Icon(
                      icon,
                      size: 58,
                      color: premium ? const Color(0xFFFFB21A) : PipeBuyerColors.orange,
                    ),
                  ),
                ),`,
    `                // PIPEBUYER_SUBSCRIPTION_ARTWORK_V1
                child: MarketplaceSubscriptionArtwork(
                  planTitle: title,
                  fallbackLabel: artworkLabel,
                  height: 130,
                ),`,
    "plan artwork",
  );
}
fs.writeFileSync(target, source);
execFileSync("dart", ["format", target], {cwd: root, stdio: "inherit"});
execFileSync("flutter", ["analyze",
  "lib/marketplace/marketplace_vip_access.dart",
  "lib/marketplace/marketplace_subscription_artwork.dart",
], {cwd: root, stdio: "inherit"});
