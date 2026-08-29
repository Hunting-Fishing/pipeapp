import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seller payout UI keeps provider account metadata server private', () {
    final source = File(
      'lib/marketplace/marketplace_payout_settings.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("collection('payment_provider_accounts')")));
    expect(source, contains("'refreshStripeSellerStatus'"));
    expect(source, contains("'createStripeSellerOnboardingLink'"));
    expect(source, contains("host.endsWith('.stripe.com')"));
  });
}
