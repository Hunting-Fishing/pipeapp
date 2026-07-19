import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_property_details.dart';

void main() {
  test('acres and hectares are normalized for property listings', () {
    final fromAcres = convertPropertyArea(160, 'Acres');
    final fromHectares = convertPropertyArea(64.7497, 'Hectares');

    expect(fromAcres.acres, 160);
    expect(fromAcres.hectares, closeTo(64.7497, .001));
    expect(fromHectares.acres, closeTo(160, .01));
  });

  test('non-land building measures do not invent acreage', () {
    final conversion = convertPropertyArea(10000, 'Square feet');
    expect(conversion.hasLandMeasure, isFalse);
  });
}
