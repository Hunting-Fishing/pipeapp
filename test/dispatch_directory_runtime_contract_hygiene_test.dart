import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory runtime regression follows semantic lifecycle markers', () {
    final source = File(
      'test/dispatch_directory_filter_runtime_stability_contract_test.dart',
    ).readAsStringSync();

    expect(source, contains("replaceAll(RegExp(r'\\s+'), ' ')"));
    expect(source, contains("contains('_filters = value;')"));
    expect(source, contains("contains('_loadGeneration++;')"));
    expect(source, contains("contains('_filterDebounce?.cancel();')"));
    expect(
      source,
      contains("contains('setState(() => _loadFuture = _load());')"),
    );

    // This was the stale implementation-shape assertion that survived the
    // lifecycle redesign and caused an avoidable regression failure.
    expect(
      source,
      isNot(contains("contains('setState(() => _filters = value);')")),
    );
  });
}
