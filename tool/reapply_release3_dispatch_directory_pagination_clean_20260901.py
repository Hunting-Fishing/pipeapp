from pathlib import Path

DIRECTORY = Path('lib/marketplace/marketplace_dispatch_directory.dart')
TEST = Path('test/marketplace_dispatch_directory_projection_query_test.dart')

source = DIRECTORY.read_text(encoding='utf-8')
old = """class DispatchDirectoryPageData {
  const DispatchDirectoryPageData({
    required this.entries,
    required this.cursor,
    required this.hasMore,
  });

  final List<DispatchDirectoryEntry> entries;
  final QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}
"""
new = """class DispatchDirectoryPageData {
  const DispatchDirectoryPageData({
    required this.entries,
    required this.cursor,
    required this.hasMore,
  });

  final List<DispatchDirectoryEntry> entries;
  final QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  DispatchDirectoryPageData append(DispatchDirectoryPageData nextPage) {
    final entriesById = <String, DispatchDirectoryEntry>{
      for (final entry in entries) entry.id: entry,
      for (final entry in nextPage.entries) entry.id: entry,
    };
    final mergedEntries = entriesById.values.toList()
      ..sort((left, right) => left.operatingName
          .toLowerCase()
          .compareTo(right.operatingName.toLowerCase()));
    return DispatchDirectoryPageData(
      entries: mergedEntries,
      cursor: nextPage.cursor,
      hasMore: nextPage.hasMore,
    );
  }
}
"""
if source.count(old) != 1:
    raise SystemExit(f'page-data anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """  final TextEditingController _search = TextEditingController();
  DispatchDirectoryFilters _filters = const DispatchDirectoryFilters();
"""
new = """  final TextEditingController _search = TextEditingController();
  DispatchDirectoryFilters _filters = const DispatchDirectoryFilters();
  bool _loadingMore = false;
  String? _loadMoreError;
"""
if source.count(old) != 1:
    raise SystemExit(f'state anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """  void _reload() {
    _filterDebounce?.cancel();
    final nextLoad = _load();
    setState(() {
      _loadFuture = nextLoad;
    });
  }

  void _setFilters(DispatchDirectoryFilters value) {
    setState(() {
      _filters = value;
      _loadGeneration++;
    });
"""
new = """  void _reload() {
    _filterDebounce?.cancel();
    final nextLoad = _load();
    setState(() {
      _loadMoreError = null;
      _loadingMore = false;
      _loadFuture = nextLoad;
    });
  }

  Future<void> _loadMore() async {
    final current = _lastSuccessfulData;
    if (_loadingMore ||
        widget.seedEntries != null ||
        current == null ||
        !current.hasMore ||
        current.cursor == null) {
      return;
    }

    final generation = _loadGeneration;
    final repository =
        _repository ??= MarketplaceDispatchDirectoryRepository();
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final nextPage = await repository.loadPage(
        filters: _filters,
        after: current.cursor,
      );
      if (!mounted || generation != _loadGeneration) return;
      final merged = current.append(nextPage);
      setState(() {
        _lastSuccessfulData = merged;
        _loadFuture = Future.value(merged);
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError =
            'Could not load more companies. The companies already shown were kept.';
      });
    }
  }

  void _setFilters(DispatchDirectoryFilters value) {
    setState(() {
      _filters = value;
      _loadGeneration++;
      _loadMoreError = null;
      _loadingMore = false;
    });
"""
if source.count(old) != 1:
    raise SystemExit(f'reload/filter anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """            if (snapshot.data?.hasMore == true) ...[
              const SizedBox(height: 8),
              const Text(
                'More public provider profiles are available. Pagination will be wired into the next Directory data slice.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PipeBuyerColors.muted, fontSize: 12),
              ),
            ],
"""
new = """            if (retainedData?.hasMore == true &&
                widget.seedEntries == null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: _loadingMore
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_outlined),
                  label: Text(
                    _loadingMore
                        ? 'Loading more companies…'
                        : 'Load more companies',
                  ),
                ),
              ),
              if (_loadMoreError != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sync_problem_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _loadMoreError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ],
"""
if source.count(old) != 1:
    raise SystemExit(f'pagination placeholder anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)
DIRECTORY.write_text(source, encoding='utf-8')

test = TEST.read_text(encoding='utf-8')
if not test.startswith("import 'package:cloud_firestore/cloud_firestore.dart';"):
    raise SystemExit('projection test import anchor mismatch')
test = test.replace(
    "import 'package:cloud_firestore/cloud_firestore.dart';\n",
    "import 'dart:io';\n\nimport 'package:cloud_firestore/cloud_firestore.dart';\n",
    1,
)
anchor = """  test('Directory filters preserve structured service and capability matching', () {
"""
insert = """  test('Directory page append deduplicates and keeps alphabetical order', () {
    DispatchDirectoryEntry entry(String id, String name) =>
        DispatchDirectoryEntry.fromDirectoryProjection(id, {
          'companyName': name,
          'serviceCodes': ['transport_hotshot'],
          'serviceAreaSummary': 'Northern Alberta',
        });

    final first = DispatchDirectoryPageData(
      entries: [entry('beta', 'Beta Hauling'), entry('alpha', 'Alpha Hauling')],
      cursor: null,
      hasMore: true,
    );
    final second = DispatchDirectoryPageData(
      entries: [entry('alpha', 'Alpha Hauling'), entry('gamma', 'Gamma Hauling')],
      cursor: null,
      hasMore: false,
    );

    final merged = first.append(second);

    expect(merged.entries.map((entry) => entry.id), ['alpha', 'beta', 'gamma']);
    expect(merged.hasMore, isFalse);
  });

  test('Directory UI wires cursor pagination without the old placeholder', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> _loadMore() async'));
    expect(source, contains('after: current.cursor'));
    expect(source, contains('final merged = current.append(nextPage);'));
    expect(source, contains("'Load more companies'"));
    expect(
      source,
      isNot(contains('Pagination will be wired into the next Directory data slice.')),
    );
  });

""" + anchor
if test.count(anchor) != 1:
    raise SystemExit(f'projection test group anchor mismatch: {test.count(anchor)}')
test = test.replace(anchor, insert, 1)
TEST.write_text(test, encoding='utf-8')
