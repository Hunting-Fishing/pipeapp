import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_equipment_capability.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_service_taxonomy.dart';

void main() {
  test('legacy fleet services normalize to stable taxonomy codes', () {
    final draft = DispatchEquipmentCapabilityDraft.fromVehicle(
      'vehicle-1',
      const <String, dynamic>{
        'ownerUid': 'visual-carrier',
        'name': 'Pilot 12',
        'vehicleType': 'Pilot truck',
        'pilotTruck': true,
        'services': <String>['Pilot / escort', 'Route survey'],
        'available': true,
      },
    );

    expect(draft.equipmentType, DispatchEquipmentType.pilotEscort);
    expect(draft.normalizedServiceCodes, contains('pilot_escort_vehicle'));
    expect(draft.normalizedServiceCodes, contains('pilot_route_survey'));
  });

  test('capability values reject unknown fields and invalid numbers', () {
    const draft = DispatchEquipmentCapabilityDraft(
      name: 'Lowboy 7',
      equipmentType: DispatchEquipmentType.trailer,
      available: true,
      serviceCodes: <String>['transport_lowboy'],
      capabilityValues: <String, Object?>{
        'max_payload': 42000,
        'deck_length': -2,
        'oversize_capable': true,
        'not_a_real_capability': true,
      },
    );

    expect(draft.normalizedCapabilityValues['max_payload'], 42000.0);
    expect(draft.normalizedCapabilityValues['oversize_capable'], isTrue);
    expect(
      draft.normalizedCapabilityValues.containsKey('deck_length'),
      isFalse,
    );
    expect(
      draft.normalizedCapabilityValues.containsKey('not_a_real_capability'),
      isFalse,
    );
  });

  test('North American display units round trip to canonical storage', () {
    final payload = DispatchServiceTaxonomy.capabilityByCode('max_payload')!;
    final deckLength = DispatchServiceTaxonomy.capabilityByCode('deck_length')!;

    final pounds = DispatchCapabilityDisplayUnits.toDisplay(payload, 1000);
    final kilograms = DispatchCapabilityDisplayUnits.toCanonical(
      payload,
      pounds,
    );
    expect(kilograms, closeTo(1000, 0.001));
    expect(DispatchCapabilityDisplayUnits.label(payload), 'lb');

    final feet = DispatchCapabilityDisplayUnits.toDisplay(deckLength, 10);
    final metres = DispatchCapabilityDisplayUnits.toCanonical(deckLength, feet);
    expect(metres, closeTo(10, 0.001));
    expect(DispatchCapabilityDisplayUnits.label(deckLength), 'ft');
  });

  test('service selection only keeps known stable service codes', () {
    const draft = DispatchEquipmentCapabilityDraft(
      name: 'Picker 4',
      equipmentType: DispatchEquipmentType.cranePicker,
      available: true,
      serviceCodes: <String>[
        'crane_picker_truck',
        'crane_rigging',
        'unknown_service',
        'crane_picker_truck',
      ],
      capabilityValues: <String, Object?>{},
    );

    expect(draft.normalizedServiceCodes, const <String>[
      'crane_picker_truck',
      'crane_rigging',
    ]);
  });
}
