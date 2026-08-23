import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final contractFiles = <String>[
    'test/marketplace_dispatch_credential_analytics_actions_test.dart',
    'test/marketplace_dispatch_credential_persistence_discoverability_test.dart',
  ];

  test('credential source contracts do not depend on single-line Text widgets', () {
    for (final path in contractFiles) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('source.contains("const Text(') ||
            source.contains("source.contains('const Text("),
        isFalse,
        reason:
            '$path contains an exact const Text(...) source assertion. Dart format may legally wrap widget arguments; use a whitespace-tolerant RegExp or semantic markers instead.',
      );
    }
  });

  test('analytics action contracts verify behavior markers rather than layout', () {
    final source = File(
      'test/marketplace_dispatch_credential_analytics_actions_test.dart',
    ).readAsStringSync();
    expect(source.contains("'View details'"), isTrue);
    expect(source.contains('button: true'), isTrue);
    expect(source.contains('InkWell('), isTrue);
    expect(source.contains('onTap:'), isTrue);
  });
}
