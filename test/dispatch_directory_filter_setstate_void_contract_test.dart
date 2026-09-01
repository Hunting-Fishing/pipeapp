import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory filter refresh setState callbacks return void', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync();
    final compact = source.replaceAll(RegExp(r'\s+'), ' ');

    expect(
      compact,
      isNot(
        contains('setState(() => _loadFuture = _load());'),
      ),
    );

    final reloadStart = compact.indexOf('void _reload() {');
    final loadMoreStart = compact.indexOf(
      'Future<void> _loadMore() async',
      reloadStart,
    );
    final filtersStart = compact.indexOf(
      'void _setFilters(DispatchDirectoryFilters value) {',
    );
    final clearStart = compact.indexOf('void _clearFilters()', filtersStart);

    expect(reloadStart, greaterThanOrEqualTo(0));
    expect(loadMoreStart, greaterThan(reloadStart));
    expect(filtersStart, greaterThan(loadMoreStart));
    expect(clearStart, greaterThan(filtersStart));

    final reload = compact.substring(reloadStart, loadMoreStart);
    expect(reload, contains('_filterDebounce?.cancel();'));
    expect(reload, contains('final nextLoad = _load();'));
    expect(reload, contains('setState(() {'));
    expect(reload, contains('_loadFuture = nextLoad;'));
    expect(reload, isNot(contains('setState(() =>')));

    final filter = compact.substring(filtersStart, clearStart);
    expect(filter, contains('_filters = value;'));
    expect(filter, contains('_loadGeneration++;'));
    expect(filter, contains('_filterDebounce?.cancel();'));
    expect(
      filter,
      contains('Timer(const Duration(milliseconds: 180), () {'),
    );
    expect(filter, contains('if (!mounted) return;'));
    expect(filter, contains('final nextLoad = _load();'));
    expect(filter, contains('setState(() {'));
    expect(filter, contains('_loadFuture = nextLoad;'));
    expect(filter, isNot(contains('setState(() => _loadFuture')));
  });
}
