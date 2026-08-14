"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const file = path.join(root, "firebase", "functions", "scripts", "seed_visual_sandbox.js");
let source = fs.readFileSync(file, "utf8");

if (!source.includes('"visual-bobcat-s160"')) {
  const anchor = `  const listings = {\n    "visual-pipe-drill": sellerListing("visual-pipe-drill", {`;
  const replacement = `  const listings = {\n    "visual-bobcat-s160": sellerListing("visual-bobcat-s160", {\n      title: "2011 Bobcat S160 Skid-Steer Loader",\n      category: "Heavy Equipment",\n      productType: "Skid Steer",\n      brand: "Bobcat",\n      model: "S160",\n      modelYear: 2011,\n      machineHours: 4860,\n      operatingStatus: "Operational",\n      price: 24500,\n      priceBasis: "Total",\n      quantity: 1,\n      condition: "Good",\n      description: "Visual sandbox machine for testing manufacturer-source approximate weights and Dispatch quote planning. Exact configuration and transport weight must be confirmed.",\n      weightInputMode: "catalog_estimate",\n      ageDays: -2,\n    }),\n    "visual-pipe-drill": sellerListing("visual-pipe-drill", {`;
  if (!source.includes(anchor)) throw new Error("Visual listing seed anchor not found");
  source = source.replace(anchor, replacement);
}

fs.writeFileSync(file, source, "utf8");
console.log("Added Bobcat S160 marketplace fixture for weight/Dispatch testing.");
