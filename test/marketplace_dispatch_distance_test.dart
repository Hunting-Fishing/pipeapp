import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_distance.dart';

void main() {
  test('mapped dispatch distance is calculated in kilometres', () {
    const grandePrairie = GeoPoint(55.1707, -118.7947);
    const dawsonCreek = GeoPoint(55.7596, -120.2377);
    final distance = dispatchDistanceKm(grandePrairie, dawsonCreek);

    expect(distance, isNotNull);
    expect(distance!, greaterThan(100));
    expect(distance, lessThan(130));
  });

  test('distance label distinguishes server estimates and truck routes', () {
    expect(
        dispatchDistanceLabel({
          'straightLineDistanceKm': 118.4,
          'routeStatus': 'pending_provider',
        }),
        '~118 km straight-line • truck route pending');
    expect(
        dispatchDistanceLabel({
          'routeDistanceKm': 143,
          'routeStatus': 'ready',
        }),
        '143 km truck route');
    expect(
      dispatchDistanceLabel(const {}),
      'Truck route needs mapped pickup and delivery',
    );
  });
}
