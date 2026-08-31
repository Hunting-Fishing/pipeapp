import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_membership_page.dart';

void main() {
  test('Dispatch membership status requires explicit active payload', () {
    expect(dispatchMembershipStatusActive(null), isFalse);
    expect(dispatchMembershipStatusActive({'active': false}), isFalse);
    expect(dispatchMembershipStatusActive({'active': true}), isTrue);
  });

  test('hosted Stripe purchase and Portal controls are web-only', () {
    expect(dispatchHostedStripeSurfaceAllowed(isWeb: true), isTrue);
    expect(dispatchHostedStripeSurfaceAllowed(isWeb: false), isFalse);
  });

  test('promo guidance is visible for monthly and yearly Dispatch checkout', () {
    expect(
      dispatchMembershipPromotionHint('monthly'),
      contains('Apply it here before payment'),
    );
    expect(
      dispatchMembershipPromotionHint('yearly'),
      contains('Apply it here before payment'),
    );
  });

  test('Dispatch membership paid-through date is formatted from server millis',
      () {
    final utc = DateTime.utc(2026, 8, 21);
    final label = dispatchMembershipPaidThrough({
      'currentPeriodEndMillis': utc.millisecondsSinceEpoch,
    });
    expect(label, isNotEmpty);
    expect(label, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  test('Dispatch prices are rendered from the server catalog', () {
    final catalog = {
      'plans': {
        'monthly': {
          'currency': 'CAD',
          'amountMinor': 2500,
          'interval': 'month',
        },
        'yearly': {
          'currency': 'CAD',
          'amountMinor': 30000,
          'interval': 'year',
        },
      },
    };
    expect(
        dispatchSubscriptionPriceLabel(catalog, 'monthly'), r'CA$25 / month');
    expect(dispatchSubscriptionPriceLabel(catalog, 'yearly'), r'CA$300 / year');
  });

  test('Dispatch pricing never invents a local fallback amount', () {
    expect(dispatchSubscriptionPriceLabel(const {}, 'monthly'),
        'Price unavailable');
  });

  testWidgets('payment success does not claim redirect grants access',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MarketplacePaymentReturnPage(success: true),
      ),
    );

    expect(find.text('Payment submitted'), findsOneWidget);
    expect(
      find.textContaining(
          'does not grant paid access from this browser redirect'),
      findsOneWidget,
    );
    expect(find.text('View Dispatch membership'), findsOneWidget);
  });

  testWidgets('payment cancel clearly leaves membership unpaid',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MarketplacePaymentReturnPage(success: false),
      ),
    );

    expect(find.text('Payment cancelled'), findsOneWidget);
    expect(
      find.textContaining('does not mark a membership paid'),
      findsOneWidget,
    );
  });
}
