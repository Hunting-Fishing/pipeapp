"use strict";

import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");

const files = {
  core: path.join(root, "lib", "marketplace", "oil_gas_marketplace.dart"),
  messages: path.join(root, "lib", "marketplace", "marketplace_messages_page.dart"),
  vipDart: path.join(root, "lib", "marketplace", "marketplace_vip_access.dart"),
  marketplaceCommands: path.join(root, "firebase", "functions", "marketplace_commands.js"),
  communicationCommands: path.join(root, "firebase", "functions", "communication_commands.js"),
};

function output(command, args) {
  return execFileSync(command, args, {cwd: root, encoding: "utf8"}).trim();
}

function replaceOnce(source, search, replacement, label) {
  const index = source.indexOf(search);
  if (index < 0) throw new Error(`Patch anchor missing: ${label}`);
  const next = source.indexOf(search, index + search.length);
  if (next >= 0) throw new Error(`Patch anchor ambiguous: ${label}`);
  return source.slice(0, index) + replacement + source.slice(index + search.length);
}

function replaceRegexOnce(source, regex, replacement, label) {
  const flags = regex.flags.includes("g") ? regex.flags : `${regex.flags}g`;
  const matches = [...source.matchAll(new RegExp(regex.source, flags))];
  if (matches.length !== 1) {
    throw new Error(`Expected exactly one ${label}; found ${matches.length}.`);
  }
  return source.replace(regex, replacement);
}

function ensureImport(source, anchor, importLine) {
  if (source.includes(importLine)) return source;
  return replaceOnce(source, anchor, `${anchor}\n${importLine}`, `import ${importLine}`);
}

