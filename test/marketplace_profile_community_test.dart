import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pipe_app/marketplace/marketplace_location.dart';
import 'package:pipe_app/marketplace/marketplace_profile_community.dart';

void main() {
  const location = MarketplaceLocation(
    point: LatLng(55.1707, -118.7947),
    visibility: LocationVisibility.exact,
    publicName: 'Grande Prairie, Alberta',
    address: 'Private street address',
    nearestTown: 'Grande Prairie',
    accessNotes: 'Private gate notes',
    region: 'Alberta',
    postalCode: 'T8V 0X9',
    country: 'Canada',
  );

  test('primary community keeps exact coordinates private', () {
    final privateData = primaryCommunityPrivateData(location, 'seller-1');
    final point = privateData['exactGeoPoint'] as GeoPoint;
    expect(point.latitude, 55.1707);
    expect(point.longitude, -118.7947);
    expect(privateData['fullAddress'], 'Private street address');
    expect(privateData['ownerUid'], 'seller-1');
  });

  test('primary community publishes only broad-area discovery data', () {
    final publicData = primaryCommunityPublicData(location);
    final point = publicData['publicGeoPoint'] as GeoPoint;
    expect(publicData['locationVisibility'], 'approximate');
    expect(point.latitude, 55.15);
    expect(point.longitude, -118.8);
    expect(publicData, isNot(contains('fullAddress')));
    expect(publicData, isNot(contains('accessNotes')));
  });
}
