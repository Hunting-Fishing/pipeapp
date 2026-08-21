import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const candidates = [
  {
    label: 'Dashboard',
    filePath: path.join(
      repoRoot,
      'lib',
      'marketplace',
      'pipebuyer_dispatch_dashboard_quote_v2_preflight.dart',
    ),
  },
  {
    label: 'Jobs page',
    filePath: path.join(
      repoRoot,
      'lib',
      'marketplace',
      'pipebuyer_dispatch_page_quote_v2_preflight.dart',
    ),
  },
];

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

function lineBounds(source, lineNumber) {
  const lines = source.split('\n');
  const index = lineNumber - 1;
  if (!Number.isInteger(lineNumber) || index < 0 || index >= lines.length) {
    fail(`Analyzer line ${lineNumber} is outside the candidate source.`);
  }
  let start = 0;
  for (let i = 0; i < index; i += 1) start += lines[i].length + 1;
  return {line: lines[index], start, lines, index};
}

function normalizeGap(source, start, end) {
  let suffixStart = end;
  while (source[suffixStart] === '\r' || source[suffixStart] === '\n') {
    suffixStart += 1;
  }
  return `${source.slice(0, start).trimEnd()}\n\n${source.slice(suffixStart)}`;
}

function removeUnusedImport(source, lineNumber) {
  const {line, lines, index} = lineBounds(source, lineNumber);
  if (!/^\s*import\s+["'][^"']+["'];\s*$/.test(line)) {
    fail(`Analyzer identified a non-plain import for cleanup: ${line}`);
  }
  lines.splice(index, 1);
  return {source: lines.join('\n'), description: line.trim()};
}

function removeTopLevelClassLike(source, symbol, lineNumber) {
  const {line, start} = lineBounds(source, lineNumber);
  if (/^\s/.test(line)) fail(`${symbol} is not top-level; refusing cleanup.`);
  if (!/^(?:class|enum|mixin|extension)\b/.test(line.trim())) {
    fail(`${symbol} is not a supported class-like declaration.`);
  }
  const occurrences = countSymbol(source, symbol);
  if (occurrences !== 1) {
    fail(`${symbol} still has ${Math.max(0, occurrences - 1)} reference(s); refusing cleanup.`);
  }
  const openBrace = source.indexOf('{', start);
  if (openBrace < 0) fail(`Could not locate the body for ${symbol}.`);
  const end = scanBalancedBlockEnd(source, openBrace);
  if (end < 0) fail(`Could not determine the end of ${symbol}.`);
  return normalizeGap(source, start, end);
}

function removeTopLevelValue(source, symbol, lineNumber) {
  const {line, start} = lineBounds(source, lineNumber);
  if (/^\s/.test(line)) fail(`${symbol} is not top-level; refusing cleanup.`);
  if (!/^(?:const|final)\b/.test(line.trim())) {
    fail(`${symbol} is not a supported top-level value declaration.`);
  }
  const occurrences = countSymbol(source, symbol);
  if (occurrences !== 1) {
    fail(`${symbol} still has ${Math.max(0, occurrences - 1)} reference(s); refusing cleanup.`);
  }
  const end = findTopLevelValueEnd(source, start);
  if (end < 0) fail(`Could not determine the end of ${symbol}.`);
  return normalizeGap(source, start, end);
}

function removeTopLevelFunction(source, symbol, lineNumber) {
  const {line, start} = lineBounds(source, lineNumber);
  if (/^\s/.test(line)) fail(`${symbol} is not top-level; refusing cleanup.`);
  const occurrences = countSymbol(source, symbol);
  if (occurrences !== 1) {
    fail(`${symbol} still has ${Math.max(0, occurrences - 1)} reference(s); refusing cleanup.`);
  }
  const openBrace = source.indexOf('{', start);
  if (openBrace < 0) fail(`Could not locate a bounded function body for ${symbol}.`);
  const end = scanBalancedBlockEnd(source, openBrace);
  if (end < 0) fail(`Could not determine the end of ${symbol}.`);
  return normalizeGap(source, start, end);
}

function runMachineAnalyzer(filePath) {
  // Important Windows rule: analyze a path relative to cwd. The repository lives
  // under "D:\\Game Development", and passing the absolute path through a shell
  // splits it at the space before Dart ever sees the candidate file.
  const relativePath = path.relative(repoRoot, filePath);
  const result = spawnSync('dart', ['analyze', '--format=machine', relativePath], {
    cwd: repoRoot,
    encoding: 'utf8',
    shell: process.platform === 'win32',
  });
  if (result.error) fail(`Could not start Dart analyzer: ${result.error.message}`);
  const rawOutput = `${result.stdout ?? ''}\n${result.stderr ?? ''}`;
  const output = rawOutput
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  const diagnostics = output.filter((line) => /^(INFO|WARNING|ERROR)\|/.test(line));
  if (result.status !== 0 && diagnostics.length === 0) {
    console.error(rawOutput.trim());
    fail(
      `Dart analyzer exited ${result.status} without machine diagnostics for ${relativePath}; refusing to treat analyzer transport failure as a clean candidate.`,
    );
  }
  return diagnostics;
}

