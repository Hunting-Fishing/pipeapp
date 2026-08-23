import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

import {normalizeDirectorySeedSafeRepository} from './dispatch_directory_seed_safe_repository_transform.mjs';
import {stabilizeDirectoryDropdownLayout} from './dispatch_directory_dropdown_layout_transform.mjs';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const expectedBranch = 'design/formal-beautification-foundation';
const branch = execFileSync('git', ['branch', '--show-current'], {
  cwd: repoRoot,
  encoding: 'utf8',
}).trim();
if (branch !== expectedBranch) {
  throw new Error(`STOP: Wrong branch. Expected ${expectedBranch}, found ${branch}.`);
}

const sourcePath = path.join(
  repoRoot,
  'lib',
  'marketplace',
  'marketplace_dispatch_directory.dart',
);
if (!fs.existsSync(sourcePath)) {
  throw new Error('STOP: Production Dispatch Directory source is missing.');
}

const original = fs.readFileSync(sourcePath, 'utf8');
const transformed = stabilizeDirectoryDropdownLayout(
  normalizeDirectorySeedSafeRepository(original),
);
const secondPass = stabilizeDirectoryDropdownLayout(
  normalizeDirectorySeedSafeRepository(transformed),
);
if (secondPass !== transformed) {
  throw new Error('STOP: Combined Directory seed-safe/layout transform is not idempotent.');
}

if (transformed === original.replace(/\r\n/g, '\n')) {
  console.log('Directory seed-safe/layout source is already normalized.');
  process.exit(0);
}

const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const backupDir = path.join(
  repoRoot,
  '_local_backups',
  `dispatch-directory-seed-safe-layout-${stamp}`,
);
fs.mkdirSync(backupDir, {recursive: true});
fs.copyFileSync(
  sourcePath,
  path.join(backupDir, 'marketplace_dispatch_directory.dart'),
);
fs.writeFileSync(sourcePath, transformed, 'utf8');
console.log(`Backup created: ${backupDir}`);
console.log('DIRECTORY SEED-SAFE + DROPDOWN LAYOUT SOURCE APPLIED');
console.log('Seeded mode avoids eager Firebase repository construction: INSTALLED');
console.log('Service/availability/business dropdown overflow control: INSTALLED');
