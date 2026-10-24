import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_listing_specs.dart';
import 'package:pipe_app/marketplace/oil_gas_marketplace.dart';

void main() {
  test('pipe dropdown catalogs provide comprehensive OCTG & line pipe options',
      () {
    expect(
        pipeWallAndScheduleOptions, contains('Standard wall (STD / SCH 40)'));
    expect(pipeWallAndScheduleOptions, contains('Heavy wall (XS / SCH 80)'));
    expect(pipeWallAndScheduleOptions, contains('Drill pipe — 16.60 lb/ft'));
    expect(pipeWallAndScheduleOptions,
        contains('Casing — 17.00 lb/ft (5-1/2 in)'));

    expect(
        pipeGradeOptions,
        containsAll(<String>[
          'J-55 (API 5CT)',
          'N-80 (API 5CT)',
          'L-80 (API 5CT Sour Service)',
          'P-110 (API 5CT High Collapse)',
          'E-75 (API 5DP Drill Pipe)',
          'S-135 (API 5DP Drill Pipe)',
          'API 5L X52 / X56 (Line Pipe)',
        ]));
    expect(
        pipeConnectionOptions,
        containsAll(<String>[
          'EUE 8rd (External Upset)',
          '8rd LTC (Long Round Thread)',
          'Buttress Thread (BTC)',
          'NC46 (4 IF / 4-1/2 XH)',
          'NC50 (4-1/2 IF)',
        ]));
    expect(
        pipeLengthRangeOptions,
        containsAll(<String>[
          'Range 1 (18–22 ft / ~6 m)',
          'Range 2 (27–31 ft / ~9.5 m)',
          'Range 3 (38–45 ft / ~12.5 m)',
        ]));
  });

  test(
      'equipment brand models include heavy haul, oilfield, crane, and site support brands',
      () {
    expect(
        equipmentBrandModels.keys,
        containsAll(<String>[
          'Caterpillar',
          'John Deere',
          'Komatsu',
          'Kenworth',
          'Peterbilt',
          'Western Star',
          'Mack',
          'Freightliner',
          'Trail King',
          'Fontaine',
          'Gardner Denver',
          'SPM / Weir',
          'Ariel',
          'Cameron / SLB',
          'Grove / Manitowoc',
          'Genie / JLG',
        ]));
    expect(equipmentBrandModels['Kenworth'], contains('C500'));
    expect(equipmentBrandModels['Peterbilt'], contains('389'));
    expect(equipmentBrandModels['Ariel'], contains('JGK/4'));
  });

  test('marketplaceListingSpecs extracts structured pipe dropdown fields', () {
    final specs = marketplaceListingSpecs(<String, dynamic>{
      'productType': 'Drill Pipe',
      'pipeSize': '4-1/2 in',
      'pipeSchedule': 'Drill pipe — 16.60 lb/ft',
      'pipeGrade': 'E-75 (API 5DP Drill Pipe)',
      'pipeConnection': 'NC46 (4 IF / 4-1/2 XH)',
      'pipeLengthRange': 'Range 2 (27–31 ft / ~9.5 m)',
      'pipeBand': 'White band',
      'quantity': 100,
      'inspectionStatus': 'Third-party inspected — report available',
    });

    final labels = specs.map((spec) => spec.label).toList();
    expect(
        labels,
        containsAll(<String>[
          'Item type',
          'Pipe size',
          'Wall / weight',
          'Steel grade',
          'Thread / connection',
          'Length / range',
          'Pipe band',
          'Quantity',
          'Inspection',
        ]));
  });
}