function patchCore(source) {
  if (!source.includes("// PIPEBUYER_WEB_CORRECTIONS_V3")) {
    source = ensureImport(
      source,
      "import 'marketplace_listing_media.dart';",
      "import 'marketplace_listing_specs.dart';",
    );
    source = ensureImport(
      source,
      "import 'marketplace_listing_specs.dart';",
      "import 'marketplace_offer_analysis.dart';",
    );

    source = replaceOnce(
      source,
      "  Widget _structuredDetailsPanel() {\n    final details = listing.details;\n    final rows = <Widget>[];",
      "  Widget _structuredDetailsPanel() {\n    final details = listing.details;\n    // PIPEBUYER_WEB_CORRECTIONS_V3: compact specification grid for web.\n    if (listing.category != 'Site & Property') {\n      return MarketplaceListingSpecsGrid(\n        listing: <String, dynamic>{\n          ...details,\n          'productType': listing.productType,\n          'quantity': listing.quantity,\n          'condition': listing.condition,\n          'priceBasis': listing.priceBasis,\n          'category': listing.category,\n        },\n      );\n    }\n    final rows = <Widget>[];",
      "listing details grid",
    );

    source = replaceOnce(
      source,
      "    MarketplaceTruckingPlan? truckingPlan;\n    final submitted = await showDialog<bool>(",
      "    MarketplaceTruckingPlan? truckingPlan;\n    final quantityKey = GlobalKey();\n    final offerPriceKey = GlobalKey();\n    final truckingPlanKey = GlobalKey();\n    final dispatchDestinationKey = GlobalKey();\n    final truckingDateKey = GlobalKey();\n    final submitted = await showDialog<bool>(",
      "offer navigation keys",
    );

    source = replaceOnce(
      source,
      "              final askingUnit = listing.numericPrice ?? 0;\n              final askingTotal = askingUnit * requestedQty;\n              final offeredTotal = offeredUnit * requestedQty;\n              final difference = offeredTotal - askingTotal;\n              final percent =\n                  askingTotal == 0 ? 0 : (difference / askingTotal * 100);\n              return AlertDialog(",
      "              final askingUnit = listing.numericPrice ?? 0;\n              final listedQty = listing.quantity ?? requestedQty;\n              final analysis = MarketplaceOfferAnalysis(\n                listedQuantity: listedQty,\n                requestedQuantity: requestedQty,\n                askingUnitPrice: askingUnit,\n                offeredUnitPrice: offeredUnit,\n              );\n              final offerReady = analysis.valid &&\n                  truckingPlan != null &&\n                  (truckingPlan != MarketplaceTruckingPlan.requestDispatch ||\n                      (dispatchDeliveryLocation != null && truckingDate != null));\n              void jumpTo(GlobalKey key) {\n                final target = key.currentContext;\n                if (target == null) return;\n                Scrollable.ensureVisible(\n                  target,\n                  duration: const Duration(milliseconds: 320),\n                  curve: Curves.easeOutCubic,\n                  alignment: .18,\n                );\n              }\n              return AlertDialog(",
      "offer analysis calculation",
    );

    source = replaceOnce(
      source,
      "                        TextField(\n                            controller: quantity,\n                            onChanged: (_) => refresh(() {}),\n                            keyboardType: TextInputType.number,\n                            decoration: const InputDecoration(\n                                labelText: 'Quantity requested',\n                                hintText: 'e.g. 54',\n                                helperText:\n                                    'Enter the number of pieces or units you want.',\n                                suffixText: 'pieces')),",
      "                        MarketplaceOfferQuantityField(\n                            key: quantityKey,\n                            controller: quantity,\n                            availableQuantity: listedQty,\n                            onChanged: (_) => refresh(() {}),\n                            unitLabel: 'pieces',\n                            errorText: requestedQty <= 0\n                                ? 'Enter at least 1 piece.'\n                                : requestedQty > listedQty\n                                    ? 'Only $listedQty pieces are available.'\n                                    : null),",
      "quantity field",
    );

    source = replaceOnce(
      source,
      "                        TextField(\n                            controller: amount,\n                            onChanged: (_) => refresh(() {}),",
      "                        TextField(\n                            key: offerPriceKey,\n                            controller: amount,\n                            onChanged: (_) => refresh(() {}),",
      "offer price key",
    );

    source = replaceOnce(
      source,
      "                                helperText: listing.priceBasis.isEmpty\n                                    ? 'Enter your price using the listing’s pricing unit.'\n                                    : 'Price ${listing.priceBasis.toLowerCase()}',\n                                prefixText: '\\\\$ ')),",
      "                                helperText: listing.priceBasis.isEmpty\n                                    ? 'Enter your price using the listing’s pricing unit.'\n                                    : 'Price ${listing.priceBasis.toLowerCase()}',\n                                errorText: offeredUnit <= 0\n                                    ? 'Enter a valid offer price.'\n                                    : null,\n                                prefixText: '\\\\$ ')),",
      "offer price validation",
    );

    source = replaceRegexOnce(
      source,
      /                        Container\(\n                            padding: const EdgeInsets\.all\(12\),\n                            decoration: BoxDecoration\(\n                                color: difference < 0[\s\S]*?                        const SizedBox\(height: 10\),\n                        TextField\(\n                            controller: note,/,
      "                        MarketplaceOfferAnalysisCard(\n                            analysis: analysis, unitLabel: 'pieces'),\n                        const SizedBox(height: 10),\n                        TextField(\n                            controller: note,",
      "legacy offer math card",
    );

    source = replaceOnce(
      source,
      "                        MarketplaceTruckingPlanSelector(\n                            dispatchEnabled: _features.dispatch,",
      "                        MarketplaceTruckingPlanSelector(\n                            key: truckingPlanKey,\n                            dispatchEnabled: _features.dispatch,",
      "trucking plan key",
    );

    source = replaceOnce(
      source,
      "                          MarketplaceDeliveryLocationSelector(\n                              value: dispatchDeliveryLocation,\n                              onChanged: (value) => refresh(\n                                  () => dispatchDeliveryLocation = value)),",
      "                          Container(\n                            key: dispatchDestinationKey,\n                            decoration: BoxDecoration(\n                              borderRadius: BorderRadius.circular(15),\n                              border: Border.all(\n                                color: dispatchDeliveryLocation == null\n                                    ? const Color(0xFFD92D20)\n                                    : const Color(0xFF148A45),\n                                width: 1.4,\n                              ),\n                            ),\n                            child: MarketplaceDeliveryLocationSelector(\n                                value: dispatchDeliveryLocation,\n                                onChanged: (value) => refresh(\n                                    () => dispatchDeliveryLocation = value)),\n                          ),",
      "dispatch destination highlight",
    );

    source = replaceOnce(
      source,
      "                        _listingOfferDateButton(\n                            label: 'Trucking / pickup date',",
      "                        _listingOfferDateButton(\n                            key: truckingDateKey,\n                            label: 'Trucking / pickup date',",
      "trucking date key",
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
    final step = label.startsWith('Purchase')
        ? 1
        : label.startsWith('Money')
            ? 2
            : 3;
    final requiredDate = label.startsWith('Trucking');
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: MarketplaceOfferDateField(
        step: step,
        label: label,
        icon: icon,
        value: value,
        required: requiredDate,
        onPressed: onTap,
      ),
    );
  }
`,
      "offer date helper",
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
                          GlobalKey? target;
                          if (requestedQty <= 0 || requestedQty > listedQty) {
                            missing.add('valid quantity');
                            target ??= quantityKey;
                          }
                          if (offeredUnit <= 0) {
                            missing.add('offer price');
                            target ??= offerPriceKey;
                          }
                          if (truckingPlan == null) {
                            missing.add('trucking plan');
                            target ??= truckingPlanKey;
                          }
                          if (truckingPlan == MarketplaceTruckingPlan.requestDispatch &&
                              dispatchDeliveryLocation == null) {
                            missing.add('delivery destination');
                            target ??= dispatchDestinationKey;
                          }
                          if (truckingPlan == MarketplaceTruckingPlan.requestDispatch &&
                              truckingDate == null) {
                            missing.add('trucking / pickup date');
                            target ??= truckingDateKey;
                          }
                          if (target != null) jumpTo(target);
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
                                  if (target != null) jumpTo(target);
                                },
                              ),
                            ));
                        },
                        child: const Text('Submit offer'))`,
      "submit offer validation",
    );
  }
  return source;
}

function patchMessages(source) {
  if (!source.includes("// PIPEBUYER_MESSAGES_CORRECTIONS_V3")) {
    source = ensureImport(
      source,
      "import 'marketplace_offer_schedule.dart';",
      "import 'marketplace_offer_comparison.dart';",
    );

    source = replaceRegexOnce(
      source,
      /                return Material\(\n                    color: const Color\(0xFFF4F8FC\),[\s\S]*?                                  label: Text\(latest\.isEmpty\n                                      \? 'Make offer'\n                                      : 'Offers & history'\)\)\)\n                        \]\)\)\);/,
      `                // PIPEBUYER_MESSAGES_CORRECTIONS_V3: the live offer is visible in the deal room.
                return MarketplaceConversationOfferSummary(
                  listingId: listingId,
                  sellerUid: '${conversation?['sellerUid'] ?? ''}',
                  askingPrice: askingPrice,
                  availableQuantity: available,
                  currentPrice: currentPrice,
                  currentQuantity: currentQuantity,
                  basis: basis,
                  onOpenOffers: () => _openOffers(conversation!, listing),
                );`,
      "conversation offer header",
    );

    source = replaceOnce(
      source,
      "constraints:\n                    const BoxConstraints(maxWidth: 620, maxHeight: 720),",
      "constraints:\n                    const BoxConstraints(maxWidth: 980, maxHeight: 760),",
      "wider offer dialog",
    );

    source = replaceOnce(
      source,
      "                          const SizedBox(height: 14),\n                          Expanded(\n                              child: MarketplaceNegotiationHistory(",
      "                          const SizedBox(height: 14),\n                          MarketplaceOfferComparisonSummary(\n                            listingId: '${conversation['listingId']}',\n                            sellerUid: sellerUid,\n                            askingPrice: listing['price'] as num?,\n                            availableQuantity:\n                                (listing['quantity'] as num?)?.toInt(),\n                          ),\n                          const SizedBox(height: 10),\n                          Expanded(\n                              child: MarketplaceNegotiationHistory(",
      "offer comparison table",
    );
  }
  return source;
}

