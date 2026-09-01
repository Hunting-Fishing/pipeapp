import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_public_detail.dart';

void main() {
  test('Dispatch public detail parses only bounded display fields', () {
    final detail = DispatchPublicDetail.fromDirectoryProjection({
      'serviceCodes': ['transport_hotshot', 'field_mobile_mechanic'],
      'serviceAreaSummary': 'Grande Prairie and 250 km radius',
      'availability': 'available_today',
      'emergencyCallout': true,
      'remoteSiteCapable': true,
      'publicLocation': {'label': 'Grande Prairie, Alberta'},
      'publicServiceArea': {
        'mode': 'radius',
        'centerLabel': 'Grande Prairie, Alberta',
        'radiusKm': 250,
      },
      'mapPoint': {'latitude': 55.17, 'longitude': -118.79},
      'geohash': 'c3gjg0',
      'privateEmail': 'must-not-render@example.test',
      'policyNumber': 'PRIVATE-123',
    });

    expect(detail.hasContent, isTrue);
    expect(detail.serviceCodes, contains('transport_hotshot'));
    expect(detail.serviceLabel('transport_hotshot'), 'Hotshot');
    expect(detail.serviceAreaSummary, contains('Grande Prairie'));
    expect(detail.availabilityLabel, 'Available today');
    expect(detail.emergencyCallout, isTrue);
    expect(detail.remoteSiteCapable, isTrue);
    expect(detail.approximateHomeBase, 'Grande Prairie, Alberta');
    expect(detail.hasPublishedRadius, isTrue);
    expect(detail.serviceAreaRadiusKm, 250);
  });

  testWidgets('Dispatch detail card shows simple public service information', (
    tester,
  ) async {
    final detail = DispatchPublicDetail.fromDirectoryProjection({
      'serviceCodes': ['transport_hotshot'],
      'serviceAreaSummary': 'Grande Prairie region',
      'availability': 'available_now',
      'emergencyCallout': true,
      'remoteSiteCapable': true,
      'publicLocation': {'label': 'Grande Prairie, Alberta'},
      'publicServiceArea': {
        'mode': 'radius',
        'centerLabel': 'Grande Prairie, Alberta',
        'radiusKm': 250,
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DispatchPublicDetailCard(detail: detail),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dispatch services'), findsOneWidget);
    expect(find.text('Hotshot'), findsOneWidget);
    expect(find.text('Emergency callout'), findsOneWidget);
    expect(find.text('Remote-site capable'), findsOneWidget);
    expect(find.text('Grande Prairie region'), findsOneWidget);
    expect(
      find.textContaining('Within 250 km of Grande Prairie'),
      findsOneWidget,
    );
    expect(find.textContaining('Exact yards, homes'), findsOneWidget);
    expect(find.textContaining('must-not-render'), findsNothing);
    expect(find.textContaining('PRIVATE-123'), findsNothing);
  });

  test(
    'Seller storefront treats Dispatch projection as optional signed-in data',
    () {
      final source = File(
        'lib/marketplace/marketplace_public_profile_page.dart',
      ).readAsStringSync();
      final detailSource = File(
        'lib/marketplace/marketplace_dispatch_public_detail.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('Future<Map<String, dynamic>> _loadDispatchDirectoryDetail()'),
      );
      expect(source, contains('FirebaseAuth.instance.currentUser == null'));
      expect(source, contains(".collection('dispatch_directory_entries')"));
      expect(source, contains('catch (_)'));
      expect(
        source,
        contains('DispatchPublicDetailCard(detail: dispatchDetail)'),
      );
      expect(detailSource, isNot(contains('mapPoint')));
      expect(detailSource, isNot(contains('geohash')));
      expect(detailSource, isNot(contains('privateEmail')));
      expect(detailSource, isNot(contains('policyNumber')));
    },
  );
}
