import 'package:flutter_test/flutter_test.dart';
import 'package:pipeapp/marketplace/marketplace_service_area.dart';
import 'package:pipeapp/marketplace/open_address_autocomplete.dart';

void main() {
  group('Photon settlement classification', () {
    test('Fort St. John keeps Peace River as parent district, not city', () {
      final address = openAddressFromPhotonFeature({
        'properties': {
          'name': 'Fort St. John',
          'type': 'city',
          'district': 'Peace River',
          'state': 'British Columbia',
          'country': 'Canada',
          'countrycode': 'CA',
          'osm_type': 'N',
          'osm_id': '2865722923',
        },
        'geometry': {
          'coordinates': [-120.8472, 56.2528],
        },
      });

      expect(address.name, 'Fort St. John');
      expect(address.city, 'Fort St. John');
      expect(address.district, 'Peace River');
      expect(address.region, 'British Columbia');
      expect(
        openAddressMatchesSearchType(
          address,
          OpenAddressSearchType.settlement,
        ),
        isTrue,
      );
    });

    test('regional district is administrative and never a town result', () {
      final address = openAddressFromPhotonFeature({
        'properties': {
          'name': 'Peace River Regional District',
          'type': 'district',
          'state': 'British Columbia',
          'country': 'Canada',
          'countrycode': 'CA',
          'osm_type': 'R',
          'osm_id': '1234',
        },
        'geometry': {
          'coordinates': [-122.7, 56.6],
        },
      });

      expect(address.city, isEmpty);
      expect(
        openAddressMatchesSearchType(
          address,
          OpenAddressSearchType.settlement,
        ),
        isFalse,
      );
      expect(
        openAddressMatchesSearchType(
          address,
          OpenAddressSearchType.administrative,
        ),
        isTrue,
      );
    });

    test('duplicate town node and relation prefer relation result', () {
      final node = OpenAddress(
        label: 'Dawson Creek, Peace River, British Columbia, Canada',
        point: const LatLng(55.7605, -120.2364),
        name: 'Dawson Creek',
        city: 'Dawson Creek',
        district: 'Peace River',
        region: 'British Columbia',
        country: 'Canada',
        countryCode: 'CA',
        placeType: 'city',
        osmType: 'N',
        osmId: '1141667381',
      );
      final relation = OpenAddress(
        label: node.label,
        point: node.point,
        name: node.name,
        city: node.city,
        district: node.district,
        region: node.region,
        country: node.country,
        countryCode: node.countryCode,
        placeType: node.placeType,
        osmType: 'R',
        osmId: '9999',
      );

      final values = dedupeOpenAddressResults([node, relation]);
      expect(values, hasLength(1));
      expect(values.single.osmType, 'R');
      expect(values.single.osmId, '9999');
    });
  });

  group('service-area polygon classification', () {
    Map<String, dynamic> polygonCandidate({
      required String name,
      required String addressType,
      required Map<String, dynamic> address,
      String adminLevel = '',
    }) =>
        {
          'name': name,
          'display_name': '$name, British Columbia, Canada',
          'addresstype': addressType,
          'address': address,
          'namedetails': {'name': name},
          'extratags': {
            if (adminLevel.isNotEmpty) 'admin_level': adminLevel,
          },
          'geojson': {
            'type': 'Polygon',
            'coordinates': [
              [
                [-121.0, 56.0],
                [-120.8, 56.0],
                [-120.8, 56.2],
                [-121.0, 56.0],
              ],
            ],
          },
        };

    test('town mode rejects Peace River Regional District for Fort St. John', () {
      final broad = polygonCandidate(
        name: 'Peace River Regional District',
        addressType: 'county',
        adminLevel: '6',
        address: {
          'city': 'Fort St. John',
          'county': 'Peace River Regional District',
          'state': 'British Columbia',
          'country': 'Canada',
        },
      );
      final municipality = polygonCandidate(
        name: 'Fort St. John',
        addressType: 'city',
        adminLevel: '8',
        address: {
          'city': 'Fort St. John',
          'county': 'Peace River Regional District',
          'state': 'British Columbia',
          'country': 'Canada',
        },
      );

      final selected = selectServiceAreaBoundaryCandidate(
        candidates: [broad, municipality],
        requestedName: 'Fort St. John',
        mode: ServiceAreaMode.places,
        countryCode: 'CA',
      );

      expect(selected['name'], 'Fort St. John');
    });

    test('town mode rejects broader Canadian admin level even with city text', () {
      final broad = polygonCandidate(
        name: 'Fort St. John',
        addressType: 'administrative',
        adminLevel: '6',
        address: {
          'city': 'Fort St. John',
          'county': 'Peace River Regional District',
          'state': 'British Columbia',
          'country': 'Canada',
        },
      );

      final selected = selectServiceAreaBoundaryCandidate(
        candidates: [broad],
        requestedName: 'Fort St. John',
        mode: ServiceAreaMode.places,
        countryCode: 'CA',
      );

      expect(selected, isEmpty);
    });

    test('region mode accepts Peace River Regional District boundary', () {
      final region = polygonCandidate(
        name: 'Peace River Regional District',
        addressType: 'county',
        adminLevel: '6',
        address: {
          'county': 'Peace River Regional District',
          'state': 'British Columbia',
          'country': 'Canada',
        },
      );

      final selected = selectServiceAreaBoundaryCandidate(
        candidates: [region],
        requestedName: 'Peace River Regional District',
        mode: ServiceAreaMode.regions,
        countryCode: 'CA',
      );

      expect(selected['name'], 'Peace River Regional District');
    });

    test('region mode accepts province boundary for British Columbia', () {
      final province = polygonCandidate(
        name: 'British Columbia',
        addressType: 'state',
        adminLevel: '4',
        address: {
          'state': 'British Columbia',
          'country': 'Canada',
        },
      );

      final selected = selectServiceAreaBoundaryCandidate(
        candidates: [province],
        requestedName: 'British Columbia',
        mode: ServiceAreaMode.regions,
        countryCode: 'CA',
      );

      expect(selected['name'], 'British Columbia');
    });
  });
}
