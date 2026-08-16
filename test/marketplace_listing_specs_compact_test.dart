import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_listing_specs.dart';

void main() {
  test('industrial listing specs prioritize buyer decision facts', () {
    final specs = marketplaceListingSpecs({
      'brand': 'CAT',
      'model': '352',
      'modelYear': 2023,
      'machineHours': 4375,
      'serialNumber': 'CAT00352HKXH10047',
      'category': 'Heavy Equipment',
      'productType': 'Excavator',
      'condition': 'Good',
      'publicLocationName': 'Grande Prairie area, AB',
    });

    expect(specs.map((spec) => spec.label).take(8), [
      'Make / model',
      'Year',
      'Machine hours',
      'Serial number',
      'Category',
      'Item type',
      'Condition',
      'Location',
    ]);
    expect(specs.first.value, 'CAT 352');
  });

  testWidgets('compact listing grid keeps core facts visible', (tester) async {
    tester.view.physicalSize = const Size(760, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MarketplaceListingSpecsGrid(
              title: 'Asset overview',
              listing: const {
                'category': 'Heavy Equipment',
                'productType': 'Bulldozer',
                'condition': 'Good',
                'publicLocationName': 'Grande Prairie area, AB',
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Asset overview'), findsOneWidget);
    expect(find.text('HEAVY EQUIPMENT'), findsNothing);
    expect(find.text('Heavy Equipment'), findsOneWidget);
    expect(find.text('Bulldozer'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Grande Prairie area, AB'), findsOneWidget);
  });

  testWidgets('secondary specs collapse behind More specifications',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarketplaceListingSpecsGrid(
            listing: const {
              'brand': 'CAT',
              'model': '352',
              'modelYear': 2023,
              'machineHours': 4375,
              'serialNumber': 'SERIAL-1',
              'category': 'Heavy Equipment',
              'productType': 'Excavator',
              'condition': 'Good',
              'publicLocationName': 'Grande Prairie, AB',
              'operatingStatus': 'Operational',
            },
          ),
        ),
      ),
    );

    expect(find.textContaining('More specifications'), findsOneWidget);
  });
}
