function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function replaceExactlyOne(text, before, after, label) {
  const count = text.split(before).length - 1;
  if (count !== 1) fail(`${label}: expected exactly one source target, found ${count}.`);
  return text.replace(before, after);
}

function replaceBetween(text, startMarker, endMarker, replacement, label) {
  const start = text.indexOf(startMarker);
  if (start < 0) fail(`${label}: start marker was not found.`);
  const end = text.indexOf(endMarker, start + startMarker.length);
  if (end < 0) fail(`${label}: end marker was not found.`);
  return text.slice(0, start) + replacement + text.slice(end);
}

function validate(source) {
  const compact = source.replace(/\s+/g, ' ');
  const required = [
    "import 'dart:async';",
    'DispatchDirectoryPageData? _lastSuccessfulData;',
    'Timer? _filterDebounce;',
    'int _loadGeneration = 0;',
    'final generation = ++_loadGeneration;',
    'initialData: _lastSuccessfulData,',
    'final retainedData = snapshot.data ?? _lastSuccessfulData;',
    'snapshot.connectionState == ConnectionState.waiting && retainedData == null',
    'snapshot.hasError && retainedData == null',
    'Timer(const Duration(milliseconds: 180), () {',
    "'Updating Directory results...'",
    "'Could not refresh these filters. Showing the last loaded Directory results.'",
  ];
  for (const marker of required) {
    if (!compact.includes(marker.replace(/\s+/g, ' '))) {
      fail(`Runtime-stability transform is missing: ${marker}`);
    }
  }
  if (compact.includes('_filters = value; _loadFuture = _load();')) {
    fail('Filter controls still replace the Directory future immediately.');
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

  if (source.includes('DispatchDirectoryPageData? _lastSuccessfulData;')) {
    validate(source);
    return source;
  }

  if (!source.startsWith("import 'dart:async';\n")) {
    source = "import 'dart:async';\n\n" + source;
  }

  source = replaceExactlyOne(
    source,
    `  late Future<DispatchDirectoryPageData> _loadFuture;\n  final TextEditingController _search = TextEditingController();`,
    `  late Future<DispatchDirectoryPageData> _loadFuture;\n  DispatchDirectoryPageData? _lastSuccessfulData;\n  Timer? _filterDebounce;\n  int _loadGeneration = 0;\n  final TextEditingController _search = TextEditingController();`,
    'Directory retained-results state',
  );

  source = replaceBetween(
    source,
    `  Future<DispatchDirectoryPageData> _load() {`,
    `  @override\n  void dispose() {`,
    `  Future<DispatchDirectoryPageData> _load() {\n    final generation = ++_loadGeneration;\n    final seed = widget.seedEntries;\n    final Future<DispatchDirectoryPageData> request;\n    if (seed != null) {\n      request = Future.value(\n        DispatchDirectoryPageData(\n          entries: seed,\n          cursor: null,\n          hasMore: false,\n        ),\n      );\n    } else {\n      request = _repository.loadPage(filters: _filters);\n    }\n    return request.then((data) {\n      if (generation == _loadGeneration) {\n        _lastSuccessfulData = data;\n      }\n      return data;\n    });\n  }\n\n`,
    'Directory generation-aware load lifecycle',
  );

  source = replaceBetween(
    source,
    `  @override\n  void dispose() {`,
    `  @override\n  Widget build(BuildContext context) {`,
    `  @override\n  void dispose() {\n    _filterDebounce?.cancel();\n    _search.dispose();\n    super.dispose();\n  }\n\n  void _reload() {\n    _filterDebounce?.cancel();\n    setState(() => _loadFuture = _load());\n  }\n\n  void _setFilters(DispatchDirectoryFilters value) {\n    setState(() => _filters = value);\n    _filterDebounce?.cancel();\n    _filterDebounce = Timer(const Duration(milliseconds: 180), () {\n      if (!mounted) return;\n      setState(() => _loadFuture = _load());\n    });\n  }\n\n  void _clearFilters() {\n    _search.clear();\n    _setFilters(const DispatchDirectoryFilters());\n  }\n\n`,
    'Directory filter refresh lifecycle',
  );

  source = replaceExactlyOne(
    source,
    `    return FutureBuilder<DispatchDirectoryPageData>(\n      future: _loadFuture,\n      builder: (context, snapshot) {\n        if (snapshot.connectionState == ConnectionState.waiting) {\n          return const Center(child: CircularProgressIndicator());\n        }\n        if (snapshot.hasError) {`,
    `    return FutureBuilder<DispatchDirectoryPageData>(\n      future: _loadFuture,\n      initialData: _lastSuccessfulData,\n      builder: (context, snapshot) {\n        final retainedData = snapshot.data ?? _lastSuccessfulData;\n        if (snapshot.connectionState == ConnectionState.waiting &&\n            retainedData == null) {\n          return const Center(child: CircularProgressIndicator());\n        }\n        if (snapshot.hasError && retainedData == null) {`,
    'Directory non-blank FutureBuilder lifecycle',
  );

  source = replaceExactlyOne(
    source,
    `        final allEntries = snapshot.data?.entries ?? const <DispatchDirectoryEntry>[];`,
    `        final allEntries =\n            retainedData?.entries ?? const <DispatchDirectoryEntry>[];`,
    'Directory retained result source',
  );

  source = replaceExactlyOne(
    source,
    `            const SizedBox(height: 14),\n            Row(\n              children: [`,
    `            if (snapshot.connectionState == ConnectionState.waiting &&\n                retainedData != null) ...[\n              const SizedBox(height: 8),\n              const Row(\n                children: [\n                  SizedBox(\n                    width: 16,\n                    height: 16,\n                    child: CircularProgressIndicator(strokeWidth: 2),\n                  ),\n                  SizedBox(width: 8),\n                  Text(\n                    'Updating Directory results...',\n                    style: TextStyle(\n                      color: PipeBuyerColors.muted,\n                      fontWeight: FontWeight.w700,\n                    ),\n                  ),\n                ],\n              ),\n            ],\n            if (snapshot.hasError && retainedData != null) ...[\n              const SizedBox(height: 8),\n              _DirectoryRefreshWarning(onRetry: _reload),\n            ],\n            const SizedBox(height: 14),\n            Row(\n              children: [`,
    'Directory inline refresh state',
  );

  const warningWidget = `\nclass _DirectoryRefreshWarning extends StatelessWidget {\n  const _DirectoryRefreshWarning({required this.onRetry});\n\n  final VoidCallback onRetry;\n\n  @override\n  Widget build(BuildContext context) => Container(\n        padding: const EdgeInsets.all(12),\n        decoration: BoxDecoration(\n          color: const Color(0xFFFFF4E8),\n          borderRadius: BorderRadius.circular(12),\n          border: Border.all(color: const Color(0xFFFFD2A8)),\n        ),\n        child: Row(\n          children: [\n            const Icon(Icons.sync_problem_outlined, color: PipeBuyerColors.orange),\n            const SizedBox(width: 10),\n            const Expanded(\n              child: Text(\n                'Could not refresh these filters. Showing the last loaded Directory results.',\n                style: TextStyle(fontWeight: FontWeight.w700),\n              ),\n            ),\n            TextButton(onPressed: onRetry, child: const Text('Retry')),\n          ],\n        ),\n      );\n}\n`;
  const emptyMarker = '\nclass _DirectoryEmptyState extends StatelessWidget {';
  if (!source.includes('class _DirectoryRefreshWarning extends StatelessWidget')) {
    source = replaceExactlyOne(
      source,
      emptyMarker,
      warningWidget + emptyMarker,
      'Directory inline refresh warning widget',
    );
  }

  validate(source);
  return source;
}
