import 'package:firebase_auth/firebase_auth.dart';

enum MarketplaceAdministratorState {
  signedOut,
  roleMissing,
  mfaRequired,
  authorized,
  unavailable,
}

MarketplaceAdministratorState marketplaceAdministratorClaimsState(
  Map<String, dynamic>? claims,
) {
  final values = claims ?? const <String, dynamic>{};
  final hasAdministratorRole =
      values['admin'] == true && values['role'] == 'administrator';
  if (!hasAdministratorRole) {
    return MarketplaceAdministratorState.roleMissing;
  }

  final firebase = values['firebase'];
  final secondFactor = firebase is Map
      ? firebase['sign_in_second_factor']?.toString().trim()
      : null;
  if (secondFactor == null || secondFactor.isEmpty) {
    return MarketplaceAdministratorState.mfaRequired;
  }
  return MarketplaceAdministratorState.authorized;
}

bool marketplaceAdministratorClaims(Map<String, dynamic>? claims) =>
    marketplaceAdministratorClaimsState(claims) ==
    MarketplaceAdministratorState.authorized;

/// Checks the current user's administrator-token state without trusting email,
/// public profile data, or client-writable Firestore fields.
Future<MarketplaceAdministratorState> marketplaceAdministratorState({
  FirebaseAuth? auth,
  bool forceRefresh = false,
}) async {
  final user = (auth ?? FirebaseAuth.instance).currentUser;
  if (user == null) return MarketplaceAdministratorState.signedOut;

  try {
    final result = await user.getIdTokenResult(forceRefresh);
    return marketplaceAdministratorClaimsState(result.claims);
  } on FirebaseAuthException {
    return MarketplaceAdministratorState.unavailable;
  } catch (_) {
    return MarketplaceAdministratorState.unavailable;
  }
}

/// Returns true only when the current token contains the complete approved
/// administrator role and evidence that this sign-in completed MFA.
Future<bool> marketplaceAdministratorAccess({
  FirebaseAuth? auth,
  bool forceRefresh = false,
}) async =>
    await marketplaceAdministratorState(
      auth: auth,
      forceRefresh: forceRefresh,
    ) ==
    MarketplaceAdministratorState.authorized;
