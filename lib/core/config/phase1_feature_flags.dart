import 'package:cloud_firestore/cloud_firestore.dart';

import 'phase1_feature_policy.dart';

class Phase1FeatureFlags {
  const Phase1FeatureFlags({
    required this.marketplace,
    required this.wantedAds,
    required this.offers,
    required this.auctions,
    required this.dispatch,
    required this.paidFeatures,
    required this.regulatedListings,
    required this.revision,
  });

  static const safeDefaults = Phase1FeatureFlags(
    marketplace: true,
    wantedAds: true,
    offers: true,
    auctions: true,
    dispatch: true,
    paidFeatures: false,
    regulatedListings: false,
    revision: 0,
  );

  final bool marketplace;
  final bool wantedAds;
  final bool offers;
  final bool auctions;
  final bool dispatch;
  final bool paidFeatures;
  final bool regulatedListings;
  final int revision;

  factory Phase1FeatureFlags.fromMap(
    Map<String, dynamic>? data, {
    Phase1FeaturePolicy buildPolicy = Phase1FeaturePolicy.current,
  }) {
    bool remoteValue(String field, bool fallback) {
      final value = data?[field];
      return value is bool ? value : fallback;
    }

    // The local environment is the full PipeBuyer integration sandbox. Core
    // marketplace transaction surfaces stay available there even if a seeded
    // remote feature document is temporarily missing/stale. Production and
    // staging still respect both the build policy and remote kill switches.
    final localIntegration =
        buildPolicy.environment.trim().toLowerCase() == 'local';

    return Phase1FeatureFlags(
      marketplace: localIntegration ||
          remoteValue('marketplace', safeDefaults.marketplace),
      wantedAds:
          localIntegration || remoteValue('wantedAds', safeDefaults.wantedAds),
      offers: localIntegration || remoteValue('offers', safeDefaults.offers),
      auctions: localIntegration ||
          (remoteValue('auctions', safeDefaults.auctions) &&
              buildPolicy.auctionsEnabledForBuild),
      dispatch: localIntegration ||
          (remoteValue('dispatch', safeDefaults.dispatch) &&
              buildPolicy.dispatchEnabledForBuild),
      paidFeatures: remoteValue(
            'paidFeatures',
            safeDefaults.paidFeatures,
          ) &&
          buildPolicy.paidFeaturesEnabled,
      regulatedListings: remoteValue(
            'regulatedListings',
            safeDefaults.regulatedListings,
          ) &&
          buildPolicy.regulatedListingsEnabled,
      revision: ((data?['revision'] as num?)?.toInt() ?? 0).clamp(0, 1 << 31),
    );
  }
}

class Phase1FeatureFlagRepository {
  Phase1FeatureFlagRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<Phase1FeatureFlags> watch() => _firestore
      .collection('platform_configuration')
      .doc('phase1_features')
      .snapshots()
      .map((snapshot) => Phase1FeatureFlags.fromMap(snapshot.data()));
}
