import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/open_address_autocomplete.dart';

void main() {
  test('Fort St. John city result does not become Peace River county', () {
    final address = openAddressFromFeature({
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [-120.8469, 56.2465],
      },
      'properties': {
        'type': 'city',
        'name': 'Fort St. John',
        'county': 'Peace River',
        'state': 'British Columbia',
        'country': 'Canada',
        'countrycode': 'CA',
        'osm_type': 'R',
        'osm_id': '7908930',
      },
    });

    expect(address.city, 'Fort St. John');
    expect(address.label, 'Fort St. John, British Columbia, Canada');
    expect(address.placeType, 'city');
    expect(address.osmId, '7908930');
  });
}
