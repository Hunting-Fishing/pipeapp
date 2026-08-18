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

  test('analytics and alerts use the permanent top tab without duplicate cards', () {
    expect(source.contains("text: 'Analytics & alerts'"), isTrue);
    expect(source.contains('Open analytics & alerts'), isFalse);
    expect(
      RegExp(r"title:\s*'Analytics & alerts'").allMatches(source).length,
      0,
    );
    expect(source.contains('Select any status tile below'), isTrue);
  });

  test('analytics totals can drill into the credential records they summarize', () {
    expect(source.contains('Future<void> _showCredentialMetricDetails'), isTrue);
    expect(source.contains('Future<void> _showCredentialQuickActions'), isTrue);
    expect(source.contains("const Text('View details')"), isTrue);
    expect(source.contains('records: evidenceRecords'), isTrue);
    expect(source.contains('records: insuranceWithLimits'), isTrue);
  });

  test('insurance matching data remains described as private and self-reported', () {
    expect(
      source.contains('Exact policy numbers and coverage amounts remain private.'),
      isTrue,
    );
    expect(source.contains('not Pipe Buyer verification'), isTrue);
  });
}
