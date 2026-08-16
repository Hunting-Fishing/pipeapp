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

hardened = hardened.replace(
  "const returnCardPattern = /(\\s*)return Card\\(\\n([ \\t]*)margin:/;",
  "const returnCardPattern = /^([ \\t]*)return Card\\(\\n([ \\t]*)margin:/m;",
);
hardened = hardened.replace(
  "const statementIndent = returnMatch[1].match(/\\n([ \\t]*)$/)?.[1] ?? '                ';",
  "const statementIndent = returnMatch[1];",
);

if (hardened === original) {
  throw new Error('Could not apply the Timed Offer Activity structural hardening to v2.');
}

fs.writeFileSync(v2Path, hardened, 'utf8');
try {
  await import(pathToFileURL(v3Path).href + `?run=${Date.now()}`);
} finally {
  fs.writeFileSync(v2Path, original, 'utf8');
}
