"use strict";

import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const corePath = path.join(root, "lib", "marketplace", "oil_gas_marketplace.dart");
const messagesPath = path.join(root, "lib", "marketplace", "marketplace_messages_page.dart");
const commitPush = process.argv.includes("--commit-push");

function run(command, args, options = {}) {
  console.log(`\n> ${command} ${args.join(" ")}`);
  return execFileSync(command, args, {
    cwd: root,
    stdio: "inherit",
    encoding: "utf8",
    ...options,
  });
}

function output(command, args) {
  return execFileSync(command, args, {cwd: root, encoding: "utf8"}).trim();
}

function replaceLiteralOnce(source, search, replacement, label) {
  const first = source.indexOf(search);
  if (first < 0) throw new Error(`Patch anchor missing: ${label}`);
  if (source.indexOf(search, first + search.length) >= 0) {
    throw new Error(`Patch anchor is ambiguous: ${label}`);
  }
  return source.slice(0, first) + replacement + source.slice(first + search.length);
}

function replaceRegexOnce(source, pattern, replacement, label) {
  const matches = [...source.matchAll(new RegExp(pattern.source, pattern.flags.includes("g") ? pattern.flags : `${pattern.flags}g`))];
  if (matches.length !== 1) {
    throw new Error(`Expected exactly one ${label} match, found ${matches.length}.`);
  }
  return source.replace(pattern, replacement);
}

