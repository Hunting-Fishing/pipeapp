import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_listing_status.dart';

void main() {
  final now = DateTime(2026, 7, 18, 12);

  test('owner listing remains visually controlled while showing activity', () {
    final presentation = MarketplaceListingPresentation.fromMap({
      'sellerUid': 'owner-1',
      'offerCount': 3,
      'createdAt': now.subtract(const Duration(days: 2)),
    }, currentUserUid: 'owner-1', now: now);

    expect(presentation.emphasized, isTrue);
    expect(presentation.badges.map((badge) => badge.label),
        containsAll(<String>['Your listing', '3 offers', 'New']));
  });

  test('price reductions use the original listing price', () {
    final presentation = MarketplaceListingPresentation.fromMap({
      'sellerUid': 'seller-2',
      'price': 80,
      'initialPrice': 100,
    }, currentUserUid: 'buyer-1', now: now);

    expect(presentation.badges.single.label, '↓ 20% price drop');
  });

  test('auction cards identify bids and urgent closing time', () {
    final presentation = MarketplaceListingPresentation.fromMap({
      'sellerUid': 'seller-3',
      'bidCount': 2,
      'auctionEndAt': now.add(const Duration(hours: 6)),
    }, currentUserUid: 'buyer-1', isAuction: true, now: now);

    expect(presentation.badges.map((badge) => badge.label),
        containsAll(<String>['2 bids', 'Ends soon']));
  });

  test('wanted, verified, and boosted listing signals are surfaced', () {
    final presentation = MarketplaceListingPresentation.fromMap({
      'sellerUid': 'seller-4',
      'transactionType': 'Wanted / Seeking',
      'sellerVerified': true,
      'boostStatus': 'active',
    }, currentUserUid: 'buyer-1', now: now);

    expect(
      presentation.badges.map((badge) => badge.label),
      containsAll(<String>['Wanted', 'Verified seller', 'Boosted']),
    );
    expect(presentation.emphasized, isTrue);
  });
}
