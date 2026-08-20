import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {normalizeDirectorySeedSafeRepository} from './dispatch_directory_seed_safe_repository_transform.mjs';

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
const transformed = normalizeDirectorySeedSafeRepository(original);
if (transformed === original) {
  console.log('Directory repository lifecycle is already seed-safe.');
  process.exit(0);
}

const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const backupDir = path.join(
  repoRoot,
  '_local_backups',
  `dispatch-directory-seed-safe-repository-${stamp}`,
);
fs.mkdirSync(backupDir, {recursive: true});
fs.copyFileSync(target, path.join(backupDir, path.basename(target)));
fs.writeFileSync(target, transformed, 'utf8');

console.log(`Backup created: ${backupDir}`);
console.log('DISPATCH DIRECTORY SEED-SAFE REPOSITORY FIX READY');
console.log('Seeded widget mode avoids Firebase repository construction: INSTALLED');
console.log('Live Directory mode lazily creates Firestore repository: INSTALLED');
console.log('Dispatch tracker modified by repair: NO');
