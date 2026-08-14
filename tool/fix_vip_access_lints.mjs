"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const target = path.join(root, "lib", "marketplace", "marketplace_vip_access.dart");

let source = fs.readFileSync(target, "utf8");

source = source.replace(
  "  if (listing['vipEarlyAccessEnabled'] == false) return null;",
  "  if (listing['vipEarlyAccessEnabled'] != true) return null;",
);

source = source.replace(
  "        child: child,\n        onUpgrade: onUpgrade,",
  "        onUpgrade: onUpgrade,\n        child: child,",
);

source = source.replace(
  "          child: child,\n          onUpgrade: onUpgrade,",
  "          onUpgrade: onUpgrade,\n          child: child,",
);

fs.writeFileSync(target, source, "utf8");
console.log("Normalized VIP early-access policy and Flutter child ordering.");
