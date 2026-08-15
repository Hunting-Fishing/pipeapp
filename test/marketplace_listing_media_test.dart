import 'package:flutter/material.dart';
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

  testWidgets('listing media uses industrial fallback when seller has no photo',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarketplaceListingMedia(
            listing: {
              'title': '5-1/2 J55 Casing',
              'category': 'Pipe, Tubing & Materials',
              'productType': 'Casing',
              'imageUrls': <String>[],
            },
          ),
        ),
      ),
    );

    expect(find.text('Seller photo not provided'), findsOneWidget);
    expect(find.text('Casing'), findsOneWidget);
  });

  testWidgets('listing media can surface the photo count', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarketplaceListingMedia(
            listing: {
              'title': 'Pipe bundle',
              'category': 'Pipe, Tubing & Materials',
              'imageUrls': <String>[
                'invalid://one',
                'invalid://two',
                'invalid://three',
              ],
            },
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('3 photos'), findsOneWidget);
  });
}
