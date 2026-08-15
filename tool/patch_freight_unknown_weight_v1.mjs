"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const file = path.join(root, "lib", "marketplace", "marketplace_freight_quote.dart");
let source = fs.readFileSync(file, "utf8");

function replaceOnce(before, after, label) {
  if (source.includes(after)) return;
  const index = source.indexOf(before);
  if (index < 0) throw new Error(`Anchor not found: ${label}`);
  source = source.slice(0, index) + after + source.slice(index + before.length);
}

replaceOnce(
  `import 'marketplace_trucking_plan.dart';\n`,
  `import 'marketplace_trucking_plan.dart';\nimport 'marketplace_weight_catalog.dart';\n`,
  "shared weight import",
);

if (!source.includes("PIPEBUYER_WEIGHT_SNAPSHOT_V1")) {
  replaceOnce(
    `  static FreightWeightEstimate fromListing(Map<String, dynamic> data) {\n`,
    `  static FreightWeightEstimate fromListing(Map<String, dynamic> data) {\n    // PIPEBUYER_WEIGHT_SNAPSHOT_V1\n    final frozen = MarketplaceWeightEstimate.fromListing(data);\n    if (frozen.hasWeight) {\n      return FreightWeightEstimate(\n        kg: frozen.kg,\n        source: frozen.source,\n        confidence: frozen.confidence,\n      );\n    }\n    if (frozen.status == 'unknown') {\n      return FreightWeightEstimate(\n        kg: null,\n        source: frozen.source,\n        confidence: frozen.confidence,\n      );\n    }\n`,
    "frozen listing weight snapshot",
  );
}

const oldResolver = `    final make = '\${data['brand'] ?? data['make'] ?? ''}'.trim();\n    final model = '\${data['model'] ?? ''}'.trim();\n    if (make.isEmpty || model.isEmpty) return listed;\n    final key = _catalogKey(make, model);\n    final catalog = await FirebaseFirestore.instance\n        .collection('weight_catalog')\n        .doc(key)\n        .get();\n    final value = catalog.data()?['operatingWeightKg'] as num? ??\n        catalog.data()?['shippingWeightKg'] as num?;\n    if (value == null || value <= 0) return listed;\n    return FreightWeightEstimate(\n        kg: value.toDouble(),\n        source:\n            '\${catalog.data()?['manufacturer'] ?? make} verified catalog • $make $model',\n        confidence: '\${catalog.data()?['verificationStatus'] ?? 'catalog'}');\n`;
const newResolver = `    // PIPEBUYER_WEIGHT_CATALOG_RESOLVER_V1\n    final resolved = await MarketplaceWeightCatalogRepository().resolve(\n      category: '\${data['category'] ?? ''}',\n      productType: '\${data['productType'] ?? ''}',\n      manufacturer: '\${data['brand'] ?? data['make'] ?? ''}',\n      model: '\${data['model'] ?? ''}',\n      modelYear: (data['modelYear'] as num?)?.toInt(),\n      pipeSize: '\${data['pipeSize'] ?? ''}',\n      quantity: (data['quantity'] as num?)?.toInt() ?? 1,\n      lengthM: _number(data['jointLengthM']) ??\n          ((_number(data['jointLengthFt']) ?? 0) * 0.3048),\n    );\n    if (!resolved.hasWeight) return listed;\n    return FreightWeightEstimate(\n      kg: resolved.kg,\n      source: resolved.source,\n      confidence: resolved.confidence,\n    );\n`;
if (!source.includes("PIPEBUYER_WEIGHT_CATALOG_RESOLVER_V1")) {
  replaceOnce(oldResolver, newResolver, "shared weight catalog resolver");
}
source = source.replace(
  `\n  static String _catalogKey(String make, String model) =>\n      '\${make}_$model'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');\n`,
  "\n",
);

replaceOnce(
  `    required this.weightChanged,\n  });\n\n  final String pickup;\n  final MarketplaceLocation delivery;\n  final double weightKg;\n`,
  `    required this.weightChanged,\n    required this.weightUnknown,\n  });\n\n  final String pickup;\n  final MarketplaceLocation delivery;\n  final double? weightKg;\n`,
  "nullable freight draft",
);
replaceOnce(
  `  final bool weightChanged;\n}\n\nclass _FreightQuoteDialog`,
  `  final bool weightChanged;\n  final bool weightUnknown;\n}\n\nclass _FreightQuoteDialog`,
  "unknown weight draft flag",
);
replaceOnce(
  `  bool _weightChanged = false;\n`,
  `  bool _weightChanged = false;\n  bool _weightUnknown = false;\n`,
  "unknown weight UI state",
);
replaceOnce(
  `  double? get _enteredWeight {\n    final value = double.tryParse(_weight.text.trim().replaceAll(',', ''));\n`,
  `  double? get _enteredWeight {\n    if (_weightUnknown) return null;\n    final value = double.tryParse(_weight.text.trim().replaceAll(',', ''));\n`,
  "entered weight unknown behavior",
);
replaceOnce(
  `            weightKg: _enteredWeight!,\n            details: _details.text.trim(),\n            truckingDate: _date,\n            weightChanged: _weightChanged));\n`,
  `            weightKg: _enteredWeight,\n            details: _details.text.trim(),\n            truckingDate: _date,\n            weightChanged: _weightChanged,\n            weightUnknown: _weightUnknown));\n`,
  "nullable freight draft construction",
);
replaceOnce(
  `          weightSource:\n              draft.weightChanged ? 'shipper_adjusted' : estimate.source,\n`,
  `          weightSource: draft.weightUnknown\n              ? (estimate.kg == null\n                  ? 'shipper_unknown'\n                  : 'shipper_unknown_catalog_reference_available')\n              : draft.weightChanged\n                  ? 'shipper_adjusted'\n                  : estimate.source,\n`,
  "Dispatch unknown weight source",
);

