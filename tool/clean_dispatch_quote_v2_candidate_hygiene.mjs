import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const candidateDashboard = path.join(
  repoRoot,
  'lib',
  'marketplace',
  'pipebuyer_dispatch_dashboard_quote_v2_preflight.dart',
);
const candidatePage = path.join(
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

function nextTopLevelDeclaration(source, from) {
  const markers = [
    '\nclass ',
    '\nenum ',
    '\nmixin ',
    '\nextension ',
    '\ntypedef ',
    '\nconst ',
    '\nfinal ',
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
  if (classIndex < 0) return {source, removed: false};
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
      } else if (char === quote) quote = null;
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
    else if (char === ';' && paren === 0 && bracket === 0 && brace === 0) return index + 1;
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
  const declarationLine = source.slice(lineStart, lineEnd < 0 ? source.length : lineEnd);
  if (/^\s/.test(declarationLine) || !/^(?:const|final)\b/.test(declarationLine.trim())) {
    fail(`${symbol} is not a bounded top-level const/final declaration.`);
  }
  const declarationEnd = findTopLevelValueEnd(source, lineStart);
  if (declarationEnd < 0 || declarationEnd <= symbolIndex) fail(`Could not determine the end of ${symbol}.`);
  let suffixStart = declarationEnd;
  while (source[suffixStart] === '\r' || source[suffixStart] === '\n') suffixStart += 1;
  return {
    source: `${source.slice(0, lineStart).trimEnd()}\n\n${source.slice(suffixStart)}`,
    removed: true,
  };
}

function removeUnreferencedTopLevelFunction(source, symbol) {
  const occurrences = countSymbol(source, symbol);
  if (occurrences === 0) return {source, removed: false};
  if (occurrences !== 1) {
    fail(`${symbol} still has ${occurrences - 1} reference(s); refusing to prune it.`);
  }
  const symbolIndex = source.indexOf(symbol);
  const lineStart = source.lastIndexOf('\n', symbolIndex) + 1;
  const lineEnd = source.indexOf('\n', symbolIndex);
  const declarationLine = source.slice(lineStart, lineEnd < 0 ? source.length : lineEnd);
  if (/^\s/.test(declarationLine)) fail(`${symbol} is not top-level; refusing to prune it.`);
  const openBrace = source.indexOf('{', symbolIndex);
  if (openBrace < 0 || (lineEnd >= 0 && openBrace > lineEnd + 300)) {
    fail(`Could not locate a bounded function body for ${symbol}.`);
  }
  const end = scanBalancedBlockEnd(source, openBrace);
  if (end < 0) fail(`Could not determine the end of ${symbol}.`);
  let suffixStart = end;
  while (source[suffixStart] === '\r' || source[suffixStart] === '\n') suffixStart += 1;
  return {
    source: `${source.slice(0, lineStart).trimEnd()}\n\n${source.slice(suffixStart)}`,
    removed: true,
  };
}

function runMachineAnalyzer(filePath) {
  const result = spawnSync('dart', ['analyze', '--format=machine', filePath], {
    cwd: repoRoot,
    encoding: 'utf8',
    shell: process.platform === 'win32',
  });
  const output = `${result.stdout ?? ''}\n${result.stderr ?? ''}`
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  return output.filter((line) => /^(INFO|WARNING|ERROR)\|/.test(line));
}

function removeAnalyzerUnusedImport(source, diagnostic) {
  const parts = diagnostic.split('|');
  if (parts.length < 8) fail(`Could not parse analyzer diagnostic: ${diagnostic}`);
  const lineNumber = Number(parts[4]);
  const lines = source.split('\n');
  const index = lineNumber - 1;
  if (!Number.isInteger(lineNumber) || index < 0 || index >= lines.length) {
    fail(`Analyzer unused-import line is outside candidate source: ${diagnostic}`);
  }
  const importLine = lines[index];
  if (!/^\s*import\s+["'][^"']+["'];\s*$/.test(importLine)) {
    fail(`Analyzer identified a non-plain import for cleanup: ${importLine}`);
  }
  lines.splice(index, 1);
  return {source: lines.join('\n'), description: importLine.trim()};
}

function cleanupAnalyzerDeadCode(filePath, label) {
  let source = fs.readFileSync(filePath, 'utf8').replace(/\r\n/g, '\n');
  const actions = [];

  for (let pass = 0; pass < 12; pass += 1) {
    fs.writeFileSync(filePath, source, 'utf8');
    const diagnostics = runMachineAnalyzer(filePath);
    if (diagnostics.length === 0) return {source, actions};

    const unsupported = diagnostics.filter((line) => {
      const code = line.split('|')[2] ?? '';
      return code !== 'UNUSED_IMPORT' && code !== 'UNUSED_ELEMENT';
    });
    if (unsupported.length > 0) {
      console.error(`${label} candidate has non-hygiene diagnostics:`);
      for (const line of diagnostics) console.error(line);
      fail(`${label} candidate has diagnostics other than bounded unused imports/elements.`);
    }

    const diagnostic = diagnostics[0];
    const parts = diagnostic.split('|');
    const code = parts[2] ?? '';
    if (code === 'UNUSED_IMPORT') {
      const result = removeAnalyzerUnusedImport(source, diagnostic);
      source = result.source;
      actions.push(`unused import: ${result.description}`);
      continue;
    }

    const message = parts.slice(7).join('|');
    const match = message.match(/declaration '([^']+)' isn't referenced/);
    if (!match) {
      console.error(diagnostic);
      fail(`${label} UNUSED_ELEMENT diagnostic did not identify a declaration.`);
    }
    const symbol = match[1];
    if (!symbol.startsWith('_')) {
      console.error(diagnostic);
      fail(`${label} analyzer identified a non-private unused element; refusing cleanup.`);
    }
    const lineNumber = Number(parts[4]);
    const lines = source.split('\n');
    const declarationLine = lines[lineNumber - 1] ?? '';
    if (/^\s/.test(declarationLine)) {
      console.error(diagnostic);
      fail(`${label} unused element ${symbol} is not top-level; refusing cleanup.`);
    }

    let result;
    if (/^(?:class|enum|mixin|extension)\b/.test(declarationLine.trim())) {
      result = removeUnreferencedTopLevelClass(source, symbol);
    } else if (/^(?:const|final)\b/.test(declarationLine.trim())) {
      result = removeUnreferencedTopLevelValue(source, symbol);
    } else {
      result = removeUnreferencedTopLevelFunction(source, symbol);
    }
    if (!result.removed) fail(`${label} analyzer identified ${symbol}, but bounded cleanup did not remove it.`);
    source = result.source;
    actions.push(`unused top-level element: ${symbol}`);
  }

  fail(`${label} candidate hygiene exceeded the bounded cleanup pass limit.`);
}

