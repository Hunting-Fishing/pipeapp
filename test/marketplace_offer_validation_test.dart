import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_offer_validation.dart';

void main() {
  test('incomplete offer identifies every missing required field', () {
    const requirements = MarketplaceOfferRequirements(
      offeredUnitPrice: 0,
      requestedQuantity: 0,
      hasTruckingPlan: false,
      requestsDispatch: false,
      hasDispatchDestination: false,
      hasTruckingDate: false,
    );

    expect(requirements.missing,
        ['quantity requested', 'offer price', 'trucking plan']);
    expect(requirements.complete, isFalse);
  });

  test('dispatch requires both destination and trucking date', () {
    const requirements = MarketplaceOfferRequirements(
      offeredUnitPrice: 70,
      requestedQuantity: 54,
      hasTruckingPlan: true,
      requestsDispatch: true,
      hasDispatchDestination: false,
      hasTruckingDate: false,
    );

    expect(requirements.missing,
        ['delivery destination', 'trucking / pickup date']);
    expect(requirements.guidance,
        'Still required: delivery destination, trucking / pickup date.');
  });

  test('complete offer has no missing requirements', () {
    const requirements = MarketplaceOfferRequirements(
      offeredUnitPrice: 70,
      requestedQuantity: 54,
      hasTruckingPlan: true,
      requestsDispatch: true,
      hasDispatchDestination: true,
      hasTruckingDate: true,
    );

    expect(requirements.complete, isTrue);
    expect(requirements.missing, isEmpty);
  });

  testWidgets('submit stays interactive and explains incomplete fields',
      (tester) async {
    var submitted = false;
    const requirements = MarketplaceOfferRequirements(
      offeredUnitPrice: 0,
      requestedQuantity: 0,
      hasTruckingPlan: false,
      requestsDispatch: false,
      hasDispatchDestination: false,
      hasTruckingDate: false,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarketplaceOfferSubmitButton(
          requirements: requirements,
          onComplete: () => submitted = true,
        ),
      ),
    ));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
    await tester.tap(find.text('Submit offer'));
    await tester.pump();

    expect(submitted, isFalse);
    expect(find.text('Offer not submitted'), findsOneWidget);
    expect(find.textContaining('Still required: quantity requested'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('complete submit invokes the offer action', (tester) async {
    var submitted = false;
    const requirements = MarketplaceOfferRequirements(
      offeredUnitPrice: 70,
      requestedQuantity: 54,
      hasTruckingPlan: true,
      requestsDispatch: false,
      hasDispatchDestination: false,
      hasTruckingDate: false,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarketplaceOfferSubmitButton(
          requirements: requirements,
          onComplete: () => submitted = true,
        ),
      ),
    ));

    await tester.tap(find.text('Submit offer'));
    expect(submitted, isTrue);
  });
}
