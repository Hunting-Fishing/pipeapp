import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_buyer/marketplace/marketplace_auctions_page.dart';

void main() {
  group('auction timing state', () {
    final now = DateTime.utc(2026, 8, 14, 12);

    test('upcoming auction is not live or ended', () {
      final listing = <String, dynamic>{
        'auctionStartAt': now.add(const Duration(hours: 2)),
        'auctionEndAt': now.add(const Duration(hours: 8)),
        'status': 'active',
      };

      expect(isAuctionUpcoming(listing, now), isTrue);
      expect(isAuctionLive(listing, now), isFalse);
      expect(isAuctionEnded(listing, now), isFalse);
    });

    test('started auction remains live before end time', () {
      final listing = <String, dynamic>{
        'auctionStartAt': now.subtract(const Duration(hours: 1)),
        'auctionEndAt': now.add(const Duration(hours: 3)),
        'status': 'active',
      };

      expect(isAuctionUpcoming(listing, now), isFalse);
      expect(isAuctionLive(listing, now), isTrue);
      expect(isAuctionEnded(listing, now), isFalse);
    });

    test('end timestamp makes auction ended', () {
      final listing = <String, dynamic>{
        'auctionStartAt': now.subtract(const Duration(hours: 4)),
        'auctionEndAt': now.subtract(const Duration(seconds: 1)),
        'status': 'active',
      };

      expect(isAuctionEnded(listing, now), isTrue);
      expect(isAuctionLive(listing, now), isFalse);
    });

    test('terminal marketplace status makes auction ended', () {
      final listing = <String, dynamic>{
        'auctionStartAt': now.subtract(const Duration(hours: 1)),
        'auctionEndAt': now.add(const Duration(hours: 3)),
        'status': 'sold',
      };

      expect(isAuctionEnded(listing, now), isTrue);
      expect(isAuctionLive(listing, now), isFalse);
    });

    test('ISO date strings are accepted by timing parser', () {
      final start = now.add(const Duration(hours: 1));
      final end = now.add(const Duration(hours: 5));
      final listing = <String, dynamic>{
        'auctionStartAt': start.toIso8601String(),
        'auctionEndAt': end.toIso8601String(),
      };

      expect(parseAuctionStart(listing), start);
      expect(parseAuctionEnd(listing), end);
    });
  });
}
