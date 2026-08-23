import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory runtime regression checks production lifecycle semantics',
      () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

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
    expect(
      compact,
      contains('Timer(const Duration(milliseconds: 180), () {'),
    );
    expect(compact, contains('final nextLoad = _load();'));
    expect(
      compact,
      contains('setState(() { _loadFuture = nextLoad; });'),
    );

    // The production callback body must return void. Inspect production
    // source directly instead of scanning a test file for quoted assertions.
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
