import 'dart:io';

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

  testWidgets(
    'placement selector exposes Timed Buying without Auction wording',
    (tester) async {
      String selected = 'Marketplace';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) =>
                  MarketplaceListingPlacementSelector(
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
    },
  );

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
              MarketplaceListingChecklistItem(
                label: 'Identity',
                complete: true,
              ),
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

  testWidgets(
    'section card renders compact step badge and Create Listing omits redundant category guide box',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarketplaceListingSectionCard(
              step: 1,
              title: 'Category & core identity',
              description: 'Headline title, category, and product type.',
              icon: Icons.category_outlined,
              child: Text('Form body'),
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Category & core identity'), findsOneWidget);
      expect(find.text('Form body'), findsOneWidget);

      final createListingSource = File(
        'lib/marketplace/oil_gas_marketplace.dart',
      ).readAsStringSync();
      expect(
        createListingSource,
        isNot(contains('MarketplaceListingCategoryGuide(')),
      );
      expect(createListingSource, contains('MarketplaceListingSectionCard('));
    },
  );

  testWidgets(
    'compact itemHeight:null dropdown stays slim when closed and opens multi-line menu cleanly',
    (tester) async {
      String? value = 'Heavy Equipment';
      const items = [
        (
          'Heavy Equipment',
          'Excavators, dozers, skid steers, loaders, cranes and compact equipment.',
        ),
        (
          'Pipe, Tubing & Materials',
          'Drill pipe, casing, tubing, line pipe, OCTG and sucker rod.',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, setState) => DropdownButtonFormField<String>(
                  key: const Key('compact_category_dropdown'),
                  initialValue: value,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  selectedItemBuilder: (context) => items
                      .map(
                        (item) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  items: items
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.$1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.$1),
                                Text(
                                  item.$2,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            ),
          ),
        ),
      );

      final closedSize = tester.getSize(
        find.byKey(const Key('compact_category_dropdown')),
      );
      expect(closedSize.height, lessThanOrEqualTo(56));

      await tester.tap(find.byKey(const Key('compact_category_dropdown')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Pipe, Tubing & Materials'), findsWidgets);

      await tester.tap(find.text('Pipe, Tubing & Materials').last);
      await tester.pumpAndSettle();
      expect(value, 'Pipe, Tubing & Materials');
    },
  );
}
