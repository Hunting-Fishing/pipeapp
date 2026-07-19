import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_trucking_plan.dart';

void main() {
  test('trucking choices store stable offer values', () {
    expect(
        MarketplaceTruckingPlan.buyerArranged.storageValue, 'buyer_arranged');
    expect(MarketplaceTruckingPlan.requestDispatch.storageValue,
        'request_dispatch');
    expect(MarketplaceTruckingPlan.sellerPickup.storageValue, 'seller_pickup');
  });

  test('dispatch choice clearly identifies the carrier bidding workflow', () {
    expect(MarketplaceTruckingPlan.requestDispatch.label, contains('Dispatch'));
    expect(MarketplaceTruckingPlan.requestDispatch.description,
        contains('carrier bids'));
  });
}
