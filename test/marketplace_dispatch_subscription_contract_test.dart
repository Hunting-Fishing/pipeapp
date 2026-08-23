import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account memberships route exposes Dispatch subscription panel', () {
    final menu = File(
      'lib/marketplace/marketplace_account_menu.dart',
    ).readAsStringSync();
    final dialog = File(
      'lib/marketplace/marketplace_memberships_dialog.dart',
    ).readAsStringSync();

    expect(menu, contains('MarketplaceMembershipsDialog'));
    expect(menu, contains('onVipDetails: onMemberships'));
    expect(dialog, contains('MarketplaceDispatchSubscriptionPanel'));
    expect(dialog, contains('Dispatch membership'));
  });

  test('Dispatch membership UI uses server status and callable Checkout only', () {
    final panel = File(
      'lib/marketplace/marketplace_dispatch_subscription_panel.dart',
    ).readAsStringSync();
    final client = File(
      'lib/marketplace/marketplace_dispatch_subscription_client.dart',
    ).readAsStringSync();

    expect(panel, contains('_client.getStatus()'));
    expect(panel, contains('_client.createCheckout(plan)'));
    expect(panel, contains('Complete payment in Stripe'));
    expect(panel, contains('Returning from Checkout does not activate membership'));
    expect(client, contains("'getDispatchSubscriptionStatus'"));
    expect(client, contains("'createDispatchSubscriptionCheckout'"));
    expect(client, contains("uri.host == 'checkout.stripe.com'"));
  });

  test('billing management is server-gated and Stripe-host validated', () {
    final panel = File(
      'lib/marketplace/marketplace_dispatch_subscription_panel.dart',
    ).readAsStringSync();
    final client = File(
      'lib/marketplace/marketplace_dispatch_subscription_client.dart',
    ).readAsStringSync();

    expect(panel, contains('status.canManageBilling'));
    expect(panel, contains('_client.createBillingPortal()'));
    expect(panel, contains('Manage billing or cancel in Stripe'));
    expect(client, contains("'createDispatchBillingPortalSession'"));
    expect(client, contains("uri.host == 'billing.stripe.com'"));
  });

  test('Dispatch membership UI has no direct authoritative Firestore write', () {
    final panel = File(
      'lib/marketplace/marketplace_dispatch_subscription_panel.dart',
    ).readAsStringSync();
    final client = File(
      'lib/marketplace/marketplace_dispatch_subscription_client.dart',
    ).readAsStringSync();

    expect(panel, isNot(contains('FirebaseFirestore')));
    expect(client, isNot(contains('FirebaseFirestore')));
    expect(panel, isNot(contains("collection('dispatch_subscriptions')")));
    expect(client, isNot(contains("collection('dispatch_subscriptions')")));
  });

  test('Dispatch plan pricing is rendered from server catalog models', () {
    final panel = File(
      'lib/marketplace/marketplace_dispatch_subscription_panel.dart',
    ).readAsStringSync();
    final client = File(
      'lib/marketplace/marketplace_dispatch_subscription_client.dart',
    ).readAsStringSync();

    expect(panel, contains('status.monthly'));
    expect(panel, contains('status.yearly'));
    expect(panel, contains('catalog.formattedPrice'));
    expect(client, contains("data['plans']"));
    expect(client, contains("data['unitAmountMinor']"));
  });
}
