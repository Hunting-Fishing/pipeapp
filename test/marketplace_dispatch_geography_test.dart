import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_company_profile.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_geography.dart';
import 'package:pipe_app/marketplace/marketplace_service_area.dart';

MarketplaceServiceArea _area() => const MarketplaceServiceArea(
      mode: ServiceAreaMode.radius,
      center: LatLng(55.170712, -118.794712),
      centerLabel: 'Grande Prairie, Alberta',
      radiusKm: 300,
      places: <ServiceAreaPlace>[
        ServiceAreaPlace(
          name: 'Grande Prairie',
          point: LatLng(55.170712, -118.794712),
          region: 'Alberta',
          country: 'Canada',
          countryCode: 'ca',
          osmType: 'relation',
          osmId: '12345',
          boundaryRings: <List<LatLng>>[
            <LatLng>[
              LatLng(55.10, -118.90),
              LatLng(55.20, -118.90),
              LatLng(55.20, -118.70),
            ],
          ],
        ),
      ],
    );

void main() {
  test('structured service area drives profile summary and home-base label',
      () {
    final profile = DispatchCompanyProfileDraft(
      companyName: 'Northline Heavy Haul Ltd.',
      operatingName: 'Northline Heavy Haul',
      businessType: DispatchBusinessType.corporation,
      description:
          'Heavy haul, pilot support and industrial transport serving northern Alberta and remote sites.',
      website: 'https://example.test',
      serviceCodes: const <String>['transport_lowboy'],
      serviceAreaLabel: 'Legacy text that should not win',
      availability: DispatchAvailability.availableNow,
      emergencyCallout: true,
      remoteSiteCapable: true,
      serviceArea: _area(),
    );

    expect(
      profile.effectiveServiceAreaLabel,
      'Grande Prairie, Alberta and within 300 km',
    );
    expect(profile.homeBaseLabel, 'Grande Prairie, Alberta');
    expect(profile.readyForDirectoryFoundation, isTrue);
  });

  test('public home location is approximate instead of exact GPS', () {
    final projected = DispatchPublicGeographyProjection.homeLocation(_area());
    final point = projected['point'] as GeoPoint;

    expect(projected['precision'], 'approximate_1km');
    expect(projected['source'], 'service_area_center');
    expect(point.latitude, 55.17);
    expect(point.longitude, -118.79);
    expect(point.latitude, isNot(55.170712));
    expect(point.longitude, isNot(-118.794712));
  });

  test('public service area strips exact place points and boundary geometry',
      () {
    final projected = DispatchPublicGeographyProjection.serviceArea(_area());
    final places = projected['places'] as List<dynamic>;
    final place = Map<String, dynamic>.from(places.single as Map);
    final center = projected['center'] as GeoPoint;

    expect(projected['mode'], 'radius');
    expect(projected['radiusKm'], 300);
    expect(projected['countryCodes'], contains('CA'));
    expect(center.latitude, 55.17);
    expect(center.longitude, -118.79);
    expect(place['name'], 'Grande Prairie');
    expect(place.containsKey('point'), isFalse);
    expect(place.containsKey('boundaryRings'), isFalse);
  });
}
