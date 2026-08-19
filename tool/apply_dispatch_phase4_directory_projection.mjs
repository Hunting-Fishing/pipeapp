import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const expectedBranch = 'design/formal-beautification-foundation';

function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function branch() {
  return execFileSync('git', ['branch', '--show-current'], {
    cwd: repoRoot,
    encoding: 'utf8',
  }).trim();
}

function count(text, marker) {
  return text.split(marker).length - 1;
}

function insertAfterOnce(text, marker, addition, label) {
  if (text.includes(addition.trim())) return text;
  const matches = count(text, marker);
  if (matches !== 1) fail(`${label}: expected one anchor, found ${matches}.`);
  return text.replace(marker, `${marker}${addition}`);
}

if (branch() !== expectedBranch) {
  fail(`Wrong branch. Expected ${expectedBranch}, found ${branch()}.`);
}

const indexPath = path.join(repoRoot, 'firebase', 'functions', 'index.js');
const rulesPath = path.join(repoRoot, 'firebase', 'firestore.rules');
const packagePath = path.join(repoRoot, 'firebase', 'functions', 'package.json');
const modulePath = path.join(repoRoot, 'firebase', 'functions', 'dispatch_directory_projection.js');
for (const target of [indexPath, rulesPath, packagePath, modulePath]) {
  if (!fs.existsSync(target)) fail(`Required Phase 4 projection file is missing: ${target}`);
}

let indexSource = fs.readFileSync(indexPath, 'utf8').replace(/\r\n/g, '\n');
let rulesSource = fs.readFileSync(rulesPath, 'utf8').replace(/\r\n/g, '\n');
const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));

const dispatchImport = 'const { createDispatchCommands } = require("./dispatch_commands");';
const projectionImport = '\nconst { createDispatchDirectoryProjection } = require("./dispatch_directory_projection");';
indexSource = insertAfterOnce(
    indexSource,
    dispatchImport,
    projectionImport,
    'Directory projection import',
);

const dispatchInstance = 'const dispatchCommands = createDispatchCommands(admin);';
const projectionInstance = '\nconst dispatchDirectoryProjection = createDispatchDirectoryProjection(admin);';
indexSource = insertAfterOnce(
    indexSource,
    dispatchInstance,
    projectionInstance,
    'Directory projection instance',
);

const triggerAnchor = 'const wantedMatching = createWantedMatching(admin);';
const triggerBlock = `\nexports.syncDispatchDirectoryFromPublicProfile = onDocumentWritten(\n  {\n    document: "public_business_profiles/{companyId}",\n    retry: true,\n  },\n  async (event) => dispatchDirectoryProjection.syncCompany(event.params.companyId),\n);\nexports.syncDispatchDirectoryFromCarrierStatus = onDocumentWritten(\n  {\n    document: "dispatch_carriers/{companyId}",\n    retry: true,\n  },\n  async (event) => dispatchDirectoryProjection.syncCompany(event.params.companyId),\n);`;
indexSource = insertAfterOnce(
    indexSource,
    triggerAnchor,
    triggerBlock,
    'Directory projection triggers',
);

if (!rulesSource.includes('match /dispatch_directory_entries/{companyId}')) {
  const nextBlock = '    match /public_seller_profiles/{sellerId} {';
  const nextIndex = rulesSource.indexOf(nextBlock);
  if (nextIndex < 0) fail('Could not locate public_seller_profiles rule boundary.');
  const directoryRules = `    // Directory entries are a server-owned public projection. Providers edit\n    // their bounded business profile; trusted Functions publish the searchable\n    // entry so private contacts, credentials, exact addresses, and Auth IDs\n    // cannot be copied into Directory documents by a client.\n    match /dispatch_directory_entries/{companyId} {\n      allow read: if phase1FeatureEnabled('dispatch') && signedIn();\n      allow create, update, delete: if false;\n    }\n\n`;
  rulesSource = rulesSource.slice(0, nextIndex) + directoryRules + rulesSource.slice(nextIndex);
}

const checkCommand = String(packageJson.scripts && packageJson.scripts.check || '');
if (!checkCommand) fail('firebase/functions package.json is missing scripts.check.');
if (!checkCommand.includes('node --check dispatch_directory_projection.js')) {
  const marker = 'node --check dispatch_commands.js';
  if (!checkCommand.includes(marker)) fail('Could not locate dispatch_commands syntax-check anchor.');
  packageJson.scripts.check = checkCommand.replace(
      marker,
      `${marker} && node --check dispatch_directory_projection.js`,
  );
}

const requiredIndexMarkers = [
  'createDispatchDirectoryProjection',
  'const dispatchDirectoryProjection = createDispatchDirectoryProjection(admin);',
  'public_business_profiles/{companyId}',
  'dispatch_carriers/{companyId}',
  'dispatchDirectoryProjection.syncCompany(event.params.companyId)',
];
for (const marker of requiredIndexMarkers) {
  if (!indexSource.includes(marker)) fail(`Transformed Functions index is missing: ${marker}`);
}
for (const marker of [
  'match /dispatch_directory_entries/{companyId}',
  "allow read: if phase1FeatureEnabled('dispatch') && signedIn();",
  'allow create, update, delete: if false;',
]) {
  if (!rulesSource.includes(marker)) fail(`Transformed Firestore rules are missing: ${marker}`);
}
if (!packageJson.scripts.check.includes('node --check dispatch_directory_projection.js')) {
  fail('Transformed Functions syntax gate does not include directory projection.');
}

const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const backupDir = path.join(repoRoot, '_local_backups', `dispatch-phase4-directory-projection-${stamp}`);
fs.mkdirSync(backupDir, {recursive: true});
for (const target of [indexPath, rulesPath, packagePath]) {
  fs.copyFileSync(target, path.join(backupDir, path.basename(target)));
}

fs.writeFileSync(indexPath, indexSource, 'utf8');
fs.writeFileSync(rulesPath, rulesSource, 'utf8');
fs.writeFileSync(packagePath, `${JSON.stringify(packageJson, null, 2)}\n`, 'utf8');

console.log(`Backup created: ${backupDir}`);
console.log('DISPATCH PHASE 4 DIRECTORY PROJECTION SOURCE READY');
console.log('Server-owned projection module: INSTALLED');
console.log('Public profile trigger: INSTALLED');
console.log('Authoritative carrier-status trigger: INSTALLED');
console.log('Directory client writes: BLOCKED');
console.log('Dispatch tracker modified by installer: NO');
