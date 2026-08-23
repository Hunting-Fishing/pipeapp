/// Compile-time safety policy for the Phase 1 client.
///
/// Remote feature configuration remains the operational kill switch. Features
/// that carry higher financial or regulatory risk also require an explicit
/// build-time opt-in so a production artifact cannot expose them accidentally.
class Phase1FeaturePolicy {
  const Phase1FeaturePolicy({
    required this.environment,
    required this.regulatedListingsRequested,
    required this.paidFeaturesRequested,
    this.auctionsRequested = true,
    this.dispatchRequested = true,
  });

  static const current = Phase1FeaturePolicy(
    environment: String.fromEnvironment(
      'PIPE_ENV',
      defaultValue: 'development',
    ),
    regulatedListingsRequested: bool.fromEnvironment(
      'PIPE_ENABLE_REGULATED_LISTINGS',
      defaultValue: false,
    ),
    paidFeaturesRequested: bool.fromEnvironment(
      'PIPE_ENABLE_PAID_FEATURES',
      defaultValue: false,
    ),
    auctionsRequested: bool.fromEnvironment(
      'PIPE_ENABLE_AUCTIONS',
      defaultValue: true,
    ),
    dispatchRequested: bool.fromEnvironment(
      'PIPE_ENABLE_DISPATCH',
      defaultValue: true,
    ),
  );

  final String environment;
  final bool regulatedListingsRequested;
  final bool paidFeaturesRequested;
  final bool auctionsRequested;
  final bool dispatchRequested;

  bool get isProduction => environment.trim().toLowerCase() == 'production';

  bool get regulatedListingsEnabled =>
      !isProduction && regulatedListingsRequested;

  /// Paid workflows are allowed in production only through an explicit build
  /// approval. The remote `paidFeatures` flag remains a second, immediate kill
  /// switch, so compiling an approved artifact does not by itself enable paid
  /// features for users.
  bool get paidFeaturesEnabled => paidFeaturesRequested;

  /// Auctions and Dispatch remain available during development, but a
  /// production artifact must explicitly opt in at build time. The remote
  /// feature document remains the immediate operational kill switch.
  bool get auctionsEnabledForBuild => !isProduction || auctionsRequested;

  bool get dispatchEnabledForBuild => !isProduction || dispatchRequested;

  bool allowsMarketplaceCategory(String category) =>
      category != 'Site & Property' || regulatedListingsEnabled;
}
