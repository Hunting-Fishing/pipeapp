import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const expectedBranch = 'design/formal-beautification-foundation';

function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function branch() {
  return execFileSync('git', ['branch', '--show-current'], {
    cwd: repoRoot,
    encoding: 'utf8',
  }).trim();
}

function replaceExactlyOne(text, before, after, label) {
  const count = text.split(before).length - 1;
  if (count !== 1) fail(`${label}: expected exactly one source target, found ${count}.`);
  return text.replace(before, after);
}

if (branch() !== expectedBranch) {
  fail(`Wrong branch. Expected ${expectedBranch}, found ${branch()}.`);
}

const directoryPath = path.join(
    repoRoot,
    'lib',
    'marketplace',
    'marketplace_dispatch_directory.dart',
);
const navigationPath = path.join(
    repoRoot,
    'lib',
    'marketplace',
    'marketplace_dispatch_navigation.dart',
);
const launcherPath = path.join(repoRoot, 'tool', 'start_formal_acceptance_environment.ps1');

for (const target of [directoryPath, navigationPath, launcherPath]) {
  if (!fs.existsSync(target)) fail(`Required Phase 4 source is missing: ${target}`);
}

let directory = fs.readFileSync(directoryPath, 'utf8').replace(/\r\n/g, '\n');
let navigation = fs.readFileSync(navigationPath, 'utf8').replace(/\r\n/g, '\n');
let launcher = fs.readFileSync(launcherPath, 'utf8').replace(/\r\n/g, '\n');

const projectionFactory = `  factory DispatchDirectoryEntry.fromDirectoryProjection(\n    String id,\n    Map<String, dynamic> data,\n  ) {\n    final publicLocation = _map(data['publicLocation']);\n    final serviceCodes = data['serviceCodes'] is Iterable\n        ? (data['serviceCodes'] as Iterable)\n            .map((value) => '$value'.trim())\n            .where((value) => value.isNotEmpty)\n            .toSet()\n            .toList()\n        : <String>[];\n    serviceCodes.sort();\n    final point = data['mapPoint'];\n\n    return DispatchDirectoryEntry(\n      id: id,\n      operatingName: _firstText([data['companyName'], data['operatingName']]),\n      description: '\${data['publicSummary'] ?? ''}'.trim(),\n      website: '\${data['website'] ?? ''}'.trim(),\n      businessTypeCode: '\${data['businessType'] ?? ''}'.trim(),\n      serviceCodes: serviceCodes,\n      serviceAreaLabel: '\${data['serviceAreaSummary'] ?? ''}'.trim(),\n      availabilityCode: '\${data['availability'] ?? ''}'.trim(),\n      emergencyCallout: data['emergencyCallout'] == true,\n      remoteSiteCapable: data['remoteSiteCapable'] == true,\n      homeBaseLabel: '\${publicLocation['label'] ?? ''}'.trim(),\n      homeBasePoint: point is GeoPoint ? point : null,\n    );\n  }\n\n`;

if (!directory.includes('factory DispatchDirectoryEntry.fromDirectoryProjection(')) {
  const legacyFactory = '  factory DispatchDirectoryEntry.fromPublicBusinessProfile(\n';
  if (!directory.includes(legacyFactory)) {
    fail('Directory projection parser anchor was not found.');
  }
  directory = directory.replace(legacyFactory, projectionFactory + legacyFactory);
}

