import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory widget tests use the accepted responsive test harness', () {
    final source = File(
      'test/marketplace_dispatch_directory_test.dart',
    ).readAsStringSync();
    final compact = source.replaceAll(RegExp(r'\s+'), ' ');

    expect(
      compact,
      contains('tester.binding.setSurfaceSize(const Size(1200, 1000));'),
    );
    expect(
      compact,
      contains('addTearDown(() => tester.binding.setSurfaceSize(null));'),
    );
    expect(source, contains('tester.scrollUntilVisible('));
    expect(source, isNot(contains('tester.dragUntilVisible(')));
    expect(source, contains('const Duration(milliseconds: 220)'));
    expect(
      source,
      contains('The accepted runtime lifecycle debounces remote refreshes for 180 ms.'),
    );
  });
}
