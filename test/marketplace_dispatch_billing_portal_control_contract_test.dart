import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dispatch Portal control verifies exact provider configuration before enablement', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_billing_portal_control.dart',
    ).readAsStringSync();

    expect(source, contains('verifyDispatchBillingPortalConfiguration'));
    expect(source, contains('Verify & enable Billing Portal'));
    expect(source, contains('Re-verify with Stripe'));
    expect(source, contains('stripePortalConfigurationId'));
    expect(source, contains("'confirmProduction': true"));
    expect(source, contains('payment-method updates and invoice history'));
    expect(source, contains('plan switching disabled'));
    expect(source, contains('setDispatchBillingPortalReadiness'));
    expect(source, contains("'enabled': false"));
  });

  test('Dispatch Portal readiness UI requires provider proof bound to exact bpc', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_billing_portal_control.dart',
    ).readAsStringSync();

    expect(source, contains("_portal['providerVerified'] == true"));
    expect(source, contains('providerVerifiedConfigurationId'));
    expect(source, contains('providerVerificationRevision'));
    expect(source, contains('PROVIDER VERIFIED'));
    expect(source, contains('Payment-method updates'));
    expect(source, contains('Cancellation at period end'));
    expect(source, contains('Monthly ↔ Yearly plan switching disabled'));
    expect(source, contains('re-checked live with Stripe'));
  });

  test('Dispatch Portal control never writes financial Firestore state directly', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_billing_portal_control.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('FirebaseFirestore')));
    expect(source, isNot(contains('.set(')));
    expect(source, isNot(contains('.update(')));
    expect(source, isNot(contains('.delete(')));
    expect(source, isNot(contains('stripeSubscriptionsEnabled')));
  });

  test('Dispatch operations page composes Portal verification with readiness', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_subscription_admin_page.dart',
    ).readAsStringSync();

    expect(source, contains('MarketplaceDispatchBillingPortalControl'));
    expect(source, contains('MarketplaceDispatchSubscriptionLaunchReadinessPanel'));
    expect(source, contains('MarketplaceAdministratorState.authorized'));
  });
}
