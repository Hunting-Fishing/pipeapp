import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_vip_subscription_checkout.dart';

void main() {
  test('VIP price label renders the server catalog amount', () {
    expect(
      vipSubscriptionPlanLabel(const <String, dynamic>{
        'currency': 'CAD',
        'amount': 100,
        'interval': 'month',
      }),
      r'CA$100 / month',
    );
  });

  test('VIP pricing never invents a local fallback amount', () {
    expect(vipSubscriptionPlanLabel(null), 'VIP pricing unavailable');
    expect(
      vipSubscriptionPlanLabel(const <String, dynamic>{
        'currency': 'CAD',
        'amount': 0,
        'interval': 'month',
      }),
      'VIP pricing unavailable',
    );
  });
}
