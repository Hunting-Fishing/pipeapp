import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_equipment_catalog.dart';
import 'package:pipe_app/marketplace/oil_gas_marketplace.dart';

void main() {
  late EquipmentCatalog catalog;

  setUpAll(() async {
    EquipmentCatalog.clearCacheForTesting();
    catalog = await EquipmentCatalog.loadFromAsset(
      useCache: false,
      jsonLoader: (path) => File(path).readAsString(),
    );
  });

  group('EquipmentCatalog 50+ year dataset & licensing integrity', () {
    test('loads 1970–2026 catalog with clean public-domain licensing metadata',
        () {
      expect(catalog.schemaVersion, 2);
      expect(catalog.yearFloor, 1970);
      expect(catalog.yearCeiling, 2026);
      expect(catalog.allManufacturers.length, greaterThanOrEqualTo(55));

      final totalModels = catalog.allManufacturers.fold<int>(
        0,
        (sum, mfr) => sum + mfr.models.length,
      );
      expect(totalModels, greaterThanOrEqualTo(1200));

      expect(catalog.licensing, isNotNull);
      expect(catalog.licensing!['prohibitedSourcesUsed'], isFalse);
    });

    test('preserves backward compatibility with legacy equipmentBrandModels',
        () {
      for (final entry in equipmentBrandModels.entries) {
        final brand = entry.key;
        if (brand == kManualCatalogOptionValue) continue;
        final mfr = catalog.findManufacturer(brand);
        expect(mfr, isNotNull, reason: 'Missing manufacturer "$brand"');
        for (final legacyModel in entry.value) {
          if (legacyModel == kManualCatalogOptionValue) continue;
          if (mfr!.manualEntryOnly) {
            expect(
              mfr.exampleModels,
              contains(legacyModel),
              reason:
                  'Manual-entry manufacturer "$brand" should list "$legacyModel" in exampleModels',
            );
          } else {
            final matched = catalog.findModel(brand, legacyModel);
            expect(
              matched,
              isNotNull,
              reason: 'Missing legacy model "$legacyModel" under "$brand"',
            );
          }
        }
      }
    });

    test(
        'strictly couples Model and Model Year bidirectionally (e.g. 2020–2026)',
        () {
      // Bobcat T76 was produced 2020–2026 only.
      final bobcat2022 = catalog
          .modelsFor(brand: 'Bobcat', modelYear: 2022)
          .map((m) => m.model)
          .toSet();
      final bobcat2019 = catalog
          .modelsFor(brand: 'Bobcat', modelYear: 2019)
          .map((m) => m.model)
          .toSet();
      final bobcat1985 = catalog
          .modelsFor(brand: 'Bobcat', modelYear: 1985)
          .map((m) => m.model)
          .toSet();

      expect(bobcat2022, contains('T76'));
      expect(bobcat2019, isNot(contains('T76')));
      expect(bobcat1985, isNot(contains('T76')));

      // Classic Bobcat 743 (1981–1990) appears in 1985, never in 2022.
      expect(bobcat1985, contains('743'));
      expect(bobcat2022, isNot(contains('743')));

      // Reverse coupling: selecting T76 restricts valid years strictly to 2026..2020.
      expect(
        catalog.yearsFor(brand: 'Bobcat', model: 'T76'),
        equals(<int>[2026, 2025, 2024, 2023, 2022, 2021, 2020]),
      );

      // Peterbilt 589 (2024–2026) vs Peterbilt 379 (1987–2007).
      expect(
        catalog.yearsFor(brand: 'Peterbilt', model: '589'),
        equals(<int>[2026, 2025, 2024]),
      );
      final peterbilt2005 = catalog
          .modelsFor(brand: 'Peterbilt', modelYear: 2005)
          .map((m) => m.model)
          .toSet();
      expect(peterbilt2005, contains('379'));
      expect(peterbilt2005, isNot(contains('589')));
    });

    test('filters multiple engine/powertrain options by model and year', () {
      // Peterbilt 389 in 2008 offered Caterpillar C15 ACERT & Cummins ISX15/X15,
      // whereas in 2020 it offered Cummins ISX15/X15 & PACCAR MX-13 (no CAT C15).
      final engines2008 = catalog.engineOptionsFor(
        brand: 'Peterbilt',
        model: '389',
        modelYear: 2008,
      );
      final engines2020 = catalog.engineOptionsFor(
        brand: 'Peterbilt',
        model: '389',
        modelYear: 2020,
      );

      expect(engines2008.length, greaterThanOrEqualTo(2));
      expect(
        engines2008.any((e) => e.manufacturer.contains('Caterpillar')),
        isTrue,
      );

      expect(engines2020.length, greaterThanOrEqualTo(2));
      expect(
        engines2020.any((e) => e.manufacturer.contains('Cummins')),
        isTrue,
      );
      expect(
        engines2020.any((e) => e.manufacturer.contains('PACCAR')),
        isTrue,
      );
      expect(
        engines2020.any((e) => e.manufacturer.contains('Caterpillar')),
        isFalse,
      );
    });

    test('enforces manual Model # and Year entry for uncovered/custom brands',
        () {
      expect(catalog.requiresManualModelAndYear('Caterpillar'), isFalse);
      expect(catalog.requiresManualModelAndYear('Bobcat'), isFalse);
      expect(catalog.requiresManualModelAndYear('Peterbilt'), isFalse);

      // Uncovered trailer / custom oilfield / unlisted OEMs require manual entry.
      expect(catalog.requiresManualModelAndYear('Trail King'), isTrue);
      expect(
        catalog.requiresManualModelAndYear('National Oilwell Varco'),
        isTrue,
      );
      expect(catalog.requiresManualModelAndYear('Ariel'), isTrue);
      expect(
        catalog.requiresManualModelAndYear(kManualCatalogOptionValue),
        isTrue,
      );
      expect(
        catalog.modelsFor(brand: 'Trail King', modelYear: 2021),
        isEmpty,
      );
    });

    test('resolves aliases and OEM PIN VDS model codes accurately', () {
      expect(catalog.findManufacturer('CAT')?.name, 'Caterpillar');
      expect(catalog.findManufacturer('Deere')?.name, 'John Deere');
      expect(catalog.findManufacturer('Doosan')?.name, 'Develon');

      expect(catalog.findModel('Caterpillar', '0320D')?.model, '320D');
      expect(catalog.findModel('Kubota', 'C0752')?.model, 'SVL75-2');
    });
  });
}
