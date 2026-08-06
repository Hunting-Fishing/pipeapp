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

    expect(source, isNot(contains('subtotal * 0.025')));
    expect(source, isNot(contains('subtotal * 0.010')));
    expect(source, isNot(contains('TOTAL COMPANY EARNINGS (3.5%)')));
    expect(source, isNot(contains('2.5% SELLER COMMISSIONS')));
    expect(source, isNot(contains('1.0% ESCROW PROTECTION')));
  });

  test('payment readiness policy remains safe by default', () {
    final source = File(
      'lib/marketplace/marketplace_payment_readiness.dart',
    ).readAsStringSync();

    expect(source, contains('paymentsEnabled = false'));
    expect(source, contains('tokenPurchasesEnabled = false'));
    expect(source, contains('platformCustodyEnabled = false'));
    expect(source, contains('directBankDetailsAllowed = false'));
    expect(source, contains('clientSecretEntryAllowed = false'));
    expect(source, contains('Stripe Connect'));
    expect(source, contains('PayPal Multiparty'));
    expect(source, contains('Processor-managed only'));
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
