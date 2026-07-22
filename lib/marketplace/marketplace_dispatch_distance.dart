import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Returns the straight-line planning distance between two mapped points.
///
/// This is deliberately labelled as an estimate in the UI. Legal truck-route
/// distance can differ because of road access, bridges, borders and permits.
double? dispatchDistanceKm(GeoPoint? origin, GeoPoint? destination) {
  if (origin == null || destination == null) return null;
  const earthRadiusKm = 6371.0088;
  double radians(double degrees) => degrees * math.pi / 180;
  final lat1 = radians(origin.latitude);
  final lat2 = radians(destination.latitude);
  final deltaLat = radians(destination.latitude - origin.latitude);
  final deltaLon = radians(destination.longitude - origin.longitude);
  final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(lat1) *
          math.cos(lat2) *
          math.sin(deltaLon / 2) *
          math.sin(deltaLon / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

String dispatchDistanceLabel(Map<String, dynamic> data) {
  final distance = data['distanceKm'] as num?;
  if (distance == null || distance <= 0) return 'Distance needs mapped points';
  final source = '${data['distanceSource'] ?? ''}';
  final prefix = source == 'user_entered_route' ? '' : '~';
  final suffix =
      source == 'user_entered_route' ? 'route distance' : 'map estimate';
  return '$prefix${distance.round()} km $suffix';
}
