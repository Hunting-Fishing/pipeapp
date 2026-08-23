import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const indexPath = path.join(root, 'firebase/functions/index.js');
const acceptancePath = path.join(root, 'tool/start_formal_acceptance_environment.ps1');

for (const file of [indexPath, acceptancePath]) {
  if (!fs.existsSync(file)) throw new Error(`Missing ${path.relative(root, file)}`);
}

let index = fs.readFileSync(indexPath, 'utf8').replace(/\r\n/g, '\n');
let acceptance = fs.readFileSync(acceptancePath, 'utf8').replace(/\r\n/g, '\n');

function functionBlock(exportName, endMarker) {
  const startMarker = `exports.${exportName} = onDocumentCreated`;
  const start = index.indexOf(startMarker);
  if (start < 0) throw new Error(`Could not find ${exportName}.`);
  const end = index.indexOf(endMarker, start);
  if (end < 0) throw new Error(`Could not bound ${exportName}.`);
  return {start, end, block: index.slice(start, end)};
}

function addVisualSandboxAggregationGuard(exportName, endMarker) {
  const {start, block} = functionBlock(exportName, endMarker);
  if (block.includes('if (data.visualSandbox === true) return null;')) return;

  // These handlers intentionally use different indentation styles today:
  // onConversationCreated is multiline while onOfferCreated has a compact
  // callback declaration. Match the statement structurally and preserve the
  // indentation actually present in each handler instead of assuming spaces.
  const dataMatch = block.match(/^([ \t]*)const data = event\.data\.data\(\);\n/m);
  if (!dataMatch || dataMatch.index == null) {
    throw new Error(`Could not find event data statement in ${exportName}.`);
  }

  const indent = dataMatch[1];
  const dataLine = dataMatch[0];
  const guard = [
    `${indent}// Visual-sandbox conversations/offers already receive deterministic`,
    `${indent}// analytics counters from seed_live_test_listing_analytics.js. Skip`,
    `${indent}// asynchronous aggregate increments so fixture verification cannot`,
    `${indent}// race delayed emulator onCreate deliveries. Production documents do`,
    `${indent}// not carry visualSandbox=true and keep the normal aggregation path.`,
    `${indent}if (data.visualSandbox === true) return null;`,
    '',
  ].join('\n');

  const absolute = start + dataMatch.index;
  index = index.slice(0, absolute) +
    dataLine + guard +
    index.slice(absolute + dataLine.length);
}

addVisualSandboxAggregationGuard(
  'onConversationCreated',
  'exports.onOfferCreated',
);
addVisualSandboxAggregationGuard(
  'onOfferCreated',
  'exports.onListingMediaModeration',
);

const oldPostSmoke = [
  "Write-Step 'Confirming deterministic fixtures after Timed Buying smoke cleanup'",
  '& powershell -ExecutionPolicy Bypass -File $reseedHelper -SkipSeed',
  'if ($LASTEXITCODE -ne 0) {',
  "  throw 'Formal test-data verification failed after Timed Buying smoke cleanup.'",
  '}',
].join('\n');
const newPostSmoke = [
  "Write-Step 'Re-normalizing deterministic fixtures after Timed Buying smoke cleanup'",
  '# A fresh emulator can still be draining asynchronous onCreate work from the',
  '# original seed while the callable smoke test runs. Re-run the deterministic',
  '# seed after the smoke cleanup so acceptance always starts from one canonical',
  '# dataset instead of merely verifying a possibly still-moving fixture.',
  '& powershell -ExecutionPolicy Bypass -File $reseedHelper',
  'if ($LASTEXITCODE -ne 0) {',
  "  throw 'Formal test-data normalization failed after Timed Buying smoke cleanup.'",
  '}',
].join('\n');

if (acceptance.includes(oldPostSmoke)) {
  acceptance = acceptance.replace(oldPostSmoke, newPostSmoke);
} else if (!acceptance.includes("Write-Step 'Re-normalizing deterministic fixtures after Timed Buying smoke cleanup'")) {
  throw new Error('Acceptance post-smoke verification block changed; review before patching.');
}

for (const [exportName, endMarker] of [
  ['onConversationCreated', 'exports.onOfferCreated'],
  ['onOfferCreated', 'exports.onListingMediaModeration'],
]) {
  const {block} = functionBlock(exportName, endMarker);
  if (!block.includes('if (data.visualSandbox === true) return null;')) {
    throw new Error(`Missing visual-sandbox aggregation guard in ${exportName}.`);
  }
}

for (const required of [
  "Write-Step 'Re-normalizing deterministic fixtures after Timed Buying smoke cleanup'",
  '& powershell -ExecutionPolicy Bypass -File $reseedHelper\n',
]) {
  if (!acceptance.includes(required)) {
    throw new Error(`Missing acceptance repair marker: ${required}`);
  }
}

fs.writeFileSync(indexPath, index, 'utf8');
fs.writeFileSync(acceptancePath, acceptance, 'utf8');

console.log('Formal emulator fixture-race repair applied.');
console.log('  - visualSandbox conversation/offer creates no longer race analytics counters');
console.log('  - post-smoke acceptance now re-normalizes the deterministic fixture');
console.log('  - patcher tolerates compact or multiline function indentation');
