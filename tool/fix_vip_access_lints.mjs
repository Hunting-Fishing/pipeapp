"use strict";

import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const target = path.join(root, "lib", "marketplace", "marketplace_vip_access.dart");

let source = fs.readFileSync(target, "utf8");

source = source.replace(
  `DateTime? marketplaceAccessDate(dynamic value) => switch (value) {\n      Timestamp timestamp => timestamp.toDate(),\n      DateTime date => date,\n      int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),\n      String text => DateTime.tryParse(text),\n      _ => null,\n    };`,
  `DateTime? marketplaceAccessDate(dynamic value) {\n  final parsed = switch (value) {\n    Timestamp timestamp => timestamp.toDate(),\n    DateTime date => date,\n    int milliseconds =>\n      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),\n    String text => DateTime.tryParse(text),\n    _ => null,\n  };\n  return parsed?.toUtc();\n}`,
);

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
console.log("Normalized VIP UTC timing, explicit early-access policy and Flutter child ordering.");
