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

const beforeBytes = fs.readFileSync(target);
const before = beforeBytes.toString('utf8').replace(/\r\n/g, '\n');
if (!before.includes("_firestore.collection('dispatch_directory_entries')")) {
  fail('Accepted server-owned Directory query layer is not installed.');
}

const transformed = stabilizeDirectoryFilterRuntime(before);
const secondPass = stabilizeDirectoryFilterRuntime(transformed);
if (secondPass !== transformed) {
  fail('Directory runtime transform is not idempotent in memory.');
}

const afterBytes = fs.readFileSync(target);
if (!beforeBytes.equals(afterBytes)) {
  fail('Dry-run verifier modified the production Directory file.');
}

console.log('DIRECTORY FILTER RUNTIME TRANSFORM DRY-RUN PASSED');
console.log('Current local post-query source recognized: PASS');
console.log('Complete runtime transform validates in memory: PASS');
console.log('Second in-memory pass is idempotent: PASS');
console.log('Production Directory source modified by dry-run: NO');
