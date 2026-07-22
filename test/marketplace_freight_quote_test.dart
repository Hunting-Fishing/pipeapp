import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_freight_quote.dart';

void main() {
  test('uses an explicit seller shipping weight first', () {
    final estimate = FreightWeightEstimate.fromListing({
      'shippingWeightKg': 12500,
      'operatingWeightKg': 10000,
    });

    expect(estimate.kg, 12500);
    expect(estimate.source, 'Seller shipping weight');
    expect(estimate.confidence, 'seller adjusted');
  });

  test('calculates a complete pipe load from nominal mass', () {
    final estimate = FreightWeightEstimate.fromListing({
      'nominalWeightLbFt': 10,
      'jointLengthFt': 30,
      'quantity': 20,
    });

    expect(estimate.kg, closeTo(2721.55422, 0.001));
    expect(estimate.confidence, 'engineering estimate');
  });

  test('requires a manual weight when listing data is incomplete', () {
    final estimate =
        FreightWeightEstimate.fromListing({'title': 'Unknown load'});

    expect(estimate.kg, isNull);
    expect(estimate.confidence, 'manual weight required');
  });
}
