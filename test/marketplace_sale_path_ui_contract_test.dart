import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('listing owners cannot bypass settlement with a mark-sold control', () {
    final source =
        File('lib/marketplace/marketplace_account_hub.dart').readAsStringSync();

    expect(source, isNot(contains("_transitionListing('mark_sold')")));
    expect(
      source,
      contains('For Sale listings become sold only after an accepted offer'),
    );
    expect(source, contains("_transitionListing('mark_fulfilled')"));
    expect(
        source, contains('if (isMarketplaceSale && widget.auctionsEnabled)'));
    expect(source, contains('This legacy listing type cannot enter a sale'));
  });

  test('active create form exposes only implemented sale listing model', () {
    final source =
        File('lib/marketplace/oil_gas_marketplace.dart').readAsStringSync();
    final activeSource =
        source.split('Retired FlutterFlow vehicle-listing form').first;

    expect(activeSource,
        isNot(contains("labelText: 'Marketplace listing type *'")));
    expect(
      activeSource,
      contains('Rental and request-for-quote workflows are not available'),
    );
    expect(activeSource, contains("Text('For Sale'"));
  });

  test('unsupported listing models cannot open a purchase offer composer', () {
    final source = File(
      'lib/marketplace/marketplace_messages_page.dart',
    ).readAsStringSync();

    expect(source, contains('marketplaceListingSupportsPurchaseOffers'));
    expect(
      source,
      contains('New purchase offers are unavailable for this listing type'),
    );
  });
}
