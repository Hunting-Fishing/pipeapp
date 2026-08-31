import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/dispatch_promotion_code_field.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_subscription_checkout.dart';

void main() {
  test('formats server Dispatch subscription catalog prices', () {
    expect(
      dispatchSubscriptionPlanLabel(const {
        'currency': 'CAD',
        'amount': 25,
        'interval': 'month',
      }),
      r'CA$25 / month',
    );
    expect(
      dispatchSubscriptionPlanLabel(const {
        'currency': 'CAD',
        'amount': 300,
        'interval': 'year',
      }),
      r'CA$300 / year',
    );
  });

  test('falls back safely for invalid catalog data', () {
    expect(dispatchSubscriptionPlanLabel(null), 'Subscribe');
    expect(
      dispatchSubscriptionPlanLabel(const {
        'currency': 'CAD',
        'amount': 0,
        'interval': 'month',
      }),
      'Subscribe',
    );
  });

  test('promo code entry is available for both Dispatch checkout plans', () {
    expect(dispatchPromotionCodeEntryAvailable('monthly'), isTrue);
    expect(dispatchPromotionCodeEntryAvailable('MONTHLY'), isTrue);
    expect(dispatchPromotionCodeEntryAvailable('yearly'), isTrue);
    expect(dispatchPromotionCodeEntryAvailable('YEARLY'), isTrue);
    expect(dispatchPromotionCodeEntryAvailable('weekly'), isFalse);
    expect(dispatchPromotionCodeHelpText, contains('Apply it before payment'));
    expect(dispatchPromotionCodeHelpText, contains('Stripe Checkout'));
  });

  testWidgets('promo field is obvious and Apply invokes the supplied action',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var applied = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DispatchPromotionCodeField(
            controller: controller,
            onChanged: (_) {},
            onApply: () => applied = true,
          ),
        ),
      ),
    );

    expect(find.text('Promo code (optional)'), findsOneWidget);
    expect(find.text('Enter promo code'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'FOUNDING500');
    await tester.tap(find.text('Apply'));
    await tester.pump();

    expect(applied, isTrue);
  });

  testWidgets('promo field shows Stripe-confirmed discount feedback',
      (tester) async {
    final controller = TextEditingController(text: 'SAVE20');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DispatchPromotionCodeField(
            controller: controller,
            onChanged: (_) {},
            onApply: () {},
            appliedSummary: 'Promo applied — 20% off.',
          ),
        ),
      ),
    );

    expect(find.text('Promo applied — 20% off.'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });
}