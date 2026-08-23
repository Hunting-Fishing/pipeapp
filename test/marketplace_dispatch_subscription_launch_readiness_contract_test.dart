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
    expect(panel, contains('Nothing on this card activates public subscriptions'));
    expect(panel, isNot(contains("'stripeSubscriptionsEnabled': true")));
    expect(panel, isNot(contains('FirebaseFirestore')));
    expect(panel, isNot(contains('.set(')));
    expect(panel, isNot(contains('.update(')));
    expect(panel, isNot(contains('.delete(')));
  });

  test('Dispatch readiness requires provider-bound Portal proof and gives one next action', () {
    final panel = File(
      'lib/marketplace/marketplace_dispatch_subscription_launch_readiness_panel.dart',
    ).readAsStringSync();

    expect(panel, contains("_portal['providerVerified'] == true"));
    expect(panel, contains('providerVerifiedConfigurationId'));
    expect(panel, contains('providerVerificationRevision'));
    expect(panel, contains('LinearProgressIndicator'));
    expect(panel, contains('Recommended next action'));
    expect(panel, contains('BILLING OFF'));
    expect(panel, contains('6 launch prerequisites'));
  });

  test('Dispatch billing operations workspace stays focused and protected', () {
    final page = File(
      'lib/marketplace/marketplace_dispatch_subscription_admin_page.dart',
    ).readAsStringSync();

    expect(page, contains('Protected financial operations'));
    expect(page, contains('maxWidth: 1080'));
    expect(page, contains("number: '1'"));
    expect(page, contains("number: '2'"));
    expect(page, contains("number: '3'"));
    expect(page, contains('It does not contain a public subscription-activation button'));
  });
}
