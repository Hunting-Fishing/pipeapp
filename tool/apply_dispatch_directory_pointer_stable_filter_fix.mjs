import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

import {stabilizeDirectoryPointerSelection} from './dispatch_directory_pointer_stable_filter_transform.mjs';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const expectedBranch = 'design/formal-beautification-foundation';

function fail(message) {
  throw new Error(`STOP: ${message}`);
}

const branch = execFileSync('git', ['branch', '--show-current'], {
  cwd: repoRoot,
  encoding: 'utf8',
}).trim();
if (branch !== expectedBranch) {
  fail(`Wrong branch. Expected ${expectedBranch}, found ${branch}.`);
}

const target = path.join(
  repoRoot,
  'lib',
  'marketplace',
  'marketplace_dispatch_directory.dart',
);
if (!fs.existsSync(target)) fail('Dispatch Directory source is missing.');

const original = fs.readFileSync(target, 'utf8').replace(/\r\n/g, '\n');
const transformed = stabilizeDirectoryPointerSelection(original);
if (transformed === original) {
  console.log('Dispatch Directory pointer-stable filter control is already installed.');
  process.exit(0);
}

const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const backupDir = path.join(
  repoRoot,
  '_local_backups',
  `dispatch-directory-pointer-stable-filter-${stamp}`,
);
fs.mkdirSync(backupDir, {recursive: true});
fs.copyFileSync(target, path.join(backupDir, path.basename(target)));
fs.writeFileSync(target, transformed, 'utf8');

console.log(`Backup created: ${backupDir}`);
console.log('DIRECTORY POINTER-STABLE FILTER SOURCE APPLIED');
console.log('Legacy overlay dropdown filters: REMOVED');
console.log('Inline service/availability/business selectors: INSTALLED');
console.log('Pointer-triggered selector geometry staging: INSTALLED');
console.log('Dispatch tracker modified by repair: NO');
