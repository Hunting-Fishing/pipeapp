import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_activity_presentation.dart';

void main() {
  test('listing activity context shows image quantity and asking price', () {
    final context = MarketplaceListingActivityContext.fromMaps(
      embedded: const {},
      listing: const {
        'title': 'Premium tubing lot',
        'imageUrls': ['https://example.test/first.jpg'],
        'thumbnailUrl': 'https://example.test/first.jpg',
        'quantity': 120,
        'price': 75,
        'priceBasis': 'Per piece',
      },
    );

    expect(context.title, 'Premium tubing lot');
    expect(context.thumbnailUrl, 'https://example.test/first.jpg');
    expect(context.commerceLine, r'120 pieces • $75.00 • Per piece');
  });

  test('notification fallback explains messages using listing name', () {
    const listing = MarketplaceListingActivityContext(
      title: 'D8 dozer',
      thumbnailUrl: null,
      quantity: 1,
      price: 250000,
      priceBasis: 'Total asking price',
      category: 'Heavy Equipment',
      sellerName: 'Northern Equipment',
    );

    expect(
      marketplaceNotificationBody(const {'type': 'message'}, listing),
      'A marketplace member sent you a message about D8 dozer.',
    );
  });

  test('greeting prefers business then saved personal display name', () {
    expect(
      marketplaceGreetingName(
        account: const {'display_name': 'Jordan Bailey'},
        publicBusiness: const {'publicName': 'Gold City Services'},
        email: 'fallback@example.com',
      ),
      'Gold City Services',
    );
    expect(
      marketplaceGreetingName(
        account: const {'display_name': 'Jordan Bailey'},
        email: 'fallback@example.com',
      ),
      'Jordan Bailey',
    );
  });

  test('seller best offer uses each buyers latest active proposal only', () {
    final best = marketplaceBestSellerOfferTotal(const [
      {
        'buyerUid': 'buyer-a',
        'proposedByUid': 'buyer-a',
        'offeredTotal': 9000,
        'status': 'pending',
        'createdAt': 1000,
      },
      {
        'buyerUid': 'buyer-a',
        'proposedByUid': 'buyer-a',
        'offeredTotal': 10000,
        'status': 'pending',
        'createdAt': 2000,
      },
      {
        'buyerUid': 'buyer-b',
        'proposedByUid': 'buyer-b',
        'offeredTotal': 12000,
        'status': 'declined',
        'createdAt': 3000,
      },
      {
        'buyerUid': 'buyer-c',
        'proposedByUid': 'buyer-c',
        'offeredTotal': 11500,
        'status': 'pending',
        'createdAt': 2500,
      },
    ]);

    expect(best, 11500);
  });

  test('activity time is concise and readable', () {
    final now = DateTime(2026, 8, 13, 12);
    expect(
      marketplaceActivityTime(DateTime(2026, 8, 13, 11, 45), now: now),
      '15 min ago',
    );
    expect(
      marketplaceActivityTime(DateTime(2026, 8, 11, 12), now: now),
      '2 days ago',
    );
  });
}
