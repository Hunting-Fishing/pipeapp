import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';

const root = process.cwd();
const sourcePath = path.join(root, 'tool', 'fix_trust_onboarding_v1.mjs');
const runtimePath = path.join(root, 'tool', '.fix_trust_onboarding_v2_runtime.mjs');
let source = fs.readFileSync(sourcePath, 'utf8');

const fixes = [
  ["${_readiness.missingPoints}", "\\${_readiness.missingPoints}"],
  ["${_emailVerified ? 'email' : 'mobile'}", "\\${_emailVerified ? 'email' : 'mobile'}"],
  ["${MarketplaceTrustReadiness.totalPoints}", "\\${MarketplaceTrustReadiness.totalPoints}"],
];

for (const [before, after] of fixes) {
  const count = source.split(before).length - 1;
  if (count === 0) {
    console.log(`already escaped or absent: ${before}`);
    continue;
  }
  source = source.split(before).join(after);
  console.log(`escaped ${count} Dart interpolation(s): ${before}`);
}

const suspicious = [...source.matchAll(/(?<!\\)\$\{(?:_|MarketplaceTrustReadiness)/g)];
if (suspicious.length > 0) {
  throw new Error(`Unescaped Dart interpolation remains in trust patcher (${suspicious.length}).`);
}

fs.writeFileSync(runtimePath, source, 'utf8');
try {
  const result = spawnSync(process.execPath, [runtimePath], {
    cwd: root,
    stdio: 'inherit',
  });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  try { fs.unlinkSync(runtimePath); } catch (_) {}
}
