import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_wanted_matching.dart';

void main() {
  group('MarketplaceWantedMatchingEngine Unit Tests', () {
    test('evaluates exact match between listing and wanted request', () {
      final listing = {
        'category': 'Heavy Equipment',
        'productType': 'Excavator',
        'title': '2022 CAT 320 Excavator',
        'condition': 'Excellent',
        'region': 'Alberta',
      };

      final wanted = {
        'id': 'wanted-999',
        'category': 'Heavy Equipment',
        'productType': 'Excavator',
        'preferredCondition': 'Excellent',
        'targetLocation': 'Alberta',
      };

      final match = MarketplaceWantedMatchingEngine.evaluate(
        listingId: 'listing-888',
        wantedId: 'wanted-999',
        listing: listing,
        wanted: wanted,
      );

      expect(match.score, 1.0);
      expect(match.scorePercentage, 100);
      expect(match.isHighConfidence, isTrue);
      expect(match.matchReasons, hasLength(4));
    });

    test('ranks multiple wanted requests by score', () {
      final listing = {
        'category': 'Pipe, Tubing & Materials',
        'productType': 'Line Pipe',
        'condition': 'New surplus',
        'region': 'Texas',
      };

      final wantedAds = [
        {
          'id': 'wanted-low',
          'category': 'Heavy Equipment',
          'productType': 'Bulldozer',
        },
        {
          'id': 'wanted-high',
          'category': 'Pipe, Tubing & Materials',
          'productType': 'Line Pipe',
          'region': 'Texas',
        },
      ];

      final matches = MarketplaceWantedMatchingEngine.findMatchesForListing(
        listingId: 'listing-777',
        listing: listing,
        wantedAds: wantedAds,
        minScore: 0.50,
      );

      expect(matches, hasLength(1));
      expect(matches.first.wantedId, 'wanted-high');
      expect(matches.first.isHighConfidence, isTrue);
    });
  });
}
