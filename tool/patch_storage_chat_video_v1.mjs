"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const file = path.join(root, "firebase", "storage.rules");
let source = fs.readFileSync(file, "utf8");
const before = `        && request.resource.size <= 15 * 1024 * 1024\n        && (isImage() || isVideo()\n          || request.resource.contentType == 'application/pdf');`;
const after = `        && ((isVideo() && request.resource.size <= 25 * 1024 * 1024)\n          || (!isVideo() && request.resource.size <= 15 * 1024 * 1024))\n        && (isImage() || isVideo()\n          || request.resource.contentType == 'application/pdf');`;
if (!source.includes(after)) {
  if (!source.includes(before)) throw new Error("Chat attachment storage rule anchor not found");
  source = source.replace(before, after);
}
fs.writeFileSync(file, source, "utf8");
console.log("Aligned chat Storage rules: 15 MB image/PDF, 25 MB video.");
