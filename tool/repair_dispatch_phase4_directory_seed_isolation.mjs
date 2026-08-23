import fs from 'node:fs';
import path from 'node:path';

const repoRoot = process.cwd();
const target = path.join(
  repoRoot,
  'lib',
  'marketplace',
  'marketplace_dispatch_directory.dart',
);

if (!fs.existsSync(target)) {
  throw new Error(`Directory source is missing: ${target}`);
}

let source = fs.readFileSync(target, 'utf8');

const fixedMarkers = [
  'late final MarketplaceDispatchDirectoryRepository? _repository;',
  'widget.seedEntries == null',
  "throw StateError('Directory repository is unavailable outside seed mode.');",
];

if (fixedMarkers.every((marker) => source.includes(marker))) {
  console.log('Dispatch Phase 4 Directory seed isolation already applied.');
  process.exit(0);
}

const oldField =
  '  late final MarketplaceDispatchDirectoryRepository _repository;';
const newField =
  '  late final MarketplaceDispatchDirectoryRepository? _repository;';

const oldInit = `    _repository = widget.repository ?? MarketplaceDispatchDirectoryRepository();\n    _loadFuture = _load();`;
const newInit = `    _repository = widget.seedEntries == null\n        ? widget.repository ?? MarketplaceDispatchDirectoryRepository()\n        : widget.repository;\n    _loadFuture = _load();`;

const oldLoad = `    return _repository.loadPage();`;
const newLoad = `    final repository = _repository;\n    if (repository == null) {\n      throw StateError('Directory repository is unavailable outside seed mode.');\n    }\n    return repository.loadPage();`;

for (const [label, oldText] of [
  ['repository field', oldField],
  ['repository initialization', oldInit],
  ['repository load', oldLoad],
]) {
  const count = source.split(oldText).length - 1;
  if (count !== 1) {
    throw new Error(
      `Expected exactly one ${label} repair target, found ${count}. Stop instead of guessing.`,
    );
  }
}

source = source.replace(oldField, newField);
source = source.replace(oldInit, newInit);
source = source.replace(oldLoad, newLoad);

for (const marker of fixedMarkers) {
  if (!source.includes(marker)) {
    throw new Error(`Repair marker missing after update: ${marker}`);
  }
}

fs.writeFileSync(target, source, 'utf8');
console.log('Dispatch Phase 4 Directory seed isolation applied.');
