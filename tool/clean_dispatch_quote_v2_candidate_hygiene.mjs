import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const candidateDashboard = path.join(
  repoRoot,
  'lib',
  'marketplace',
  'pipebuyer_dispatch_dashboard_quote_v2_preflight.dart',
);

function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function nextTopLevelDeclaration(source, from) {
  const markers = [
    '\nclass ',
    '\nenum ',
    '\nmixin ',
    '\nextension ',
    '\ntypedef ',
  ];
  let next = -1;
  for (const marker of markers) {
    const index = source.indexOf(marker, from);
    if (index >= 0 && (next < 0 || index < next)) next = index + 1;
  }
  return next < 0 ? source.length : next;
}

function removeUnreferencedTopLevelClass(source, className) {
  const marker = `class ${className}`;
  const classIndex = source.indexOf(marker);
  if (classIndex < 0) {
    return {source, removed: false};
  }
  if (source.indexOf(marker, classIndex + marker.length) >= 0) {
    fail(`${className} is declared more than once in the candidate.`);
  }

  const lineStart = source.lastIndexOf('\n', classIndex) + 1;
  const classEnd = nextTopLevelDeclaration(source, classIndex + marker.length);
  const outside = source.slice(0, lineStart) + source.slice(classEnd);
  if (outside.includes(className)) {
    fail(`${className} is still referenced outside its declaration; refusing to prune it.`);
  }

  const cleaned = `${source.slice(0, lineStart).trimEnd()}\n\n${source
    .slice(classEnd)
    .replace(/^\s+/, '')}`;
  return {source: cleaned, removed: true};
}

if (!fs.existsSync(candidateDashboard)) {
  fail('Quote V2 candidate dashboard is missing. Build the candidate before hygiene cleanup.');
}

let source = fs.readFileSync(candidateDashboard, 'utf8').replace(/\r\n/g, '\n');
if (source.includes('class _DispatchQuoteDialog extends StatefulWidget')) {
  fail('Retired Dashboard quote editor still exists before candidate hygiene cleanup.');
}

const result = removeUnreferencedTopLevelClass(
  source,
  '_DispatchUnitRequirementDraft',
);
source = result.source;

if (source.includes('class _DispatchUnitRequirementDraft')) {
  fail('Unreferenced _DispatchUnitRequirementDraft remains after cleanup.');
}

fs.writeFileSync(candidateDashboard, source, 'utf8');

console.log('PIPE BUYER QUOTE V2 CANDIDATE HYGIENE CLEANUP PASSED');
console.log(
  `Unreferenced _DispatchUnitRequirementDraft removed: ${result.removed ? 'YES' : 'NOT PRESENT'}`,
);
console.log('Production source modified by hygiene cleanup: NO');
