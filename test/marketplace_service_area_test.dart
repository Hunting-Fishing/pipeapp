import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_service_area.dart';

Map<String, dynamic> boundary({
  required String type,
  required String displayName,
  required Map<String, String> address,
}) =>
    {
      'addresstype': type,
      'display_name': displayName,
      'address': address,
      'geojson': {
        'type': 'Polygon',
        'coordinates': const [
          [
            [-120.9, 56.2],
            [-120.8, 56.2],
            [-120.8, 56.3],
            [-120.9, 56.2],
          ],
        ],
      },
    };

void main() {
  test('town mode selects Fort St. John, not Peace River region', () {
    final regionalDistrict = boundary(
      type: 'county',
      displayName: 'Peace River Regional District, British Columbia, Canada',
      address: const {
        'county': 'Peace River Regional District',
        'state': 'British Columbia',
      },
    );
    final fortStJohn = boundary(
      type: 'city',
      displayName:
          'Fort St. John, Peace River Regional District, British Columbia, Canada',
      address: const {
        'city': 'Fort St. John',
        'county': 'Peace River Regional District',
        'state': 'British Columbia',
      },
    );

    final selected = selectServiceAreaBoundaryCandidate(
      [regionalDistrict, fortStJohn],
      requestedName: 'Fort St. John',
      settlementOnly: true,
    );

    expect(selected, same(fortStJohn));
  });

  test('town mode rejects a county-only boundary', () {
    final selected = selectServiceAreaBoundaryCandidate(
      [
        boundary(
          type: 'county',
          displayName:
              'Peace River Regional District, British Columbia, Canada',
          address: const {'county': 'Peace River Regional District'},
        ),
      ],
      requestedName: 'Peace River Regional District',
      settlementOnly: true,
    );

    expect(selected, isNull);
  });
}
