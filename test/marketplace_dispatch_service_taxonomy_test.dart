import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_service_taxonomy.dart';

void main() {
  test('service codes are unique stable machine keys', () {
    final codes = DispatchServiceTaxonomy.services.map((service) => service.code);
    expect(codes.toSet().length, codes.length);
    for (final code in codes) {
      expect(code, matches(RegExp(r'^[a-z0-9_]+$')));
    }
  });

  test('capability field codes are unique stable machine keys', () {
    final codes = DispatchServiceTaxonomy.capabilityFields.map((field) => field.code);
    expect(codes.toSet().length, codes.length);
    for (final code in codes) {
      expect(code, matches(RegExp(r'^[a-z0-9_]+$')));
    }
  });

  test('every service belongs to a declared category and subcategory', () {
    final categoryCodes = DispatchServiceTaxonomy.categories
        .map((category) => category.code)
        .toSet();
    for (final service in DispatchServiceTaxonomy.services) {
      expect(categoryCodes, contains(service.category));
      expect(service.subcategoryCode, isNotEmpty);
      expect(service.subcategoryLabel, isNotEmpty);
    }
  });

  test('every referenced capability field exists', () {
    final capabilityCodes = DispatchServiceTaxonomy.capabilityFields
        .map((field) => field.code)
        .toSet();
    for (final service in DispatchServiceTaxonomy.services) {
      for (final capability in service.capabilityFieldCodes) {
        expect(
          capabilityCodes,
          contains(capability),
          reason: '${service.code} references unknown capability $capability',
        );
      }
    }
  });

  test('numeric capacity fields define a canonical unit', () {
    for (final field in DispatchServiceTaxonomy.capabilityFields.where(
      (field) => field.valueType == DispatchCapabilityValueType.number,
    )) {
      expect(field.canonicalUnit, isNotNull, reason: field.code);
      expect(field.acceptedUnits, isNotEmpty, reason: field.code);
      expect(field.acceptedUnits, contains(field.canonicalUnit));
    }
  });

  test('required service families are represented', () {
    expect(
      DispatchServiceTaxonomy.servicesForCategory(
        DispatchServiceCategoryCode.transportation,
      ).map((service) => service.code),
      containsAll(<String>[
        'transport_flat_deck',
        'transport_lowboy',
        'transport_hotshot',
        'transport_pipe_hauling',
        'transport_heavy_equipment',
        'transport_oversize_overweight',
      ]),
    );
    expect(
      DispatchServiceTaxonomy.servicesForCategory(
        DispatchServiceCategoryCode.pilotOversizeSupport,
      ).map((service) => service.code),
      containsAll(<String>[
        'pilot_escort_vehicle',
        'pilot_high_pole',
        'pilot_route_survey',
        'pilot_traffic_control',
        'pilot_permit_assistance',
      ]),
    );
    expect(
      DispatchServiceTaxonomy.servicesForCategory(
        DispatchServiceCategoryCode.craneLifting,
      ).map((service) => service.code),
      containsAll(<String>[
        'crane_picker_truck',
        'crane_mobile_crane',
        'crane_telehandler',
        'crane_forklift',
        'crane_rigging',
      ]),
    );
    expect(
      DispatchServiceTaxonomy.servicesForCategory(
        DispatchServiceCategoryCode.industrialFieldServices,
      ).map((service) => service.code),
      containsAll(<String>[
        'field_grading',
        'field_road_maintenance',
        'field_hydrovac',
        'field_mobile_mechanic',
        'field_mobile_welding',
        'field_towing_recovery',
        'field_site_support',
      ]),
    );
  });

  test('legacy Dispatch labels resolve to stable service codes', () {
    const expected = <String, String>{
      'Flat deck': 'transport_flat_deck',
      'Step deck': 'transport_step_deck',
      'Lowboy': 'transport_lowboy',
      'Winch': 'transport_winch_truck',
      'Hotshot': 'transport_hotshot',
      'Pipe hauling': 'transport_pipe_hauling',
      'Heavy equipment': 'transport_heavy_equipment',
      'Oversize load': 'transport_oversize_overweight',
      'General freight': 'transport_general_freight',
      'Oilfield service': 'field_site_support',
      'Picker / crane': 'crane_picker_truck',
      'Towing / recovery': 'field_towing_recovery',
      'Local haul': 'transport_local_haul',
      'Long distance': 'transport_long_distance',
      'Pilot / escort': 'pilot_escort_vehicle',
      'Route survey': 'pilot_route_survey',
      'Traffic control': 'pilot_traffic_control',
      'Hazmat qualified': 'transport_dangerous_goods',
    };

    for (final entry in expected.entries) {
      expect(
        DispatchServiceTaxonomy.fromLegacyLabel(entry.key)?.code,
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('directory featured services span major provider families', () {
    final featured = DispatchServiceTaxonomy.featuredDirectoryServices
        .map((service) => service.code)
        .toSet();
    expect(featured, contains('pilot_escort_vehicle'));
    expect(featured, contains('transport_lowboy'));
    expect(featured, contains('crane_picker_truck'));
    expect(featured, contains('transport_hotshot'));
    expect(featured, contains('field_grading'));
    expect(featured, contains('field_mobile_mechanic'));
  });

  test('public taxonomy labels do not use marketplace auction terminology', () {
    final publicText = <String>[
      ...DispatchServiceTaxonomy.categories.map((category) => category.label),
      ...DispatchServiceTaxonomy.services.map((service) => service.label),
      ...DispatchServiceTaxonomy.capabilityFields.map((field) => field.label),
    ].join(' ').toLowerCase();

    expect(publicText, isNot(contains('auction')));
    expect(publicText, isNot(contains('bid')));
  });
}
