import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_weight_catalog.dart';

void main() {
  test('equipment catalog keys prefer exact year then generic model', () {
    final ids = marketplaceWeightCatalogIds(
      category: 'Heavy Equipment',
      productType: 'Skid Steer',
      manufacturer: 'Bobcat',
      model: 'S160',
      modelYear: 2011,
    );

    expect(ids.take(2), [
      'equipment_bobcat_s160_2011',
      'equipment_bobcat_s160',
    ]);
  });

  test('listing snapshot remains the preferred frozen weight source', () {
    final estimate = MarketplaceWeightEstimate.fromListing({
      'shippingWeightKg': 9999,
      'weightSnapshot': {
        'status': 'estimated',
        'estimatedWeightKg': 3692.2,
        'sourceLabel': 'Bobcat archived S160 specifications',
        'confidence': 'manufacturer source',
        'catalogId': 'equipment_bobcat_s160',
        'catalogRevision': 1,
      },
    });

    expect(estimate.kg, closeTo(3692.2, .001));
    expect(estimate.catalogId, 'equipment_bobcat_s160');
    expect(estimate.source, contains('Bobcat'));
  });

  test('unknown weight is explicit instead of silently becoming zero', () {
    final estimate = MarketplaceWeightEstimate.fromListing({
      'weightSnapshot': {
        'status': 'unknown',
        'sourceLabel': 'Seller does not know the load weight',
        'confidence': 'unknown',
      },
    });

    expect(estimate.hasWeight, isFalse);
    expect(estimate.status, 'unknown');
    expect(estimate.kg, isNull);
  });
}
