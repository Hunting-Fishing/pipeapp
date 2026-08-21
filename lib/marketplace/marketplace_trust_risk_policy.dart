import 'dart:math' as math;

/// Versioned, deterministic Trust & Safety review-priority policy.
///
/// This policy is intentionally non-enforcing. A score only helps an
/// administrator decide which case to inspect first. It must never be used to
/// automatically remove content, suspend an account, block a payment, or label
/// a person as fraudulent.
class MarketplaceTrustRiskPolicy {
  const MarketplaceTrustRiskPolicy._();

  static const revision = '2026-08-21-review-priority-v1';
  static const minimumComparablePrices = 5;

  static const Map<String, int> _reasonWeights = {
    'fraud_or_scam': 55,
    'reused_photos': 45,
    'duplicate_listing': 35,
    'misleading_information': 35,
    'prohibited_or_unsafe_item': 35,
    'hate_or_racist_content': 30,
    'vulgar_or_harassing_content': 25,
    'spam': 20,
    'other': 10,
  };

  static TrustRiskAssessment assess({
    required Map<String, dynamic> report,
    Map<String, dynamic>? listing,
    List<double> comparableUnitPrices = const [],
  }) {
    var score = 0;
    final signals = <TrustRiskSignal>[];

    void add(int points, String code, String label) {
      if (points <= 0 || signals.any((signal) => signal.code == code)) return;
      score += points;
      signals.add(TrustRiskSignal(code: code, points: points, label: label));
    }

    final reason = '${report['reason'] ?? ''}'.trim().toLowerCase();
    final reasonWeight = _reasonWeights[reason] ?? 10;
    add(
      reasonWeight,
      'report_reason_$reason',
      _reasonLabel(reason),
    );

    final source = '${report['source'] ?? 'user'}'.trim().toLowerCase();
    final priority = '${report['priority'] ?? ''}'.trim().toLowerCase();
    if (source == 'automated' && priority == 'high') {
      add(15, 'automated_high_priority', 'Automated pre-screen marked this case high priority.');
    }

    final moderationSignals = _stringList(report['moderationSignals']);
    if (moderationSignals.contains('possible_payment_fraud')) {
      add(30, 'possible_payment_fraud', 'Payment language matched the existing conservative fraud pre-screen.');
    }
    if (moderationSignals.contains('possible_threat')) {
      add(20, 'possible_threat', 'The existing safety pre-screen detected possible threatening language.');
    }
    if (moderationSignals.contains('possible_hate_or_racist_content')) {
      add(15, 'possible_hate_or_racist_content', 'The existing safety pre-screen detected possible hateful content.');
    }
    if (moderationSignals.contains('vulgar_or_harassing_content')) {
      add(8, 'vulgar_or_harassing_content', 'The existing safety pre-screen detected possible harassment or vulgar abuse.');
    }

    final duplicateListingIds = <String>{
      ..._stringList(report['duplicateListingIds']),
      ..._stringList(_nested(report, 'duplicateMediaEvidence', 'duplicateListingIds')),
      ..._stringList(_nested(report, 'duplicateEvidence', 'duplicateListingIds')),
    };
    final matchedHashes = <String>{
      ..._stringList(report['matchedImageHashes']),
      ..._stringList(_nested(report, 'duplicateMediaEvidence', 'matchedImageHashes')),
      ..._stringList(_nested(report, 'duplicateEvidence', 'matchedImageHashes')),
    };
    final reviewMediaItems = _objectList(report['reviewMediaItems']);

    if (duplicateListingIds.isNotEmpty || matchedHashes.isNotEmpty) {
      add(20, 'exact_duplicate_media', 'Exact image-hash evidence links this case to another listing.');
    }
    if (duplicateListingIds.length >= 2 || matchedHashes.length >= 2 || reviewMediaItems.length >= 2) {
      add(8, 'multiple_duplicate_matches', 'More than one duplicate-media match is available for human review.');
    }

    final listingUnitPrice = listing == null ? null : normalizedUnitPrice(listing);
    final peerPrices = comparableUnitPrices
        .where((price) => price.isFinite && price > 0)
        .toList(growable: false)
      ..sort();

    if (listing != null &&
        _priceComparisonAllowed(listing) &&
        listingUnitPrice != null &&
        peerPrices.length >= minimumComparablePrices) {
      final median = _median(peerPrices);
      if (median > 0) {
        final ratio = listingUnitPrice / median;
        if (ratio <= 0.20 || ratio >= 5.0) {
          add(
            18,
            'extreme_price_outlier',
            'Asking unit price is far outside the bounded peer median; verify item details before relying on this signal.',
          );
        } else if (ratio <= 0.40 || ratio >= 2.5) {
          add(
            10,
            'price_outlier',
            'Asking unit price differs materially from the bounded peer median; this is a review hint, not proof of fraud.',
          );
        }
      }
    }

    final clampedScore = score.clamp(0, 100).toInt();
    final tier = clampedScore >= 70
        ? TrustRiskTier.high
        : clampedScore >= 40
            ? TrustRiskTier.elevated
            : TrustRiskTier.normal;

    return TrustRiskAssessment(
      policyRevision: revision,
      score: clampedScore,
      tier: tier,
      signals: List.unmodifiable(signals),
      automaticEnforcement: false,
    );
  }