for (const filePath of [candidateDashboard, candidatePage]) {
  if (!fs.existsSync(filePath)) fail(`Quote V2 candidate is missing: ${filePath}`);
}

let dashboardSource = fs.readFileSync(candidateDashboard, 'utf8').replace(/\r\n/g, '\n');
if (dashboardSource.includes('class _DispatchQuoteDialog extends StatefulWidget')) {
  fail('Retired Dashboard quote editor still exists before candidate hygiene cleanup.');
}

const draftResult = removeUnreferencedTopLevelClass(
  dashboardSource,
  '_DispatchUnitRequirementDraft',
);
dashboardSource = draftResult.source;
const unitTypesResult = removeUnreferencedTopLevelValue(
  dashboardSource,
  '_dispatchQuoteUnitTypes',
);
dashboardSource = unitTypesResult.source;
fs.writeFileSync(candidateDashboard, dashboardSource, 'utf8');

let pageSource = fs.readFileSync(candidatePage, 'utf8').replace(/\r\n/g, '\n');
const vehicleIconResult = removeUnreferencedTopLevelFunction(
  pageSource,
  '_vehicleTypeFallbackIcon',
);
pageSource = vehicleIconResult.source;
fs.writeFileSync(candidatePage, pageSource, 'utf8');

const dashboardAnalyzer = cleanupAnalyzerDeadCode(candidateDashboard, 'Dashboard');
fs.writeFileSync(candidateDashboard, dashboardAnalyzer.source, 'utf8');
const pageAnalyzer = cleanupAnalyzerDeadCode(candidatePage, 'Jobs page');
fs.writeFileSync(candidatePage, pageAnalyzer.source, 'utf8');

console.log('PIPE BUYER QUOTE V2 CANDIDATE HYGIENE CLEANUP PASSED');
console.log(`Unreferenced _DispatchUnitRequirementDraft removed: ${draftResult.removed ? 'YES' : 'NOT PRESENT'}`);
console.log(`Cascading _dispatchQuoteUnitTypes removed: ${unitTypesResult.removed ? 'YES' : 'NOT PRESENT'}`);
console.log(`Legacy _vehicleTypeFallbackIcon removed after bid-form replacement: ${vehicleIconResult.removed ? 'YES' : 'NOT PRESENT'}`);
for (const action of dashboardAnalyzer.actions) console.log(`Dashboard analyzer cleanup: ${action}`);
for (const action of pageAnalyzer.actions) console.log(`Jobs analyzer cleanup: ${action}`);
console.log('Dashboard candidate hygiene analyzer: PASS');
console.log('Jobs candidate hygiene analyzer: PASS');
console.log('Production source modified by hygiene cleanup: NO');
