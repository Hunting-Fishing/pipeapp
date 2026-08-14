"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const write = (file, value) => fs.writeFileSync(path.join(root, file), value, "utf8");

function replaceOnce(source, before, after, label) {
  if (source.includes(after)) return source;
  const index = source.indexOf(before);
  if (index < 0) throw new Error(`Anchor not found: ${label}`);
  return source.slice(0, index) + after + source.slice(index + before.length);
}

{
  const file = "firebase/functions/marketplace_listing_policy.js";
  let source = read(file);
  source = replaceOnce(
    source,
    `  "quantityAndLength",\n`,
    `  "quantityAndLength",\n  // Client preference/source inputs only. The trusted weightSnapshot is\n  // server-generated after publication and cannot be supplied by clients.\n  "weightInputMode",\n  "sellerEstimatedWeightKg",\n  "sellerWeightSource",\n  "jointLengthFt",\n  "jointLengthM",\n  "nominalWeightLbFt",\n  "outsideDiameterMm",\n  "wallThicknessMm",\n`,
    "listing weight input fields",
  );
  source = replaceOnce(
    source,
    `  listing.transactionType = transactionType;\n`,
    `  listing.transactionType = transactionType;\n\n  // PIPEBUYER_WEIGHT_INPUT_V1\n  const weightInputMode = String(listing.weightInputMode || "catalog_estimate");\n  if (!["catalog_estimate", "seller_estimate", "unknown"].includes(weightInputMode)) {\n    invalid("Weight preference is invalid.");\n  }\n  listing.weightInputMode = weightInputMode;\n  if (weightInputMode === "seller_estimate") {\n    const sellerWeight = Number(listing.sellerEstimatedWeightKg);\n    if (!Number.isFinite(sellerWeight) || sellerWeight <= 0 || sellerWeight > 100000000) {\n      invalid("Seller estimated shipping weight must be greater than zero.");\n    }\n    listing.sellerEstimatedWeightKg = sellerWeight;\n    listing.sellerWeightSource = "seller_estimate";\n  } else {\n    delete listing.sellerEstimatedWeightKg;\n    delete listing.sellerWeightSource;\n  }\n  for (const field of [\n    "jointLengthFt", "jointLengthM", "nominalWeightLbFt",\n    "outsideDiameterMm", "wallThicknessMm",\n  ]) {\n    if (listing[field] == null || listing[field] === "") continue;\n    const number = Number(listing[field]);\n    if (!Number.isFinite(number) || number <= 0 || number > 1000000) {\n      invalid(\`\${field} must be greater than zero.\`);\n    }\n    listing[field] = number;\n  }\n`,
    "weight input validation",
  );
  write(file, source);
}

