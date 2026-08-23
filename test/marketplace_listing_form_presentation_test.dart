import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_listing_form_presentation.dart';

void main() {
  test('listing guide prioritizes heavy equipment identity', () {
    final guide = marketplaceListingGuideFor('Heavy Equipment', 'Bulldozer');

    expect(guide.title, contains('Heavy equipment'));
    expect(guide.recommendedFacts, contains('Machine hours'));
    expect(guide.recommendedFacts, contains('Serial / PIN'));
    expect(guide.recommendedFacts, contains('Attachments'));
  });

  test('listing guide prioritizes pipe comparison facts', () {
    final guide = marketplaceListingGuideFor(
      'Pipe, Tubing & Materials',
      'Drill Pipe',
    );

    expect(guide.recommendedFacts, contains('Nominal size / OD'));
    expect(guide.recommendedFacts, contains('Quantity / joints'));
    expect(guide.recommendedFacts, contains('Inspection status'));
  });

  testWidgets('placement selector exposes Timed Buying without Auction wording',
      (tester) async {
    String selected = 'Marketplace';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => MarketplaceListingPlacementSelector(
              selected: selected,
              timedBuyingEnabled: true,
              wantedEnabled: true,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('Timed Buying'), findsOneWidget);
    expect(find.text('Wanted Ad'), findsOneWidget);
    expect(find.textContaining('Auction'), findsNothing);

    await tester.tap(find.text('Timed Buying'));
    await tester.pump();
    expect(selected, 'Timed Buying');
  });

  testWidgets('responsive fields stack on compact widths', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: MarketplaceListingResponsiveFields(
              children: [
                SizedBox(key: Key('first'), height: 40),
                SizedBox(key: Key('second'), height: 40),
              ],
            ),
          ),
        ),
      ),
    );

    final first = tester.getTopLeft(find.byKey(const Key('first')));
    final second = tester.getTopLeft(find.byKey(const Key('second')));
    expect(second.dy, greaterThan(first.dy));
  });

  testWidgets('publish checklist communicates readiness', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarketplaceListingPublishChecklist(
            destinationLabel: 'Timed Buying',
            items: [
              MarketplaceListingChecklistItem(label: 'Identity', complete: true),
              MarketplaceListingChecklistItem(label: 'Terms', complete: true),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Ready for Timed Buying review'), findsOneWidget);
    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
  });
}
