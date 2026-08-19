function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function matches(text, regex) {
  const flags = regex.flags.includes('g') ? regex.flags : `${regex.flags}g`;
  return [...text.matchAll(new RegExp(regex.source, flags))];
}

const canonicalAssignment =
    '_repository = widget.repository ?? MarketplaceDispatchDirectoryRepository();';

function normalizeInitStateAssignment(source) {
  const initMatches = matches(
    source,
    /@override\s+void\s+initState\s*\(\s*\)\s*\{/m,
  );
  if (initMatches.length !== 1) {
    fail(`Expected exactly one Directory initState method, found ${initMatches.length}. No guessing.`);
  }

  const initStart = initMatches[0].index;
  const loadBoundary = /\n\s*Future<DispatchDirectoryPageData>\s+_load\s*\(\s*\)\s*\{/m;
  const suffix = source.slice(initStart);
  const loadMatch = suffix.match(loadBoundary);
  if (!loadMatch || loadMatch.index == null) {
    fail('Could not find the Directory _load method boundary after initState.');
  }

  const initEnd = initStart + loadMatch.index;
  let initSegment = source.slice(initStart, initEnd);
  const assignments = [...initSegment.matchAll(/_repository\s*=\s*[^;]+;/g)];

  if (assignments.length > 1) {
    fail(`Expected at most one repository assignment inside initState, found ${assignments.length}. No guessing.`);
  }

  if (assignments.length === 1) {
    initSegment = initSegment.replace(
      /_repository\s*=\s*[^;]+;/,
      canonicalAssignment,
    );
  } else {
    const superMatches = [...initSegment.matchAll(/super\.initState\s*\(\s*\)\s*;/g)];
    if (superMatches.length !== 1) {
      fail(`Repository assignment is missing and initState has ${superMatches.length} super.initState calls. No guessing.`);
    }
    initSegment = initSegment.replace(
      /super\.initState\s*\(\s*\)\s*;/,
      `super.initState();\n    ${canonicalAssignment}`,
    );
  }

  return source.slice(0, initStart) + initSegment + source.slice(initEnd);
}

function validate(source) {
  const nonNullable = matches(
    source,
    /^\s*late\s+final\s+MarketplaceDispatchDirectoryRepository\s+_repository\s*;\s*$/m,
  );
  if (nonNullable.length !== 1) {
    fail(`Expected exactly one non-null Directory repository field, found ${nonNullable.length}.`);
  }

  const assignmentPattern =
      /\b_repository\s*=\s*widget\.repository\s*\?\?\s*MarketplaceDispatchDirectoryRepository\s*\(\s*\)\s*;/m;
  if (!assignmentPattern.test(source)) {
    fail('Directory repository is not initialized deterministically in initState.');
  }

  if (!/_repository\.loadPage\s*\(/m.test(source)) {
    fail('Directory repository loadPage call was not found.');
  }

  if (/MarketplaceDispatchDirectoryRepository\?\s+_repository\s*;/m.test(source)) {
    fail('Nullable Directory repository declaration is still present.');
  }

  const initStart = source.search(/@override\s+void\s+initState\s*\(\s*\)\s*\{/m);
  const assignmentIndex = source.indexOf(canonicalAssignment, initStart);
  const firstLoadIndex = source.indexOf('_loadFuture = _load();', initStart);
  if (initStart < 0 || assignmentIndex < initStart || firstLoadIndex < 0) {
    fail('Directory initState repository/load lifecycle could not be validated.');
  }
  if (assignmentIndex > firstLoadIndex) {
    fail('Directory repository is initialized after the first Directory load starts.');
  }
}

export function normalizeDirectoryRepositoryNullability(input) {
  let source = input.replace(/\r\n/g, '\n');

  if (!source.includes('class MarketplaceDispatchDirectoryPage extends StatefulWidget')) {
    fail('Dispatch Directory page was not found.');
  }
  if (!source.includes("_firestore.collection('dispatch_directory_entries')")) {
    fail('Accepted server-owned Directory projection query is not installed.');
  }

  const alreadyCorrect = matches(
    source,
    /^\s*late\s+final\s+MarketplaceDispatchDirectoryRepository\s+_repository\s*;\s*$/m,
  );
  if (alreadyCorrect.length > 1) {
    fail(`Multiple non-null Directory repository declarations were found: ${alreadyCorrect.length}.`);
  }

  if (alreadyCorrect.length === 0) {
    const nullablePattern = /^([ \t]*)(?:(?:late\s+final|late|final)\s+)?MarketplaceDispatchDirectoryRepository\?\s+_repository\s*;\s*$/gm;
    const nullable = [...source.matchAll(nullablePattern)];
    if (nullable.length !== 1) {
      fail(`Expected exactly one nullable Directory repository declaration, found ${nullable.length}. No guessing.`);
    }

    source = source.replace(
      nullablePattern,
      '$1late final MarketplaceDispatchDirectoryRepository _repository;',
    );
  }

  // Normalize the whole invariant, not only the field declaration. Earlier
  // local source variants could have a nullable/partial initState assignment;
  // the repair must make the field and initialization agree before validation.
  source = normalizeInitStateAssignment(source);

  validate(source);
  return source;
}
