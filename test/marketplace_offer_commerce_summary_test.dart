import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_offer_analysis.dart';

void main() {
  test('original full listing stays independent from buyer offer', () {
    const analysis = MarketplaceOfferAnalysis(
      listedQuantity: 100,
      requestedQuantity: 100,
      askingUnitPrice: 42,
      offeredUnitPrice: 30,
    );

    expect(analysis.listedQuantity, 100);
    expect(analysis.askingUnitPrice, 42);
    expect(analysis.fullListingAskValue, 4200);
    expect(analysis.offeredTotal, 3000);
    expect(analysis.unitDifference, -12);
    expect(analysis.requestedValueDifference, -1200);
    expect(analysis.priceDifferencePercent, closeTo(-28.5714, .001));
  });

  test('partial offer preserves full listing and calculates remaining inventory', () {
    const analysis = MarketplaceOfferAnalysis(
      listedQuantity: 54,
      requestedQuantity: 25,
      askingUnitPrice: 73,
      offeredUnitPrice: 70,
    );

    expect(analysis.fullListingAskValue, 3942);
    expect(analysis.requestedAskValue, 1825);
    expect(analysis.offeredTotal, 1750);
    expect(analysis.remainingQuantity, 29);
    expect(analysis.remainingAskValue, 2117);
    expect(analysis.requestedValueDifference, -75);
    expect(analysis.requestedQuantityPercent, closeTo(46.296, .001));
    expect(analysis.remainingQuantityPercent, closeTo(53.704, .001));
  });
}
