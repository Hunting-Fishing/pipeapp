import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/industrial_icon_assets.dart';
import 'package:pipe_app/marketplace/oil_gas_marketplace.dart';

void main() {
  test('industrial icon resolver maps primary marketplace categories', () {
    expect(IndustrialIconAssets.forLabel('Pipe, Tubing & Materials'),
        IndustrialIconAssets.pipeBundle);
    expect(IndustrialIconAssets.forLabel('Vacuum Truck'),
        IndustrialIconAssets.vacuumTruck);
    expect(IndustrialIconAssets.forLabel('Timed auction'),
        IndustrialIconAssets.complianceGavel);
    expect(IndustrialIconAssets.forLabel('Dispatch dashboard'),
        IndustrialIconAssets.dashboard);
    expect(IndustrialIconAssets.forLabel('Crawler Excavator'),
        IndustrialIconAssets.crawlerExcavator);
    expect(IndustrialIconAssets.forLabel('Lowboy trailer'),
        IndustrialIconAssets.lowboyTrailer);
    expect(IndustrialIconAssets.forLabel('Drill Pipe'),
        IndustrialIconAssets.drillPipe);
    expect(IndustrialIconAssets.forLabel('Production Tubing'),
        IndustrialIconAssets.productionTubing);
    expect(IndustrialIconAssets.forLabel('Skid Steer Loader'),
        IndustrialIconAssets.skidSteer);
    expect(IndustrialIconAssets.forLabel('BOP'), IndustrialIconAssets.bopStack);
    expect(IndustrialIconAssets.forLabel('Annular BOP'),
        IndustrialIconAssets.annularBop);
    expect(IndustrialIconAssets.forLabel('Wanted / Seeking'),
        IndustrialIconAssets.wantedEquipment);
    expect(IndustrialIconAssets.forLabel('Dispatch load board'),
        IndustrialIconAssets.dispatchLoadBoard);
    expect(IndustrialIconAssets.forLabel('Farm & Ranch Products'),
        IndustrialIconAssets.ranchGate);
    expect(IndustrialIconAssets.forLabel('Heater Treater'),
        IndustrialIconAssets.heaterTreater);
    expect(IndustrialIconAssets.forLabel('Steel Plate'),
        IndustrialIconAssets.steelPlate);
    expect(IndustrialIconAssets.forLabel('Cattle Panel'),
        IndustrialIconAssets.cattlePanel);
    expect(IndustrialIconAssets.forLabel('Winch Truck'),
        IndustrialIconAssets.winchTruck);
    expect(IndustrialIconAssets.forLabel('Browse Marketplace'),
        IndustrialIconAssets.browseMarketplace);
    expect(IndustrialIconAssets.forLabel('Report listing'),
        IndustrialIconAssets.reportListing);
    expect(IndustrialIconAssets.forLabel('Photos reused from another listing'),
        IndustrialIconAssets.duplicatePhoto);
    expect(IndustrialIconAssets.forLabel('Unknown custom machinery'), isNull);
  });

  test('every active marketplace category and type has reusable artwork', () {
    for (final category in marketplaceCategories) {
      expect(
        IndustrialIconAssets.forLabel(category.name),
        isNotNull,
        reason: 'Missing category artwork: ${category.name}',
      );
      for (final type in category.types) {
        expect(
          IndustrialIconAssets.forLabel(type),
          isNotNull,
          reason: 'Missing reusable equipment-family artwork: $type',
        );
      }
    }
  });

  test('equipment models resolve through generic equipment families', () {
    expect(
      IndustrialIconAssets.forLabel('CAT 320 Hydraulic Excavator'),
      IndustrialIconAssets.crawlerExcavator,
    );
    expect(
      IndustrialIconAssets.forLabel('Case 580SV Backhoe'),
      IndustrialIconAssets.crawlerExcavator,
    );
    expect(
      IndustrialIconAssets.forLabel('Bobcat T76 compact track loader'),
      IndustrialIconAssets.skidSteer,
    );
    expect(
      IndustrialIconAssets.forLabel('Komatsu D65EX-18 Dozer'),
      IndustrialIconAssets.bulldozer,
    );
    expect(
      IndustrialIconAssets.forLabel('Vibratory soil compactor'),
      IndustrialIconAssets.bulldozer,
    );
    expect(
      IndustrialIconAssets.forLabel('150 ton crawler crane'),
      IndustrialIconAssets.craneTruck,
    );
    expect(IndustrialIconAssets.forLabel('Caterpillar 320'), isNull);
  });

  test('Dispatch fleet types resolve with transportation context', () {
    expect(IndustrialIconAssets.forVehicleType('Truck'),
        IndustrialIconAssets.semiTruck);
    expect(IndustrialIconAssets.forVehicleType('Tractor'),
        IndustrialIconAssets.semiTruck);
    expect(IndustrialIconAssets.forVehicleType('Pickup'),
        IndustrialIconAssets.pickupFlatbed);
    expect(IndustrialIconAssets.forVehicleType('Hotshot'),
        IndustrialIconAssets.hotshotGooseneck);
    expect(IndustrialIconAssets.forVehicleType('Pilot truck'),
        IndustrialIconAssets.escortPickup);
  });

  testWidgets('form option presents an icon and readable label',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MarketplaceFormOption(
                label: 'Pilot truck',
                subtitle: 'Escort and route support',
                icon: Icons.assistant_direction_outlined,
                assetPath: IndustrialIconAssets.escortPickup))));
    await tester.pumpAndSettle();

    expect(find.text('Pilot truck'), findsOneWidget);
    expect(find.text('Escort and route support'), findsOneWidget);
    expect(find.byType(IndustrialAssetIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fleet type dropdown fits a narrow mobile viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const types = ['Truck', 'Pickup', 'Tractor', 'Hotshot', 'Pilot truck'];

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                    initialValue: types.first,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Vehicle type'),
                    items: types
                        .map((type) => DropdownMenuItem(
                            value: type,
                            child: MarketplaceFormOption(
                                label: type,
                                icon: Icons.local_shipping_outlined,
                                assetPath:
                                    IndustrialIconAssets.forVehicleType(type))))
                        .toList(),
                    onChanged: (_) {})))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    for (final type in types.skip(1)) {
      expect(find.text(type), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  test('resolved production icon files are installed', () {
    for (final path in [
      IndustrialIconAssets.pipeBundle,
      IndustrialIconAssets.vacuumTruck,
      IndustrialIconAssets.complianceGavel,
      IndustrialIconAssets.dashboard,
      IndustrialIconAssets.crawlerExcavator,
      IndustrialIconAssets.lowboyTrailer,
      IndustrialIconAssets.drillPipe,
      IndustrialIconAssets.annularBop,
      IndustrialIconAssets.wantedEquipment,
      IndustrialIconAssets.dispatchLoadBoard,
    ]) {
      expect(File(path).existsSync(), isTrue, reason: 'Missing asset: $path');
    }
  });

  test('complete industrial package is installed', () {
    final files = Directory('assets/images/industrial_icons')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.svg'))
        .toList();
    expect(files, hasLength(259));
  });

  testWidgets('representative industrial SVGs render through Flutter',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Wrap(
                children: [
      IndustrialIconAssets.pipeBundle,
      IndustrialIconAssets.vacuumTruck,
      IndustrialIconAssets.complianceGavel,
      IndustrialIconAssets.dashboard,
      IndustrialIconAssets.crawlerExcavator,
      IndustrialIconAssets.lowboyTrailer,
      IndustrialIconAssets.drillPipe,
      IndustrialIconAssets.annularBop,
      IndustrialIconAssets.wantedEquipment,
      IndustrialIconAssets.dispatchLoadBoard,
    ]
                    .map((path) => IndustrialAssetIcon(
                        assetPath: path,
                        label: 'Test icon',
                        size: 72,
                        fallback: const Icon(Icons.error_outline)))
                    .toList()))));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(IndustrialAssetIcon), findsNWidgets(10));
  });

  testWidgets('all 56 expansion SVGs render through Flutter', (tester) async {
    final paths = <String>[];
    for (var folder = 10; folder <= 15; folder++) {
      final directory = Directory('assets/images/industrial_icons')
          .listSync()
          .whereType<Directory>()
          .firstWhere((entry) => entry.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('$folder-'));
      paths.addAll(directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.svg'))
          .map((file) => file.path.replaceAll(Platform.pathSeparator, '/')));
    }
    expect(paths, hasLength(56));

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Wrap(
                    children: paths
                        .map((path) => IndustrialAssetIcon(
                            assetPath: path,
                            label: 'Expansion icon',
                            size: 32,
                            fallback: const Icon(Icons.error_outline)))
                        .toList())))));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(IndustrialAssetIcon), findsNWidgets(56));
  });

  testWidgets('all 131 Phase 2 SVGs render through Flutter', (tester) async {
    final paths = <String>[];
    for (var folder = 16; folder <= 25; folder++) {
      final directory = Directory('assets/images/industrial_icons')
          .listSync()
          .whereType<Directory>()
          .firstWhere((entry) => entry.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('$folder-'));
      paths.addAll(directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.svg'))
          .map((file) => file.path.replaceAll(Platform.pathSeparator, '/')));
    }
    expect(paths, hasLength(131));

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Wrap(
                    children: paths
                        .map((path) => IndustrialAssetIcon(
                            assetPath: path,
                            label: 'Phase 2 icon',
                            size: 32,
                            fallback: const Icon(Icons.error_outline)))
                        .toList())))));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(IndustrialAssetIcon), findsNWidgets(131));
  });
}