const oldLoadSignature = `  Future<DispatchDirectoryPageData> loadPage({\n    QueryDocumentSnapshot<Map<String, dynamic>>? after,\n    int pageSize = 60,\n  }) async {\n    final page = await loadFirestoreDocumentPage(\n      _firestore.collection('public_business_profiles'),\n      after: after,\n      pageSize: pageSize,\n    );\n    final entries = page.documents\n        .map(\n          (document) => DispatchDirectoryEntry.fromPublicBusinessProfile(\n            document.id,\n            document.data(),\n          ),\n        )\n        .where((entry) => entry.isDirectoryReady)\n        .toList(growable: false);\n    return DispatchDirectoryPageData(\n      entries: entries,\n      cursor: page.cursor,\n      hasMore: page.hasMore,\n    );\n  }`;
const newLoadSignature = `  Future<DispatchDirectoryPageData> loadPage({\n    DispatchDirectoryFilters filters = const DispatchDirectoryFilters(),\n    QueryDocumentSnapshot<Map<String, dynamic>>? after,\n    int pageSize = 60,\n  }) async {\n    Query<Map<String, dynamic>> query =\n        _firestore.collection('dispatch_directory_entries');\n    final searchTerms = filters.searchText\n        .trim()\n        .toLowerCase()\n        .split(RegExp(r'[^a-z0-9]+'))\n        .where((value) => value.length >= 2)\n        .toList();\n\n    if (filters.serviceCode.isNotEmpty) {\n      query = query.where('serviceCodes', arrayContains: filters.serviceCode);\n    } else if (searchTerms.isNotEmpty) {\n      query = query.where('searchTokens', arrayContains: searchTerms.first);\n    } else if (filters.availabilityCode.isNotEmpty) {\n      query = query.where('availability', isEqualTo: filters.availabilityCode);\n    } else if (filters.businessTypeCode.isNotEmpty) {\n      query = query.where('businessType', isEqualTo: filters.businessTypeCode);\n    }\n\n    final page = await loadFirestoreDocumentPage(\n      query,\n      after: after,\n      pageSize: pageSize,\n    );\n    final entries = page.documents\n        .map(\n          (document) => DispatchDirectoryEntry.fromDirectoryProjection(\n            document.id,\n            document.data(),\n          ),\n        )\n        .where((entry) => entry.isDirectoryReady && entry.matches(filters))\n        .toList()\n      ..sort((left, right) => left.operatingName\n          .toLowerCase()\n          .compareTo(right.operatingName.toLowerCase()));\n    return DispatchDirectoryPageData(\n      entries: entries,\n      cursor: page.cursor,\n      hasMore: page.hasMore,\n    );\n  }`;

if (!directory.includes("_firestore.collection('dispatch_directory_entries')")) {
  directory = replaceExactlyOne(
      directory,
      oldLoadSignature,
      newLoadSignature,
      'server-owned Directory repository/query layer',
  );
}

directory = directory.replace(
    `    return _repository.loadPage();`,
    `    return _repository.loadPage(filters: _filters);`,
);
directory = directory.replace(
    `  void _setFilters(DispatchDirectoryFilters value) =>\n      setState(() => _filters = value);`,
    `  void _setFilters(DispatchDirectoryFilters value) {\n    setState(() {\n      _filters = value;\n      _loadFuture = _load();\n    });\n  }`,
);
directory = directory.replace(
    'This first Directory slice uses only public company profile data.',
    'Results come from the server-owned Dispatch Directory projection, which excludes private contacts, exact addresses, credentials and account-only data.',
);
directory = directory.replace(
    'No private provider data is used by this Directory view.',
    'Only the bounded server-owned Directory projection is read by this view.',
);
directory = directory.replace(
    'Provider profiles become eligible after they contain an operating name, at least one structured service, and a service area.',
    'Active, Directory-ready provider profiles will appear here after the server projection publishes them.',
);

const oldImport = "import 'marketplace_dispatch_service_taxonomy.dart';";
const newImport = "import 'marketplace_dispatch_directory.dart';";
if (!navigation.includes(newImport)) {
  navigation = replaceExactlyOne(
      navigation,
      oldImport,
      newImport,
      'Directory navigation import',
  );
}

const foundationStart = navigation.indexOf(
    'class MarketplaceDispatchDirectoryFoundation extends StatelessWidget {',
);
if (foundationStart < 0) fail('Directory foundation class boundary was not found.');
const prefix = navigation.slice(0, foundationStart);
const existingFoundation = navigation.slice(foundationStart);
if (!existingFoundation.includes('MarketplaceDispatchDirectoryPage(')) {
  navigation = `${prefix}class MarketplaceDispatchDirectoryFoundation extends StatelessWidget {\n  const MarketplaceDispatchDirectoryFoundation({\n    super.key,\n    required this.accountState,\n    this.legacyProviderTools,\n  });\n\n  final DispatchAccountState accountState;\n  final Widget? legacyProviderTools;\n\n  @override\n  Widget build(BuildContext context) => MarketplaceDispatchDirectoryPage(\n        key: ValueKey(accountState.providerStatusLabel),\n        legacyProviderTools: legacyProviderTools,\n      );\n}\n`;
}

