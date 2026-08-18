import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/marketplace/marketplace_dispatch_credentials.dart',
  ).readAsStringSync();

  test('analytics navigation uses the top tab without duplicate shortcut cards', () {
    expect(source.contains("text: 'Analytics & alerts'"), isTrue);
    expect(source.contains('Open analytics & alerts'), isFalse);
    expect(
      RegExp(r"title:\s*'Analytics & alerts'").allMatches(source).length,
      0,
    );
  });

  test('credential readiness totals expose visible drill-down actions', () {
    expect(source.contains('Select any status tile below'), isTrue);
    expect(source.contains('Future<void> _showCredentialMetricDetails'), isTrue);
    expect(source.contains('Future<void> _showCredentialQuickActions'), isTrue);
    expect(source.contains("'View details'"), isTrue);
    expect(source.contains('Semantics('), isTrue);
    expect(source.contains('button: true'), isTrue);
    expect(source.contains('InkWell('), isTrue);
    expect(source.contains('onTap: ()'), isTrue);
  });

  test('analytics tiles retain the records behind each displayed number', () {
    for (final marker in [
      "label: 'Current'",
      'records: current',
      "label: 'Expired'",
      'records: expired',
      "label: 'Not provided'",
      'records: missing',
      "label: 'Evidence files'",
      'records: evidenceRecords',
      "label: 'Insurance limits'",
      'records: insuranceWithLimits',
    ]) {
      expect(source.contains(marker), isTrue, reason: 'Missing $marker');
    }
  });

  test('analytics record details provide metadata and evidence actions', () {
    expect(source.contains('Private evidence on file'), isTrue);
    expect(source.contains("pop('edit')"), isTrue);
    expect(source.contains("pop('evidence')"), isTrue);
    expect(source.contains("pop('remove_evidence')"), isTrue);
    expect(source.contains("case 'edit':"), isTrue);
    expect(source.contains("case 'evidence':"), isTrue);
    expect(source.contains("case 'remove_evidence':"), isTrue);
  });
}