{
  const file = "firebase/functions/index.js";
  let source = read(file);
  if (!source.includes('require("./marketplace_weight_policy")')) {
    const anchor = `const { createMarketplaceCommands } = require("./marketplace_commands");\n`;
    source = replaceOnce(
      source,
      anchor,
      `${anchor}const {\n  applyWeightSnapshot,\n  resolveListingWeightSnapshot,\n} = require("./marketplace_weight_policy");\n`,
      "weight policy import",
    );
  }
  if (!source.includes("function listingWeightFingerprint")) {
    const anchor = `async function notifyActiveAdministrators(notification) {\n`;
    const helper = `function listingWeightFingerprint(listing) {\n  if (!listing) return "";\n  const fields = [\n    "category", "productType", "brand", "make", "model", "modelYear",\n    "pipeSize", "quantity", "weightInputMode", "sellerEstimatedWeightKg",\n    "jointLengthFt", "jointLengthM", "nominalWeightLbFt",\n    "outsideDiameterMm", "wallThicknessMm",\n  ];\n  return JSON.stringify(fields.map((field) => listing[field] ?? null));\n}\n\n`;
    source = replaceOnce(source, anchor, helper + anchor, "weight fingerprint helper");
  }
  if (!source.includes("exports.onPublicListingWeightSnapshot")) {
    const anchor = `// Reserve amounts are seller-only. This guard also cleans legacy clients that\n`;
    const block = `// Maintains a frozen planning-weight snapshot on each listing. A later catalog\n// edit does not rewrite historical listings; the snapshot is recalculated only\n// when weight-driving listing fields themselves change.\nexports.onPublicListingWeightSnapshot = onDocumentWritten(\n  "public_listings/{listingId}",\n  async (event) => {\n    const before = event.data.before.exists ? event.data.before.data() : null;\n    const after = event.data.after.exists ? event.data.after.data() : null;\n    if (!after) return null;\n    if (after.weightSnapshot &&\n        listingWeightFingerprint(before) === listingWeightFingerprint(after)) {\n      return null;\n    }\n    const snapshot = await resolveListingWeightSnapshot(admin.firestore(), after);\n    const weighted = applyWeightSnapshot(after, snapshot);\n    await event.data.after.ref.set({\n      weightSnapshot: weighted.weightSnapshot,\n      weightStatus: weighted.weightStatus,\n      weightSource: weighted.weightSource,\n      weightConfidence: weighted.weightConfidence,\n      shippingWeightKg: weighted.shippingWeightKg || null,\n      catalogWeightKg: weighted.catalogWeightKg || null,\n      weightSnapshotCreatedAt: admin.firestore.FieldValue.serverTimestamp(),\n    }, {merge: true});\n    return null;\n  },\n);\n\n`;
    source = replaceOnce(source, anchor, block + anchor, "listing weight snapshot trigger");
  }
  write(file, source);
}

{
  const file = "firebase/functions/communication_command_policy.js";
  let source = read(file);
  source = replaceOnce(
    source,
    `    maximumBytes: 15 * 1024 * 1024,\n    contentTypes: new Set([\n      "image/jpeg",\n      "image/png",\n      "image/webp",\n      "application/pdf",\n    ]),\n`,
    `    maximumBytes: 25 * 1024 * 1024,\n    imageMaximumBytes: 15 * 1024 * 1024,\n    contentTypes: new Set([\n      "image/jpeg",\n      "image/png",\n      "image/webp",\n      "application/pdf",\n      "video/mp4",\n      "video/quicktime",\n    ]),\n`,
    "chat video content types",
  );
  source = replaceOnce(
    source,
    `  if (!policy.contentTypes.has(contentType)) {\n`,
    `  if (policy.imageMaximumBytes &&\n      (contentType.startsWith("image/") || contentType === "application/pdf") &&\n      sizeBytes > policy.imageMaximumBytes) {\n    throw new CommunicationPolicyError(\n        "invalid-argument",\n        \`Images and documents must be \${policy.imageMaximumBytes} bytes or smaller.\`,\n    );\n  }\n  if (!policy.contentTypes.has(contentType)) {\n`,
    "image/document upload sublimit",
  );
  write(file, source);
}

{
  const file = "tool/start_live_test_sandbox.ps1";
  let source = read(file);
  if (!source.includes("seed_live_test_weight_catalog.js")) {
    const anchor = `  & node (Join-Path $functionsDir 'scripts\\seed_live_test_dispatch_access.js')\n  if ($LASTEXITCODE -ne 0) {\n    throw 'Dispatch carrier-access seed failed. Check the error above.'\n  }\n`;
    source = replaceOnce(
      source,
      anchor,
      `${anchor}\n  & node (Join-Path $functionsDir 'scripts\\seed_live_test_weight_catalog.js')\n  if ($LASTEXITCODE -ne 0) {\n    throw 'Weight catalog seed failed. Check the error above.'\n  }\n`,
      "sandbox weight catalog seeder",
    );
  }
  write(file, source);
}

console.log("Patched stable listing weight snapshots, schema, chat media policy, and sandbox seed.");
