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
  final routed = data['routeDistanceKm'] as num?;
  final status = '${data['routeStatus'] ?? ''}';
  if (routed != null && routed > 0) {
    final qualifier = status == 'review_required' ? ' • review required' : '';
    return '${routed.round()} km truck route$qualifier';
  }
  final direct = data['straightLineDistanceKm'] as num?;
  if (direct != null && direct > 0) {
    final pending = status == 'pending_provider'
        ? ' • truck route pending'
        : ' • truck route not configured';
    return '~${direct.round()} km straight-line$pending';
  }
  final distance = data['distanceKm'] as num?;
  if (distance == null || distance <= 0) {
    return 'Truck route needs mapped pickup and delivery';
  }
  final source = '${data['distanceSource'] ?? ''}';
  final trustedRoute = const {
    'here_truck_route',
    'verified_truck_route',
  }.contains(source);
  final prefix = trustedRoute ? '' : '~';
  final suffix = trustedRoute ? 'truck route' : 'legacy distance estimate';
  return '$prefix${distance.round()} km $suffix';
}
