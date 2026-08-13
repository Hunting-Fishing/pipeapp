import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pipe_app/marketplace/marketplace_listing_insights.dart';

void main() {
  test('activity label includes every public listing counter', () {
    const activity = MarketplaceListingActivity(
      views: 3,
      saves: 1,
      shares: 0,
      likes: 2,
      offers: 1,
    );

    expect(activity.label, '3 views • 1 save • 0 shares • 2 likes • 1 offer');
  });

  test('location label keeps public place and adds missing region context', () {
    expect(
      marketplacePublicLocationLabel(
        publicName: 'Edmonton area',
        nearestTown: 'Edmonton',
        region: 'Alberta',
        country: 'Canada',
      ),
      'Edmonton area, Alberta, Canada',
    );
    expect(
      marketplacePublicLocationLabel(
        publicName: 'Grande Prairie, Alberta, Canada',
        nearestTown: 'Grande Prairie',
        region: 'Alberta',
        country: 'Canada',
      ),
      'Grande Prairie, Alberta, Canada',
    );
    expect(
      marketplacePublicLocationLabel(
        publicName: 'Grande Prairie area, AB',
        nearestTown: 'Grande Prairie',
        region: 'Alberta',
        country: 'Canada',
      ),
      'Grande Prairie area, AB, Canada',
    );
  });

  test('distance uses the viewer setup point and clearly stays approximate',
      () {
    final label = marketplaceDistanceLabel(
      viewer: const LatLng(55.1707, -118.7947),
      listing: const LatLng(53.5461, -113.4938),
      viewerLabel: 'Grande Prairie',
    );

    expect(label, startsWith('About '));
    expect(label, endsWith(' km from Grande Prairie'));
  });

  test('viewer community prefers the private setup location locally', () {
    final community = marketplaceViewerCommunityFromData(
      user: {
        'primaryCommunityLocation': {
          'exactGeoPoint': const GeoPoint(55.17, -118.79),
          'publicName': 'Grande Prairie area',
        },
      },
      publicSeller: {
        'primaryCommunityGeoPoint': const GeoPoint(55.15, -118.8),
        'baseCommunity': 'Grande Prairie, AB',
      },
    );

    expect(community?.point, const LatLng(55.17, -118.79));
    expect(community?.label, 'Grande Prairie area');
  });
}
