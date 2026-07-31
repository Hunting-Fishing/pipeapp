/// Compile-time safety policy for the Phase 1 client.
///
/// Server-controlled feature configuration will be added before Gate 0 closes.
/// These defaults fail closed so a production build cannot accidentally expose
/// regulated listings or unimplemented paid workflows. Marketplace inventory
/// always comes from the configured backend; demo listings are not compiled in.
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

  bool get paidFeaturesEnabled => !isProduction && paidFeaturesRequested;

  /// Auctions and Dispatch remain available during development, but a
  /// production artifact must explicitly opt in at build time. The remote
  /// feature document remains the immediate operational kill switch.
  bool get auctionsEnabledForBuild => !isProduction || auctionsRequested;

  bool get dispatchEnabledForBuild => !isProduction || dispatchRequested;

  bool allowsMarketplaceCategory(String category) =>
      category != 'Site & Property' || regulatedListingsEnabled;
}
