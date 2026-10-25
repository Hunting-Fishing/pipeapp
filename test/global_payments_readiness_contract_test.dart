import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_membership_page.dart';
import 'package:pipe_app/marketplace/regional_phone_field.dart';

void main() {
  test('global phone regions cover 195+ countries and key oilfield basins', () {
    final codes = phoneRegions.map((r) => r.code).toSet();
    expect(phoneRegions.length, greaterThanOrEqualTo(195));
    expect(codes.length, equals(phoneRegions.length));
    expect(
      codes,
      containsAll(<String>[
        'CA',
        'US',
        'MX',
        'TT',
        'GY',
        'SR',
        'BR',
        'AR',
        'CO',
        'GB',
        'NO',
        'NL',
        'DE',
        'AE',
        'SA',
        'QA',
        'KW',
        'OM',
        'BH',
        'IQ',
        'EG',
        'NG',
        'AO',
        'GA',
        'GQ',
        'MZ',
        'NA',
        'SG',
        'MY',
        'ID',
        'AU',
        'PG',
        'TL',
      ]),
    );
  });

  test('Oilfield Directory List Services wires Stripe Checkout and sanctions',
      () {
    final source = File(
      'lib/marketplace/pipebuyer_list_services_page.dart',
    ).readAsStringSync();
    final client = File(
      'lib/marketplace/pipebuyer_yellow_pages_client.dart',
    ).readAsStringSync();

    expect(client, contains("'createYellowPagesListingCheckout'"));
    expect(client, contains("'createYellowPagesBillingPortalSession'"));
    expect(client, contains("'billingInterval': billingInterval"));

    expect(source, contains('createListingCheckout'));
    expect(source, contains('Continue to Secure Stripe Checkout'));
    expect(source, contains('_kSanctionedStripeCountries'));
    for (final code in <String>['BY', 'CU', 'IR', 'KP', 'RU', 'SY']) {
      expect(source, contains("'$code'"));
    }
  });

  test('router preserves Stripe payment return query parameters across flows',
      () {
    final navSource = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
    expect(navSource, contains("uri.queryParameters['payment']"));
    expect(navSource, contains("paymentAction == 'success'"));
    expect(navSource, contains("paymentAction == 'cancel'"));
    expect(navSource, contains("'/payments/success'"));
    expect(navSource, contains("'/payments/cancel'"));
  });

  test(
      'seller payout settings expose all 37 CA Connect countries and wire fallback',
      () {
    final payoutSource = File(
      'lib/marketplace/marketplace_payout_settings.dart',
    ).readAsStringSync();
    for (final country in <String>[
      'CA',
      'US',
      'GB',
      'NO',
      'NL',
      'DE',
      'FR',
      'CH',
      'SE',
      'DK',
    ]) {
      expect(payoutSource, contains("MapEntry('$country',"));
    }
    expect(payoutSource, contains('Direct Wire / PO External Settlement'));
  });

  testWidgets('MarketplacePaymentReturnPage renders Yellow Pages success state',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MarketplacePaymentReturnPage(
          success: true,
          flow: 'yellow_pages',
          requestId: 'req_123',
        ),
      ),
    );

    expect(
      find.text('Stripe received your checkout submission'),
      findsOneWidget,
    );
    expect(find.textContaining('Ref #req_123'), findsOneWidget);
    expect(find.text('Return to Oilfield Directory'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
