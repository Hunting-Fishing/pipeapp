import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory repository reads the server-owned projection', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync();

    expect(
      source.contains("_firestore.collection('dispatch_directory_entries')"),
      isTrue,
    );
    expect(
      source.contains('DispatchDirectoryEntry.fromDirectoryProjection'),
      isTrue,
    );
    expect(
      source.contains("query.where('serviceCodes', arrayContains:"),
      isTrue,
    );
  });

  test('Dispatch navigation uses the real Directory page', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_navigation.dart',
    ).readAsStringSync();

    expect(source.contains("import 'marketplace_dispatch_directory.dart';"), isTrue);
    expect(source.contains('MarketplaceDispatchDirectoryPage('), isTrue);
    expect(source.contains('Service taxonomy active'), isFalse);
  });

  test('formal acceptance launcher includes deterministic Directory fixtures', () {
    final source = File('tool/start_formal_acceptance_environment.ps1')
        .readAsStringSync();

    expect(source.contains('seed_dispatch_directory_visual.js'), isTrue);
    expect(
      source.contains('Seeding deterministic Dispatch Directory provider fixtures'),
      isTrue,
    );
  });
}
