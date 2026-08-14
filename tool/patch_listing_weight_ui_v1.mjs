"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const file = path.join(root, "lib", "marketplace", "oil_gas_marketplace.dart");
let source = fs.readFileSync(file, "utf8");

function replaceOnce(before, after, label) {
  if (source.includes(after)) return;
  const index = source.indexOf(before);
  if (index < 0) throw new Error(`Anchor not found: ${label}`);
  source = source.slice(0, index) + after + source.slice(index + before.length);
}

replaceOnce(
  `import 'marketplace_freight_quote.dart';\n`,
  `import 'marketplace_freight_quote.dart';\nimport 'marketplace_weight_catalog.dart';\n`,
  "weight catalog import",
);
replaceOnce(
  `  'Bobcat': ['E35', 'E60', 'S650', 'T76', 'TL619'],`,
  `  'Bobcat': ['E35', 'E60', 'S160', 'S650', 'T76', 'TL619'],`,
  "Bobcat S160 model option",
);
replaceOnce(
  `  final _quantity = TextEditingController();\n`,
  `  final _quantity = TextEditingController();\n  final _jointLengthFt = TextEditingController();\n  final _weightInputKey = GlobalKey<MarketplaceListingWeightInputState>();\n`,
  "weight UI state",
);
replaceOnce(
  `    _quantity.dispose();\n`,
  `    _quantity.dispose();\n    _jointLengthFt.dispose();\n`,
  "joint length dispose",
);

if (!source.includes("PIPEBUYER_LISTING_WEIGHT_UI_V1")) {
  const anchor = `            if (isPipe) ...[\n              const SizedBox(height: 12),\n              DropdownButtonFormField<String>(`;
  const ui = `            // PIPEBUYER_LISTING_WEIGHT_UI_V1\n            if (!isProperty) ...[\n              const SizedBox(height: 12),\n              if (isPipe) ...[\n                TextFormField(\n                  controller: _jointLengthFt,\n                  keyboardType:\n                      const TextInputType.numberWithOptions(decimal: true),\n                  decoration: const InputDecoration(\n                    labelText: 'Approx. joint / piece length',\n                    hintText: 'Example: 31',\n                    suffixText: 'ft',\n                    prefixIcon: Icon(Icons.straighten_outlined),\n                    helperText:\n                        'Used with approved pipe mass data to estimate total shipping weight.',\n                  ),\n                ),\n                const SizedBox(height: 10),\n              ],\n              MarketplaceListingWeightInput(\n                key: _weightInputKey,\n                category: _category ?? '',\n                productType: _productType == _otherCatalogValue\n                    ? _customProductType.text.trim()\n                    : (_productType ?? ''),\n                manufacturer: isMachine\n                    ? (_equipmentBrand == _otherCatalogValue\n                        ? _brand.text.trim()\n                        : (_equipmentBrand ?? ''))\n                    : '',\n                model: isMachine\n                    ? (_equipmentModel == _otherCatalogValue\n                        ? _model.text.trim()\n                        : (_equipmentModel ?? ''))\n                    : '',\n                modelYear: isMachine ? _equipmentYear : null,\n                pipeSize: isPipe\n                    ? (_pipeSize == _otherCatalogValue\n                        ? _customPipeSize.text.trim()\n                        : (_pipeSize ?? ''))\n                    : '',\n                quantity: int.tryParse(\n                      _quantity.text.replaceAll(RegExp(r'[^0-9]'), ''),\n                    ) ??\n                    1,\n                lengthM: isPipe\n                    ? (num.tryParse(_jointLengthFt.text.trim())?.toDouble() ??\n                            0) *\n                        0.3048\n                    : null,\n              ),\n            ],\n`;
  const index = source.indexOf(anchor);
  if (index < 0) throw new Error("Anchor not found: active pipe detail section");
  source = source.slice(0, index) + ui + source.slice(index);
}

replaceOnce(
  `        'quantityAndLength': _quantity.text.trim(),\n`,
  `        'quantityAndLength': _quantity.text.trim(),\n        if (isPipeListing && num.tryParse(_jointLengthFt.text.trim()) != null)\n          'jointLengthFt': num.tryParse(_jointLengthFt.text.trim()),\n        ...(_weightInputKey.currentState?.listingFields ??\n            const <String, dynamic>{'weightInputMode': 'catalog_estimate'}),\n`,
  "listing weight payload",
);
replaceOnce(
  `      _quantity.clear();\n`,
  `      _quantity.clear();\n      _jointLengthFt.clear();\n`,
  "listing weight reset",
);

fs.writeFileSync(file, source, "utf8");
console.log("Patched active Create Listing flow with weight estimate/unknown capture.");
