import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/config/phase1_feature_flags.dart';
import 'package:pipe_app/core/config/phase1_feature_policy.dart';

void main() {
  const development = Phase1FeaturePolicy(
    environment: 'development',
    regulatedListingsRequested: true,
    paidFeaturesRequested: true,
  );
  const production = Phase1FeaturePolicy(
    environment: 'production',
    regulatedListingsRequested: true,
    paidFeaturesRequested: true,
  );
  const productionLaunchCandidate = Phase1FeaturePolicy(
    environment: 'production',
    regulatedListingsRequested: false,
    paidFeaturesRequested: false,
    auctionsRequested: true,
    dispatchRequested: true,
  );

  test('missing remote configuration uses safe defaults', () {
    final flags = Phase1FeatureFlags.fromMap(null, buildPolicy: development);

    expect(flags.marketplace, isTrue);
    expect(flags.wantedAds, isTrue);
    expect(flags.offers, isTrue);
    expect(flags.auctions, isFalse);
    expect(flags.dispatch, isFalse);
    expect(flags.paidFeatures, isFalse);
    expect(flags.regulatedListings, isFalse);
  });

  test('development can use explicitly enabled controlled features', () {
    final flags = Phase1FeatureFlags.fromMap({
      'auctions': true,
      'dispatch': true,
      'paidFeatures': true,
      'regulatedListings': true,
      'revision': 7,
    }, buildPolicy: development);

    expect(flags.auctions, isTrue);
    expect(flags.dispatch, isTrue);
    expect(flags.paidFeatures, isTrue);
    expect(flags.regulatedListings, isTrue);
    expect(flags.revision, 7);
  });

  test('production build locks cannot be overridden remotely', () {
    final flags = Phase1FeatureFlags.fromMap({
      'auctions': true,
      'dispatch': true,
      'paidFeatures': true,
      'regulatedListings': true,
    }, buildPolicy: production);

    expect(flags.auctions, isFalse);
    expect(flags.dispatch, isFalse);
    expect(flags.paidFeatures, isFalse);
    expect(flags.regulatedListings, isFalse);
  });

  test('approved production candidate still requires remote enablement', () {
    final enabled = Phase1FeatureFlags.fromMap({
      'auctions': true,
      'dispatch': true,
    }, buildPolicy: productionLaunchCandidate);
    final remotelyDisabled = Phase1FeatureFlags.fromMap({
      'auctions': false,
      'dispatch': false,
    }, buildPolicy: productionLaunchCandidate);

    expect(enabled.auctions, isTrue);
    expect(enabled.dispatch, isTrue);
    expect(remotelyDisabled.auctions, isFalse);
    expect(remotelyDisabled.dispatch, isFalse);
  });

  test('remote configuration can immediately disable core features', () {
    final flags = Phase1FeatureFlags.fromMap({
      'marketplace': false,
      'wantedAds': false,
      'offers': false,
    }, buildPolicy: development);

    expect(flags.marketplace, isFalse);
    expect(flags.wantedAds, isFalse);
    expect(flags.offers, isFalse);
  });
}
