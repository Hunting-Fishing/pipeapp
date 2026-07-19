import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_listing_media.dart';

void main() {
  test('selected listing thumbnail takes precedence over upload order', () {
    final listing = {
      'imageUrls': [
        'https://example.com/one.jpg',
        'https://example.com/two.jpg'
      ],
      'thumbnailUrl': 'https://example.com/two.jpg',
    };

    expect(
        marketplaceListingThumbnailUrl(listing), 'https://example.com/two.jpg');
  });

  test('thumbnail falls back to first valid uploaded photo', () {
    final listing = {
      'imageUrls': ['https://example.com/one.jpg', ''],
      'thumbnailUrl': 'https://example.com/missing.jpg',
    };

    expect(
        marketplaceListingThumbnailUrl(listing), 'https://example.com/one.jpg');
  });
}
