function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function matches(text, regex) {
  const flags = regex.flags.includes('g') ? regex.flags : `${regex.flags}g`;
  return [...text.matchAll(new RegExp(regex.source, flags))];
}

const fieldLine = '  MarketplaceDispatchDirectoryRepository? _repository;';
const initAssignment = '    _repository = widget.repository;';
const lazyRepositoryPattern =
  /final\s+repository\s*=\s*_repository\s*\?\?=\s*MarketplaceDispatchDirectoryRepository\s*\(\s*\)\s*;/m;

function normalizeField(source) {
  const patterns = [
    /^[ \t]*late[ \t]+final[ \t]+MarketplaceDispatchDirectoryRepository[ \t]+_repository[ \t]*;[ \t]*$/gm,
    /^[ \t]*(?:(?:late[ \t]+final|late|final)[ \t]+)?MarketplaceDispatchDirectoryRepository\?[ \t]+_repository[ \t]*;[ \t]*$/gm,
  ];
  const hits = patterns.flatMap((pattern) => matches(source, pattern));
  if (hits.length !== 1) {
    fail(`Expected exactly one Directory repository state field, found ${hits.length}. No guessing.`);
  }
  return source.replace(hits[0][0], fieldLine);
}

function normalizeInitState(source) {
  const initMatch = source.match(/@override\s+void\s+initState\s*\(\s*\)\s*\{/m);
  if (!initMatch || initMatch.index == null) {
    fail('Directory initState method was not found.');
  }
  const initStart = initMatch.index;
  const suffix = source.slice(initStart);
  const loadMatch = suffix.match(/\n[ \t]*Future<DispatchDirectoryPageData>\s+_load\s*\(\s*\)\s*\{/m);
  if (!loadMatch || loadMatch.index == null) {
    fail('Directory _load method boundary was not found after initState.');
  }
  const initEnd = initStart + loadMatch.index;
  let segment = source.slice(initStart, initEnd);

  const assignments = [...segment.matchAll(/_repository\s*=\s*[^;]+;/g)];
  if (assignments.length > 1) {
    fail(`Expected at most one repository assignment in initState, found ${assignments.length}. No guessing.`);
  }
  if (assignments.length === 1) {
    segment = segment.replace(/^[ \t]*_repository\s*=\s*[^;]+;/m, initAssignment);
  } else {
    const superCalls = [...segment.matchAll(/super\.initState\s*\(\s*\)\s*;/g)];
    if (superCalls.length !== 1) {
      fail(`Repository assignment is missing and initState has ${superCalls.length} super.initState calls. No guessing.`);
    }
    segment = segment.replace(
      /super\.initState\s*\(\s*\)\s*;/,
      `super.initState();\n${initAssignment}`,
    );
  }

  return source.slice(0, initStart) + segment + source.slice(initEnd);
}

function normalizeLoadCall(source) {
  if (
    lazyRepositoryPattern.test(source) &&
    /repository\.loadPage\s*\(/m.test(source) &&
    !/_repository\.loadPage\s*\(/m.test(source)
  ) {
    return source;
  }

  const callPattern = /^([ \t]*)(request\s*=\s*|return\s+)_repository\.loadPage\s*\(/gm;
  const calls = [...source.matchAll(callPattern)];
  if (calls.length !== 1) {
    fail(`Expected exactly one direct _repository.loadPage call, found ${calls.length}. No guessing.`);
  }
  const [, indent, prefix] = calls[0];
  const replacement =
    `${indent}final repository =\n` +
    `${indent}    _repository ??= MarketplaceDispatchDirectoryRepository();\n` +
    `${indent}${prefix}repository.loadPage(`;
  return source.replace(callPattern, replacement);
}

function validate(source) {
  const fields = matches(
    source,
    /^[ \t]*MarketplaceDispatchDirectoryRepository\?[ \t]+_repository[ \t]*;[ \t]*$/m,
  );
  if (fields.length !== 1) {
    fail(`Expected exactly one lazy nullable Directory repository field, found ${fields.length}.`);
  }

  if (!/\b_repository\s*=\s*widget\.repository\s*;/m.test(source)) {
    fail('Directory initState does not preserve only the injected repository.');
  }
  if (/widget\.repository\s*\?\?\s*MarketplaceDispatchDirectoryRepository\s*\(/m.test(source)) {
    fail('Directory initState still eagerly creates FirebaseFirestore-backed repository state.');
  }
  if (/_repository\.loadPage\s*\(/m.test(source)) {
    fail('Direct nullable _repository.loadPage invocation is still present.');
  }
  if (!lazyRepositoryPattern.test(source)) {
    fail('Directory live repository is not lazily created after the seeded-data branch.');
  }
  if (!/repository\.loadPage\s*\(/m.test(source)) {
    fail('Directory live repository loadPage call is missing.');
  }

  const loadMatch = source.match(/Future<DispatchDirectoryPageData>\s+_load\s*\(\s*\)\s*\{/m);
  if (!loadMatch || loadMatch.index == null) {
    fail('Directory _load method start could not be validated.');
  }
  const loadStart = loadMatch.index;
  const suffix = source.slice(loadStart);
  const disposeMatch = suffix.match(/\n[ \t]*@override\s+void\s+dispose\s*\(\s*\)\s*\{/m);
  if (!disposeMatch || disposeMatch.index == null) {
    fail('Directory _load method end could not be validated.');
  }
  const load = suffix.slice(0, disposeMatch.index);
  const seedIndex = load.indexOf('final seed = widget.seedEntries;');
  const seedBranchIndex = load.indexOf('if (seed != null)');
  const repositoryConstructionIndex = load.indexOf('MarketplaceDispatchDirectoryRepository()');
  if (seedIndex < 0 || seedBranchIndex < seedIndex || repositoryConstructionIndex < seedBranchIndex) {
    fail('Directory repository construction is not safely deferred until after the seedEntries branch.');
  }

  if (!source.includes("_firestore.collection('dispatch_directory_entries')")) {
    fail('Accepted server-owned Dispatch Directory query layer is missing.');
  }
}

export function normalizeDirectorySeedSafeRepository(input) {
  let source = input.replace(/\r\n/g, '\n');

  if (!source.includes('class MarketplaceDispatchDirectoryPage extends StatefulWidget')) {
    fail('Dispatch Directory page was not found.');
  }
  if (!source.includes("_firestore.collection('dispatch_directory_entries')")) {
    fail('Accepted server-owned Directory projection query is not installed.');
  }

  source = normalizeField(source);
  source = normalizeInitState(source);
  source = normalizeLoadCall(source);
  validate(source);
  return source;
}
