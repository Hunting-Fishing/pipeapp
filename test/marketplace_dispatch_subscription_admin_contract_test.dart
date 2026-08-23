import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dispatch billing operations page requires MFA-backed administrator access', () {
    final page = File(
      'lib/marketplace/marketplace_dispatch_subscription_admin_page.dart',
    ).readAsStringSync();

    expect(page, contains('marketplaceAdministratorState(forceRefresh: true)'));
    expect(page, contains('MarketplaceAdministratorState.authorized'));
    expect(page, contains('MarketplaceDispatchSubscriptionAdminPanel'));
    expect(page, contains('Complete multi-factor authentication'));
  });

  test('Dispatch reconciliation UI uses only server callables for financial operations', () {
    final page = File(
      'lib/marketplace/marketplace_dispatch_subscription_admin_page.dart',
    ).readAsStringSync();
    final panel = File(
      'lib/marketplace/marketplace_dispatch_subscription_admin_panel.dart',
    ).readAsStringSync();
    final combined = '$page\n$panel';

    expect(panel, contains("'getDispatchSubscriptionReconciliationQueue'"));
    expect(panel, contains("'reconcileDispatchSubscriptionInvoice'"));
    expect(panel, contains('Reconcile Stripe ↔ Firestore'));
    expect(combined, isNot(contains('FirebaseFirestore')));
    expect(combined, isNot(contains('.set(')));
    expect(combined, isNot(contains('.update(')));
    expect(combined, isNot(contains('.delete(')));
  });

  test('Dispatch billing operations explains the current Stripe provider chain', () {
    final page = File(
      'lib/marketplace/marketplace_dispatch_subscription_admin_page.dart',
    ).readAsStringSync();

    expect(
      page,
      contains(
        'Stripe Invoice → InvoicePayment → PaymentIntent → Charge → Balance Transaction',
      ),
    );
    expect(page, contains('100% promotional invoice'));
    expect(page, contains('Flutter cannot mark an invoice balanced'));
  });
}
