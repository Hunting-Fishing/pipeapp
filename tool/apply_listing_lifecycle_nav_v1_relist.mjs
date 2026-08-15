"use strict";

import fs from "node:fs";
import path from "node:path";

const rel = "firebase/functions/marketplace_commands.js";
const target = path.join(process.cwd(), rel);
let text = fs.readFileSync(target, "utf8");

function replaceOnce(before, after, label) {
  if (text.includes(after)) return;
  const first = text.indexOf(before);
  if (first < 0) throw new Error(`Patch anchor not found: ${label}`);
  if (text.indexOf(before, first + before.length) >= 0) {
    throw new Error(`Patch anchor is not unique: ${label}`);
  }
  text = text.slice(0, first) + after + text.slice(first + before.length);
}

replaceOnce(
    '        "buyNowPrice", "convertedAt", "conversionSource", "fulfilledAt",\n' +
    '        "lastMatchedAt",',
    '        "buyNowPrice", "convertedAt", "conversionSource", "fulfilledAt",\n' +
    '        "lastMatchedAt", "publishedAt", "expiresAt", "renewedAt",\n' +
    '        "expiredAt", "listingDurationDays", "renewalCount",\n' +
    '        "lifecycleVersion", "expiryWarningSentAt", "expiryWarningFor",',
    "relist lifecycle reset fields",
);

replaceOnce(
    '        source: "marketplace_relist_callable",\n' +
    '        relistedFromListingId: listingId,\n' +
    '        initialPrice: Number(clone.price || 0),',
    '        source: "marketplace_relist_callable",\n' +
    '        relistedFromListingId: listingId,\n' +
    '        publishedAt: Timestamp.now(),\n' +
    '        expiresAt: Timestamp.fromMillis(\n' +
    '          Date.now() + MARKETPLACE_LISTING_ACTIVE_DAYS * DAY_MS,\n' +
    '        ),\n' +
    '        listingDurationDays: MARKETPLACE_LISTING_ACTIVE_DAYS,\n' +
    '        renewalCount: 0,\n' +
    '        lifecycleVersion: 1,\n' +
    '        initialPrice: Number(clone.price || 0),',
    "relist fresh lifecycle",
);

fs.writeFileSync(target, text, "utf8");
console.log(`patched: ${rel} relist lifecycle reset`);
