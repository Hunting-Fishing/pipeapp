"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const target = path.join(root, "lib", "marketplace", "oil_gas_marketplace.dart");

function replaceOnce(source, search, replacement, label) {
  const first = source.indexOf(search);
  if (first < 0) throw new Error(`Patch anchor missing: ${label}`);
  const second = source.indexOf(search, first + search.length);
  if (second >= 0) throw new Error(`Patch anchor ambiguous: ${label}`);
  return source.slice(0, first) + replacement + source.slice(first + search.length);
}

function replaceRegexOnce(source, regex, replacement, label) {
  const flags = regex.flags.includes("g") ? regex.flags : `${regex.flags}g`;
  const finder = new RegExp(regex.source, flags);
  const matches = [...source.matchAll(finder)];
  if (matches.length !== 1) {
    throw new Error(`Expected exactly one ${label}; found ${matches.length}.`);
  }
  return source.replace(regex, replacement);
}

let source = fs.readFileSync(target, "utf8");
if (source.includes("PIPEBUYER_OFFER_SUMMARY_V4")) {
  console.log("Make Offer V4 summary is already applied.");
  process.exit(0);
}

source = replaceOnce(
  source,
  "import 'marketplace_listing_media.dart';",
  "import 'marketplace_listing_media.dart';\nimport 'marketplace_offer_analysis.dart';\nimport 'marketplace_offer_commerce_summary.dart';",
  "offer summary imports",
);

source = replaceOnce(
  source,
  `              final askingUnit = listing.numericPrice ?? 0;\n              final askingTotal = askingUnit * requestedQty;\n              final offeredTotal = offeredUnit * requestedQty;\n              final difference = offeredTotal - askingTotal;\n              final percent =\n                  askingTotal == 0 ? 0 : (difference / askingTotal * 100);`,
  `              final askingUnit = listing.numericPrice ?? 0;\n              final listedQty = listing.quantity ??\n                  (requestedQty > 0 ? requestedQty : 1);\n              final basisLower = listing.priceBasis.toLowerCase();\n              final unitLabel = basisLower.contains('joint')\n                  ? 'joints'\n                  : basisLower.contains('piece') || basisLower.contains('each')\n                      ? 'pieces'\n                      : 'units';\n              // PIPEBUYER_OFFER_SUMMARY_V4: original listing values remain static.\n              final analysis = MarketplaceOfferAnalysis(\n                listedQuantity: listedQty,\n                requestedQuantity: requestedQty,\n                askingUnitPrice: askingUnit,\n                offeredUnitPrice: offeredUnit,\n              );`,
  "offer calculation block",
);

source = replaceOnce(
  source,
  `                        TextField(\n                            controller: quantity,\n                            onChanged: (_) => refresh(() {}),\n                            keyboardType: TextInputType.number,\n                            decoration: const InputDecoration(\n                                labelText: 'Quantity requested',\n                                hintText: 'e.g. 54',\n                                helperText:\n                                    'Enter the number of pieces or units you want.',\n                                suffixText: 'pieces')),`,
  `                        MarketplaceOfferQuantityField(\n                          controller: quantity,\n                          availableQuantity: listedQty,\n                          unitLabel: unitLabel,\n                          errorText: requestedQty <= 0\n                              ? 'Enter at least 1 $unitLabel.'\n                              : requestedQty > listedQty\n                                  ? 'Only $listedQty $unitLabel are available.'\n                                  : null,\n                          onChanged: (_) => refresh(() {}),\n                        ),`,
  "quantity input",
);

source = replaceRegexOnce(
  source,
  /                        if \(requestedQty > 0 && offeredUnit > 0\)\n                          Container\([\s\S]*?                        const SizedBox\(height: 10\),\n                        TextField\(\n                            controller: note,/,
  `                        if (requestedQty > 0 && offeredUnit > 0)\n                          MarketplaceOfferCommerceSummary(\n                            analysis: analysis,\n                            unitLabel: unitLabel,\n                          ),\n                        const SizedBox(height: 10),\n                        TextField(\n                            controller: note,`,
  "legacy offer total panel",
);

source = replaceRegexOnce(
  source,
  /\n  Widget _offerLine\(String label, num amount\) => Row\(children: \[[\s\S]*?\n      \]\);\n/,
  "\n",
  "unused legacy offer-line helper",
);

fs.writeFileSync(target, source, "utf8");
console.log("Applied Make Offer V4 static/dynamic/analytics redesign.");
