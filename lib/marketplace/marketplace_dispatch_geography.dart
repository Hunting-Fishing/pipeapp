import 'package:cloud_firestore/cloud_firestore.dart';

import 'marketplace_service_area.dart';

class DispatchPublicGeographyProjection {
  const DispatchPublicGeographyProjection._();

  static const String precisionCode = 'approximate_1km';

  static Map<String, dynamic> homeLocation(MarketplaceServiceArea area) => {
        'label': area.centerLabel.trim(),
        'point': _approximatePoint(
          area.center.latitude,
          area.center.longitude,
        ),
        'precision': precisionCode,
        'source': 'service_area_center',
      };

  static GeoPoint _approximatePoint(double latitude, double longitude) =>
      GeoPoint(
        _roundCoordinate(latitude),
        _roundCoordinate(longitude),
      );

  static double _roundCoordinate(double value) =>
      (value * 100).roundToDouble() / 100;
}
