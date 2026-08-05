import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('home action artwork', () {
    const assets = <String, String>{
      'Browse Marketplace':
          'assets/images/industrial_icons/24-marketplace-workflows/02-browse-marketplace.svg',
      'Create Listing':
          'assets/images/industrial_icons/24-marketplace-workflows/03-sell-create-listing.svg',
    };

    for (final entry in assets.entries) {
      test('${entry.key} uses transparent card-ready artwork', () {
        final source = File(entry.value).readAsStringSync();
        expect(source, contains('viewBox="0 0 256 256"'));
        expect(source, contains('<title>${entry.key}</title>'));
        expect(source, contains('Transparent high-contrast'));

        // The action card already provides its own navy artwork panel. A
        // second full-canvas navy rectangle makes the illustration look like
        // a small dark tile inside another dark tile.
        expect(
          source,
          isNot(contains('<rect x="8" y="8" width="240" height="240"')),
        );
      });
    }
  });
}
