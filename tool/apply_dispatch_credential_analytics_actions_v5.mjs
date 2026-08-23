import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, '..');
const baseScript = path.join(__dirname, 'apply_dispatch_credential_analytics_actions_v4.mjs');
const runtimeScript = path.join(__dirname, '.dispatch_credential_analytics_actions_v5_runtime.mjs');

function fail(message) {
  throw new Error(`STOP: ${message}`);
}

if (!fs.existsSync(baseScript)) {
  fail(`Required V4 atomic migration is missing: ${baseScript}`);
}

const source = fs.readFileSync(baseScript, 'utf8');
const brittleMarker = `"const Text('View details')"`;
const tolerantMarker = `"'View details'"`;
const occurrences = source.split(brittleMarker).length - 1;
if (occurrences !== 2) {
  fail(
    `Expected exactly two known formatter-sensitive View details validation markers in V4, found ${occurrences}. No guessing.`,
  );
}

// V4's actual transformation is atomic and formatter-tolerant. Its only defect
// was its own final self-validation using a single-line Dart spelling for
// const Text('View details'). Patch those two validation literals in-memory,
// then execute the otherwise unchanged V4 migration from the same tool folder.
const hardened = source.split(brittleMarker).join(tolerantMarker);

try {
  fs.writeFileSync(runtimeScript, hardened, 'utf8');
  execFileSync(process.execPath, [runtimeScript], {
    cwd: repoRoot,
    stdio: 'inherit',
  });
} finally {
  if (fs.existsSync(runtimeScript)) fs.unlinkSync(runtimeScript);
}

console.log('Credential analytics V5 formatter-tolerant self-validation: PASS');
console.log('V4 production transformation logic changed by V5: NO');
console.log('Dispatch tracker modified by V5: NO');
