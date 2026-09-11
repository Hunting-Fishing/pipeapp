import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('R5 Dispatch transaction UI exposes structured BOL workflow', () {
    final transaction = source(
      'lib/marketplace/marketplace_dispatch_transaction.dart',
    );
    expect(transaction, contains('Bill of lading'));
    expect(transaction, contains('Record bill of lading'));
    expect(transaction, contains('Edit bill of lading'));
    expect(transaction, contains("action: 'record_bol'"));
    expect(transaction, contains("transaction['billOfLading']"));
    expect(transaction, contains("transaction['workflowVersion']"));
  });

  test('R5 Dispatch repository sends normalized BOL fields through command path', () {
    final repository = source(
      'lib/marketplace/marketplace_dispatch_repository.dart',
    );
    expect(repository, contains("'bolNumber': bolNumber.trim()"));
    expect(repository, contains("'bolShipperReference': bolShipperReference.trim()"));
    expect(repository, contains("'bolPieceCount': bolPieceCount"));
    expect(repository, contains("'bolNotes': bolNotes.trim()"));
    expect(repository, contains("'updateDispatchTransaction'"));
  });

  test('R5 BOL stays separate from Release 6 financial settlement', () {
    final transaction = source(
      'lib/marketplace/marketplace_dispatch_transaction.dart',
    );
    expect(transaction, isNot(contains('provider proceeds')));
    expect(transaction, isNot(contains('payout state')));
    expect(transaction, isNot(contains('charge freight')));
  });
}
