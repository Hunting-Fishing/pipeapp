import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';

const root = process.cwd();
const v2Path = path.join(root, 'tool/apply_timed_buying_trust_v2.mjs');
const v3Path = path.join(root, 'tool/apply_timed_buying_trust_v3.mjs');

if (!fs.existsSync(v2Path)) throw new Error('Missing apply_timed_buying_trust_v2.mjs');
if (!fs.existsSync(v3Path)) throw new Error('Missing apply_timed_buying_trust_v3.mjs');

const original = fs.readFileSync(v2Path, 'utf8');
let hardened = original;

// v3 inserts the buyer-position widget before v2 is imported, so the legacy
// inline widget template in v2 is intentionally unreachable at runtime.
// It still has to be parseable by Node, however. The older template contains
// Dart ${...} interpolation inside a JavaScript template literal, which makes
// Node try to parse Dart as JavaScript. Replace only that unreachable template
// body with a harmless placeholder while this wrapper executes.
const legacyWidgetTemplate = /  const widgetClass = `class _TimedBuyingBuyerTrustPosition extends StatelessWidget \{[\s\S]*?`;\s*page = insertBeforeIndex\(page, index, widgetClass\);/;
if (legacyWidgetTemplate.test(hardened)) {
  hardened = hardened.replace(
    legacyWidgetTemplate,
    "  const widgetClass = '';\n  page = insertBeforeIndex(page, index, widgetClass);",
  );
}

// Preserve the prior structural hardening for the compact Timed Offer Activity
// rows. These replacements are text-level on purpose because v2 is treated as
// migration source text until it has been made parser-safe.
hardened = hardened.replace(
  "const returnCardPattern = /(\\s*)return Card\\(\\n([ \\t]*)margin:/;",
  "const returnCardPattern = /^([ \\t]*)return Card\\(\\n([ \\t]*)margin:/m;",
);
hardened = hardened.replace(
  "const statementIndent = returnMatch[1].match(/\\n([ \\t]*)$/)?.[1] ?? '                ';",
  "const statementIndent = returnMatch[1];",
);

if (hardened === original) {
  throw new Error('Could not apply parser/structural hardening to Timed Buying trust v2.');
}

fs.writeFileSync(v2Path, hardened, 'utf8');
try {
  await import(pathToFileURL(v3Path).href + `?run=${Date.now()}`);
} finally {
  // Always put the developer-facing migration source back exactly as fetched.
  // Product/backend files are handled independently by the PowerShell runner.
  fs.writeFileSync(v2Path, original, 'utf8');
}
