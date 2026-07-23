import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_listing_query.dart';

void main() {
  test('appendUniqueById preserves order and removes duplicate pages', () {
    final merged = appendUniqueById(
      const [
        (id: 'a', value: 1),
        (id: 'b', value: 2),
      ],
      const [
        (id: 'b', value: 20),
        (id: 'c', value: 3),
      ],
      (item) => item.id,
    );

    expect(merged.map((item) => item.id), ['a', 'b', 'c']);
    expect(merged.map((item) => item.value), [1, 2, 3]);
  });

  test('marketplace listing page size is intentionally bounded', () {
    expect(marketplaceListingPageSize, 24);
  });
}
