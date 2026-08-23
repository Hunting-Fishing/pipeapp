import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dispatch billing operations has a stable authenticated admin route', () {
    final deepLinks = File(
      'lib/marketplace/marketplace_deep_links.dart',
    ).readAsStringSync();
    final nav = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
    final page = File(
      'lib/marketplace/marketplace_dispatch_subscription_admin_page.dart',
    ).readAsStringSync();

    expect(
      deepLinks,
      contains("dispatchBillingAdminPath = '/admin/dispatch-billing'"),
    );
    expect(deepLinks, contains('dispatchBillingAdminRouteName'));
    expect(nav, contains('MarketplaceDeepLinks.dispatchBillingAdminRouteName'));
    expect(nav, contains('MarketplaceDeepLinks.dispatchBillingAdminPath'));
    expect(nav, contains('MarketplaceDispatchSubscriptionAdminPage'));
    expect(page, contains('marketplaceAdministratorState(forceRefresh: true)'));
    expect(page, contains('MarketplaceAdministratorState.authorized'));
  });
}
