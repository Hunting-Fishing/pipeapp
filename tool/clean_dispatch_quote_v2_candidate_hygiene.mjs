import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const dashboardPath = path.join(
  repoRoot,
  'lib',
  'marketplace',
  'pipebuyer_dispatch_dashboard_quote_v2_preflight.dart',
);
const pagePath = path.join(
  repoRoot,
  'lib',
  'marketplace',
  'pipebuyer_dispatch_page_quote_v2_preflight.dart',
);

function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function countSymbol(source, symbol) {
  return (source.match(new RegExp(`\\b${escapeRegex(symbol)}\\b`, 'g')) || []).length;
}

function scanBalancedBlockEnd(source, openBraceIndex) {
  let depth = 0;
  let quote = null;
  let triple = false;
  let escaped = false;
  let lineComment = false;
  let blockComment = false;

  for (let index = openBraceIndex; index < source.length; index += 1) {
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

    if (char === '{') depth += 1;
    else if (char === '}') {
      depth -= 1;
      if (depth === 0) return index + 1;
    }
  }
  return -1;
}

function findTopLevelValueEnd(source, start) {
  let paren = 0;
  let bracket = 0;
  let brace = 0;
  let quote = null;
  let escaped = false;

  for (let index = start; index < source.length; index += 1) {
    const char = source[index];
    if (quote !== null) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char === '\\') {
        escaped = true;
        continue;
      }
      if (char === quote) quote = null;
      continue;
    }
    if (char === '"' || char === "'") {
      quote = char;
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

function normalizeGap(source, start, end) {
  let suffixStart = end;
  while (source[suffixStart] === '\r' || source[suffixStart] === '\n') {
    suffixStart += 1;
  }
  return `${source.slice(0, start).trimEnd()}\n\n${source.slice(suffixStart)}`;
}

function removeTopLevelClassIfExternallyUnreferenced(source, className) {
  const marker = `class ${className}`;
  const classIndex = source.indexOf(marker);
  if (classIndex < 0) return {source, removed: false};
  if (source.indexOf(marker, classIndex + marker.length) >= 0) {
    fail(`${className} is declared more than once in the candidate.`);
  }

  const start = source.lastIndexOf('\n', classIndex) + 1;
  const openBrace = source.indexOf('{', classIndex + marker.length);
  if (openBrace < 0) fail(`Could not locate ${className} body.`);
  const end = scanBalancedBlockEnd(source, openBrace);
  if (end < 0) fail(`Could not determine ${className} body end.`);

  const outside = `${source.slice(0, start)}${source.slice(end)}`;
  const externalReferences = countSymbol(outside, className);
  if (externalReferences !== 0) {
    fail(`${className} still has ${externalReferences} external reference(s); refusing cleanup.`);
  }

  return {source: normalizeGap(source, start, end), removed: true};
}

function removeTopLevelValueIfUnreferenced(source, symbol) {
  const occurrences = countSymbol(source, symbol);
  if (occurrences === 0) return {source, removed: false};
  if (occurrences !== 1) return {source, removed: false};

  const symbolIndex = source.indexOf(symbol);
  const start = source.lastIndexOf('\n', symbolIndex) + 1;
  const lineEnd = source.indexOf('\n', symbolIndex);
  const line = source.slice(start, lineEnd < 0 ? source.length : lineEnd).trim();
  if (!/^(?:const|final)\b/.test(line)) {
    fail(`${symbol} is not a bounded top-level const/final declaration.`);
  }
  const end = findTopLevelValueEnd(source, start);
  if (end < 0) fail(`Could not determine ${symbol} declaration end.`);
  return {source: normalizeGap(source, start, end), removed: true};
}

function removeTopLevelFunctionIfUnreferenced(source, symbol) {
  const occurrences = countSymbol(source, symbol);
  if (occurrences === 0) return {source, removed: false};
  if (occurrences !== 1) return {source, removed: false};

  const symbolIndex = source.indexOf(symbol);
  const start = source.lastIndexOf('\n', symbolIndex) + 1;
  const declarationLineEnd = source.indexOf('\n', symbolIndex);
  const declarationLine = source.slice(start, declarationLineEnd < 0 ? source.length : declarationLineEnd);
  if (/^\s/.test(declarationLine)) {
    fail(`${symbol} is not top-level; refusing cleanup.`);
  }

  const arrow = source.indexOf('=>', symbolIndex);
  const openBrace = source.indexOf('{', symbolIndex);
  if (arrow >= 0 && (openBrace < 0 || arrow < openBrace)) {
    const end = findTopLevelValueEnd(source, start);
    if (end < 0) fail(`Could not determine arrow-function end for ${symbol}.`);
    return {source: normalizeGap(source, start, end), removed: true};
  }
  if (openBrace < 0) fail(`Could not locate function body for ${symbol}.`);
  const end = scanBalancedBlockEnd(source, openBrace);
  if (end < 0) fail(`Could not determine function body end for ${symbol}.`);
  return {source: normalizeGap(source, start, end), removed: true};
}

function removePlainImportIfNoConsumer(source, importPath, consumerToken) {
  const importPattern = new RegExp(`^\\s*import\\s+['\"]${escapeRegex(importPath)}['\"];\\s*$`, 'm');
  const match = source.match(importPattern);
  if (!match) return {source, removed: false};

  const withoutImport = source.replace(importPattern, '');
  if (consumerToken && withoutImport.includes(consumerToken)) {
    fail(`Import ${importPath} still has consumer token ${consumerToken}; refusing cleanup.`);
  }
  return {source: withoutImport.replace(/^\s*\n/, ''), removed: true};
}

function replaceRequiredImport(source, before, after, label) {
  if (source.includes(after)) {
    if (source.includes(before)) {
      fail(`${label} contains both isolated and canonical imports.`);
    }
    return source;
  }
  const count = source.split(before).length - 1;
  if (count !== 1) {
    fail(`${label} expected exactly one isolated import but found ${count}.`);
  }
  return source.replace(before, after);
}

for (const filePath of [dashboardPath, pagePath]) {
  if (!fs.existsSync(filePath)) fail(`Quote V2 candidate is missing: ${filePath}`);
}

let dashboard = fs.readFileSync(dashboardPath, 'utf8').replace(/\r\n/g, '\n');
let page = fs.readFileSync(pagePath, 'utf8').replace(/\r\n/g, '\n');

if (dashboard.includes('class _DispatchQuoteDialog extends StatefulWidget')) {
  fail('Retired Dashboard Quote V1 editor still exists in the transformed candidate.');
}
if (page.includes("labelText: 'All-in transport price'")) {
  fail('Retired Jobs all-in quote editor still exists in the transformed candidate.');
}

const draft = removeTopLevelClassIfExternallyUnreferenced(
  dashboard,
  '_DispatchUnitRequirementDraft',
);
dashboard = draft.source;

const unitTypes = removeTopLevelValueIfUnreferenced(
  dashboard,
  '_dispatchQuoteUnitTypes',
);
dashboard = unitTypes.source;

const locationImport = removePlainImportIfNoConsumer(
  dashboard,
  'marketplace_location.dart',
  'MarketplaceLocation',
);
dashboard = locationImport.source;

const vehicleIcon = removeTopLevelFunctionIfUnreferenced(
  page,
  '_vehicleTypeFallbackIcon',
);
page = vehicleIcon.source;

// Candidate builder isolates renamed preflight files from live production by
// rewriting their imports to preflight filenames. V5 later places these files
// under canonical filenames in a mirror, and production promotion also writes
// them under canonical filenames. Normalize those import identities now so the
// candidate being mirror-tested has the same Dart library identities as the
// candidate that will be promoted.
dashboard = replaceRequiredImport(
  dashboard,
  "import 'pipebuyer_dispatch_repository_quote_v2_preflight.dart';",
  "import 'marketplace_dispatch_repository.dart';",
  'Dashboard repository import',
);
page = replaceRequiredImport(
  page,
  "import 'pipebuyer_dispatch_repository_quote_v2_preflight.dart';",
  "import 'marketplace_dispatch_repository.dart';",
  'Jobs repository import',
);
page = replaceRequiredImport(
  page,
  "import 'pipebuyer_dispatch_dashboard_quote_v2_preflight.dart';",
  "import 'marketplace_dispatch_dashboard.dart';",
  'Jobs Dashboard import',
);

if (dashboard.includes('pipebuyer_dispatch_repository_quote_v2_preflight.dart') ||
    page.includes('pipebuyer_dispatch_repository_quote_v2_preflight.dart') ||
    page.includes('pipebuyer_dispatch_dashboard_quote_v2_preflight.dart')) {
  fail('Preflight-only Dart import identity remains after canonicalization.');
}

fs.writeFileSync(dashboardPath, dashboard, 'utf8');
fs.writeFileSync(pagePath, page, 'utf8');

console.log('PIPE BUYER QUOTE V2 DETERMINISTIC CANDIDATE HYGIENE PASSED');
console.log(`Dashboard dead _DispatchUnitRequirementDraft removed: ${draft.removed ? 'YES' : 'NOT PRESENT'}`);
console.log(`Dashboard cascading _dispatchQuoteUnitTypes removed: ${unitTypes.removed ? 'YES' : 'NOT PRESENT / STILL REFERENCED'}`);
console.log(`Dashboard unused marketplace_location.dart import removed: ${locationImport.removed ? 'YES' : 'NOT PRESENT'}`);
console.log(`Jobs dead _vehicleTypeFallbackIcon removed: ${vehicleIcon.removed ? 'YES' : 'NOT PRESENT / STILL REFERENCED'}`);
console.log('Candidate Dart imports normalized to production canonical identities: YES');
console.log('Analyzer mutation inside hygiene helper: NO');
console.log('Production source modified by hygiene helper: NO');
console.log('Next authority: V5 canonical-mirror strict flutter analyze on the complete candidate graph.');