import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_trust_risk_policy.dart';

void main() {
  group('MarketplaceTrustRiskPolicy', () {
    test('explicit fraud report is elevated but never automatic enforcement', () {
      final assessment = MarketplaceTrustRiskPolicy.assess(
        report: const {
          'reason': 'fraud_or_scam',
          'source': 'user',
        },
      );

      expect(assessment.score, 55);
      expect(assessment.tier, TrustRiskTier.elevated);
      expect(assessment.automaticEnforcement, isFalse);
      expect(
        assessment.signals.map((signal) => signal.code),
        contains('report_reason_fraud_or_scam'),
      );
    });

    test('existing payment-fraud pre-screen promotes review priority', () {
      final assessment = MarketplaceTrustRiskPolicy.assess(
        report: const {
          'reason': 'fraud_or_scam',
          'source': 'automated',
          'priority': 'high',
          'moderationSignals': ['possible_payment_fraud'],
        },
      );

      expect(assessment.score, 100);
      expect(assessment.tier, TrustRiskTier.high);
      expect(assessment.automaticEnforcement, isFalse);
      expect(
        assessment.signals.map((signal) => signal.code),
        containsAll(['automated_high_priority', 'possible_payment_fraud']),
      );
    });

    test('exact duplicate photo evidence increases review priority', () {
      final assessment = MarketplaceTrustRiskPolicy.assess(
        report: const {
          'reason': 'reused_photos',
          'duplicateMediaEvidence': {
            'duplicateListingIds': ['listing-a', 'listing-b'],
            'matchedImageHashes': [
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            ],
          },
        },
      );

      expect(assessment.tier, TrustRiskTier.high);
      expect(
        assessment.signals.map((signal) => signal.code),
        containsAll(['exact_duplicate_media', 'multiple_duplicate_matches']),
      );
    });

    test('price outlier is ignored without enough comparable listings', () {
      final assessment = MarketplaceTrustRiskPolicy.assess(
        report: const {'reason': 'other'},
        listing: const {
          'transactionType': 'For Sale',
          'category': 'Pipe',
          'currency': 'CAD',
          'price': 100,
          'priceBasis': 'Per item',
        },
        comparableUnitPrices: const [1000, 1000, 1000, 1000],
      );

      expect(
        assessment.signals.map((signal) => signal.code),
        isNot(contains('extreme_price_outlier')),
      );
    });

    test('extreme price outlier is a review hint, not proof of fraud', () {
      final assessment = MarketplaceTrustRiskPolicy.assess(
        report: const {'reason': 'other'},
        listing: const {
          'transactionType': 'For Sale',
          'category': 'Pipe',
          'currency': 'CAD',
          'price': 100,
          'priceBasis': 'Per item',
        },
        comparableUnitPrices: const [1000, 1000, 1100, 900, 950, 1050],
      );

      expect(
        assessment.signals.map((signal) => signal.code),
        contains('extreme_price_outlier'),
      );
      expect(assessment.automaticEnforcement, isFalse);
      expect(assessment.tier, TrustRiskTier.normal);
    });

    test('total listing price is normalized by quantity', () {
      expect(
        MarketplaceTrustRiskPolicy.normalizedUnitPrice(const {
          'price': 2500,
          'priceBasis': 'Total lot',
          'quantity': 10,
        }),
        250,
      );
    });

    test('peer comparison requires same category and currency', () {
      const subject = {
        'transactionType': 'For Sale',
        'status': 'active',
        'category': 'Pipe',
        'currency': 'CAD',
        'price': 100,
      };

      expect(
        MarketplaceTrustRiskPolicy.comparableListing(
          const {
            'transactionType': 'For Sale',
            'status': 'active',
            'category': 'Pipe',
            'currency': 'CAD',
            'price': 120,
          },
          subject,
        ),
        isTrue,
      );
      expect(
        MarketplaceTrustRiskPolicy.comparableListing(
          const {
            'transactionType': 'For Sale',
            'status': 'active',
            'category': 'Equipment',
            'currency': 'CAD',
            'price': 120,
          },
          subject,
        ),
        isFalse,
      );
      expect(
        MarketplaceTrustRiskPolicy.comparableListing(
          const {
            'transactionType': 'For Sale',
            'status': 'active',
            'category': 'Pipe',
            'currency': 'USD',
            'price': 120,
          },
          subject,
        ),
        isFalse,
      );
    });
  });
}
