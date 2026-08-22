import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin fee queue has an authenticated route and MFA-backed page', () {
    final deepLinks = File(
      'lib/marketplace/marketplace_deep_links.dart',
    ).readAsStringSync();
    final nav = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
    final page = File(
      'lib/marketplace/marketplace_external_settlement_admin_page.dart',
    ).readAsStringSync();

    expect(deepLinks, contains("settlementAdminPath = '/admin/settlement-fees'"));
    expect(nav, contains('MarketplaceDeepLinks.settlementAdminRouteName'));
    expect(nav, contains('MarketplaceExternalSettlementAdminPage'));
    expect(page, contains('marketplaceAdministratorState(forceRefresh: true)'));
    expect(page, contains('MarketplaceAdministratorState.authorized'));
  });

  test('admin fee queue surfaces operational payment states', () {
    final page = File(
      'lib/marketplace/marketplace_external_settlement_admin_page.dart',
    ).readAsStringSync();

    for (final label in const [
      'CONFIRMATION PENDING',
      'FEE DUE',
      'CHECKOUT OPEN',
      'PROCESSING',
      'FAILED',
      'PAID',
      'TAX REVIEW',
      'PATH CONFLICT',
    ]) {
      expect(page, contains(label), reason: label);
    }
    expect(page, contains('stripeMarketplaceFeeSessionId'));
    expect(page, contains('stripeMarketplaceFeePaymentIntentId'));
    expect(page, contains('stripeMarketplaceFeeChargeId'));
    expect(page, contains('stripeMarketplaceFeeBalanceTransactionId'));
    expect(page, contains('marketplaceFeeReconciliationStatus'));
  });

  test('admin reconciliation is server-controlled and cannot mutate financial state directly', () {
    final page = File(
      'lib/marketplace/marketplace_external_settlement_admin_page.dart',
    ).readAsStringSync();

    expect(page, contains("'reconcileExternalSettlementFee'"));
    expect(page, contains('Reconcile Stripe ↔ Firestore'));
    expect(page, contains('zero unexplained difference'));
    expect(page, isNot(contains('.update({')));
    expect(page, isNot(contains('.set({')));
    expect(page, isNot(contains('.delete()')));
    expect(page, contains('Server-controlled financial operations view'));
  });
}
