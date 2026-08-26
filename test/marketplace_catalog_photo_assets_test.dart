import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_catalog_photo_assets.dart';

void main() {
  test(
    'Marketplace photographic package contains exactly 67 installed assets',
    () {
      expect(MarketplaceCatalogPhotoAssets.allAssetPaths, hasLength(67));

      for (final path in MarketplaceCatalogPhotoAssets.allAssetPaths) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'Missing Marketplace photograph: $path',
        );

        final filename = path.split('/').last;
        expect(
          filename,
          matches(RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*\.svg$')),
          reason: 'Production-unsafe Marketplace filename: $filename',
        );
      }
    },
  );

  test('all 67 supplied photographs are reachable through catalog mapping', () {
    const expectedTypes = <String, List<String>>{
      'Heavy Equipment': [
        'Backhoe',
        'Bulldozer',
        'Compactor',
        'Crane',
        'Drilling Rig',
        'Excavator',
        'Forklift',
        'Grader',
        'Loader',
        'Skid Steer',
      ],
      'Oil & Gas Equipment': ['Generator'],
      'Oilfield & Drilling': ['Derrick', 'Drill Rig'],
      'Pipe, Tubing & Materials': [
        'Casing',
        'Drill Pipe',
        'Drill Stem',
        'Fittings',
        'Flanges',
        'Line Pipe',
        'OCTG',
        'Steel Plate',
        'Sucker Rod',
      ],
      'Farm & Ranch Products': [
        'Bale Feeder',
        'Buffalo / Bison Panel',
        'Cattle Panel',
        'Continuous Fence',
        'Corral Panel',
        'Custom Pipe Fabrication',
        'Farm Gate',
        'Fence Post',
        'Livestock Shelter',
      ],
      'Tanks & Containers': [
        'Chemical Tank',
        'Frac Tank',
        'Fuel Tank',
        'IBC Tote',
        'Propane Tank',
        'Tank Skid',
        'Vault Tank',
        'Water Tank',
        'Other / not listed',
      ],
      'Transport & Hauling': [
        'Drop Deck',
        'Flatbed Trailer',
        'Lowboy Trailer',
        'Roll Off Truck',
        'Semi Truck',
        'Step Deck',
        'Vacuum Truck',
        'Water Truck',
        'Winch Truck',
        'Other / not listed',
      ],
      'Portable Buildings': [
        'Bathroom Unit',
        'Container Office',
        'Crew Shack',
        'Guard Shack',
        'Lunchroom',
        'Modular Building',
        'Portable Office',
        'Storage Unit',
        'Other / not listed',
      ],
      'Site Support': [
        'Air Compressor',
        'Boom Lift',
        'Generator',
        'Light Tower',
        'Material Cage',
        'Scissor Lift',
        'Spill Kit',
        'Tool Room',
        'Welding Machine',
        'Rig Mat',
        'Other / not listed',
      ],
    };

    final resolved = <String>{};

    for (final entry in expectedTypes.entries) {
      for (final productType in entry.value) {
        final path = MarketplaceCatalogPhotoAssets.forProductType(
          entry.key,
          productType,
        );

        expect(
          path,
          isNotNull,
          reason: 'Missing photo mapping: ${entry.key} / $productType',
        );

        resolved.add(path!);
      }
    }

    expect(
      resolved,
      equals(MarketplaceCatalogPhotoAssets.allAssetPaths),
      reason:
          'Every supplied Marketplace photo must be reachable with no orphan files.',
    );
  });

  test('ambiguous Other artwork stays category specific', () {
    final portable = MarketplaceCatalogPhotoAssets.forProductType(
      'Portable Buildings',
      'Other / not listed',
    );

    final tanks = MarketplaceCatalogPhotoAssets.forProductType(
      'Tanks & Containers',
      'Other / not listed',
    );

    final transport = MarketplaceCatalogPhotoAssets.forProductType(
      'Transport & Hauling',
      'Other / not listed',
    );

    final siteSupport = MarketplaceCatalogPhotoAssets.forProductType(
      'Site Support',
      'Other / not listed',
    );

    expect({portable, tanks, transport, siteSupport}, hasLength(4));
  });

  test('Rig Mat has dedicated Site Support artwork', () {
    expect(
      MarketplaceCatalogPhotoAssets.forProductType('Site Support', 'Rig Mat'),
      '${MarketplaceCatalogPhotoAssets.root}/rig-mat.svg',
    );
  });
}