function patchVipDart(source) {
  if (source.includes("// PIPEBUYER_VIP_EXPLICIT_V3")) return source;
  return replaceOnce(
    source,
    "  final explicit = marketplaceAccessDate(listing['vipEarlyAccessUntil']);\n  if (explicit != null) return explicit;\n  if (listing['vipEarlyAccessEnabled'] == false) return null;",
    "  final explicit = marketplaceAccessDate(listing['vipEarlyAccessUntil']);\n  if (explicit != null) return explicit;\n  // PIPEBUYER_VIP_EXPLICIT_V3: existing inventory stays public unless publication enabled early access.\n  if (listing['vipEarlyAccessEnabled'] != true) return null;",
    "VIP explicit listing flag",
  );
}

function patchMarketplaceCommands(source) {
  if (source.includes("// PIPEBUYER_VIP_SERVER_V3")) return source;

  source = replaceOnce(
    source,
    "const {buildDispatchRouteState} = require(\"./dispatch_routing_policy\");",
    "const {buildDispatchRouteState} = require(\"./dispatch_routing_policy\");\nconst {requireVipEarlyListingAccess} = require(\"./marketplace_vip_access_policy\");",
    "VIP server import",
  );

  source = replaceOnce(
    source,
    "        source: \"marketplace_callable\",\n        status: \"active\",",
    "        source: \"marketplace_callable\",\n        status: \"active\",\n        // PIPEBUYER_VIP_SERVER_V3: all newly published marketplace inventory gets a 24-hour priority window.\n        vipEarlyAccessEnabled: true,\n        vipEarlyAccessUntil: Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000),",
    "new listing VIP publication fields",
  );

  source = replaceOnce(
    source,
    "      const now = Timestamp.now();\n      const proposal = validateOfferProposal({\n        listing,\n        conversation,\n        actorUid: uid,",
    "      const now = Timestamp.now();\n      await requireVipEarlyListingAccess({\n        db, request, uid, listing, transaction, nowMillis: now.toMillis(),\n      });\n      const proposal = validateOfferProposal({\n        listing,\n        conversation,\n        actorUid: uid,",
    "VIP offer enforcement",
  );

  source = replaceOnce(
    source,
    "      const now = Timestamp.now();\n      const validated = validatePlaceBid(listing, uid, amount, now);",
    "      const now = Timestamp.now();\n      await requireVipEarlyListingAccess({\n        db, request, uid, listing, transaction, nowMillis: now.toMillis(),\n      });\n      const validated = validatePlaceBid(listing, uid, amount, now);",
    "VIP auction bid enforcement",
  );

  source = replaceOnce(
    source,
    "      const now = Timestamp.now();\n      const price = validateBuyNow(listing, uid, now);",
    "      const now = Timestamp.now();\n      await requireVipEarlyListingAccess({\n        db, request, uid, listing, transaction, nowMillis: now.toMillis(),\n      });\n      const price = validateBuyNow(listing, uid, now);",
    "VIP Buy Now enforcement",
  );

  return source;
}

