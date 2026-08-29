import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_subscription_checkout.dart';

void main() {
  test('formats server Dispatch subscription catalog prices', () {
    expect(
      dispatchSubscriptionPlanLabel(const {
        'currency': 'CAD',
        'amount': 25,
        'interval': 'month',
      }),
      r'CA$25 / month',
    );
    expect(
      dispatchSubscriptionPlanLabel(const {
        'currency': 'CAD',
        'amount': 300,
        'interval': 'year',
      }),
      r'CA$300 / year',
    );
  });

  test('falls back safely for invalid catalog data', () {
    expect(dispatchSubscriptionPlanLabel(null), 'Subscribe');
    expect(
      dispatchSubscriptionPlanLabel(const {
        'currency': 'CAD',
        'amount': 0,
        'interval': 'month',
      }),
      'Subscribe',
    );
  });

  test('promo code guidance is limited to monthly Dispatch checkout', () {
    expect(dispatchPromotionCodeEntryAvailable('monthly'), isTrue);
    expect(dispatchPromotionCodeEntryAvailable('MONTHLY'), isTrue);
    expect(dispatchPromotionCodeEntryAvailable('yearly'), isFalse);
    expect(dispatchPromotionCodeHelpText, contains('secure Stripe checkout'));
  });
}
