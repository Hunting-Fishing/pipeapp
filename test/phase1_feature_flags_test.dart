import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/config/phase1_feature_flags.dart';
import 'package:pipe_app/core/config/phase1_feature_policy.dart';

void main() {
  const development = Phase1FeaturePolicy(
    environment: 'development',
    regulatedListingsRequested: true,
    paidFeaturesRequested: true,
  );
  const productionLocked = Phase1FeaturePolicy(
    environment: 'production',
    regulatedListingsRequested: true,
    paidFeaturesRequested: false,
    auctionsRequested: false,
    dispatchRequested: false,
  );
  const productionLaunchCandidate = Phase1FeaturePolicy(
    environment: 'production',
    regulatedListingsRequested: false,
    paidFeaturesRequested: true,
    auctionsRequested: false,
    dispatchRequested: true,
  );

  test('missing remote configuration uses fail-closed controlled-feature defaults', () {
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
    }, buildPolicy: productionLocked);

    expect(flags.auctions, isFalse);
    expect(flags.dispatch, isFalse);
    expect(flags.paidFeatures, isFalse);
    expect(flags.regulatedListings, isFalse);
  });

  test('approved production Dispatch and Paid Features still require remote enablement', () {
    final enabled = Phase1FeatureFlags.fromMap({
      'auctions': false,
      'dispatch': true,
      'paidFeatures': true,
    }, buildPolicy: productionLaunchCandidate);
    final remotelyDisabled = Phase1FeatureFlags.fromMap({
      'auctions': false,
      'dispatch': false,
      'paidFeatures': false,
    }, buildPolicy: productionLaunchCandidate);

    expect(enabled.auctions, isFalse);
    expect(enabled.dispatch, isTrue);
    expect(enabled.paidFeatures, isTrue);
    expect(remotelyDisabled.dispatch, isFalse);
    expect(remotelyDisabled.paidFeatures, isFalse);
  });

  test('missing remote config stays off even in an approved production artifact', () {
    final flags = Phase1FeatureFlags.fromMap(
      null,
      buildPolicy: productionLaunchCandidate,
    );

    expect(flags.dispatch, isFalse);
    expect(flags.paidFeatures, isFalse);
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