const weightField = `              const SizedBox(height: 9),\n              TextFormField(\n                  controller: _weight,\n                  keyboardType:\n                      const TextInputType.numberWithOptions(decimal: true),\n                  onChanged: (_) => setState(() => _weightChanged = true),\n                  decoration: InputDecoration(\n                      labelText: 'Estimated shipping weight *',\n                      hintText:\n                          _usePounds ? 'Example: 12,500' : 'Example: 5,670',\n                      helperText:\n                          'Enter the estimated weight for the complete load.',\n                      prefixIcon: const Icon(Icons.scale_outlined),\n                      suffixText: _usePounds ? 'lb' : 'kg'),\n                  validator: (_) => _enteredWeight == null\n                      ? 'Enter a valid load weight'\n                      : null),\n              const SizedBox(height: 8),\n              _weightAnalytics(),\n`;
const upgradedWeightField = `              const SizedBox(height: 9),\n              Wrap(spacing: 8, runSpacing: 8, children: [\n                ChoiceChip(\n                  selected: !_weightUnknown,\n                  label: Text(widget.estimate.kg == null\n                      ? 'Enter approximate weight'\n                      : 'Use / adjust approximate weight'),\n                  avatar: const Icon(Icons.scale_outlined, size: 18),\n                  onSelected: (_) => setState(() => _weightUnknown = false),\n                ),\n                ChoiceChip(\n                  selected: _weightUnknown,\n                  label: const Text(\"I don't know the weight\"),\n                  avatar: const Icon(Icons.help_outline, size: 18),\n                  onSelected: (_) => setState(() {\n                    _weightUnknown = true;\n                    _weightChanged = false;\n                  }),\n                ),\n              ]),\n              const SizedBox(height: 9),\n              if (!_weightUnknown)\n                TextFormField(\n                  controller: _weight,\n                  keyboardType:\n                      const TextInputType.numberWithOptions(decimal: true),\n                  onChanged: (_) => setState(() => _weightChanged = true),\n                  decoration: InputDecoration(\n                    labelText: 'Estimated shipping weight',\n                    hintText:\n                        _usePounds ? 'Example: 12,500' : 'Example: 5,670',\n                    helperText:\n                        'Approximate total load weight for carrier planning.',\n                    prefixIcon: const Icon(Icons.scale_outlined),\n                    suffixText: _usePounds ? 'lb' : 'kg',\n                  ),\n                  validator: (_) => _enteredWeight == null\n                      ? 'Enter a valid load weight or choose “I don’t know”'\n                      : null,\n                ),\n              if (_weightUnknown)\n                const Card(\n                  margin: EdgeInsets.zero,\n                  color: Color(0xFFFFF4E5),\n                  child: Padding(\n                    padding: EdgeInsets.all(11),\n                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                      Icon(Icons.warning_amber_rounded, color: Color(0xFFF08A24)),\n                      SizedBox(width: 8),\n                      Expanded(\n                        child: Text(\n                          'Weight will be marked TO CONFIRM. Carriers can quote subject to verified load configuration and certified weights before transport.',\n                          style: TextStyle(fontSize: 11),\n                        ),\n                      ),\n                    ]),\n                  ),\n                ),\n              const SizedBox(height: 8),\n              _weightAnalytics(),\n`;
replaceOnce(weightField, upgradedWeightField, "unknown weight controls");
replaceOnce(
  `  Widget _weightAnalytics() {\n    final kg = _enteredWeight;\n`,
  `  Widget _weightAnalytics() {\n    if (_weightUnknown) return const SizedBox.shrink();\n    final kg = _enteredWeight;\n`,
  "unknown weight analytics",
);
replaceOnce(
  `    final kg = draft.weightKg;\n    final weight =\n        '\${_formatNumber(kg)} kg • \${(kg / 1000).toStringAsFixed(2)} t';\n`,
  `    final kg = draft.weightKg;\n    final weight = kg == null\n        ? 'TO CONFIRM — shipper does not know the load weight'\n        : '\${_formatNumber(kg)} kg • \${(kg / 1000).toStringAsFixed(2)} t';\n`,
  "review unknown weight summary",
);
replaceOnce(
  `'The entered weight is for quote planning, not a certified legal load weight. The carrier remains responsible for axle, permit and route compliance.'`,
  `marketplaceWeightDisclaimer`,
  "shared planning-only disclaimer",
);

fs.writeFileSync(file, source, "utf8");
console.log("Patched Request Carrier Quotes with frozen listing weights and explicit unknown-weight handling.");
