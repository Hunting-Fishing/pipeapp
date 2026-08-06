import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pipe_app/marketplace/marketplace_location.dart';
import 'package:pipe_app/marketplace/marketplace_profile_community.dart';
import 'package:pipe_app/marketplace/open_address_autocomplete.dart';

void main() {
  test('settlement prediction becomes a map-backed primary community', () {
    const prediction = OpenAddress(
      label: 'Dawson Creek, British Columbia, Canada',
      point: LatLng(55.7596, -120.2377),
      city: 'Dawson Creek',
      region: 'British Columbia',
      country: 'Canada',
      countryCode: 'CA',
      placeType: 'city',
      osmType: 'N',
      osmId: '123',
    );

    final community = marketplaceCommunityFromOpenAddress(prediction);
    expect(community.nearestTown, 'Dawson Creek');
    expect(community.region, 'British Columbia');
    expect(community.country, 'Canada');
    expect(community.point.latitude, closeTo(55.7596, .00001));
    expect(community.visibility.value, 'approximate');
    expect(primaryCommunityLabel(community),
        'Dawson Creek, British Columbia');
  });
}
