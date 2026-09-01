import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_directory.dart';

void main() {
  test('Directory entry parses the server-owned public projection', () {
    final entry = DispatchDirectoryEntry.fromDirectoryProjection(
      'northline',
      {
        'companyName': 'Northline Heavy Haul',
        'operatingName': 'Northline Heavy Haul',
        'serviceCodes': [
          'transport_lowboy',
          'transport_pipe_hauling',
        ],
        'searchTokens': ['northline', 'heavy', 'haul', 'edmonton'],
        'serviceAreaSummary': 'Edmonton and Western Canada',
        'publicLocation': {
          'label': 'Edmonton, Alberta',
          'precision': 'approximate_1km',
        },
        'mapPoint': const GeoPoint(53.55, -113.49),
        'availability': 'available_now',
        'businessType': 'corporation',
        'emergencyCallout': false,
        'remoteSiteCapable': true,
        'publicSummary': 'Heavy haul and pipe transportation.',
        'website': 'https://www.pipebuyer.com',
        'profileCompleteness': 100,
        'privateEmail': 'must-not-be-used@example.test',
        'policyNumber': 'PRIVATE-123',
      },
    );

    expect(entry.isDirectoryReady, isTrue);
    expect(entry.operatingName, 'Northline Heavy Haul');
    expect(entry.serviceAreaLabel, 'Edmonton and Western Canada');
    expect(entry.homeBaseLabel, 'Edmonton, Alberta');
    expect(entry.homeBasePoint, isNotNull);
    expect(entry.serviceCodes, contains('transport_lowboy'));
  });

  test('Directory page append deduplicates and keeps alphabetical order', () {
    DispatchDirectoryEntry entry(String id, String name) =>
        DispatchDirectoryEntry.fromDirectoryProjection(id, {
          'companyName': name,
          'serviceCodes': ['transport_hotshot'],
          'serviceAreaSummary': 'Northern Alberta',
        });

    final first = DispatchDirectoryPageData(
      entries: [entry('beta', 'Beta Hauling'), entry('alpha', 'Alpha Hauling')],
      cursor: null,
      hasMore: true,
    );
    final second = DispatchDirectoryPageData(
      entries: [entry('alpha', 'Alpha Hauling'), entry('gamma', 'Gamma Hauling')],
      cursor: null,
      hasMore: false,
    );

    final merged = first.append(second);

    expect(merged.entries.map((entry) => entry.id), ['alpha', 'beta', 'gamma']);
    expect(merged.hasMore, isFalse);
  });

  test('Directory UI wires cursor pagination without the old placeholder', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> _loadMore() async'));
    expect(source, contains('after: current.cursor'));
    expect(source, contains('final merged = current.append(nextPage);'));
    expect(source, contains("'Load more companies'"));
    expect(
      source,
      isNot(contains('Pagination will be wired into the next Directory data slice.')),
    );
  });

  test('Directory filters preserve structured service and capability matching', () {
    final entry = DispatchDirectoryEntry.fromDirectoryProjection(
      'pilot',
      {
        'companyName': 'Peace Country Pilot & Escort',
        'serviceCodes': ['pilot_escort_vehicle', 'pilot_high_pole'],
        'serviceAreaSummary': 'Fort St. John and Dawson Creek',
        'publicLocation': {'label': 'Fort St. John, British Columbia'},
        'availability': 'available_today',
        'businessType': 'owner_operator',
        'emergencyCallout': true,
        'remoteSiteCapable': true,
        'publicSummary': 'Pilot and high-pole support.',
      },
    );

    expect(
      entry.matches(
        const DispatchDirectoryFilters(
          searchText: 'Fort St. John',
          serviceCode: 'pilot_escort_vehicle',
          availabilityCode: 'available_today',
          businessTypeCode: 'owner_operator',
          emergencyOnly: true,
          remoteOnly: true,
        ),
      ),
      isTrue,
    );
    expect(
      entry.matches(
        const DispatchDirectoryFilters(serviceCode: 'crane_picker_truck'),
      ),
      isFalse,
    );
  });
}
