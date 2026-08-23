import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {normalizeDirectoryFilterSetStateCallbacks} from './dispatch_directory_filter_setstate_transform.mjs';

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
const transformed = normalizeDirectoryFilterSetStateCallbacks(original);
if (transformed === original) {
  console.log('Directory Future-returning setState callback repair is already installed.');
  process.exit(0);
}

const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const backupDir = path.join(
  repoRoot,
  '_local_backups',
  `dispatch-directory-setstate-void-${stamp}`,
);
fs.mkdirSync(backupDir, {recursive: true});
fs.copyFileSync(target, path.join(backupDir, path.basename(target)));
fs.writeFileSync(target, transformed, 'utf8');

console.log(`Backup created: ${backupDir}`);
console.log('DIRECTORY FILTER SETSTATE VOID-SAFETY APPLIED');
console.log('Reload callback returns void: INSTALLED');
console.log('Debounced filter callback returns void: INSTALLED');
console.log('Dispatch tracker modified by repair: NO');
