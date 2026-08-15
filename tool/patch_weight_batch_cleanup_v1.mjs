"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

{
  const file = path.join(root, "lib", "marketplace", "marketplace_freight_quote.dart");
  let source = fs.readFileSync(file, "utf8");
  source = source.replace(
    /\n  static String _catalogKey\(String make, String model\) =>\n      '\$\{make\}_\$model'\.toLowerCase\(\)\.replaceAll\(RegExp\(r'\[\^a-z0-9\]\+'\), '_'\);\n/,
    "\n",
  );
  fs.writeFileSync(file, source, "utf8");
}

{
  const file = path.join(root, "lib", "marketplace", "oil_gas_marketplace.dart");
  let source = fs.readFileSync(file, "utf8");
  const before = `                  controller: _jointLengthFt,\n                  keyboardType:\n                      const TextInputType.numberWithOptions(decimal: true),\n`;
  const after = `                  controller: _jointLengthFt,\n                  keyboardType:\n                      const TextInputType.numberWithOptions(decimal: true),\n                  onChanged: (_) => setState(() {}),\n`;
  if (source.includes(before) && !source.includes(after)) {
    source = source.replace(before, after);
  }
  fs.writeFileSync(file, source, "utf8");
}

console.log("Applied weight batch analyzer/refresh cleanup.");
