/// Compile-time safety policy for the Phase 1 client.
///
/// Server-controlled feature configuration will be added before Gate 0 closes.
/// These defaults fail closed so a production build cannot accidentally expose
/// demo inventory, regulated listings, or unimplemented paid workflows.
class Phase1FeaturePolicy {
  const Phase1FeaturePolicy({
    required this.environment,
    required this.demoContentRequested,
    required this.regulatedListingsRequested,
    required this.paidFeaturesRequested,
  });

  static const current = Phase1FeaturePolicy(
    environment: String.fromEnvironment(
      'PIPE_ENV',
      defaultValue: 'development',
    ),
    demoContentRequested: bool.fromEnvironment(
      'PIPE_ENABLE_DEMO_CONTENT',
      defaultValue: false,
    ),
    regulatedListingsRequested: bool.fromEnvironment(
      'PIPE_ENABLE_REGULATED_LISTINGS',
      defaultValue: false,
    ),
    paidFeaturesRequested: bool.fromEnvironment(
      'PIPE_ENABLE_PAID_FEATURES',
      defaultValue: false,
    ),
  );

  final String environment;
  final bool demoContentRequested;
  final bool regulatedListingsRequested;
  final bool paidFeaturesRequested;

  bool get isProduction => environment.trim().toLowerCase() == 'production';

  bool get demoContentEnabled => !isProduction && demoContentRequested;

  bool get regulatedListingsEnabled =>
      !isProduction && regulatedListingsRequested;

  bool get paidFeaturesEnabled => !isProduction && paidFeaturesRequested;

  bool allowsMarketplaceCategory(String category) =>
      category != 'Site & Property' || regulatedListingsEnabled;
}