const directorySeedDeclaration =
    "$directorySeed = Join-Path $repoRoot 'firebase\\functions\\scripts\\seed_dispatch_directory_visual.js'";
if (!launcher.includes(directorySeedDeclaration)) {
  launcher = replaceExactlyOne(
      launcher,
      "$timedBuyingSmoke = Join-Path $repoRoot 'firebase\\functions\\integration\\timed_buying_sandbox.mjs'",
      "$timedBuyingSmoke = Join-Path $repoRoot 'firebase\\functions\\integration\\timed_buying_sandbox.mjs'\n$directorySeed = Join-Path $repoRoot 'firebase\\functions\\scripts\\seed_dispatch_directory_visual.js'",
      'Directory visual seed declaration',
  );
  launcher = replaceExactlyOne(
      launcher,
      "if (-not (Test-Path $timedBuyingSmoke)) {\n  throw 'Timed Buying sandbox callable smoke test is missing.'\n}",
      "if (-not (Test-Path $timedBuyingSmoke)) {\n  throw 'Timed Buying sandbox callable smoke test is missing.'\n}\nif (-not (Test-Path $directorySeed)) {\n  throw 'Dispatch Directory visual seed is missing.'\n}",
      'Directory visual seed existence check',
  );
  launcher = replaceExactlyOne(
      launcher,
      "Write-Step 'Running seller listing analytics function contracts'",
      "Write-Step 'Seeding deterministic Dispatch Directory provider fixtures'\n& node $directorySeed\nif ($LASTEXITCODE -ne 0) {\n  throw 'Dispatch Directory visual fixture seed failed.'\n}\n\nWrite-Step 'Running seller listing analytics function contracts'",
      'Directory visual seed execution',
  );
}

for (const marker of [
  'factory DispatchDirectoryEntry.fromDirectoryProjection(',
  "_firestore.collection('dispatch_directory_entries')",
  "query.where('serviceCodes', arrayContains: filters.serviceCode)",
  'entry.matches(filters)',
]) {
  if (!directory.includes(marker)) fail(`Transformed Directory source is missing: ${marker}`);
}
for (const marker of [
  "import 'marketplace_dispatch_directory.dart';",
  'MarketplaceDispatchDirectoryPage(',
]) {
  if (!navigation.includes(marker)) fail(`Transformed navigation is missing: ${marker}`);
}
for (const marker of [
  'seed_dispatch_directory_visual.js',
  'Seeding deterministic Dispatch Directory provider fixtures',
]) {
  if (!launcher.includes(marker)) fail(`Transformed formal launcher is missing: ${marker}`);
}

const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const backupDir = path.join(repoRoot, '_local_backups', `dispatch-phase4-directory-query-ui-${stamp}`);
fs.mkdirSync(backupDir, {recursive: true});
for (const target of [directoryPath, navigationPath, launcherPath]) {
  fs.copyFileSync(target, path.join(backupDir, path.basename(target)));
}

fs.writeFileSync(directoryPath, directory, 'utf8');
fs.writeFileSync(navigationPath, navigation, 'utf8');
fs.writeFileSync(launcherPath, launcher.replace(/\n/g, '\r\n'), 'utf8');

console.log(`Backup created: ${backupDir}`);
console.log('DISPATCH PHASE 4 DIRECTORY QUERY + LIST SOURCE READY');
console.log('Server-owned Directory repository/query layer: INSTALLED');
console.log('Service/availability/business/capability filters: INSTALLED');
console.log('Real provider list cards: INSTALLED');
console.log('Formal Directory visual fixture seed: INSTALLED');
console.log('Dispatch tracker modified by installer: NO');
