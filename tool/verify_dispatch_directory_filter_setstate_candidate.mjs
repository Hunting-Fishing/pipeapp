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

const sourcePath = path.join(
  repoRoot,
  'lib',
  'marketplace',
  'marketplace_dispatch_directory.dart',
);
if (!fs.existsSync(sourcePath)) fail('Dispatch Directory source is missing.');

const candidateRelative = process.env.PIPEBUYER_DIRECTORY_SETSTATE_CANDIDATE;
if (!candidateRelative) {
  fail('PIPEBUYER_DIRECTORY_SETSTATE_CANDIDATE is not set.');
}
const candidatePath = path.join(repoRoot, candidateRelative.replaceAll('/', path.sep));

const original = fs.readFileSync(sourcePath, 'utf8').replace(/\r\n/g, '\n');
for (const marker of [
  "_firestore.collection('dispatch_directory_entries')",
  'DispatchDirectoryPageData? _lastSuccessfulData;',
  'Timer? _filterDebounce;',
  'MarketplaceDispatchDirectoryRepository? _repository;',
  '_repository = widget.repository;',
  'isExpanded: true,',
]) {
  if (!original.includes(marker)) {
    fail(`Required already-accepted Directory invariant is missing: ${marker}`);
  }
}

const beforeHash = execFileSync(
  'git',
  ['hash-object', sourcePath],
  {cwd: repoRoot, encoding: 'utf8'},
).trim();

const transformed = normalizeDirectoryFilterSetStateCallbacks(original);
const second = normalizeDirectoryFilterSetStateCallbacks(transformed);
if (second !== transformed) {
  fail('Directory setState callback transform is not idempotent.');
}

const unsafeCount = (original.match(/setState\(\s*\(\)\s*=>\s*_loadFuture\s*=\s*_load\(\)\s*\)/g) || []).length;
if (unsafeCount < 1 || unsafeCount > 2) {
  fail(`Expected one or two unsafe Directory Future-returning setState callbacks, found ${unsafeCount}. No guessing.`);
}
if (transformed === original) {
  fail('Directory setState callback candidate did not change the known unsafe local source.');
}

fs.mkdirSync(path.dirname(candidatePath), {recursive: true});
fs.writeFileSync(candidatePath, transformed, 'utf8');

const afterHash = execFileSync(
  'git',
  ['hash-object', sourcePath],
  {cwd: repoRoot, encoding: 'utf8'},
).trim();
if (afterHash !== beforeHash) {
  fail('Candidate verifier modified production Directory source.');
}

console.log(`Candidate written: ${candidateRelative}`);
console.log('DIRECTORY FILTER SETSTATE CANDIDATE PASSED');
console.log('Exact local post-layout Directory source recognized: PASS');
console.log(`Unsafe Future-returning setState callbacks normalized in candidate: ${unsafeCount}`);
console.log('Second in-memory pass idempotent: PASS');
console.log('Production Directory source modified by candidate verifier: NO');
