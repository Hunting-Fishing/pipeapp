import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/config/phase1_feature_policy.dart';

void main() {
  test('production keeps regulated listings closed but permits explicit paid approval', () {
    const policy = Phase1FeaturePolicy(
      environment: 'production',
      regulatedListingsRequested: true,
      paidFeaturesRequested: true,
    );

    expect(policy.regulatedListingsEnabled, isFalse);
    expect(policy.paidFeaturesEnabled, isTrue);
    expect(policy.allowsMarketplaceCategory('Site & Property'), isFalse);
    expect(policy.allowsMarketplaceCategory('Heavy Equipment'), isTrue);
  });

  test('paid features remain off when build approval is absent', () {
    const production = Phase1FeaturePolicy(
      environment: 'production',
      regulatedListingsRequested: false,
      paidFeaturesRequested: false,
    );
    const staging = Phase1FeaturePolicy(
      environment: 'staging',
      regulatedListingsRequested: false,
      paidFeaturesRequested: false,
    );

    expect(production.paidFeaturesEnabled, isFalse);
    expect(staging.paidFeaturesEnabled, isFalse);
  });

  test('non-production risky features still require explicit opt-in', () {
    const safe = Phase1FeaturePolicy(
      environment: 'staging',
      regulatedListingsRequested: false,
      paidFeaturesRequested: false,
    );
    const optedIn = Phase1FeaturePolicy(
      environment: 'development',
      regulatedListingsRequested: true,
      paidFeaturesRequested: true,
    );

    expect(safe.regulatedListingsEnabled, isFalse);
    expect(safe.paidFeaturesEnabled, isFalse);
    expect(optedIn.regulatedListingsEnabled, isTrue);
    expect(optedIn.paidFeaturesEnabled, isTrue);
  });

  test('production auctions Dispatch and paid features require explicit build approval', () {
    const locked = Phase1FeaturePolicy(
      environment: 'production',
      regulatedListingsRequested: false,
      paidFeaturesRequested: false,
      auctionsRequested: false,
      dispatchRequested: false,
    );
    const approved = Phase1FeaturePolicy(
      environment: 'production',
      regulatedListingsRequested: false,
      paidFeaturesRequested: true,
      auctionsRequested: true,
      dispatchRequested: true,
    );

    expect(locked.auctionsEnabledForBuild, isFalse);
    expect(locked.dispatchEnabledForBuild, isFalse);
    expect(locked.paidFeaturesEnabled, isFalse);
    expect(approved.auctionsEnabledForBuild, isTrue);
    expect(approved.dispatchEnabledForBuild, isTrue);
    expect(approved.paidFeaturesEnabled, isTrue);
    expect(approved.regulatedListingsEnabled, isFalse);
  });
}
