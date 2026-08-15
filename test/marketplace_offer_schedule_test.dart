import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_offer_schedule.dart';

void main() {
  test('offer milestones are normalized and sorted by date', () {
    final milestones = marketplaceOfferMilestones({
      'purchaseDate': DateTime(2026, 8, 14),
      'moneyTransferDate': DateTime(2026, 8, 10),
      'truckingDate': DateTime(2026, 9, 2),
    });

    expect(milestones.map((item) => item.key),
        ['money_transfer', 'purchase', 'trucking']);
    expect(milestones.first.shortLabel, 'Transfer');
    expect(milestones.last.date, DateTime(2026, 9, 2));
  });

  testWidgets('compact schedule opens a selectable milestone calendar',
      (tester) async {
    final milestones = marketplaceOfferMilestones({
      'purchaseDate': DateTime(2026, 8, 14),
      'moneyTransferDate': DateTime(2026, 8, 10),
      'truckingDate': DateTime(2026, 9, 2),
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 390,
          child: MarketplaceOfferScheduleCard(milestones: milestones),
        ),
      ),
    ));

    expect(find.text('Purchase'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Trucking'), findsOneWidget);

    await tester.tap(find.text('Open calendar'));
    await tester.pumpAndSettle();

    expect(find.text('August 2026'), findsOneWidget);
    expect(find.textContaining('Purchase 2026-08-14'), findsOneWidget);
    expect(find.textContaining('Trucking 2026-09-02'), findsOneWidget);

    await tester.tap(find.textContaining('Trucking 2026-09-02'));
    await tester.pumpAndSettle();

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Trucking / pickup'), findsOneWidget);
  });

  testWidgets('accept review fits mobile and returns counter-offer decision',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    MarketplaceOfferDecision? decision;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              decision = await showDialog<MarketplaceOfferDecision>(
                context: context,
                builder: (_) => MarketplaceAcceptOfferDialog(offer: {
                  'offeredTotal': 3942,
                  'requestedQuantity': 54,
                  'purchaseDate': DateTime(2026, 8, 14),
                  'moneyTransferDate': DateTime(2026, 8, 10),
                  'truckingDate': DateTime(2026, 9, 2),
                }),
              );
            },
            child: const Text('Review offer'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Review offer'));
    await tester.pumpAndSettle();

    expect(find.text(r'$3,942.00'), findsOneWidget);
    expect(find.text('54 units'), findsOneWidget);
    expect(find.text('Make counter offer'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Accept offer'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final counterButton = find.text('Make counter offer');
    await tester.ensureVisible(counterButton);
    await tester.pumpAndSettle();
    await tester.tap(counterButton);
    await tester.pumpAndSettle();

    expect(decision, MarketplaceOfferDecision.counter);
  });
}
