function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function countLiteral(text, marker) {
  return text.split(marker).length - 1;
}

function replaceLiteralExactlyOne(text, before, after, label) {
  const count = countLiteral(text, before);
  if (count !== 1) {
    fail(`${label}: expected exactly one source target, found ${count}.`);
  }
  return text.replace(before, after);
}

function replaceBetween(text, startMarker, endMarker, replacement, label) {
  const startCount = countLiteral(text, startMarker);
  if (startCount !== 1) {
    fail(`${label}: expected exactly one start marker, found ${startCount}.`);
  }
  const start = text.indexOf(startMarker);
  const end = text.indexOf(endMarker, start + startMarker.length);
  if (end < 0) fail(`${label}: end marker was not found.`);
  return text.slice(0, start) + replacement + text.slice(end);
}

function replaceRegexExactlyOne(text, regex, replacement, label) {
  const flags = regex.flags.includes('g') ? regex.flags : `${regex.flags}g`;
  const global = new RegExp(regex.source, flags);
  const matches = [...text.matchAll(global)];
  if (matches.length !== 1) {
    fail(`${label}: expected exactly one semantic source target, found ${matches.length}.`);
  }
  return text.replace(regex, replacement);
}

function validate(source) {
  const required = [
    "import 'dart:async';",
    'DispatchDirectoryPageData? _lastSuccessfulData;',
    'Timer? _filterDebounce;',
    'int _loadGeneration = 0;',
    'final generation = ++_loadGeneration;',
    'initialData: _lastSuccessfulData,',
    'final retainedData = snapshot.data ?? _lastSuccessfulData;',
    'retainedData == null',
    "Timer(const Duration(milliseconds: 180), () {",
    "'Updating Directory results...'",
    "'Could not refresh these filters. Showing the last loaded Directory results.'",
    'class _DirectoryRefreshWarning extends StatelessWidget',
    "_firestore.collection('dispatch_directory_entries')",
  ];
  for (const marker of required) {
    if (!source.includes(marker)) {
      fail(`Runtime-stability transform is missing semantic marker: ${marker}`);
    }
  }

  if (!/if\s*\(\s*snapshot\.connectionState\s*==\s*ConnectionState\.waiting\s*&&\s*retainedData\s*==\s*null\s*\)/m.test(source)) {
    fail('Initial Directory loading is not guarded by retained data.');
  }
  if (!/if\s*\(\s*snapshot\.hasError\s*&&\s*retainedData\s*==\s*null\s*\)/m.test(source)) {
    fail('Directory fatal error state is not guarded by retained data.');
  }
  if (!/final\s+allEntries\s*=\s*retainedData\?\.entries\s*\?\?\s*const\s*<DispatchDirectoryEntry>\[\]\s*;/m.test(source)) {
    fail('Directory visible results are not sourced from retained data.');
  }
  if (!/_filterDebounce\?\.cancel\(\)[\s\S]*?_filterDebounce\s*=\s*Timer\(const Duration\(milliseconds:\s*180\)/m.test(source)) {
    fail('Directory filter debounce lifecycle is incomplete.');
  }
  if (!/_filters\s*=\s*value\s*;[\s\S]*?_loadGeneration\+\+/m.test(source)) {
    fail('Changing filters does not invalidate an older in-flight Directory refresh.');
  }

  const oldBlankLoading = /if\s*\(\s*snapshot\.connectionState\s*==\s*ConnectionState\.waiting\s*\)\s*\{\s*return\s+const\s+Center\s*\(\s*child:\s*CircularProgressIndicator\(\)\s*\)\s*;/m;
  if (oldBlankLoading.test(source)) {
    fail('Legacy full-page loading replacement is still present.');
  }

  // Only reject the old immediate assignment in the same filter-state block.
  // A delayed `_loadFuture = _load()` inside the debounce Timer is required.
  const synchronousFilterReload = /_filters\s*=\s*value\s*;\s*_loadFuture\s*=\s*_load\(\)\s*;/m;
  if (synchronousFilterReload.test(source)) {
    fail('Filter controls still replace the Directory future synchronously.');
  }
}

export function stabilizeDirectoryFilterRuntime(input) {
  let source = input.replace(/\r\n/g, '\n');

  if (!source.includes("_firestore.collection('dispatch_directory_entries')")) {
    fail('Server-owned Dispatch Directory projection query is not installed.');
  }
  if (!source.includes('class MarketplaceDispatchDirectoryPage extends StatefulWidget')) {
    fail('Dispatch Directory page state was not found.');
  }

  // Idempotent continuation: if the retained-results state already exists,
  // validate the complete contract instead of applying another mutation.
  if (source.includes('DispatchDirectoryPageData? _lastSuccessfulData;')) {
    validate(source);
    return source;
  }

  if (!source.includes("import 'dart:async';")) {
    source = "import 'dart:async';\n\n" + source;
  }

  source = replaceLiteralExactlyOne(
    source,
    '  late Future<DispatchDirectoryPageData> _loadFuture;\n',
    '  late Future<DispatchDirectoryPageData> _loadFuture;\n' +
      '  DispatchDirectoryPageData? _lastSuccessfulData;\n' +
      '  Timer? _filterDebounce;\n' +
      '  int _loadGeneration = 0;\n',
    'Directory retained-results state',
  );

  source = replaceBetween(
    source,
    '  Future<DispatchDirectoryPageData> _load() {',
    '  @override\n  void dispose() {',
    `  Future<DispatchDirectoryPageData> _load() {\n    final generation = ++_loadGeneration;\n    final seed = widget.seedEntries;\n    final Future<DispatchDirectoryPageData> request;\n    if (seed != null) {\n      request = Future.value(\n        DispatchDirectoryPageData(\n          entries: seed,\n          cursor: null,\n          hasMore: false,\n        ),\n      );\n    } else {\n      request = _repository.loadPage(filters: _filters);\n    }\n    return request.then((data) {\n      if (generation == _loadGeneration) {\n        _lastSuccessfulData = data;\n      }\n      return data;\n    });\n  }\n\n`,
    'Directory generation-aware load lifecycle',
  );

  source = replaceBetween(
    source,
    '  @override\n  void dispose() {',
    '  @override\n  Widget build(BuildContext context) {',
    `  @override\n  void dispose() {\n    _filterDebounce?.cancel();\n    _search.dispose();\n    super.dispose();\n  }\n\n  void _reload() {\n    _filterDebounce?.cancel();\n    setState(() => _loadFuture = _load());\n  }\n\n  void _setFilters(DispatchDirectoryFilters value) {\n    setState(() {\n      _filters = value;\n      _loadGeneration++;\n    });\n    _filterDebounce?.cancel();\n    _filterDebounce = Timer(const Duration(milliseconds: 180), () {\n      if (!mounted) return;\n      setState(() => _loadFuture = _load());\n    });\n  }\n\n  void _clearFilters() {\n    _search.clear();\n    _setFilters(const DispatchDirectoryFilters());\n  }\n\n`,
    'Directory filter refresh lifecycle',
  );

  if (!source.includes('initialData: _lastSuccessfulData,')) {
    source = replaceRegexExactlyOne(
      source,
      /(FutureBuilder<DispatchDirectoryPageData>\(\s*\n\s*future:\s*_loadFuture,)/m,
      `$1\n      initialData: _lastSuccessfulData,`,
      'Directory retained FutureBuilder initial data',
    );
  }

  if (!source.includes('final retainedData = snapshot.data ?? _lastSuccessfulData;')) {
    source = replaceRegexExactlyOne(
      source,
      /(builder:\s*\(context,\s*snapshot\)\s*\{)\s*\n\s*if\s*\(\s*snapshot\.connectionState\s*==\s*ConnectionState\.waiting\s*\)\s*\{/m,
      `$1\n        final retainedData = snapshot.data ?? _lastSuccessfulData;\n        if (snapshot.connectionState == ConnectionState.waiting &&\n            retainedData == null) {`,
      'Directory non-blank FutureBuilder loading lifecycle',
    );
  }

  source = replaceRegexExactlyOne(
    source,
    /if\s*\(\s*snapshot\.hasError\s*\)\s*\{/m,
    'if (snapshot.hasError && retainedData == null) {',
    'Directory retained FutureBuilder error lifecycle',
  );

  source = replaceRegexExactlyOne(
    source,
    /final\s+allEntries\s*=\s*snapshot\.data\?\.entries\s*\?\?\s*const\s*<DispatchDirectoryEntry>\[\]\s*;/m,
    `final allEntries =\n            retainedData?.entries ?? const <DispatchDirectoryEntry>[];`,
    'Directory retained result source',
  );

  if (!source.includes("'Updating Directory results...'")) {
    const resultHeaderPattern = /(\s+_DirectoryFilterCard\(\s*searchController:\s*_search,\s*filters:\s*_filters,\s*onChanged:\s*_setFilters,\s*onClear:\s*_clearFilters,\s*\),)\s*const SizedBox\(height:\s*14\),\s*Row\(/m;
    const inlineStatus = `$1\n            if (snapshot.connectionState == ConnectionState.waiting &&\n                retainedData != null) ...[\n              const SizedBox(height: 8),\n              const Row(\n                children: [\n                  SizedBox(\n                    width: 16,\n                    height: 16,\n                    child: CircularProgressIndicator(strokeWidth: 2),\n                  ),\n                  SizedBox(width: 8),\n                  Text(\n                    'Updating Directory results...',\n                    style: TextStyle(\n                      color: PipeBuyerColors.muted,\n                      fontWeight: FontWeight.w700,\n                    ),\n                  ),\n                ],\n              ),\n            ],\n            if (snapshot.hasError && retainedData != null) ...[\n              const SizedBox(height: 8),\n              _DirectoryRefreshWarning(onRetry: _reload),\n            ],\n            const SizedBox(height: 14),\n            Row(`;
    source = replaceRegexExactlyOne(
      source,
      resultHeaderPattern,
      inlineStatus,
      'Directory inline refresh state before result header',
    );
  }

  const warningWidget = `\nclass _DirectoryRefreshWarning extends StatelessWidget {\n  const _DirectoryRefreshWarning({required this.onRetry});\n\n  final VoidCallback onRetry;\n\n  @override\n  Widget build(BuildContext context) => Container(\n        padding: const EdgeInsets.all(12),\n        decoration: BoxDecoration(\n          color: const Color(0xFFFFF4E8),\n          borderRadius: BorderRadius.circular(12),\n          border: Border.all(color: const Color(0xFFFFD2A8)),\n        ),\n        child: Row(\n          children: [\n            const Icon(\n              Icons.sync_problem_outlined,\n              color: PipeBuyerColors.orange,\n            ),\n            const SizedBox(width: 10),\n            const Expanded(\n              child: Text(\n                'Could not refresh these filters. Showing the last loaded Directory results.',\n                style: TextStyle(fontWeight: FontWeight.w700),\n              ),\n            ),\n            TextButton(onPressed: onRetry, child: const Text('Retry')),\n          ],\n        ),\n      );\n}\n`;
  if (!source.includes('class _DirectoryRefreshWarning extends StatelessWidget')) {
    source = replaceLiteralExactlyOne(
      source,
      '\nclass _DirectoryEmptyState extends StatelessWidget {',
      warningWidget + '\nclass _DirectoryEmptyState extends StatelessWidget {',
      'Directory inline refresh warning widget',
    );
  }

  validate(source);
  return source;
}
