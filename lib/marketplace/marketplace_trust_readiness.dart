class MarketplaceTrustReadiness {
  const MarketplaceTrustReadiness({
    required this.emailVerified,
    required this.phoneVerified,
    required this.mfaEnrolled,
  });

  static const int emailOwnershipPoints = 40;
  static const int phoneOwnershipPoints = 40;
  static const int twoStepPoints = 20;
  static const int totalPoints =
      emailOwnershipPoints + phoneOwnershipPoints + twoStepPoints;

  final bool emailVerified;
  final bool phoneVerified;
  final bool mfaEnrolled;

  bool get marketplaceAccessReady => emailVerified || phoneVerified;

  int get score =>
      (emailVerified ? emailOwnershipPoints : 0) +
      (phoneVerified ? phoneOwnershipPoints : 0) +
      (mfaEnrolled ? twoStepPoints : 0);

  int get missingPoints => totalPoints - score;
}
