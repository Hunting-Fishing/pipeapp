function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function matches(text, regex) {
  const flags = regex.flags.includes('g') ? regex.flags : `${regex.flags}g`;
  return [...text.matchAll(new RegExp(regex.source, flags))];
}

function validate(source) {
  const nonNullable = matches(
    source,
    /^\s*late\s+final\s+MarketplaceDispatchDirectoryRepository\s+_repository\s*;\s*$/m,
  );
  if (nonNullable.length !== 1) {
    fail(`Expected exactly one non-null Directory repository field, found ${nonNullable.length}.`);
  }

  if (!/\b_repository\s*=\s*widget\.repository\s*\?\?\s*MarketplaceDispatchDirectoryRepository\s*\(\s*\)\s*;/m.test(source)) {
    fail('Directory repository is not initialized deterministically in initState.');
  }

  if (!/_repository\.loadPage\s*\(/m.test(source)) {
    fail('Directory repository loadPage call was not found.');
  }

  if (/MarketplaceDispatchDirectoryRepository\?\s+_repository\s*;/m.test(source)) {
    fail('Nullable Directory repository declaration is still present.');
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
  if (alreadyCorrect.length === 1) {
    validate(source);
    return source;
  }
  if (alreadyCorrect.length > 1) {
    fail(`Multiple non-null Directory repository declarations were found: ${alreadyCorrect.length}.`);
  }

  const nullablePattern = /^([ \t]*)(?:(?:late\s+final|late|final)\s+)?MarketplaceDispatchDirectoryRepository\?\s+_repository\s*;\s*$/gm;
  const nullable = [...source.matchAll(nullablePattern)];
  if (nullable.length !== 1) {
    fail(`Expected exactly one nullable Directory repository declaration, found ${nullable.length}. No guessing.`);
  }

  source = source.replace(
    nullablePattern,
    '$1late final MarketplaceDispatchDirectoryRepository _repository;',
  );

  validate(source);
  return source;
}
