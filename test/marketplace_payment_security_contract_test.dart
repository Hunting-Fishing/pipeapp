import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin clients do not accept or store financial secrets', () {
    final dashboard = File(
      'lib/marketplace/marketplace_admin_dashboard.dart',
    ).readAsStringSync();
    final portal = File(
      'lib/marketplace/marketplace_admin_transaction_portal.dart',
    ).readAsStringSync();
    final combined = '$dashboard\n$portal';

    const prohibited = <String>[
      'stripeSecretKey',
      'stripeWebhookSecret',
      'paypalSecretKey',
      'authorizeTransactionKey',
      'companyAccountNumber',
      'companyRoutingNumber',
      "doc('payment_gateways')",
      'Admin Force Release Funds',
      'Admin Force Refund Buyer',
      'force_release',
      'force_refund',
      'Industrial Escrow Protection Active',
      'escrowEnabled',
    ];

    for (final value in prohibited) {
      expect(combined, isNot(contains(value)), reason: value);
    }
  });

  test('admin clients do not present hard-coded payment revenue', () {
    final source = File(
      'lib/marketplace/marketplace_admin_dashboard.dart',
    ).readAsStringSync();

    const prohibited = <String>[
      'subtotal * 0.025',
      'subtotal * 0.010',
      'grossAuctionVolume * 0.035',
      'TOTAL COMPANY EARNINGS (3.5%)',
      '2.5% SELLER COMMISSIONS',
      '1.0% ESCROW PROTECTION',
      'EST. 3.5% AUCTION FEES',
      '3.5% company commission earnings',
      'estimated 3.5% fees',
    ];

    for (final value in prohibited) {
      expect(source, isNot(contains(value)), reason: value);
    }
    expect(source, contains("'PAYMENT REVENUE'"));
    expect(source, contains("'COMMISSION SCHEDULE'"));
    expect(source, contains("'PROVIDER SETTLEMENT'"));
    expect(source, contains("'AUCTION PAYMENT FEES'"));
    expect(source, contains("'Not active'"));
  });

  test('payment readiness policy is server controlled and secret free', () {
    final source = File(
      'lib/marketplace/marketplace_payment_readiness.dart',
    ).readAsStringSync();

    expect(source, contains("getPaymentProviderReadiness"));
    expect(source, contains("getMarketplaceFeeCatalog"));
    expect(source, contains("stripeCheckoutEnabled"));
    expect(source, contains("stripeTaxReady"));
    expect(source, contains("'SANDBOX VERIFIED'"));
    expect(source, contains("activeEnvironmentLabel"));
    expect(source, isNot(contains('paymentsEnabled = true')));
    expect(source, isNot(contains('stripeSecretKey')));
    expect(source, isNot(contains('stripeWebhookSecret')));
    expect(source, isNot(contains('clientSecretEntryAllowed = true')));
  });

  test('customer marketplace UI has no legacy listing or escrow fees', () {
    final source = [
      'lib/marketplace/marketplace_invoice_generator.dart',
      'lib/marketplace/marketplace_account_hub.dart',
      'lib/marketplace/oil_gas_marketplace.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    const prohibited = <String>[
      r'\$29.99 upfront listing fee',
      '5% of the completed sale',
      'sellerCommissionFee',
      'escrowProtectionFee',
      'Escrow Protection Fee',
      'View Itemized Invoice',
    ];
    for (final value in prohibited) {
      expect(source, isNot(contains(value)), reason: value);
    }
    expect(source, contains('No listing fee'));
    expect(source, contains('MarketplaceFeeInfoButton'));
    expect(source, contains('marketplaceFeeSnapshot'));
  });

  test('architecture requires server secrets and verified webhooks', () {
    final source = File(
      'docs/PAYMENT_PROVIDER_ARCHITECTURE.md',
    ).readAsStringSync();

    expect(source, contains('protected server'));
    expect(source, contains('signed webhook'));
    expect(source, contains('idempotency'));
    expect(source, contains('KYC/KYB'));
    expect(source, contains('non-transferable'));
    expect(source, contains('payments remain disabled'));
  });
}
