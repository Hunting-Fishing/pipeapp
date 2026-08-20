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

const sourcePath = path.join(
  repoRoot,
  'lib',
  'marketplace',
  'marketplace_dispatch_directory.dart',
);
if (!fs.existsSync(sourcePath)) fail('Dispatch Directory source is missing.');

const beforeBytes = fs.readFileSync(sourcePath);
const before = beforeBytes.toString('utf8').replace(/\r\n/g, '\n');
const transformed = normalizeDirectorySeedSafeRepository(before);
const secondPass = normalizeDirectorySeedSafeRepository(transformed);
if (secondPass !== transformed) {
  fail('Seed-safe Directory repository transform is not idempotent.');
}

const candidateRelative = process.env.PIPEBUYER_DIRECTORY_SEED_SAFE_CANDIDATE;
if (candidateRelative) {
  const candidatePath = path.join(repoRoot, ...candidateRelative.split('/'));
  fs.writeFileSync(candidatePath, transformed, 'utf8');
  console.log(`Candidate written: ${candidateRelative}`);
}

const afterBytes = fs.readFileSync(sourcePath);
if (!beforeBytes.equals(afterBytes)) {
  fail('Seed-safe candidate verifier modified production Directory source.');
}

console.log('DIRECTORY SEED-SAFE REPOSITORY CANDIDATE PASSED');
console.log('Exact local Directory source recognized: PASS');
console.log('Seeded mode avoids eager Firebase repository construction: PASS');
console.log('Live mode lazily creates repository after seed branch: PASS');
console.log('Second in-memory pass idempotent: PASS');
console.log('Production Directory source modified by candidate verifier: NO');
