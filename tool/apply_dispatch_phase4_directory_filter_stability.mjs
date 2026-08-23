import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {stabilizeDirectoryFilterRuntime} from './dispatch_directory_filter_runtime_transform.mjs';

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
const transformed = stabilizeDirectoryFilterRuntime(original);
if (transformed === original) {
  console.log('Dispatch Directory filter runtime stability is already installed.');
  process.exit(0);
}

const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const backupDir = path.join(
    repoRoot,
    '_local_backups',
    `dispatch-phase4-directory-filter-stability-${stamp}`,
);
fs.mkdirSync(backupDir, {recursive: true});
fs.copyFileSync(target, path.join(backupDir, path.basename(target)));

fs.writeFileSync(target, transformed, 'utf8');
console.log(`Backup created: ${backupDir}`);
console.log('DISPATCH PHASE 4 DIRECTORY FILTER RUNTIME STABILITY READY');
console.log('Last successful Directory results retained during filter refresh: INSTALLED');
console.log('Rapid filter/search refresh debounce: INSTALLED');
console.log('Filter refresh error keeps usable cached results: INSTALLED');
console.log('Dispatch tracker modified by repair: NO');
