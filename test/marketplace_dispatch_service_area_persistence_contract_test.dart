import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('company profile editor uses the existing open-map service area picker', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_company_profile.dart',
    ).readAsStringSync();

    expect(source, contains('MarketplaceServiceAreaPicker.show'));
    expect(source, contains('Set service area on map'));
    expect(source, contains('Edit service area on map'));
    expect(source, contains('Approximate home base:'));
  });

  test('public geography is approximate while exact service area stays private', () {
    final repository = File(
      'lib/marketplace/marketplace_dispatch_company_profile_repository.dart',
    ).readAsStringSync();
    final geography = File(
      'lib/marketplace/marketplace_dispatch_geography.dart',
    ).readAsStringSync();

    expect(
      repository,
      contains('DispatchPublicGeographyProjection.homeLocation'),
    );
    expect(
      repository,
      contains('DispatchPublicGeographyProjection.serviceArea'),
    );
    expect(repository, contains("'serviceArea': serviceArea.toMap()"));
    expect(geography, contains("precisionCode = 'approximate_1km'"));
    expect(geography, contains('(value * 100).roundToDouble() / 100'));

    final publicStart = repository.indexOf(
      'final publicProfile = <String, dynamic>{',
    );
    final privateStart = repository.indexOf(
      'final privateProfile = <String, dynamic>{',
    );
    expect(publicStart, greaterThanOrEqualTo(0));
    expect(privateStart, greaterThan(publicStart));

    final publicBlock = repository.substring(publicStart, privateStart);
    expect(publicBlock, isNot(contains('serviceArea.toMap()')));
    expect(publicBlock, isNot(contains("'companyName'")));
  });

  test('public service-area projection omits exact place points and boundaries', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_geography.dart',
    ).readAsStringSync();

    expect(source, contains("'name': place.name.trim()"));
    expect(source, contains("'osmId': place.osmId.trim()"));
    expect(source, isNot(contains("'point': place.point")));
    expect(source, isNot(contains("'boundaryRings': place.boundaryRings")));
  });
}
