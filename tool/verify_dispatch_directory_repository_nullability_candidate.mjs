import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {normalizeDirectoryRepositoryNullability} from './dispatch_directory_repository_nullability_transform.mjs';

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
const transformed = normalizeDirectoryRepositoryNullability(before);
const secondPass = normalizeDirectoryRepositoryNullability(transformed);
if (secondPass !== transformed) {
  fail('Directory repository nullability transform is not idempotent.');
}

const candidateRelative = process.env.PIPEBUYER_DIRECTORY_REPOSITORY_CANDIDATE;
if (candidateRelative) {
  const candidatePath = path.join(repoRoot, ...candidateRelative.split('/'));
  fs.writeFileSync(candidatePath, transformed, 'utf8');
  console.log(`Candidate written: ${candidateRelative}`);
}

const afterBytes = fs.readFileSync(sourcePath);
if (!beforeBytes.equals(afterBytes)) {
  fail('Repository nullability candidate verifier modified production source.');
}

console.log('DIRECTORY REPOSITORY NULLABILITY CANDIDATE PASSED');
console.log('Exact local Directory source recognized: PASS');
console.log('Nullable repository normalized in candidate: PASS');
console.log('Second in-memory pass idempotent: PASS');
console.log('Production Directory source modified by candidate verifier: NO');
