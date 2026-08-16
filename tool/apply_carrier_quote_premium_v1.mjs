"use strict";

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const file = path.join(root, "lib", "marketplace", "marketplace_freight_quote.dart");
if (!fs.existsSync(file)) throw new Error("marketplace_freight_quote.dart is missing.");
let source = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");

function replaceOnce(before, after, label) {
  if (source.includes(after)) return;
  const index = source.indexOf(before);
  if (index < 0) throw new Error(`Carrier quote migration anchor not found: ${label}`);
  source = source.slice(0, index) + after + source.slice(index + before.length);
}

function replaceRange(startText, endText, replacement, label, from = 0) {
  const start = source.indexOf(startText, from);
  if (start < 0) throw new Error(`Carrier quote range start not found: ${label}`);
  const end = source.indexOf(endText, start);
  if (end < 0) throw new Error(`Carrier quote range end not found: ${label}`);
  source = source.slice(0, start) + replacement + source.slice(end);
}

if (!source.includes("PIPEBUYER_CARRIER_QUOTE_PREMIUM_V1")) {
  replaceOnce(
    "import '../core/accessibility/pipe_status_feedback.dart';\n",
    [
      "import '../core/accessibility/pipe_status_feedback.dart';",
      "import '../core/design/pipe_buyer_components.dart';",
      "import '../core/design/pipe_buyer_theme.dart';",
      "",
    ].join("\n"),
    "Pipe Buyer design imports",
  );

  if (!source.includes("import 'marketplace_dispatch_spec_assist.dart';")) {
    replaceOnce(
      "import 'marketplace_dispatch_repository.dart';\n",
      [
        "import 'marketplace_dispatch_repository.dart';",
        "import 'marketplace_dispatch_spec_assist.dart';",
        "",
      ].join("\n"),
      "Spec Assist import",
    );
  }
  if (!source.includes("import 'marketplace_weight_catalog.dart';")) {
    replaceOnce(
      "import 'marketplace_trucking_plan.dart';\n",
      [
        "import 'marketplace_trucking_plan.dart';",
        "import 'marketplace_weight_catalog.dart';",
        "",
      ].join("\n"),
      "shared weight catalog import",
    );
  }

  if (!source.includes("PIPEBUYER_WEIGHT_SNAPSHOT_V1")) {
    replaceOnce(
      "  static FreightWeightEstimate fromListing(Map<String, dynamic> data) {\n",
      [
        "  static FreightWeightEstimate fromListing(Map<String, dynamic> data) {",
        "    // PIPEBUYER_WEIGHT_SNAPSHOT_V1",
        "    final frozen = MarketplaceWeightEstimate.fromListing(data);",
        "    if (frozen.hasWeight) {",
        "      return FreightWeightEstimate(",
        "        kg: frozen.kg,",
        "        source: frozen.source,",
        "        confidence: frozen.confidence,",
        "      );",
        "    }",
        "    if (frozen.status == 'unknown') {",
        "      return FreightWeightEstimate(",
        "        kg: null,",
        "        source: frozen.source,",
        "        confidence: frozen.confidence,",
        "      );",
        "    }",
        "",
      ].join("\n"),
      "frozen listing weight snapshot",
    );
  }

  if (!source.includes("PIPEBUYER_WEIGHT_CATALOG_RESOLVER_V1")) {
    const oldResolver = [
      "    final make = '${data['brand'] ?? data['make'] ?? ''}'.trim();",
      "    final model = '${data['model'] ?? ''}'.trim();",
      "    if (make.isEmpty || model.isEmpty) return listed;",
      "    final key = _catalogKey(make, model);",
      "    final catalog = await FirebaseFirestore.instance",
      "        .collection('weight_catalog')",
      "        .doc(key)",
      "        .get();",
      "    final value = catalog.data()?['operatingWeightKg'] as num? ??",
      "        catalog.data()?['shippingWeightKg'] as num?;",
      "    if (value == null || value <= 0) return listed;",
      "    return FreightWeightEstimate(",
      "        kg: value.toDouble(),",
      "        source:",
      "            '${catalog.data()?['manufacturer'] ?? make} verified catalog • $make $model',",
      "        confidence: '${catalog.data()?['verificationStatus'] ?? 'catalog'}');",
      "",
    ].join("\n");
    const newResolver = [
      "    // PIPEBUYER_WEIGHT_CATALOG_RESOLVER_V1",
      "    final resolved = await MarketplaceWeightCatalogRepository().resolve(",
      "      category: '${data['category'] ?? ''}',",
      "      productType: '${data['productType'] ?? ''}',",
      "      manufacturer: '${data['brand'] ?? data['make'] ?? ''}',",
      "      model: '${data['model'] ?? ''}',",
      "      modelYear: (data['modelYear'] as num?)?.toInt(),",
      "      pipeSize: '${data['pipeSize'] ?? ''}',",
      "      quantity: (data['quantity'] as num?)?.toInt() ?? 1,",
      "      lengthM: _number(data['jointLengthM']) ??",
      "          ((_number(data['jointLengthFt']) ?? 0) * 0.3048),",
      "    );",
      "    if (!resolved.hasWeight) return listed;",
      "    return FreightWeightEstimate(",
      "      kg: resolved.kg,",
      "      source: resolved.source,",
      "      confidence: resolved.confidence,",
      "    );",
      "",
    ].join("\n");
    replaceOnce(oldResolver, newResolver, "shared weight catalog resolver");
  }
  source = source.replace(
    /\n  static String _catalogKey\(String make, String model\) =>\n      '\$\{make\}_\$model'\.toLowerCase\(\)\.replaceAll\(RegExp\(r'\[\^a-z0-9\]\+'\), '_'\);\n/,
    "\n",
  );

  if (!source.includes("required this.weightUnknown")) {
    replaceOnce(
      [
        "    required this.weightChanged,",
        "  });",
        "",
        "  final String pickup;",
        "  final MarketplaceLocation delivery;",
        "  final double weightKg;",
        "  final String details;",
        "  final DateTime truckingDate;",
        "  final bool weightChanged;",
      ].join("\n"),
      [
        "    required this.weightChanged,",
        "    required this.weightUnknown,",
        "    required this.weightSource,",
        "  });",
        "",
        "  final String pickup;",
        "  final MarketplaceLocation delivery;",
        "  final double? weightKg;",
        "  final String details;",
        "  final DateTime truckingDate;",
        "  final bool weightChanged;",
        "  final bool weightUnknown;",
        "  final String weightSource;",
      ].join("\n"),
      "nullable / deferred freight weight draft",
    );
  } else if (!source.includes("required this.weightSource")) {
    replaceOnce(
      "    required this.weightUnknown,\n",
      "    required this.weightUnknown,\n    required this.weightSource,\n",
      "freight draft weight source constructor",
    );
    replaceOnce(
      "  final bool weightUnknown;\n",
      "  final bool weightUnknown;\n  final String weightSource;\n",
      "freight draft weight source field",
    );
  }

  const createCall = source.indexOf("      await MarketplaceDispatchRepository().createJob(");
  if (createCall < 0) throw new Error("createJob call was not found.");
  const weightSourceStart = source.indexOf("          weightSource:", createCall);
  const pickupPointStart = source.indexOf("          pickupGeoPoint:", weightSourceStart);
  if (weightSourceStart < 0 || pickupPointStart < 0) {
    throw new Error("Could not bound createJob weightSource.");
  }
  source = source.slice(0, weightSourceStart) +
      "          weightSource: draft.weightSource,\n" +
      source.slice(pickupPointStart);

  replaceOnce(
    "class _FreightQuoteDialogState extends State<_FreightQuoteDialog> {\n  static const _blue = Color(0xFF0878E8);\n  static const _muted = Color(0xFF66758A);\n",
    [
      "class _FreightQuoteDialogState extends State<_FreightQuoteDialog> {",
      "  // PIPEBUYER_CARRIER_QUOTE_PREMIUM_V1",
      "  static const _blue = PipeBuyerColors.orangePressed;",
      "  static const _muted = PipeBuyerColors.muted;",
      "",
    ].join("\n"),
    "premium carrier quote state marker",
  );

  if (!source.includes("bool _weightUnknown = false;")) {
    replaceOnce(
      "  bool _weightChanged = false;\n",
      [
        "  bool _weightChanged = false;",
        "  bool _weightUnknown = false;",
        "  String? _assistWeightSource;",
        "  late DispatchSpecAssistSnapshot _specSnapshot;",
        "",
      ].join("\n"),
      "deferred weight and spec-assist state",
    );
  }

  if (!source.includes("_specSnapshot = dispatchSpecAssistSnapshotFromListing(listing);")) {
    replaceOnce(
      "    _date = DateTime.now().add(const Duration(days: 7));\n",
      [
        "    _date = DateTime.now().add(const Duration(days: 7));",
        "    _specSnapshot = dispatchSpecAssistSnapshotFromListing(listing);",
        "",
      ].join("\n"),
      "initial spec-assist snapshot",
    );
  }

  if (!source.includes("if (_weightUnknown) return null;")) {
    replaceOnce(
      "  double? get _enteredWeight {\n    final value = double.tryParse(_weight.text.trim().replaceAll(',', ''));\n",
      [
        "  double? get _enteredWeight {",
        "    if (_weightUnknown) return null;",
        "    final value = double.tryParse(_weight.text.trim().replaceAll(',', ''));",
        "",
      ].join("\n"),
      "deferred entered weight",
    );
  }

  const oldDraftConstruction = [
    "        _FreightQuoteDraft(",
    "            pickup: _pickup,",
    "            delivery: _delivery!,",
    "            weightKg: _enteredWeight!,",
    "            details: _details.text.trim(),",
    "            truckingDate: _date,",
    "            weightChanged: _weightChanged));",
  ].join("\n");
  const newDraftConstruction = [
    "        _FreightQuoteDraft(",
    "            pickup: _pickup,",
    "            delivery: _delivery!,",
    "            weightKg: _enteredWeight,",
    "            details: _specSnapshot.appendToNotes(",
    "              _details.text.trim(),",
    "              weightUnknown: _weightUnknown,",
    "            ),",
    "            truckingDate: _date,",
    "            weightChanged: _weightChanged,",
    "            weightUnknown: _weightUnknown,",
    "            weightSource: _weightUnknown",
    "                ? 'shipper_unknown'",
    "                : _assistWeightSource ??",
    "                    (_weightChanged",
    "                        ? 'shipper_adjusted'",
    "                        : widget.estimate.source)));",
  ].join("\n");
  if (!source.includes("weightUnknown: _weightUnknown")) {
    replaceOnce(
      oldDraftConstruction,
      newDraftConstruction,
      "carrier quote draft construction",
    );
  }

  const mainState = source.indexOf("class _FreightQuoteDialogState extends State<_FreightQuoteDialog>");
  const buildStart = source.indexOf("  Widget build(BuildContext context) {", mainState);
  const dialogStart = source.indexOf("    return AlertDialog(\n", buildStart);
  if (buildStart < 0 || dialogStart < 0) {
    throw new Error("Main carrier request dialog build could not be located.");
  }
  const oldDialogChrome = [
    "    return AlertDialog(",
    "      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),",
    "      titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),",
    "      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 4),",
    "      actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 18),",
  ].join("\n");
  const newDialogChrome = [
    "    return AlertDialog(",
    "      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),",
    "      clipBehavior: Clip.antiAlias,",
    "      backgroundColor: PipeBuyerColors.surface,",
    "      surfaceTintColor: Colors.transparent,",
    "      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),",
    "      titlePadding: EdgeInsets.zero,",
    "      contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 4),",
    "      actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 18),",
  ].join("\n");
  replaceOnce(oldDialogChrome, newDialogChrome, "premium dialog chrome");

  const titleStart = source.indexOf("      title: Row(children: [", dialogStart);
  const contentStart = source.indexOf("      content: ConstrainedBox(", titleStart);
  if (titleStart < 0 || contentStart < 0) {
    throw new Error("Carrier quote title block could not be bounded.");
  }
  const premiumTitle = [
    "      title: Container(",
    "        padding: const EdgeInsets.fromLTRB(22, 20, 14, 19),",
    "        decoration: const BoxDecoration(",
    "          color: PipeBuyerColors.ink,",
    "        ),",
    "        child: Row(",
    "          crossAxisAlignment: CrossAxisAlignment.start,",
    "          children: [",
    "            Container(",
    "              width: 50,",
    "              height: 50,",
    "              decoration: BoxDecoration(",
    "                color: PipeBuyerColors.orange.withValues(alpha: .14),",
    "                borderRadius: BorderRadius.circular(14),",
    "                border: Border.all(",
    "                  color: PipeBuyerColors.orange.withValues(alpha: .42),",
    "                ),",
    "              ),",
    "              child: const Icon(",
    "                Icons.local_shipping_outlined,",
    "                color: PipeBuyerColors.orange,",
    "                size: 28,",
    "              ),",
    "            ),",
    "            const SizedBox(width: 13),",
    "            const Expanded(",
    "              child: Column(",
    "                crossAxisAlignment: CrossAxisAlignment.start,",
    "                children: [",
    "                  Text(",
    "                    'PIPE BUYER DISPATCH',",
    "                    style: TextStyle(",
    "                      color: PipeBuyerColors.orange,",
    "                      fontSize: 10,",
    "                      fontWeight: FontWeight.w900,",
    "                      letterSpacing: 1.0,",
    "                    ),",
    "                  ),",
    "                  SizedBox(height: 4),",
    "                  Text(",
    "                    'Request carrier quotes',",
    "                    style: TextStyle(",
    "                      color: Colors.white,",
    "                      fontSize: 23,",
    "                      fontWeight: FontWeight.w900,",
    "                      letterSpacing: -.35,",
    "                    ),",
    "                  ),",
    "                  SizedBox(height: 4),",
    "                  Text(",
    "                    'Build a professional load brief carriers can price confidently.',",
    "                    style: TextStyle(",
    "                      color: Color(0xFFB8C0CA),",
    "                      fontSize: 11.5,",
    "                      height: 1.35,",
    "                    ),",
    "                  ),",
    "                ],",
    "              ),",
    "            ),",
    "            IconButton(",
    "              tooltip: 'Close',",
    "              onPressed: () => Navigator.pop(context),",
    "              icon: const Icon(Icons.close, color: Colors.white),",
    "            ),",
    "          ],",
    "        ),",
    "      ),",
  ].join("\n") + "\n";
  source = source.slice(0, titleStart) + premiumTitle + source.slice(contentStart);

  const summaryAnchor = [
    "              _ListingLoadSummary(",
    "                  title: listingTitle,",
    "                  pickup: _pickup,",
    "                  auction: widget.auction),",
    "              const SizedBox(height: 18),",
    "              _sectionHeading(Icons.route_outlined, 'Route',",
  ].join("\n");
  const summaryUpgrade = [
    "              _ListingLoadSummary(",
    "                  title: listingTitle,",
    "                  pickup: _pickup,",
    "                  auction: widget.auction),",
    "              const SizedBox(height: 14),",
    "              MarketplaceDispatchSpecAssistPanel(",
    "                listing: widget.listing,",
    "                onChanged: (snapshot) => _specSnapshot = snapshot,",
    "                onWeightSuggested: (kg, _, __) {",
    "                  if (!mounted) return;",
    "                  setState(() {",
    "                    _weightUnknown = false;",
    "                    _weightChanged = false;",
    "                    _assistWeightSource = 'spec_assist_catalog';",
    "                    _weight.text = (_usePounds ? kg * 2.2046226218 : kg)",
    "                        .toStringAsFixed(0);",
    "                    _weight.selection = TextSelection.collapsed(",
    "                      offset: _weight.text.length,",
    "                    );",
    "                  });",
    "                },",
    "              ),",
    "              const SizedBox(height: 18),",
    "              _sectionHeading(Icons.route_outlined, 'Route',",
  ].join("\n");
  replaceOnce(summaryAnchor, summaryUpgrade, "Spec Assist panel integration");

  const weightStart = source.indexOf("              SegmentedButton<bool>(", buildStart);
  const weightEnd = source.indexOf("              Align(\n", weightStart);
  if (weightStart < 0 || weightEnd < 0) {
    throw new Error("Carrier quote weight controls could not be bounded.");
  }
  const premiumWeightControls = [
    "              Wrap(",
    "                spacing: 8,",
    "                runSpacing: 8,",
    "                children: [",
    "                  ChoiceChip(",
    "                    selected: !_weightUnknown && !_weightChanged,",
    "                    label: Text(widget.estimate.kg == null",
    "                        ? 'No suggested weight yet'",
    "                        : 'Use suggested weight'),",
    "                    avatar: const Icon(Icons.auto_awesome_outlined, size: 18),",
    "                    onSelected: widget.estimate.kg == null",
    "                        ? null",
    "                        : (_) => setState(() {",
    "                              _weightUnknown = false;",
    "                              _weightChanged = false;",
    "                              _assistWeightSource = null;",
    "                              final kg = widget.estimate.kg!;",
    "                              _weight.text =",
    "                                  (_usePounds ? kg * 2.2046226218 : kg)",
    "                                      .toStringAsFixed(0);",
    "                            }),",
    "                  ),",
    "                  ChoiceChip(",
    "                    selected: !_weightUnknown && _weightChanged,",
    "                    label: const Text('Enter / adjust weight'),",
    "                    avatar: const Icon(Icons.edit_outlined, size: 18),",
    "                    onSelected: (_) => setState(() {",
    "                      _weightUnknown = false;",
    "                      _weightChanged = true;",
    "                      _assistWeightSource = null;",
    "                    }),",
    "                  ),",
    "                  ChoiceChip(",
    "                    selected: _weightUnknown,",
    "                    label: const Text(\"I don't know — add later\"),",
    "                    avatar: const Icon(Icons.help_outline, size: 18),",
    "                    onSelected: (_) => setState(() {",
    "                      _weightUnknown = true;",
    "                      _weightChanged = false;",
    "                      _assistWeightSource = null;",
    "                    }),",
    "                  ),",
    "                ],",
    "              ),",
    "              const SizedBox(height: 10),",
    "              if (!_weightUnknown) ...[",
    "                SegmentedButton<bool>(",
    "                  showSelectedIcon: false,",
    "                  segments: const [",
    "                    ButtonSegment(value: false, label: Text('Kilograms (kg)')),",
    "                    ButtonSegment(value: true, label: Text('Pounds (lb)')),",
    "                  ],",
    "                  selected: {_usePounds},",
    "                  onSelectionChanged: (value) => _changeUnit(value.first),",
    "                ),",
    "                const SizedBox(height: 9),",
    "                TextFormField(",
    "                  controller: _weight,",
    "                  keyboardType:",
    "                      const TextInputType.numberWithOptions(decimal: true),",
    "                  onChanged: (_) => setState(() {",
    "                    _weightChanged = true;",
    "                    _assistWeightSource = null;",
    "                  }),",
    "                  decoration: InputDecoration(",
    "                    labelText: 'Approximate total shipping weight',",
    "                    hintText:",
    "                        _usePounds ? 'Example: 12,500' : 'Example: 5,670',",
    "                    helperText:",
    "                        'Use the best planning estimate available. It does not need to be a certified scale weight.',",
    "                    prefixIcon: const Icon(Icons.scale_outlined),",
    "                    suffixText: _usePounds ? 'lb' : 'kg',",
    "                  ),",
    "                  validator: (_) => _enteredWeight == null",
    "                      ? 'Enter a valid load weight or choose “I don’t know — add later”'",
    "                      : null,",
    "                ),",
    "              ] else",
    "                Container(",
    "                  width: double.infinity,",
    "                  padding: const EdgeInsets.all(13),",
    "                  decoration: BoxDecoration(",
    "                    color: PipeBuyerColors.orangeSoft,",
    "                    borderRadius: BorderRadius.circular(13),",
    "                    border: Border.all(",
    "                      color: PipeBuyerColors.orange.withValues(alpha: .35),",
    "                    ),",
    "                  ),",
    "                  child: const Row(",
    "                    crossAxisAlignment: CrossAxisAlignment.start,",
    "                    children: [",
    "                      Icon(",
    "                        Icons.schedule_outlined,",
    "                        color: PipeBuyerColors.orangePressed,",
    "                      ),",
    "                      SizedBox(width: 9),",
    "                      Expanded(",
    "                        child: Column(",
    "                          crossAxisAlignment: CrossAxisAlignment.start,",
    "                          children: [",
    "                            Text(",
    "                              'Weight can be added later',",
    "                              style: TextStyle(fontWeight: FontWeight.w900),",
    "                            ),",
    "                            SizedBox(height: 3),",
    "                            Text(",
    "                              'You can still publish the carrier request. Dispatch providers will see the shipping weight as TO CONFIRM and should treat any quote as subject to final load verification.',",
    "                              style: TextStyle(fontSize: 11, height: 1.35),",
    "                            ),",
    "                          ],",
    "                        ),",
    "                      ),",
    "                    ],",
    "                  ),",
    "                ),",
    "              const SizedBox(height: 8),",
    "              _weightAnalytics(),",
  ].join("\n") + "\n";
  source = source.slice(0, weightStart) + premiumWeightControls + source.slice(weightEnd);

  if (!source.includes("if (_weightUnknown) {\n      return Container(")) {
    replaceOnce(
      "  Widget _weightAnalytics() {\n    final kg = _enteredWeight;\n",
      [
        "  Widget _weightAnalytics() {",
        "    if (_weightUnknown) {",
        "      return Container(",
        "        width: double.infinity,",
        "        padding: const EdgeInsets.all(12),",
        "        decoration: BoxDecoration(",
        "          color: const Color(0xFFF4F7FA),",
        "          borderRadius: BorderRadius.circular(13),",
        "          border: Border.all(color: const Color(0xFFDDE5EC)),",
        "        ),",
        "        child: const Row(",
        "          children: [",
        "            Icon(Icons.pending_actions_outlined, color: PipeBuyerColors.muted),",
        "            SizedBox(width: 8),",
        "            Expanded(",
        "              child: Text(",
        "                'No weight entered. The request remains usable, but final carrier planning requires confirmed load weight and dimensions.',",
        "                style: TextStyle(color: PipeBuyerColors.muted, fontSize: 11),",
        "              ),",
        "            ),",
        "          ],",
        "        ),",
        "      );",
        "    }",
        "    final kg = _enteredWeight;",
        "",
      ].join("\n"),
      "unknown-weight analytics state",
    );
  }

  source = source.replace(
    "'The entered weight is for quote planning, not a certified legal load weight. The carrier remains responsible for axle, permit and route compliance.'",
    "marketplaceWeightDisclaimer",
  );

  if (!source.includes("TO CONFIRM — add before final dispatch planning")) {
    replaceOnce(
      [
        "    final kg = draft.weightKg;",
        "    final weight =",
        "        '${_formatNumber(kg)} kg • ${(kg / 1000).toStringAsFixed(2)} t';",
      ].join("\n"),
      [
        "    final kg = draft.weightKg;",
        "    final weight = kg == null",
        "        ? 'TO CONFIRM — add before final dispatch planning'",
        "        : '${_formatNumber(kg)} kg • ${(kg / 1000).toStringAsFixed(2)} t';",
      ].join("\n"),
      "review unknown-weight summary",
    );
  }

  const sectionStart = source.indexOf("  Widget _sectionHeading(");
  const analyticsStart = source.indexOf("  Widget _weightAnalytics()", sectionStart);
  if (sectionStart > 0 && analyticsStart > sectionStart) {
    const section = source.slice(sectionStart, analyticsStart)
        .replaceAll("const Color(0xFFE5F2FF)", "PipeBuyerColors.orangeSoft");
    source = source.slice(0, sectionStart) + section + source.slice(analyticsStart);
  }

  const listingSummaryStart = source.indexOf("class _ListingLoadSummary extends StatelessWidget");
  const reviewStart = source.indexOf("class _ReviewSummaryCard extends StatelessWidget", listingSummaryStart);
  if (listingSummaryStart > 0 && reviewStart > listingSummaryStart) {
    let block = source.slice(listingSummaryStart, reviewStart);
    block = block
        .replaceAll("const Color(0xFFEAF4FD)", "PipeBuyerColors.orangeSoft")
        .replaceAll("const Color(0xFF0878E8)", "PipeBuyerColors.orangePressed");
    source = source.slice(0, listingSummaryStart) + block + source.slice(reviewStart);
  }
}

for (const required of [
  "PIPEBUYER_CARRIER_QUOTE_PREMIUM_V1",
  "MarketplaceDispatchSpecAssistPanel(",
  "I don't know — add later",
  "weightUnknown: _weightUnknown",
  "weightSource: draft.weightSource",
  "marketplaceWeightDisclaimer",
  "TO CONFIRM — add before final dispatch planning",
]) {
  if (!source.includes(required)) {
    throw new Error(`Carrier quote migration verification marker missing: ${required}`);
  }
}
if (source.includes("weightKg: _enteredWeight!")) {
  throw new Error("Carrier quote still force-unwraps weight after deferred-weight migration.");
}

fs.writeFileSync(file, source, "utf8");
console.log("Premium Request Carrier Quotes migration applied.");
console.log("  - Pipe Buyer black/orange premium header");
console.log("  - Spec Assist with make/model/year/details and planning dimensions");
console.log("  - approved catalog lookup with future AI-ready data seam");
console.log("  - explicit I don't know / add weight later path");
console.log("  - nullable Dispatch planning weight preserved through review/publish");
