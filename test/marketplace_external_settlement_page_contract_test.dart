import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authenticated settlement workspace is routed explicitly', () {
    final deepLinks = File(
      'lib/marketplace/marketplace_deep_links.dart',
    ).readAsStringSync();
    final nav = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();

    expect(deepLinks, contains("settlementPath = '/account/settlements'"));
    expect(deepLinks, contains("settlementRouteName = 'marketplace-settlements'"));
    expect(nav, contains('MarketplaceDeepLinks.settlementRouteName'));
    expect(nav, contains('MarketplaceDeepLinks.settlementPath'));
    expect(nav, contains('requireAuth: true'));
    expect(nav, contains('MarketplaceExternalSettlementPage'));
  });

  test('settlement workspace exposes both-party and seller fee controls', () {
    final source = File(
      'lib/marketplace/marketplace_external_settlement_page.dart',
    ).readAsStringSync();

    expect(source, contains("externalSettlementBuyerConfirmed"));
    expect(source, contains("externalSettlementSellerConfirmed"));
    expect(source, contains("Confirm external settlement"));
    expect(source, contains("Pay Pipe Buyer marketplace fee"));
    expect(source, contains("Retry Pipe Buyer fee payment"));
    expect(source, contains("Continue secure fee checkout"));
    expect(source, contains("Open Stripe receipt"));
    expect(source, contains("marketplaceFeeStatus"));
    expect(source, contains("marketplaceFeeSnapshot"));
    expect(source, contains("stripeMarketplaceFeeChargeId"));
  });

  test('settlement workspace never writes financial state directly', () {
    final source = File(
      'lib/marketplace/marketplace_external_settlement_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("collection('marketplace_transactions').add")));
    expect(source, isNot(contains('.update({')));
    expect(source, isNot(contains('.set({')));
    expect(source, contains('_client.confirm(transactionId)'));
    expect(source, contains('_client.createFeeCheckout(transactionId)'));
    expect(source, contains('_client.getFeeReceipt(transactionId)'));
  });
}
