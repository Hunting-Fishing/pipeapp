import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_offer_analysis.dart';

void main() {
  test('partial offer shows quantity and value remaining', () {
    const analysis = MarketplaceOfferAnalysis(
      listedQuantity: 54,
      requestedQuantity: 25,
      askingUnitPrice: 73,
      offeredUnitPrice: 70,
    );

    expect(analysis.normalizedRequestedQuantity, 25);
    expect(analysis.remainingQuantity, 29);
    expect(analysis.requestedQuantityPercent, closeTo(46.296, .001));
    expect(analysis.remainingQuantityPercent, closeTo(53.704, .001));
    expect(analysis.fullListingAskValue, 3942);
    expect(analysis.requestedAskValue, 1825);
    expect(analysis.offeredTotal, 1750);
    expect(analysis.remainingAskValue, 2117);
    expect(analysis.unitDifference, -3);
    expect(analysis.requestedValueDifference, -75);
    expect(analysis.priceDifferencePercent, closeTo(-4.1095, .001));
    expect(analysis.valid, isTrue);
  });

  test('full-quantity offer at asking price is neutral', () {
    const analysis = MarketplaceOfferAnalysis(
      listedQuantity: 54,
      requestedQuantity: 54,
      askingUnitPrice: 73,
      offeredUnitPrice: 73,
    );

    expect(analysis.remainingQuantity, 0);
    expect(analysis.requestedQuantityPercent, 100);
    expect(analysis.offeredTotal, 3942);
    expect(analysis.requestedValueDifference, 0);
    expect(analysis.priceDifferencePercent, 0);
    expect(analysis.valid, isTrue);
  });

  test('requested quantity is capped for display but rejected for submission', () {
    const analysis = MarketplaceOfferAnalysis(
      listedQuantity: 54,
      requestedQuantity: 80,
      askingUnitPrice: 73,
      offeredUnitPrice: 70,
    );

    expect(analysis.normalizedRequestedQuantity, 54);
    expect(analysis.remainingQuantity, 0);
    expect(analysis.requestedQuantityPercent, 100);
    expect(analysis.valid, isFalse);
  });
}
