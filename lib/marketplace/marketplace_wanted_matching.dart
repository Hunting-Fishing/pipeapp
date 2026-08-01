import 'dart:math' as math;

class MarketplaceWantedMatch {
  const MarketplaceWantedMatch({
    required this.listingId,
    required this.wantedId,
    required this.score,
    required this.matchReasons,
    required this.isHighConfidence,
  });

  final String listingId;
  final String wantedId;
  final double score; // 0.0 to 1.0 (0% to 100%)
  final List<String> matchReasons;
  final bool isHighConfidence;

  int get scorePercentage => (score * 100).round();
}

class MarketplaceWantedMatchingEngine {
  /// Evaluates how closely a seller's listing matches a buyer's Wanted Ad request.
  static MarketplaceWantedMatch evaluate({
    required String listingId,
    required String wantedId,
    required Map<String, dynamic> listing,
    required Map<String, dynamic> wanted,
  }) {
    final reasons = <String>[];
    double totalPoints = 0.0;
    const maxPossiblePoints = 100.0;

    // 1. Category Matching (Weight: 35 points)
    final listingCategory = '${listing['category'] ?? ''}'.trim().toLowerCase();
    final wantedCategory = '${wanted['category'] ?? ''}'.trim().toLowerCase();
    if (listingCategory.isNotEmpty && listingCategory == wantedCategory) {
      totalPoints += 35.0;
      reasons.add('Exact category match (${listing['category']})');
    }

    // 2. Product Type / Title Keyword Matching (Weight: 30 points)
    final listingType = '${listing['productType'] ?? listing['title'] ?? ''}'.trim().toLowerCase();
    final wantedType = '${wanted['productType'] ?? wanted['title'] ?? ''}'.trim().toLowerCase();
    if (listingType.isNotEmpty && wantedType.isNotEmpty) {
      if (listingType == wantedType) {
        totalPoints += 30.0;
        reasons.add('Exact product type match (${listing['productType'] ?? listing['title']})');
      } else if (listingType.contains(wantedType) || wantedType.contains(listingType)) {
        totalPoints += 20.0;
        reasons.add('Related product type match');
      }
    }

    // 3. Specification & Condition Matching (Weight: 20 points)
    final listingCondition = '${listing['condition'] ?? ''}'.trim().toLowerCase();
    final wantedCondition = '${wanted['preferredCondition'] ?? wanted['condition'] ?? ''}'.trim().toLowerCase();
    if (wantedCondition.isEmpty || listingCondition == wantedCondition || listingCondition.contains('new')) {
      totalPoints += 20.0;
      reasons.add('Condition requirements met');
    } else {
      totalPoints += 10.0;
    }

    // 4. Regional / Location Proximity (Weight: 15 points)
    final listingRegion = '${listing['region'] ?? listing['location'] ?? ''}'.trim().toLowerCase();
    final wantedRegion = '${wanted['region'] ?? wanted['targetLocation'] ?? ''}'.trim().toLowerCase();
    if (wantedRegion.isEmpty || listingRegion.contains(wantedRegion) || wantedRegion.contains(listingRegion)) {
      totalPoints += 15.0;
      reasons.add('Target region alignment');
    }

    final score = math.min(1.0, totalPoints / maxPossiblePoints);
    final isHighConfidence = score >= 0.65;

    return MarketplaceWantedMatch(
      listingId: listingId,
      wantedId: wantedId,
      score: score,
      matchReasons: reasons,
      isHighConfidence: isHighConfidence,
    );
  }

  /// Filters and ranks a collection of wanted ads against a new listing.
  static List<MarketplaceWantedMatch> findMatchesForListing({
    required String listingId,
    required Map<String, dynamic> listing,
    required List<Map<String, dynamic>> wantedAds,
    double minScore = 0.50,
  }) {
    final matches = <MarketplaceWantedMatch>[];
    for (final wanted in wantedAds) {
      final wantedId = '${wanted['id'] ?? wanted['docId'] ?? ''}';
      if (wantedId.isEmpty) continue;
      final match = evaluate(
        listingId: listingId,
        wantedId: wantedId,
        listing: listing,
        wanted: wanted,
      );
      if (match.score >= minScore) {
        matches.add(match);
      }
    }
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }
}
