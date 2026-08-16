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

function addVisualSandboxAggregationGuard(exportName, endMarker) {
  const startMarker = `exports.${exportName} = onDocumentCreated`;
  const start = index.indexOf(startMarker);
  if (start < 0) throw new Error(`Could not find ${exportName}.`);
  const end = index.indexOf(endMarker, start);
  if (end < 0) throw new Error(`Could not bound ${exportName}.`);

  const block = index.slice(start, end);
  if (block.includes('if (data.visualSandbox === true) return null;')) return;

  const dataLine = '    const data = event.data.data();\n';
  const dataOffset = block.indexOf(dataLine);
  if (dataOffset < 0) {
    throw new Error(`Could not find event data line in ${exportName}.`);
  }

  const replacement =
    dataLine +
    '    // Visual-sandbox conversations/offers already receive deterministic\n' +
    '    // analytics counters from seed_live_test_listing_analytics.js. Skip\n' +
    '    // asynchronous aggregate increments so fixture verification cannot\n' +
    '    // race delayed emulator onCreate deliveries. Production documents do\n' +
    '    // not carry visualSandbox=true and keep the normal aggregation path.\n' +
    '    if (data.visualSandbox === true) return null;\n';

  const absolute = start + dataOffset;
  index = index.slice(0, absolute) +
    replacement +
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

for (const required of [
  'if (data.visualSandbox === true) return null;',
  "Write-Step 'Re-normalizing deterministic fixtures after Timed Buying smoke cleanup'",
  '& powershell -ExecutionPolicy Bypass -File $reseedHelper\n',
]) {
  const source = required.startsWith('Write-Step') || required.startsWith('& powershell')
    ? acceptance
    : index;
  if (!source.includes(required)) throw new Error(`Missing repair marker: ${required}`);
}

fs.writeFileSync(indexPath, index, 'utf8');
fs.writeFileSync(acceptancePath, acceptance, 'utf8');

console.log('Formal emulator fixture-race repair applied.');
console.log('  - visualSandbox conversation/offer creates no longer race analytics counters');
console.log('  - post-smoke acceptance now re-normalizes the deterministic fixture');
