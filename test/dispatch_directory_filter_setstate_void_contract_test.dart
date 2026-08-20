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
    final filtersStart = compact.indexOf(
      'void _setFilters(DispatchDirectoryFilters value) {',
    );
    final clearStart = compact.indexOf('void _clearFilters()', filtersStart);

    expect(reloadStart, greaterThanOrEqualTo(0));
    expect(filtersStart, greaterThan(reloadStart));
    expect(clearStart, greaterThan(filtersStart));

    final reload = compact.substring(reloadStart, filtersStart);
    expect(reload, contains('_filterDebounce?.cancel();'));
    expect(reload, contains('final nextLoad = _load();'));
    expect(reload, contains('setState(() { _loadFuture = nextLoad; });'));

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
    expect(filter, contains('setState(() { _loadFuture = nextLoad; });'));
  });
}
