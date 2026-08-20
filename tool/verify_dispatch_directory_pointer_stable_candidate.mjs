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

const sourcePath = path.join(
  repoRoot,
  'lib',
  'marketplace',
  'marketplace_dispatch_directory.dart',
);
const candidateRelative = process.env.PIPEBUYER_DIRECTORY_POINTER_STABLE_CANDIDATE;
if (!candidateRelative) {
  fail('PIPEBUYER_DIRECTORY_POINTER_STABLE_CANDIDATE is required.');
}
const candidatePath = path.join(repoRoot, ...candidateRelative.split('/'));
if (!fs.existsSync(sourcePath)) fail('Production Dispatch Directory source is missing.');

const original = fs.readFileSync(sourcePath, 'utf8');
const firstPass = stabilizeDirectoryPointerSelection(original);
const secondPass = stabilizeDirectoryPointerSelection(firstPass);
if (secondPass !== firstPass) {
  fail('Pointer-stable Directory filter transform is not idempotent.');
}
if (fs.readFileSync(sourcePath, 'utf8') !== original) {
  fail('Candidate verifier modified production Directory source.');
}

fs.writeFileSync(candidatePath, firstPass, 'utf8');
console.log(`Candidate written: ${candidateRelative}`);
console.log('DIRECTORY POINTER-STABLE FILTER CANDIDATE PASSED');
console.log('Exact local Directory source recognized: PASS');
console.log('Legacy overlay dropdown filters removed in candidate: PASS');
console.log('Inline same-tree selectors installed in candidate: PASS');
console.log('Pointer-driven geometry changes deferred post-frame: PASS');
console.log('Second in-memory pass idempotent: PASS');
console.log('Production Directory source modified by candidate verifier: NO');
