"use strict";

import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const target = (rel) => path.join(root, rel);
const read = (rel) => fs.readFileSync(target(rel), "utf8");
const write = (rel, text) => {
  fs.writeFileSync(target(rel), text, "utf8");
  console.log(`patched: ${rel}`);
};

function replaceOnce(text, before, after, label) {
  if (text.includes(after)) return text;
  const first = text.indexOf(before);
  if (first < 0) throw new Error(`Patch anchor not found: ${label}`);
  if (text.indexOf(before, first + before.length) >= 0) {
    throw new Error(`Patch anchor is not unique: ${label}`);
  }
  return text.slice(0, first) + after + text.slice(first + before.length);
}

function patchMarketplaceCommands() {
  const rel = "firebase/functions/marketplace_commands.js";
  let text = read(rel);
  text = replaceOnce(
      text,
      'const {buildDispatchRouteState} = require("./dispatch_routing_policy");',
      'const {buildDispatchRouteState} = require("./dispatch_routing_policy");\n' +
      'const {\n' +
      '  DAY_MS,\n' +
      '  MARKETPLACE_LISTING_ACTIVE_DAYS,\n' +
      '} = require("./marketplace_listing_lifecycle");',
      "marketplace lifecycle constants import",
  );
  const before = '        ...(typeof listing.price === "number" ? {\n' +
      '          initialPrice: listing.price,\n' +
      '        } : {}),\n' +
      '        createdAt: FieldValue.serverTimestamp(),\n' +
      '        updatedAt: FieldValue.serverTimestamp(),\n' +
      '        source: "marketplace_callable",\n' +
      '        status: "active",';
  const after = '        ...(typeof listing.price === "number" ? {\n' +
      '          initialPrice: listing.price,\n' +
      '        } : {}),\n' +
      '        publishedAt: Timestamp.now(),\n' +
      '        expiresAt: Timestamp.fromMillis(\n' +
      '          Date.now() + MARKETPLACE_LISTING_ACTIVE_DAYS * DAY_MS,\n' +
      '        ),\n' +
      '        listingDurationDays: MARKETPLACE_LISTING_ACTIVE_DAYS,\n' +
      '        renewalCount: 0,\n' +
      '        lifecycleVersion: 1,\n' +
      '        createdAt: FieldValue.serverTimestamp(),\n' +
      '        updatedAt: FieldValue.serverTimestamp(),\n' +
      '        source: "marketplace_callable",\n' +
      '        status: "active",';
  text = replaceOnce(text, before, after, "authoritative 30-day publication fields");
  write(rel, text);
}

function patchListingStatus() {
  const rel = "lib/marketplace/marketplace_listing_status.dart";
  let text = read(rel);
  text = replaceOnce(
      text,
      "import '../core/design/pipe_buyer_theme.dart';",
      "import '../core/design/pipe_buyer_theme.dart';\nimport 'marketplace_listing_lifecycle.dart';",
      "listing lifecycle status import",
  );
  text = replaceOnce(
      text,
      "    final boosted = '${data['boostStatus'] ?? ''}'.toLowerCase() == 'active';\n    final verifiedSeller = data['sellerVerified'] == true;",
      "    final boosted = '${data['boostStatus'] ?? ''}'.toLowerCase() == 'active';\n    final verifiedSeller = data['sellerVerified'] == true;\n    final lifecycle = MarketplaceListingLifecycle.fromMap(data, now: clock);\n    final expired = !isAuction && lifecycle.expired;\n    final listingExpiresSoon = !isAuction && lifecycle.expiringSoon;",
      "listing lifecycle presentation state",
  );
  text = replaceOnce(
      text,
      "      if (isOwner)\n        const MarketplaceListingBadge(\n          label: 'Your listing',\n          icon: Icons.admin_panel_settings_outlined,\n          color: _ownerBlue,\n        ),\n      if (isWanted)",
      "      if (isOwner)\n        const MarketplaceListingBadge(\n          label: 'Your listing',\n          icon: Icons.admin_panel_settings_outlined,\n          color: _ownerBlue,\n        ),\n      if (expired)\n        const MarketplaceListingBadge(\n          label: 'Expired',\n          icon: Icons.event_busy_outlined,\n          color: _urgentRed,\n        )\n      else if (listingExpiresSoon)\n        MarketplaceListingBadge(\n          label: lifecycle.daysRemaining == 1\n              ? 'Expires tomorrow'\n              : 'Expires in ${lifecycle.daysRemaining} days',\n          icon: Icons.event_outlined,\n          color: _offerOrange,\n        ),\n      if (isWanted)",
      "expired listing badge",
  );
  text = replaceOnce(
      text,
      "    final primary = isOwner\n        ? _ownerBlue\n        : isWanted",
      "    final primary = expired\n        ? _urgentRed\n        : listingExpiresSoon\n            ? _offerOrange\n            : isOwner\n                ? _ownerBlue\n                : isWanted",
      "expired listing primary color",
  );
  write(rel, text);
}

patchMarketplaceCommands();
patchListingStatus();
await import("./apply_listing_lifecycle_nav_v1_relist.mjs");
await import("./apply_listing_lifecycle_nav_v1_dartfix.mjs");
console.log("Listing publication/lifecycle presentation hardening completed.");
