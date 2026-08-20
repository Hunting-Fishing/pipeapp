import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

import {normalizeDirectorySeedSafeRepository} from './dispatch_directory_seed_safe_repository_transform.mjs';
import {stabilizeDirectoryDropdownLayout} from './dispatch_directory_dropdown_layout_transform.mjs';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const sourcePath = path.join(
  repoRoot,
  'lib',
  'marketplace',
  'marketplace_dispatch_directory.dart',
);
const candidateRelative = process.env.PIPEBUYER_DIRECTORY_SEED_SAFE_LAYOUT_CANDIDATE;
if (!candidateRelative) {
  throw new Error('STOP: PIPEBUYER_DIRECTORY_SEED_SAFE_LAYOUT_CANDIDATE is required.');
}
const candidatePath = path.join(repoRoot, ...candidateRelative.split('/'));

if (!fs.existsSync(sourcePath)) {
  throw new Error('STOP: Production Dispatch Directory source is missing.');
}

const original = fs.readFileSync(sourcePath, 'utf8');
const sourceHashBefore = original;
const firstPass = stabilizeDirectoryDropdownLayout(
  normalizeDirectorySeedSafeRepository(original),
);
const secondPass = stabilizeDirectoryDropdownLayout(
  normalizeDirectorySeedSafeRepository(firstPass),
);
if (secondPass !== firstPass) {
  throw new Error('STOP: Combined seed-safe/layout candidate transform is not idempotent.');
}
if (fs.readFileSync(sourcePath, 'utf8') !== sourceHashBefore) {
  throw new Error('STOP: Candidate verifier modified production Directory source.');
}

fs.writeFileSync(candidatePath, firstPass, 'utf8');
console.log(`Candidate written: ${candidateRelative}`);
console.log('DIRECTORY SEED-SAFE + DROPDOWN LAYOUT CANDIDATE PASSED');
console.log('Exact local Directory source recognized: PASS');
console.log('Seed-only repository lifecycle normalized in candidate: PASS');
console.log('Service/availability/business dropdown widths normalized in candidate: PASS');
console.log('Second in-memory pass idempotent: PASS');
console.log('Production Directory source modified by candidate verifier: NO');
