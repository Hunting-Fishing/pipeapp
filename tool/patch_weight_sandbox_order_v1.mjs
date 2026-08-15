"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const file = path.join(root, "tool", "start_live_test_sandbox.ps1");
let source = fs.readFileSync(file, "utf8");

const block = `  & node (Join-Path $functionsDir 'scripts\\seed_live_test_weight_catalog.js')\n  if ($LASTEXITCODE -ne 0) {\n    throw 'Weight catalog seed failed. Check the error above.'\n  }\n`;
// Remove any previous placement, then insert before marketplace inventory.
source = source.replace(`\n${block}`, "");
const anchor = `  Write-Step 'Loading full Pipe Buyer integration test data'\n  & node (Join-Path $functionsDir 'scripts\\seed_visual_sandbox.js')\n`;
const replacement = `  Write-Step 'Loading full Pipe Buyer integration test data'\n${block}\n  & node (Join-Path $functionsDir 'scripts\\seed_visual_sandbox.js')\n`;
if (!source.includes(anchor) && !source.includes(replacement)) {
  throw new Error("Sandbox seed-order anchor not found");
}
if (!source.includes(replacement)) source = source.replace(anchor, replacement);

fs.writeFileSync(file, source, "utf8");
console.log("Weight catalog now seeds before marketplace listings.");
