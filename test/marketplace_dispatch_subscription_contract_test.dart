import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String panelSource() => File(
        'lib/marketplace/marketplace_dispatch_subscription_panel.dart',
      ).readAsStringSync();
  String componentSource() => File(
        'lib/marketplace/marketplace_dispatch_subscription_components.dart',
      ).readAsStringSync();

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
    final panel = panelSource();
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

  test('customer purchase actions follow server-projected billing availability', () {
    final panel = panelSource();
    final components = componentSource();
    final client = File(
      'lib/marketplace/marketplace_dispatch_subscription_client.dart',
    ).readAsStringSync();

    expect(client, contains('final bool billingAvailable'));
    expect(client, contains("billingAvailable: data['billingAvailable'] == true"));
    expect(panel, contains('MarketplaceDispatchPlanCard'));
    expect(components, contains('status.billingAvailable &&'));
    expect(components, contains('Dispatch subscriptions are not open yet'));
    expect(components, contains('Subscriptions not available yet'));
  });

  test('customer status refreshes automatically after returning from Stripe', () {
    final panel = panelSource();

    expect(panel, contains('with WidgetsBindingObserver'));
    expect(panel, contains('WidgetsBinding.instance.addObserver(this)'));
    expect(panel, contains('WidgetsBinding.instance.removeObserver(this)'));
    expect(panel, contains('AppLifecycleState.resumed'));
    expect(panel, contains('_load();'));
  });

  test('billing management is server-gated and Stripe-host validated', () {
    final panel = panelSource();
    final components = componentSource();
    final client = File(
      'lib/marketplace/marketplace_dispatch_subscription_client.dart',
    ).readAsStringSync();

    expect(panel, contains('status.canManageBilling'));
    expect(panel, contains('_client.createBillingPortal()'));
    expect(panel, contains('Manage billing or cancel in Stripe'));
    expect(
      components,
      contains('Secure billing management is temporarily unavailable'),
    );
    expect(client, contains("'createDispatchBillingPortalSession'"));
    expect(client, contains("uri.host == 'billing.stripe.com'"));
  });

  test('Dispatch membership UI has no direct authoritative Firestore write', () {
    final panel = panelSource();
    final components = componentSource();
    final client = File(
      'lib/marketplace/marketplace_dispatch_subscription_client.dart',
    ).readAsStringSync();
    final combined = '$panel\n$components\n$client';

    expect(combined, isNot(contains('FirebaseFirestore')));
    expect(combined, isNot(contains("collection('dispatch_subscriptions')")));
    expect(combined, isNot(contains('.set(')));
    expect(combined, isNot(contains('.update(')));
    expect(combined, isNot(contains('.delete(')));
  });

  test('Dispatch plan pricing is rendered from server catalog models', () {
    final panel = panelSource();
    final components = componentSource();
    final client = File(
      'lib/marketplace/marketplace_dispatch_subscription_client.dart',
    ).readAsStringSync();

    expect(panel, contains('status.monthly'));
    expect(panel, contains('status.yearly'));
    expect(components, contains('catalog.formattedPrice'));
    expect(components, contains('Final tax treatment'));
    expect(client, contains("data['plans']"));
    expect(client, contains("data['unitAmountMinor']"));
  });

  test('stateful panel delegates presentation to extracted components', () {
    final panel = panelSource();

    expect(
      panel,
      contains("import 'marketplace_dispatch_subscription_components.dart';"),
    );
    expect(panel, contains('MarketplaceDispatchCurrentMembership'));
    expect(panel, contains('MarketplaceDispatchPlanCard'));
    expect(panel, contains('MarketplaceDispatchStatusFailure'));
    expect(panel, isNot(contains('class _DispatchPlanCard')));
    expect(panel, isNot(contains('class _CurrentDispatchMembership')));
    expect(panel, isNot(contains('MarketplaceSubscriptionArtwork')));
  });
}