function patchCore(source) {
  if (source.includes("// PIPEBUYER_WEB_REVIEW_V1")) {
    console.log("Core marketplace web review patch is already applied.");
    return source;
  }

  source = replaceLiteralOnce(
    source,
    "import 'marketplace_listing_media.dart';\nimport 'marketplace_property_details.dart';",
    "import 'marketplace_listing_media.dart';\nimport 'marketplace_listing_specs.dart';\nimport 'marketplace_offer_analysis.dart';\nimport 'marketplace_property_details.dart';",
    "core marketplace imports",
  );

  source = replaceLiteralOnce(
    source,
    "  Widget _structuredDetailsPanel() {\n    final details = listing.details;\n    final rows = <Widget>[];",
    "  Widget _structuredDetailsPanel() {\n    final details = listing.details;\n    // PIPEBUYER_WEB_REVIEW_V1: dense web specification grid.\n    if (listing.category != 'Site & Property') {\n      return MarketplaceListingSpecsGrid(\n        listing: <String, dynamic>{...details, 'category': listing.category},\n      );\n    }\n    final rows = <Widget>[];",
    "compact listing details",
  );

  source = replaceLiteralOnce(
    source,
    "    MarketplaceTruckingPlan? truckingPlan;\n    final submitted = await showDialog<bool>(",
    "    MarketplaceTruckingPlan? truckingPlan;\n    final quantityKey = GlobalKey();\n    final offerPriceKey = GlobalKey();\n    final truckingPlanKey = GlobalKey();\n    final dispatchDestinationKey = GlobalKey();\n    final truckingDateKey = GlobalKey();\n    final submitted = await showDialog<bool>(",
    "offer requirement anchors",
  );

  source = replaceLiteralOnce(
    source,
    "              final askingUnit = listing.numericPrice ?? 0;\n              final askingTotal = askingUnit * requestedQty;\n              final offeredTotal = offeredUnit * requestedQty;\n              final difference = offeredTotal - askingTotal;\n              final percent =\n                  askingTotal == 0 ? 0 : (difference / askingTotal * 100);\n              return AlertDialog(",
    "              final askingUnit = listing.numericPrice ?? 0;\n              final listedQty = (listing.quantity ?? requestedQty).toInt();\n              final analysis = MarketplaceOfferAnalysis(\n                listedQuantity: listedQty,\n                requestedQuantity: requestedQty,\n                askingUnitPrice: askingUnit,\n                offeredUnitPrice: offeredUnit,\n              );\n              final askingTotal = analysis.requestedAskValue;\n              final offeredTotal = analysis.offeredTotal;\n              final difference = analysis.requestedValueDifference;\n              final percent = analysis.priceDifferencePercent;\n              final offerReady = requestedQty > 0 &&\n                  requestedQty <= listedQty &&\n                  offeredUnit > 0 &&\n                  truckingPlan != null &&\n                  (truckingPlan != MarketplaceTruckingPlan.requestDispatch ||\n                      (dispatchDeliveryLocation != null && truckingDate != null));\n              return AlertDialog(",
    "offer analysis calculation",
  );

  source = replaceLiteralOnce(
    source,
    "                        TextField(\n                            controller: quantity,\n                            onChanged: (_) => refresh(() {}),\n                            keyboardType: TextInputType.number,\n                            decoration: const InputDecoration(\n                                labelText: 'Quantity requested',\n                                hintText: 'e.g. 54',\n                                helperText:\n                                    'Enter the number of pieces or units you want.',\n                                suffixText: 'pieces')),",
    "                        MarketplaceOfferQuantityField(\n                            key: quantityKey,\n                            controller: quantity,\n                            availableQuantity: listedQty,\n                            onChanged: (_) => refresh(() {}),\n                            unitLabel: 'pieces'),",
    "quantity field",
  );

  source = replaceLiteralOnce(
    source,
    "                        TextField(\n                            controller: amount,",
    "                        TextField(\n                            key: offerPriceKey,\n                            controller: amount,",
    "offer price focus anchor",
  );

  source = replaceLiteralOnce(
    source,
    "                                helperText: listing.priceBasis.isEmpty\n                                    ? 'Enter your price using the listing’s pricing unit.'\n                                    : 'Price ${listing.priceBasis.toLowerCase()}',\n                                prefixText: '\\\\$ ')),",
    "                                helperText: listing.priceBasis.isEmpty\n                                    ? 'Enter your price using the listing’s pricing unit.'\n                                    : 'Price ${listing.priceBasis.toLowerCase()}',\n                                errorText: offeredUnit <= 0\n                                    ? 'Enter a valid offer price.'\n                                    : null,\n                                prefixText: '\\\\$ ')),",
    "offer price validation",
  );

  source = replaceRegexOnce(
    source,
    /                        Container\(\n                            padding: const EdgeInsets\.all\(12\),\n                            decoration: BoxDecoration\(\n                                color: difference < 0[\s\S]*?                        const SizedBox\(height: 10\),\n                        TextField\(\n                            controller: note,/,
    "                        MarketplaceOfferAnalysisCard(\n                            analysis: analysis, unitLabel: 'pieces'),\n                        const SizedBox(height: 10),\n                        TextField(\n                            controller: note,",
    "offer comparison card",
  );

  source = replaceLiteralOnce(
    source,
    "                        MarketplaceTruckingPlanSelector(\n                            dispatchEnabled: _features.dispatch,",
    "                        MarketplaceTruckingPlanSelector(\n                            key: truckingPlanKey,\n                            dispatchEnabled: _features.dispatch,",
    "trucking plan focus anchor",
  );

  source = replaceLiteralOnce(
    source,
    "                          MarketplaceDeliveryLocationSelector(\n                              value: dispatchDeliveryLocation,\n                              onChanged: (value) => refresh(\n                                  () => dispatchDeliveryLocation = value)),",
    "                          Container(\n                            key: dispatchDestinationKey,\n                            decoration: BoxDecoration(\n                              borderRadius: BorderRadius.circular(15),\n                              border: Border.all(\n                                color: dispatchDeliveryLocation == null\n                                    ? const Color(0xFFD92D20)\n                                    : const Color(0xFF148A45),\n                                width: dispatchDeliveryLocation == null ? 1.4 : 1.2,\n                              ),\n                            ),\n                            child: MarketplaceDeliveryLocationSelector(\n                                value: dispatchDeliveryLocation,\n                                onChanged: (value) => refresh(\n                                    () => dispatchDeliveryLocation = value)),\n                          ),",
    "required delivery destination",
  );

  source = replaceLiteralOnce(
    source,
    "                        _listingOfferDateButton(\n                            label: 'Trucking / pickup date',",
    "                        _listingOfferDateButton(\n                            key: truckingDateKey,\n                            label: 'Trucking / pickup date',",
    "trucking date focus anchor",
  );

  source = replaceRegexOnce(
    source,
    /  Widget _listingOfferDateButton\([\s\S]*?(?=\n  (?:Widget|Future(?:<[^>]+>)?|void|String|Color|bool|num|int) _[A-Za-z0-9_]+\()/,
    `  Widget _listingOfferDateButton({
    Key? key,
    required String label,
    required DateTime? value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final complete = value != null;
    final step = label.startsWith('Purchase')
        ? 1
        : label.startsWith('Money')
            ? 2
            : 3;
    final accent = complete ? const Color(0xFF148A45) : const Color(0xFFFF6A00);
    final dateText = value == null
        ? 'Select $label'
        : '$label: ${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: complete
            ? const Color(0xFFEAF8F1)
            : const Color(0xFFFFF5E8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(color: accent.withValues(alpha: .42), width: 1.2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: complete
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF148A45), size: 21)
                      : Text('$step',
                          style: TextStyle(
                              color: accent, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(dateText,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              Icon(
                complete ? Icons.verified_rounded : Icons.chevron_right_rounded,
                color: accent,
              ),
            ]),
          ),
        ),
      ),
    );
  }
`,
    "completed offer date fields",
  );

  source = replaceRegexOnce(
    source,
    /                    FilledButton\(\n                        onPressed: requestedQty <= 0 \|\|[\s\S]*?                        child: const Text\('Submit offer'\)\)/,
    `                    FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: offerReady
                              ? const Color(0xFFFF6A00)
                              : Colors.grey.shade300,
                          foregroundColor: offerReady
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                        onPressed: () {
                          if (offerReady) {
                            Navigator.pop(context, true);
                            return;
                          }
                          final missing = <String>[];
                          GlobalKey? targetKey;
                          if (requestedQty <= 0 || requestedQty > listedQty) {
                            missing.add('valid quantity');
                            targetKey ??= quantityKey;
                          }
                          if (offeredUnit <= 0) {
                            missing.add('offer price');
                            targetKey ??= offerPriceKey;
                          }
                          if (truckingPlan == null) {
                            missing.add('trucking plan');
                            targetKey ??= truckingPlanKey;
                          }
                          if (truckingPlan == MarketplaceTruckingPlan.requestDispatch &&
                              dispatchDeliveryLocation == null) {
                            missing.add('delivery destination');
                            targetKey ??= dispatchDestinationKey;
                          }
                          if (truckingPlan == MarketplaceTruckingPlan.requestDispatch &&
                              truckingDate == null) {
                            missing.add('trucking / pickup date');
                            targetKey ??= truckingDateKey;
                          }
                          final target = targetKey?.currentContext;
                          if (target != null) {
                            Scrollable.ensureVisible(
                              target,
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                              alignment: .18,
                            );
                          }
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                'Complete before submitting: ${missing.join(', ')}.',
                              ),
                              action: SnackBarAction(
                                label: 'GO TO',
                                onPressed: () {
                                  final context = targetKey?.currentContext;
                                  if (context != null) {
                                    Scrollable.ensureVisible(
                                      context,
                                      duration: const Duration(milliseconds: 320),
                                      curve: Curves.easeOutCubic,
                                      alignment: .18,
                                    );
                                  }
                                },
                              ),
                            ));
                        },
                        child: const Text('Submit offer'))`,
    "clickable submit validation",
  );

  return source;
}

function patchMessages(source) {
  if (source.includes("// PIPEBUYER_OFFER_COMPARE_V1")) {
    console.log("Messages offer comparison patch is already applied.");
    return source;
  }
  source = replaceLiteralOnce(
    source,
    "import 'marketplace_offer_schedule.dart';\nimport 'marketplace_account_hub.dart';",
    "import 'marketplace_offer_schedule.dart';\nimport 'marketplace_offer_comparison.dart';\nimport 'marketplace_account_hub.dart';",
    "messages offer comparison import",
  );
  source = replaceLiteralOnce(
    source,
    "constraints:\n                    const BoxConstraints(maxWidth: 620, maxHeight: 720),",
    "constraints:\n                    const BoxConstraints(maxWidth: 980, maxHeight: 760),",
    "wider offer history dialog",
  );
  source = replaceLiteralOnce(
    source,
    "                          const SizedBox(height: 14),\n                          Expanded(\n                              child: MarketplaceNegotiationHistory(",
    "                          const SizedBox(height: 14),\n                          // PIPEBUYER_OFFER_COMPARE_V1: compact web comparison stays above detailed actions/history.\n                          MarketplaceOfferComparisonSummary(\n                            listingId: '${conversation['listingId']}',\n                            sellerUid: sellerUid,\n                            askingPrice: listing['price'] as num?,\n                            availableQuantity:\n                                (listing['quantity'] as num?)?.toInt(),\n                          ),\n                          const SizedBox(height: 10),\n                          Expanded(\n                              child: MarketplaceNegotiationHistory(",
    "offer comparison insertion",
  );
  return source;
}

function main() {
  process.chdir(root);
  const branch = output("git", ["branch", "--show-current"]);
  if (branch !== "pipebuyer-premium-ui") {
    throw new Error(`Refusing to patch branch ${branch}. Switch to pipebuyer-premium-ui first.`);
  }
  const dirty = output("git", ["status", "--porcelain"]);
  if (dirty) {
    throw new Error(`Working tree is not clean. Preserve or commit these files first:\n${dirty}`);
  }

  const coreOriginal = fs.readFileSync(corePath, "utf8");
  const messagesOriginal = fs.readFileSync(messagesPath, "utf8");
  const corePatched = patchCore(coreOriginal);
  const messagesPatched = patchMessages(messagesOriginal);
  fs.writeFileSync(corePath, corePatched);
  fs.writeFileSync(messagesPath, messagesPatched);

  try {
    run("dart", ["format", corePath, messagesPath]);
    run("flutter", [
      "analyze",
      "lib/marketplace/oil_gas_marketplace.dart",
      "lib/marketplace/marketplace_messages_page.dart",
      "lib/marketplace/marketplace_offer_analysis.dart",
      "lib/marketplace/marketplace_offer_comparison.dart",
      "lib/marketplace/marketplace_listing_specs.dart",
      "lib/marketplace/marketplace_vip_access.dart",
      "lib/marketplace/marketplace_listing_media.dart",
    ]);
    run("flutter", [
      "test",
      "test/marketplace_offer_analysis_test.dart",
      "test/marketplace_vip_access_test.dart",
      "test/marketplace_listing_media_test.dart",
    ]);
  } catch (error) {
    fs.writeFileSync(corePath, coreOriginal);
    fs.writeFileSync(messagesPath, messagesOriginal);
    console.error("\nValidation failed. The two large marketplace files were restored.");
    throw error;
  }

  console.log("\nWeb marketplace review patch validated locally.");
  if (!commitPush) {
    console.log("Review the app, then rerun with --commit-push to create one sandbox commit and push it.");
    return;
  }

  run("git", ["add", corePath, messagesPath]);
  const staged = output("git", ["diff", "--cached", "--name-only"]);
  if (!staged) {
    console.log("No new large-screen changes to commit.");
    return;
  }
  run("git", ["commit", "-m", "Refine web listing offer and deal room UX"]);
  run("git", ["push", "origin", "pipebuyer-premium-ui"]);
  console.log("\nPushed one validated web-review commit to pipebuyer-premium-ui.");
}

try {
  main();
} catch (error) {
  console.error(`\n${error.stack || error.message || error}`);
  process.exitCode = 1;
}
