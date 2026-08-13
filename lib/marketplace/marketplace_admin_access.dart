import 'package:firebase_auth/firebase_auth.dart';

enum MarketplaceAdministratorState {
  signedOut,
  roleMissing,
  mfaRequired,
  authorized,
  unavailable,
}

/// Identifies a provisioned administrator role without treating it as an
/// authorized administrator session. This is suitable only for low-risk UI
/// routing such as deferring onboarding; privileged tools still require MFA
/// through [marketplaceAdministratorClaims].
bool marketplaceAdministratorRoleClaims(Map<String, dynamic>? claims) {
  final values = claims ?? const <String, dynamic>{};
  return values['admin'] == true && values['role'] == 'administrator';
}

MarketplaceAdministratorState marketplaceAdministratorClaimsState(
  Map<String, dynamic>? claims,
) {
  final values = claims ?? const <String, dynamic>{};
  final hasAdministratorRole = marketplaceAdministratorRoleClaims(values);
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

/// Returns whether the signed-in account has the server-issued administrator
/// role. This does not grant access to administrator tools and does not replace
/// their second-factor requirement.
Future<bool> marketplaceAdministratorRole({
  FirebaseAuth? auth,
  bool forceRefresh = false,
}) async {
  final user = (auth ?? FirebaseAuth.instance).currentUser;
  if (user == null) return false;
  try {
    final result = await user.getIdTokenResult(forceRefresh);
    return marketplaceAdministratorRoleClaims(result.claims);
  } on FirebaseAuthException {
    return false;
  } catch (_) {
    return false;
  }
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
