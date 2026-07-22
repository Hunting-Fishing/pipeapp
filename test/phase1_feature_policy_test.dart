import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/config/phase1_feature_policy.dart';

void main() {
  test('production fails closed even when unsafe flags are requested', () {
    const policy = Phase1FeaturePolicy(
      environment: 'production',
      demoContentRequested: true,
      regulatedListingsRequested: true,
      paidFeaturesRequested: true,
    );

    expect(policy.demoContentEnabled, isFalse);
    expect(policy.regulatedListingsEnabled, isFalse);
    expect(policy.paidFeaturesEnabled, isFalse);
    expect(policy.allowsMarketplaceCategory('Site & Property'), isFalse);
    expect(policy.allowsMarketplaceCategory('Heavy Equipment'), isTrue);
  });

  test('non-production features still require explicit opt-in', () {
    const safe = Phase1FeaturePolicy(
      environment: 'staging',
      demoContentRequested: false,
      regulatedListingsRequested: false,
      paidFeaturesRequested: false,
    );
    const optedIn = Phase1FeaturePolicy(
      environment: 'development',
      demoContentRequested: true,
      regulatedListingsRequested: true,
      paidFeaturesRequested: true,
    );

    expect(safe.demoContentEnabled, isFalse);
    expect(safe.regulatedListingsEnabled, isFalse);
    expect(optedIn.demoContentEnabled, isTrue);
    expect(optedIn.regulatedListingsEnabled, isTrue);
  });
}
