import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VIP and Dispatch hosted billing share the native guard', () {
    final dispatch = File(
      'lib/marketplace/marketplace_dispatch_subscription_checkout.dart',
    ).readAsStringSync();
    final vip = File(
      'lib/marketplace/marketplace_vip_subscription_checkout.dart',
    ).readAsStringSync();

    for (final source in [dispatch, vip]) {
      expect(source, contains('marketplace_subscription_billing_policy.dart'));
      expect(source, contains('marketplaceHostedMembershipBillingAllowed()'));
      expect(source, contains('marketplaceNativeSubscriptionUnavailableMessage'));
    }

    expect(
      dispatch,
      contains("if (!marketplaceHostedMembershipBillingAllowed()) return;"),
    );
    expect(
      vip,
      contains("if (_busy || !marketplaceHostedMembershipBillingAllowed()) return;"),
    );
  });
}
