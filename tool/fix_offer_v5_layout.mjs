"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const target = path.join(
  root,
  "lib",
  "marketplace",
  "marketplace_offer_commerce_summary.dart",
);

let source = fs.readFileSync(target, "utf8");
source = source.replace(
  "            crossAxisAlignment: CrossAxisAlignment.stretch,",
  "            crossAxisAlignment: CrossAxisAlignment.start,",
);
source = source.replace(
  "  Widget build(BuildContext context) => Container(\n        height: double.infinity,\n        padding: const EdgeInsets.all(12),",
  "  Widget build(BuildContext context) => Container(\n        padding: const EdgeInsets.all(12),",
);
fs.writeFileSync(target, source, "utf8");
console.log("Normalized Make Offer V5 row constraints for scrollable dialogs.");
