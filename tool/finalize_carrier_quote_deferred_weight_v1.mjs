"use strict";

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const file = path.join(root, "lib", "marketplace", "marketplace_freight_quote.dart");
if (!fs.existsSync(file)) throw new Error("marketplace_freight_quote.dart is missing.");
let source = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");

const upgraded = "          catalogWeightKg: draft.weightUnknown ? null : estimate.kg,\n";
if (!source.includes(upgraded)) {
  const old = "          catalogWeightKg: estimate.kg,\n";
  const index = source.indexOf(old);
  if (index < 0) {
    throw new Error("Carrier quote catalogWeightKg anchor changed; review before applying deferred-weight finalizer.");
  }
  source = source.slice(0, index) + upgraded + source.slice(index + old.length);
}

if (!source.includes("weightSource: draft.weightSource,")) {
  throw new Error("Premium carrier quote migration must run before deferred-weight finalizer.");
}
if (!source.includes("draft.weightUnknown ? null : estimate.kg")) {
  throw new Error("Deferred weight still leaves a catalog value on the published Dispatch job.");
}

fs.writeFileSync(file, source, "utf8");
console.log("Deferred carrier-request weight finalized: explicit unknown sends no estimated or catalog weight to Dispatch payload checks.");
