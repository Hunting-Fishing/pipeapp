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

function countSymbol(source, symbol) {
  const escaped = symbol.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return (source.match(new RegExp(`\\b${escaped}\\b`, 'g')) || []).length;
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

function findTopLevelValueEnd(source, start) {
  let paren = 0;
  let bracket = 0;
  let brace = 0;
  let quote = null;
  let triple = false;
  let escaped = false;
  let lineComment = false;
  let blockComment = false;

  for (let index = start; index < source.length; index += 1) {
    const char = source[index];
    const next = source[index + 1] ?? '';
    const next2 = source[index + 2] ?? '';

    if (lineComment) {
      if (char === '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (char === '*' && next === '/') {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote !== null) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char === '\\') {
        escaped = true;
        continue;
      }
      if (triple) {
        if (char === quote && next === quote && next2 === quote) {
          quote = null;
          triple = false;
          index += 2;
        }
      } else if (char === quote) {
        quote = null;
      }
      continue;
    }

    if (char === '/' && next === '/') {
      lineComment = true;
      index += 1;
      continue;
    }
    if (char === '/' && next === '*') {
      blockComment = true;
      index += 1;
      continue;
    }
    if (char === '"' || char === "'") {
      quote = char;
      if (next === char && next2 === char) {
        triple = true;
        index += 2;
      }
      continue;
    }

    if (char === '(') paren += 1;
    else if (char === ')') paren -= 1;
    else if (char === '[') bracket += 1;
    else if (char === ']') bracket -= 1;
    else if (char === '{') brace += 1;
    else if (char === '}') brace -= 1;
    else if (char === ';' && paren === 0 && bracket === 0 && brace === 0) {
      return index + 1;
    }
  }
  return -1;
}

function removeUnreferencedTopLevelValue(source, symbol) {
  const occurrences = countSymbol(source, symbol);
  if (occurrences === 0) return {source, removed: false};
  if (occurrences !== 1) {
    fail(`${symbol} still has ${occurrences - 1} reference(s); refusing to prune it.`);
  }

  const symbolIndex = source.indexOf(symbol);
  const lineStart = source.lastIndexOf('\n', symbolIndex) + 1;
  const lineEnd = source.indexOf('\n', symbolIndex);
  const declarationLine = source.slice(
    lineStart,
    lineEnd < 0 ? source.length : lineEnd,
  );
  if (/^\s/.test(declarationLine)) {
    fail(`${symbol} is not a top-level declaration; refusing to prune it.`);
  }
  if (!/^(?:const|final)\b/.test(declarationLine.trim())) {
    fail(`${symbol} is not a bounded const/final top-level declaration.`);
  }

  const declarationEnd = findTopLevelValueEnd(source, lineStart);
  if (declarationEnd < 0 || declarationEnd <= symbolIndex) {
    fail(`Could not determine the end of ${symbol}.`);
  }

  let suffixStart = declarationEnd;
  while (source[suffixStart] === '\r' || source[suffixStart] === '\n') {
    suffixStart += 1;
  }
  const cleaned = `${source.slice(0, lineStart).trimEnd()}\n\n${source.slice(suffixStart)}`;
  return {source: cleaned, removed: true};
}

if (!fs.existsSync(candidateDashboard)) {
  fail('Quote V2 candidate dashboard is missing. Build the candidate before hygiene cleanup.');
}

let source = fs.readFileSync(candidateDashboard, 'utf8').replace(/\r\n/g, '\n');
if (source.includes('class _DispatchQuoteDialog extends StatefulWidget')) {
  fail('Retired Dashboard quote editor still exists before candidate hygiene cleanup.');
}

// Remove the dead unit-requirement class first. This can expose supporting
// top-level constants as newly unreferenced, so the cleanup is intentionally
// dependency-ordered rather than a one-symbol patch.
const draftResult = removeUnreferencedTopLevelClass(
  source,
  '_DispatchUnitRequirementDraft',
);
source = draftResult.source;

const unitTypesResult = removeUnreferencedTopLevelValue(
  source,
  '_dispatchQuoteUnitTypes',
);
source = unitTypesResult.source;

if (source.includes('class _DispatchUnitRequirementDraft')) {
  fail('Unreferenced _DispatchUnitRequirementDraft remains after cleanup.');
}
if (countSymbol(source, '_dispatchQuoteUnitTypes') !== 0) {
  fail('Unreferenced _dispatchQuoteUnitTypes remains after cleanup.');
}

fs.writeFileSync(candidateDashboard, source, 'utf8');

console.log('PIPE BUYER QUOTE V2 CANDIDATE HYGIENE CLEANUP PASSED');
console.log(
  `Unreferenced _DispatchUnitRequirementDraft removed: ${draftResult.removed ? 'YES' : 'NOT PRESENT'}`,
);
console.log(
  `Cascading _dispatchQuoteUnitTypes removed: ${unitTypesResult.removed ? 'YES' : 'NOT PRESENT'}`,
);
console.log('Production source modified by hygiene cleanup: NO');