function verifyAnalyzerTransport() {
  const probePath = path.join(repoRoot, 'tool', 'pipebuyer_quote_v2_hygiene_probe.dart');
  const probeSource = 'void main() {}\nvoid _pipeBuyerUnusedProbe() {}\n';
  fs.writeFileSync(probePath, probeSource, 'utf8');
  try {
    const diagnostics = runMachineAnalyzer(probePath);
    if (!diagnostics.some((line) => line.includes('|UNUSED_ELEMENT|'))) {
      console.error(diagnostics.join('\n'));
      fail(
        'Quote V2 hygiene analyzer transport probe did not capture the expected UNUSED_ELEMENT diagnostic.',
      );
    }
  } finally {
    fs.rmSync(probePath, {force: true});
  }
  console.log('Quote V2 hygiene analyzer transport through Windows path-with-spaces: PASS');
}

function parseDiagnostic(line) {
  const parts = line.split('|');
  if (parts.length < 8) fail(`Could not parse analyzer diagnostic: ${line}`);
  return {
    raw: line,
    severity: parts[0],
    code: parts[2] ?? '',
    lineNumber: Number(parts[4]),
    message: parts.slice(7).join('|'),
  };
}

function chooseBoundedDiagnostic(source, diagnostics, label) {
  const parsed = diagnostics.map(parseDiagnostic);
  const unsupported = parsed.filter(
    (item) => item.code !== 'UNUSED_IMPORT' && item.code !== 'UNUSED_ELEMENT',
  );
  if (unsupported.length > 0) {
    console.error(`${label} candidate has non-hygiene diagnostics:`);
    for (const item of parsed) console.error(item.raw);
    fail(`${label} candidate has diagnostics other than bounded unused imports/elements.`);
  }

  // Remove the containing top-level declaration before an unused member warning.
  // This prevents a dead class and its dead fromMap method being handled as two
  // unrelated repairs.
  const topLevelElement = parsed.find((item) => {
    if (item.code !== 'UNUSED_ELEMENT') return false;
    const match = item.message.match(/declaration '([^']+)' isn't referenced/);
    if (!match || !match[1].startsWith('_')) return false;
    const {line} = lineBounds(source, item.lineNumber);
    return !/^\s/.test(line);
  });
  if (topLevelElement) {
    const match = topLevelElement.message.match(/declaration '([^']+)' isn't referenced/);
    return {...topLevelElement, symbol: match[1]};
  }

  const importDiagnostic = parsed.find((item) => item.code === 'UNUSED_IMPORT');
  if (importDiagnostic) return importDiagnostic;

  console.error(`${label} candidate has only non-top-level unused elements:`);
  for (const item of parsed) console.error(item.raw);
  fail(`${label} candidate requires a semantic source repair, not automatic hygiene cleanup.`);
}

function cleanupCandidate(filePath, label) {
  if (!fs.existsSync(filePath)) fail(`Quote V2 candidate is missing: ${filePath}`);
  let source = fs.readFileSync(filePath, 'utf8').replace(/\r\n/g, '\n');
  const actions = [];

  if (source.includes('class _DispatchQuoteDialog extends StatefulWidget')) {
    fail(`${label} candidate still contains the retired Dashboard quote editor.`);
  }
  if (source.includes("labelText: 'All-in transport price'")) {
    fail(`${label} candidate still contains the retired Jobs all-in quote editor.`);
  }

  for (let pass = 0; pass < 30; pass += 1) {
    fs.writeFileSync(filePath, source, 'utf8');
    const diagnostics = runMachineAnalyzer(filePath);
    if (diagnostics.length === 0) return {source, actions};

    const selected = chooseBoundedDiagnostic(source, diagnostics, label);
    if (selected.code === 'UNUSED_IMPORT') {
      const result = removeUnusedImport(source, selected.lineNumber);
      source = result.source;
      actions.push(`unused import: ${result.description}`);
      continue;
    }

    const symbol = selected.symbol;
    const {line} = lineBounds(source, selected.lineNumber);
    if (/^(?:class|enum|mixin|extension)\b/.test(line.trim())) {
      source = removeTopLevelClassLike(source, symbol, selected.lineNumber);
    } else if (/^(?:const|final)\b/.test(line.trim())) {
      source = removeTopLevelValue(source, symbol, selected.lineNumber);
    } else {
      source = removeTopLevelFunction(source, symbol, selected.lineNumber);
    }
    actions.push(`unused top-level element: ${symbol}`);
  }

  fail(`${label} candidate hygiene exceeded the bounded cleanup pass limit.`);
}

verifyAnalyzerTransport();

const results = [];
for (const candidate of candidates) {
  const result = cleanupCandidate(candidate.filePath, candidate.label);
  fs.writeFileSync(candidate.filePath, result.source, 'utf8');
  results.push({...candidate, ...result});
}

console.log('PIPE BUYER QUOTE V2 CANDIDATE HYGIENE CLEANUP PASSED');
for (const result of results) {
  if (result.actions.length === 0) {
    console.log(`${result.label} analyzer cleanup: NOT NEEDED`);
  } else {
    for (const action of result.actions) {
      console.log(`${result.label} analyzer cleanup: ${action}`);
    }
  }
  console.log(`${result.label} candidate hygiene analyzer: PASS`);
}
console.log('Production source modified by hygiene cleanup: NO');
