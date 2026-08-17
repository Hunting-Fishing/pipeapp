import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_directory.dart';

void main() {
  test('directory entry parses only public Dispatch profile fields', () {
    final entry = DispatchDirectoryEntry.fromPublicBusinessProfile(
      'company-1',
      {
        'publicName': 'North Ridge Services',
        'description': 'Industrial field services and hotshot support.',
        'dispatchProfile': {
          'operatingName': 'North Ridge Services',
          'businessType': 'corporation',
          'serviceCodes': [
            'transport_hotshot',
            'pilot_escort_vehicle',
          ],
          'serviceAreaLabel': 'Grande Prairie and 250 km radius',
          'availability': 'available_today',
          'emergencyCallout': true,
          'remoteSiteCapable': true,
          'homeLocation': {
            'label': 'Grande Prairie, Alberta',
            'point': const GeoPoint(55.17, -118.79),
            'precision': 'approximate_1km',
          },
        },
        'privateEmail': 'must-not-be-used@example.test',
      },
    );

    expect(entry.isDirectoryReady, isTrue);
    expect(entry.operatingName, 'North Ridge Services');
    expect(entry.serviceCodes, contains('transport_hotshot'));
    expect(entry.serviceAreaLabel, contains('Grande Prairie'));
    expect(entry.homeBasePoint, isNotNull);
  });

  test('directory filters combine service, availability and geography text', () {
    const entry = DispatchDirectoryEntry(
      id: 'company-1',
      operatingName: 'North Ridge Services',
      description: 'Oilfield hauling and escort support',
      website: '',
      businessTypeCode: 'corporation',
      serviceCodes: ['transport_hotshot', 'pilot_escort_vehicle'],
      serviceAreaLabel: 'Grande Prairie and 250 km radius',
      availabilityCode: 'available_now',
      emergencyCallout: true,
      remoteSiteCapable: true,
      homeBaseLabel: 'Grande Prairie, Alberta',
      homeBasePoint: null,
    );

    expect(
      entry.matches(
        const DispatchDirectoryFilters(
          serviceCode: 'transport_hotshot',
          availabilityCode: 'available_now',
          businessTypeCode: 'corporation',
          searchText: 'Grande Prairie',
          emergencyOnly: true,
          remoteOnly: true,
        ),
      ),
      isTrue,
    );
    expect(
      entry.matches(
        const DispatchDirectoryFilters(serviceCode: 'crane_mobile_crane'),
      ),
      isFalse,
    );
  });

  testWidgets('directory renders public cards and filters by service', (
    tester,
  ) async {
    const entries = [
      DispatchDirectoryEntry(
        id: 'hotshot',
        operatingName: 'Prairie Hotshot',
        description: 'Hotshot and remote site delivery.',
        website: '',
        businessTypeCode: 'owner_operator',
        serviceCodes: ['transport_hotshot'],
        serviceAreaLabel: 'Grande Prairie region',
        availabilityCode: 'available_now',
        emergencyCallout: true,
        remoteSiteCapable: true,
        homeBaseLabel: 'Grande Prairie, Alberta',
        homeBasePoint: null,
      ),
      DispatchDirectoryEntry(
        id: 'pilot',
        operatingName: 'Northern Pilot Cars',
        description: 'Pilot and escort support.',
        website: '',
        businessTypeCode: 'corporation',
        serviceCodes: ['pilot_escort_vehicle'],
        serviceAreaLabel: 'Northern Alberta',
        availabilityCode: 'available_this_week',
        emergencyCallout: false,
        remoteSiteCapable: true,
        homeBaseLabel: 'Peace River, Alberta',
        homeBasePoint: null,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarketplaceDispatchDirectoryPage(seedEntries: entries),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prairie Hotshot'), findsOneWidget);
    expect(find.text('Northern Pilot Cars'), findsOneWidget);
    expect(find.text('2 companies shown'), findsOneWidget);

    final serviceDropdown = find.byType(DropdownButtonFormField<String>).first;
    await tester.tap(serviceDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotshot').last);
    await tester.pumpAndSettle();

    expect(find.text('Prairie Hotshot'), findsOneWidget);
    expect(find.text('Northern Pilot Cars'), findsNothing);
    expect(find.text('1 company shown'), findsOneWidget);
  });

  testWidgets('directory has an explicit empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarketplaceDispatchDirectoryPage(seedEntries: []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No companies are listed yet'), findsOneWidget);
  });
}
