import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_stripe_connect_return_page.dart';

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

  test('Stripe Connect callbacks return through authenticated seller payouts', () {
    const callbackPage = MarketplaceStripeConnectReturnPage(
      connectAction: 'return',
    );
    expect(callbackPage.connectAction, 'return');

    final navSource = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
    final callbackSource = File(
      'lib/marketplace/marketplace_stripe_connect_return_page.dart',
    ).readAsStringSync();

    expect(navSource, contains("path: '/account/seller-payouts'"));
    expect(navSource, contains("name: 'marketplaceSellerPayouts'"));
    expect(navSource, contains("state.uri.path == '/'"));
    expect(navSource, contains("connectAction == 'return'"));
    expect(navSource, contains("connectAction == 'refresh'"));
    expect(navSource, contains('MarketplaceStripeConnectReturnPage'));

    expect(callbackSource, contains("'refreshStripeSellerStatus'"));
    expect(callbackSource, contains("'createStripeSellerOnboardingLink'"));
    expect(callbackSource, contains("host.endsWith('.stripe.com')"));
    expect(
      callbackSource,
      contains("webOnlyWindowName: kIsWeb ? '_self' : null"),
    );
    expect(
      callbackSource,
      isNot(contains("collection('payment_provider_accounts')")),
    );
  });
}
