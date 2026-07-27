import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_browse_filters.dart';

void main() {
  test('price ranges use a deterministic price order', () {
    const filters = MarketplaceBrowseFilters(
      minimumPrice: 1000,
      maximumPrice: 5000,
    );

    expect(filters.validationMessage, isNull);
    expect(filters.hasPriceRange, isTrue);
    expect(filters.effectiveSort, MarketplaceBrowseSort.priceLowToHigh);
  });

  test('invalid price ranges are rejected before querying', () {
    const reversed = MarketplaceBrowseFilters(
      minimumPrice: 5000,
      maximumPrice: 1000,
    );
    const negative = MarketplaceBrowseFilters(minimumPrice: -1);

    expect(reversed.validationMessage,
        'Minimum price cannot be greater than maximum price.');
    expect(negative.validationMessage, 'Minimum price cannot be negative.');
  });

  test('active filter count and clear operations stay consistent', () {
    const filters = MarketplaceBrowseFilters(
      transactionType: 'For Sale',
      condition: 'Good',
      minimumPrice: 100,
      sort: MarketplaceBrowseSort.priceHighToLow,
    );

    expect(filters.activeCount, 4);
    final cleared = filters.copyWith(
      clearTransactionType: true,
      clearCondition: true,
      clearMinimumPrice: true,
      sort: MarketplaceBrowseSort.newest,
    );
    expect(cleared.activeCount, 0);
  });
}
