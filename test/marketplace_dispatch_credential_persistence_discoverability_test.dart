import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/marketplace/marketplace_dispatch_credentials.dart',
  ).readAsStringSync();

  test('credential dialog save persists before the user leaves the screen', () {
    expect(
      RegExp(r'Future<void>\s+_persistRecordUpdate\s*\(').hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(r'await\s+_persistRecordUpdate\s*\(\s*updated\s*\)\s*;')
          .hasMatch(source),
      isTrue,
    );
    expect(
      source.contains('Credential metadata saved privately.'),
      isTrue,
    );
  });

  test('analytics and alerts are discoverable from both tabs and records view', () {
    expect(source.contains("text: 'Analytics & alerts'"), isTrue);
    expect(source.contains("title: 'Analytics & alerts'"), isTrue);
    expect(source.contains('Open analytics & alerts'), isTrue);
    expect(
      RegExp(r'DefaultTabController\.of\(context\)\.animateTo\(1\)')
          .hasMatch(source),
      isTrue,
    );
  });

  test('insurance matching data remains described as private and self-reported', () {
    expect(source.contains('Exact policy numbers and coverage amounts remain private.'), isTrue);
    expect(source.contains('not Pipe Buyer verification'), isTrue);
  });
}
