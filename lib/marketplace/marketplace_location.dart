import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum LocationVisibility { exact, approximate, onRequest, hidden }

extension LocationVisibilityText on LocationVisibility {
  String get value => switch (this) {
        LocationVisibility.exact => 'exact',
        LocationVisibility.approximate => 'approximate',
        LocationVisibility.onRequest => 'on_request',
        LocationVisibility.hidden => 'hidden',
      };

  String get label => switch (this) {
        LocationVisibility.exact => 'Show exact location',
        LocationVisibility.approximate => 'Show approximate area',
        LocationVisibility.onRequest => 'Location available by request',
        LocationVisibility.hidden => 'Do not show on map',
      };
}

LocationVisibility locationVisibilityFromValue(
  String value, {
  LocationVisibility fallback = LocationVisibility.approximate,
}) =>
    LocationVisibility.values.firstWhere(
      (item) => item.value == value,
      orElse: () => fallback,
    );

class MarketplaceLocation {
  const MarketplaceLocation({
    required this.point,
    required this.visibility,
    required this.publicName,
    this.address = '',
    this.nearestTown = '',
    this.accessNotes = '',
    this.region = '',
    this.postalCode = '',
    this.country = '',
  });

  final LatLng point;
  final LocationVisibility visibility;
  final String publicName;
  final String address;
  final String nearestTown;
  final String accessNotes;
  final String region;
  final String postalCode;
  final String country;

  factory MarketplaceLocation.fromPrivateData(Map<String, dynamic> data) {
    final point = data['exactGeoPoint'];
    final visibilityValue = '${data['visibility'] ?? 'hidden'}';
    return MarketplaceLocation(
      point: point is GeoPoint
          ? LatLng(point.latitude, point.longitude)
          : const LatLng(55.1707, -118.7947),
      visibility: locationVisibilityFromValue(visibilityValue,
          fallback: LocationVisibility.hidden),
      publicName:
          '${data['publicName'] ?? data['nearestTown'] ?? 'Business yard'}',
      address: '${data['fullAddress'] ?? ''}',
      nearestTown: '${data['nearestTown'] ?? ''}',
      accessNotes: '${data['accessNotes'] ?? ''}',
      region: '${data['region'] ?? ''}',
      postalCode: '${data['postalCode'] ?? ''}',
      country: '${data['country'] ?? ''}',
    );
  }

  GeoPoint get exactGeoPoint => GeoPoint(point.latitude, point.longitude);

  /// A deterministic broad-area point. Exact coordinates never enter the
  /// public listing unless the seller explicitly selects `exact`.
  GeoPoint? get publicGeoPoint => switch (visibility) {
        LocationVisibility.exact => exactGeoPoint,
        LocationVisibility.approximate ||
        LocationVisibility.onRequest =>
          GeoPoint((point.latitude * 20).round() / 20,
              (point.longitude * 20).round() / 20),
        LocationVisibility.hidden => null,
      };

  Map<String, dynamic> publicData() => {
        'locationVisibility': visibility.value,
        'publicLocationName': publicName.trim(),
        'nearestTown': nearestTown.trim(),
        'region': region.trim(),
        'country': country.trim(),
        'approximateRadiusKm': visibility == LocationVisibility.exact ? 0 : 10,
        if (publicGeoPoint case final point?) 'publicGeoPoint': point,
      };

  Map<String, dynamic> privateData(String ownerUid) => {
        'ownerUid': ownerUid,
        'exactGeoPoint': exactGeoPoint,
        'fullAddress': address.trim(),
        'nearestTown': nearestTown.trim(),
        'region': region.trim(),
        'postalCode': postalCode.trim(),
        'country': country.trim(),
        'accessNotes': accessNotes.trim(),
        'visibility': visibility.value,
        'publicName': publicName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
