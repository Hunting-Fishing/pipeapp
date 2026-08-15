import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_trust_readiness.dart';

void main() {
  group('MarketplaceTrustReadiness', () {
    test('email verification alone unlocks marketplace access at 40 points',
        () {
      const readiness = MarketplaceTrustReadiness(
        emailVerified: true,
        phoneVerified: false,
        mfaEnrolled: false,
      );
      expect(readiness.marketplaceAccessReady, isTrue);
      expect(readiness.score, 40);
      expect(readiness.missingPoints, 60);
    });

    test('phone verification alone unlocks marketplace access at 40 points',
        () {
      const readiness = MarketplaceTrustReadiness(
        emailVerified: false,
        phoneVerified: true,
        mfaEnrolled: false,
      );
      expect(readiness.marketplaceAccessReady, isTrue);
      expect(readiness.score, 40);
    });

    test('unverified accounts remain blocked from marketplace access', () {
      const readiness = MarketplaceTrustReadiness(
        emailVerified: false,
        phoneVerified: false,
        mfaEnrolled: false,
      );
      expect(readiness.marketplaceAccessReady, isFalse);
      expect(readiness.score, 0);
    });

    test('email and phone total 80 and MFA completes 100', () {
      const withoutMfa = MarketplaceTrustReadiness(
        emailVerified: true,
        phoneVerified: true,
        mfaEnrolled: false,
      );
      const complete = MarketplaceTrustReadiness(
        emailVerified: true,
        phoneVerified: true,
        mfaEnrolled: true,
      );
      expect(withoutMfa.score, 80);
      expect(complete.score, MarketplaceTrustReadiness.totalPoints);
      expect(complete.missingPoints, 0);
    });
  });
}
