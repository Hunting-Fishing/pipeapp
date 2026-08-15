"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const file = path.join(root, "lib", "marketplace", "marketplace_weight_catalog_admin.dart");
let source = fs.readFileSync(file, "utf8");
source = source.replace("import 'marketplace_money.dart';\n", "");
fs.writeFileSync(file, source, "utf8");
console.log("Normalized Weight Catalog admin imports.");
