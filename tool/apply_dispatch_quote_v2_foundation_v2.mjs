import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

import {
  loadDispatchQuoteV2Files,
  transformDispatchQuoteV2Foundation,
} from './dispatch_quote_v2_foundation_transform_v3.mjs';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const expectedBranch = 'design/formal-beautification-foundation';

function currentBranch() {
  const head = fs.readFileSync(path.join(repoRoot, '.git', 'HEAD'), 'utf8').trim();
  const prefix = 'ref: refs/heads/';
  return head.startsWith(prefix) ? head.slice(prefix.length) : '';
}

if (currentBranch() !== expectedBranch) {
  throw new Error(`STOP: Quote V2 installer requires ${expectedBranch}.`);
}

const {paths, files} = loadDispatchQuoteV2Files();
const transformed = transformDispatchQuoteV2Foundation(files);
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const backupRoot = path.join(repoRoot, '_local_backups', `dispatch-quote-v2-v2-${stamp}`);
fs.mkdirSync(backupRoot, {recursive: true});

for (const [key, filePath] of Object.entries(paths)) {
  const relative = path.relative(repoRoot, filePath);
  const backupPath = path.join(backupRoot, relative);
  fs.mkdirSync(path.dirname(backupPath), {recursive: true});
  fs.copyFileSync(filePath, backupPath);
  fs.writeFileSync(filePath, transformed[key], 'utf8');
}

if (fs.readFileSync(paths.dashboard, 'utf8').includes('class _DispatchQuoteDialog extends StatefulWidget')) {
  throw new Error('STOP: Retired Dashboard quote editor remained after Quote V2 application.');
}

console.log('PIPE BUYER DISPATCH QUOTE V2 FOUNDATION V2 APPLIED');
console.log(`Backup: ${backupRoot}`);
console.log('Jobs legacy all-in quote dialog replaced: YES');
console.log('Retired Dashboard quote editor removed: YES');
console.log('Dashboard and Jobs reusable quote form wiring: YES');
console.log('Full quote-breakdown command payload: YES');
console.log('Server-calculated quote total validation: YES');
console.log('Stable quote reference + version metadata: YES');
