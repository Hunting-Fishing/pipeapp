import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dispatch launch readiness uses only audited server controls', () {
    final panel = File(
      'lib/marketplace/marketplace_dispatch_subscription_launch_readiness_panel.dart',
    ).readAsStringSync();
    final page = File(
      'lib/marketplace/marketplace_dispatch_subscription_admin_page.dart',
    ).readAsStringSync();

    expect(page, contains('MarketplaceDispatchSubscriptionLaunchReadinessPanel'));
    expect(panel, contains("'getPaymentProviderReadiness'"));
    expect(panel, contains("'getDispatchBillingPortalReadiness'"));
    expect(panel, contains("'verifyDispatchSubscriptionLifecycleWebhook'"));
    expect(panel, contains("'setPaymentProviderReadiness'"));
    expect(panel, contains("'stripeSubscriptionRecoveryVerified'"));
    expect(panel, contains('I verified this'));
    expect(panel, contains('This panel cannot activate public subscriptions'));
    expect(panel, isNot(contains("'stripeSubscriptionsEnabled': true")));
    expect(panel, isNot(contains('FirebaseFirestore')));
    expect(panel, isNot(contains('.set(')));
    expect(panel, isNot(contains('.update(')));
    expect(panel, isNot(contains('.delete(')));
  });
}
