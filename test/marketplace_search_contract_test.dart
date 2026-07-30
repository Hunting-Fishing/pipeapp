import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Marketplace search query has a deployed composite index definition',
      () {
    final document = jsonDecode(
      File('firebase/firestore.indexes.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final indexes = document['indexes'] as List<dynamic>;
    final hasSearchIndex = indexes.any((value) {
      final index = value as Map<String, dynamic>;
      if (index['collectionGroup'] != 'public_listings') return false;
      final fields =
          (index['fields'] as List<dynamic>).cast<Map<String, dynamic>>();
      return fields.any((field) =>
              field['fieldPath'] == 'searchTokens' &&
              field['arrayConfig'] == 'CONTAINS') &&
          fields.any((field) => field['fieldPath'] == 'createdAt');
    });

    expect(hasSearchIndex, isTrue);
  });

  test('client search uses the server-owned listing index', () {
    final source =
        File('lib/marketplace/oil_gas_marketplace.dart').readAsStringSync();
    final commandSource =
        File('firebase/functions/marketplace_commands.js').readAsStringSync();

    expect(
        source, contains(".where('searchTokens', arrayContains: searchToken)"));
    expect(
        commandSource, contains('searchTokens: buildMarketplaceSearchTokens'));
    expect(commandSource, contains('searchIndexVersion'));
  });
}
