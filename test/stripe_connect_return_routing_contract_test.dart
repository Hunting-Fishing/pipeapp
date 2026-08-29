import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy Stripe Connect callbacks route to authenticated seller payouts',
      () {
    final navSource = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();

    expect(navSource, contains("path: '/account/seller-payouts'"));
    expect(navSource, contains("name: 'marketplaceSellerPayouts'"));
    expect(navSource, contains('requireAuth: true'));
    expect(navSource, contains("state.uri.path == '/'"));
    expect(navSource, contains("connectAction == 'return'"));
    expect(navSource, contains("connectAction == 'refresh'"));
    expect(navSource, contains('MarketplaceStripeConnectReturnPage'));
  });

  test(
      'Stripe Connect callback page checks status and regenerates refresh links',
      () {
    final source = File(
      'lib/marketplace/marketplace_stripe_connect_return_page.dart',
    ).readAsStringSync();

    expect(source, contains("'refreshStripeSellerStatus'"));
    expect(source, contains("'createStripeSellerOnboardingLink'"));
    expect(source, contains("host.endsWith('.stripe.com')"));
    expect(source, contains("webOnlyWindowName: kIsWeb ? '_self' : null"));
    expect(source, contains("context.go('/')"));
    expect(source, isNot(contains("collection('payment_provider_accounts')")));
  });
}