  static double? normalizedUnitPrice(Map<String, dynamic> listing) {
    final price = _positiveNumber(listing['price']);
    if (price == null) return null;
    final priceBasis = '${listing['priceBasis'] ?? ''}'.trim().toLowerCase();
    final quantity = _positiveNumber(listing['quantity']);
    if (priceBasis.contains('total') && quantity != null) {
      return price / quantity;
    }
    return price;
  }

  static bool comparableListing(
    Map<String, dynamic> candidate,
    Map<String, dynamic> subject,
  ) {
    if (!_priceComparisonAllowed(candidate) || !_priceComparisonAllowed(subject)) {
      return false;
    }
    final candidatePrice = normalizedUnitPrice(candidate);
    final subjectPrice = normalizedUnitPrice(subject);
    if (candidatePrice == null || subjectPrice == null) return false;

    final candidateCategory = _comparisonCategory(candidate);
    final subjectCategory = _comparisonCategory(subject);
    if (candidateCategory.isEmpty || candidateCategory != subjectCategory) return false;

    final candidateCurrency = '${candidate['currency'] ?? 'CAD'}'.trim().toUpperCase();
    final subjectCurrency = '${subject['currency'] ?? 'CAD'}'.trim().toUpperCase();
    return candidateCurrency == subjectCurrency;
  }

  static String _comparisonCategory(Map<String, dynamic> listing) {
    return '${listing['category'] ?? listing['itemType'] ?? listing['listingType'] ?? ''}'
        .trim()
        .toLowerCase();
  }

  static bool _priceComparisonAllowed(Map<String, dynamic> listing) {
    final transactionType = '${listing['transactionType'] ?? ''}'.toLowerCase();
    final status = '${listing['status'] ?? 'active'}'.toLowerCase();
    if (status == 'moderation_removed' || status == 'archived') return false;
    if (transactionType.contains('wanted') || transactionType.contains('auction')) {
      return false;
    }
    return true;
  }

  static Object? _nested(Map<String, dynamic> map, String first, String second) {
    final value = map[first];
    if (value is Map) return value[second];
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _objectList(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static double? _positiveNumber(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number.isFinite && number > 0 ? number : null;
  }

  static double _median(List<double> sorted) {
    if (sorted.isEmpty) return 0;
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  static String _reasonLabel(String reason) => switch (reason) {
        'fraud_or_scam' => 'A user explicitly reported fraud, scam, or impersonation.',
        'reused_photos' => 'A user reported photos reused from another listing.',
        'duplicate_listing' => 'A user reported a duplicate listing.',
        'misleading_information' => 'A user reported false or misleading listing information.',
        'prohibited_or_unsafe_item' => 'A user reported a prohibited or unsafe item.',
        'hate_or_racist_content' => 'A user reported racist or hateful content.',
        'vulgar_or_harassing_content' => 'A user reported threatening, vulgar, or harassing content.',
        'spam' => 'A user reported spam or commercial abuse.',
        _ => 'A Trust & Safety report requires administrator review.',
      };
}

enum TrustRiskTier { normal, elevated, high }

class TrustRiskAssessment {
  const TrustRiskAssessment({
    required this.policyRevision,
    required this.score,
    required this.tier,
    required this.signals,
    required this.automaticEnforcement,
  });

  final String policyRevision;
  final int score;
  final TrustRiskTier tier;
  final List<TrustRiskSignal> signals;
  final bool automaticEnforcement;

  String get tierLabel => switch (tier) {
        TrustRiskTier.high => 'HIGH REVIEW PRIORITY',
        TrustRiskTier.elevated => 'ELEVATED REVIEW PRIORITY',
        TrustRiskTier.normal => 'NORMAL REVIEW PRIORITY',
      };
}

class TrustRiskSignal {
  const TrustRiskSignal({
    required this.code,
    required this.points,
    required this.label,
  });

  final String code;
  final int points;
  final String label;
}
