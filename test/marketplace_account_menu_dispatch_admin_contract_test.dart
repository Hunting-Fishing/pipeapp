import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account menu exposes Dispatch Billing only for authorized administrators', () {
    final source = File(
      'lib/marketplace/marketplace_account_menu.dart',
    ).readAsStringSync();

    expect(source, contains('marketplaceAdministratorState()'));
    expect(
      source,
      contains('snapshot.data == MarketplaceAdministratorState.authorized'),
    );
    expect(source, contains('if (showDispatchBilling)'));
    expect(source, contains("title: 'Dispatch Billing Operations'"));
    expect(source, contains("context.push('/admin/dispatch-billing')"));
  });

  test('account-menu Dispatch shortcut does not weaken protected page access', () {
    final menu = File(
      'lib/marketplace/marketplace_account_menu.dart',
    ).readAsStringSync();
    final page = File(
      'lib/marketplace/marketplace_dispatch_subscription_admin_page.dart',
    ).readAsStringSync();

    expect(menu, isNot(contains('FirebaseFirestore')));
    expect(page, contains('MarketplaceAdministratorState.authorized'));
    expect(page, contains('Complete multi-factor authentication'));
  });
}
