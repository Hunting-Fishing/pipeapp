import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final openAddressSource =
      File('lib/marketplace/open_address_autocomplete.dart').readAsStringSync();
  final serviceAreaSource =
      File('lib/marketplace/marketplace_service_area.dart').readAsStringSync();

  group('service-area town/region classification source contract', () {
    test('town parsing keeps settlement separate from district and county', () {
      expect(openAddressSource, contains('final String district;'));
      expect(openAddressSource, contains('openAddressFromPhotonFeature'));
      expect(openAddressSource, contains('final explicitSettlement = ['));
      expect(
        openAddressSource,
        contains("final district = [read('district'), read('county')]"),
      );
      expect(
        openAddressSource,
        contains('_settlementPlaceTypes.contains(item.placeType.toLowerCase())'),
      );
    });

    test('town results do not classify district or county as settlements', () {
      final settlementBlock = RegExp(
        r"const _settlementPlaceTypes = \{([\s\S]*?)\};",
      ).firstMatch(openAddressSource);
      expect(settlementBlock, isNotNull);
      final body = settlementBlock!.group(1)!;
      expect(body, isNot(contains("'district'")));
      expect(body, isNot(contains("'county'")));
      expect(body, contains("'city'"));
      expect(body, contains("'town'"));
    });

    test('duplicate semantic town results prefer an OSM relation', () {
      expect(openAddressSource, contains('dedupeOpenAddressResults'));
      expect(openAddressSource, contains('_isOsmRelation(current.osmType)'));
      expect(openAddressSource, contains('_isOsmRelation(item.osmType)'));
    });

    test('town boundary lookup is structured and rejects broad Canadian area', () {
      expect(serviceAreaSource, contains('selectServiceAreaBoundaryCandidate'));
      expect(serviceAreaSource, contains("'city': requestedName"));
      expect(serviceAreaSource, contains("'state': address.region"));
      expect(serviceAreaSource, contains("'country': address.country"));
      expect(
        serviceAreaSource,
        contains("'countrycodes': address.countryCode.toLowerCase()"),
      );
      expect(
        serviceAreaSource,
        contains("adminLevel.isNotEmpty && adminLevel != '8'"),
      );
      expect(
        serviceAreaSource,
        contains('a surrounding district will not be substituted'),
      );
    });

    test('region identity and polygon requirements are explicit', () {
      expect(serviceAreaSource, contains('_regionName(address)'));
      expect(
        serviceAreaSource,
        contains('it was not added. Choose another region result with a mapped boundary'),
      );
      expect(serviceAreaSource, contains("'county'"));
      expect(serviceAreaSource, contains("'province'"));
      expect(serviceAreaSource, contains("'country'"));
    });
  });
}
