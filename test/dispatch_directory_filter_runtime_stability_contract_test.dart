import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory filters retain usable results while remote refresh runs', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync();
    final compact = source.replaceAll(RegExp(r'\s+'), ' ');

    expect(source, contains('DispatchDirectoryPageData? _lastSuccessfulData;'));
    expect(source, contains('Timer? _filterDebounce;'));
    expect(source, contains('int _loadGeneration = 0;'));
    expect(source, contains('final generation = ++_loadGeneration;'));
    expect(source, contains('initialData: _lastSuccessfulData,'));
    expect(
      source,
      contains('final retainedData = snapshot.data ?? _lastSuccessfulData;'),
    );
    expect(
      compact,
      contains(
        'snapshot.connectionState == ConnectionState.waiting && retainedData == null',
      ),
    );
    expect(
      compact,
      contains('snapshot.hasError && retainedData == null'),
    );
    expect(
      source,
      contains('Timer(const Duration(milliseconds: 180), () {'),
    );
    expect(source, contains("'Updating Directory results...'"));
    expect(
      source,
      contains(
        "'Could not refresh these filters. Showing the last loaded Directory results.'",
      ),
    );
  });

  test('filter changes invalidate stale work and debounce with void setState callbacks', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'void _setFilters(DispatchDirectoryFilters value)',
    );
    final end = source.indexOf(
      '@override\n  Widget build(BuildContext context)',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final segment = source.substring(start, end);
    final compact = segment.replaceAll(RegExp(r'\s+'), ' ');

    expect(compact, contains('_filters = value;'));
    expect(compact, contains('_loadGeneration++;'));
    expect(compact, contains('_filterDebounce?.cancel();'));
    expect(compact, contains('Timer(const Duration(milliseconds: 180), () {'));
    expect(compact, contains('final nextLoad = _load();'));
    expect(compact, contains('setState(() { _loadFuture = nextLoad; });'));
    expect(
      compact,
      isNot(contains('setState(() => _loadFuture = _load());')),
    );
    expect(
      compact,
      isNot(contains('_filters = value; _loadFuture = _load();')),
    );
  });
}
