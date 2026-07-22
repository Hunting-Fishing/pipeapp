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

  test('distance label distinguishes mapped and entered route estimates', () {
    expect(
        dispatchDistanceLabel(
            {'distanceKm': 118.4, 'distanceSource': 'coordinate_estimate'}),
        '~118 km map estimate');
    expect(
        dispatchDistanceLabel(
            {'distanceKm': 143, 'distanceSource': 'user_entered_route'}),
        '143 km route distance');
    expect(dispatchDistanceLabel(const {}), 'Distance needs mapped points');
  });
}