function patchCommunicationCommands(source) {
  if (source.includes("// PIPEBUYER_VIP_MESSAGES_SERVER_V3")) return source;
  source = replaceOnce(
    source,
    "const {enforceUserRateLimit} = require(\"./abuse_rate_limit\");",
    "const {enforceUserRateLimit} = require(\"./abuse_rate_limit\");\nconst {requireVipEarlyListingAccess} = require(\"./marketplace_vip_access_policy\");",
    "VIP messaging import",
  );
  source = replaceOnce(
    source,
    "        const listing = listingSnapshot.data();\n        const sellerUid = String(listing.sellerUid || \"\");",
    "        const listing = listingSnapshot.data();\n        // PIPEBUYER_VIP_MESSAGES_SERVER_V3: standard users cannot open a new deal room during early access.\n        await requireVipEarlyListingAccess({db, request, uid, listing});\n        const sellerUid = String(listing.sellerUid || \"\");",
    "VIP new conversation enforcement",
  );
  return source;
}

function main() {
  const branch = output("git", ["branch", "--show-current"]);
  if (branch !== "pipebuyer-premium-ui") {
    throw new Error(`Refusing to patch branch ${branch}.`);
  }
  const dirty = output("git", ["status", "--porcelain"]);
  if (dirty) {
    throw new Error(`Working tree must be clean before this patch:\n${dirty}`);
  }

  const transforms = [
    [files.core, patchCore],
    [files.messages, patchMessages],
    [files.vipDart, patchVipDart],
    [files.marketplaceCommands, patchMarketplaceCommands],
    [files.communicationCommands, patchCommunicationCommands],
  ];

  for (const [file, transform] of transforms) {
    const original = fs.readFileSync(file, "utf8");
    const updated = transform(original);
    fs.writeFileSync(file, updated);
  }

  console.log("Web corrections V3 applied to local working tree.");
}

main();
