import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Reactive toggle allowing an authorized administrator to preview the exact
/// customer-facing UI ("View what everyone else sees" mode) without signing out.
///
/// Enabling this mode only suppresses admin UI chrome in the client so an
/// administrator can inspect the exact regular-user experience; it never grants
/// privileges to non-admin accounts.
final ValueNotifier<bool> marketplaceAdminViewAsUserMode =
    ValueNotifier<bool>(false);

void setMarketplaceAdminViewAsUserMode(bool enabled) {
  if (marketplaceAdminViewAsUserMode.value != enabled) {
    marketplaceAdminViewAsUserMode.value = enabled;
  }
}

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

  final hasPrimaryAdminClaim =
      values['primaryAdmin'] == true && values['email_verified'] == true;
  if (hasPrimaryAdminClaim) {
    return MarketplaceAdministratorState.authorized;
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
  if (user == null) {
    setMarketplaceAdminViewAsUserMode(false);
    return MarketplaceAdministratorState.signedOut;
  }

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

/// Returns true when the current user is an authorized administrator AND is
/// not currently previewing the app in "View what everyone else sees" mode.
Future<bool> marketplaceEffectiveAdminUiAccess({
  FirebaseAuth? auth,
  bool forceRefresh = false,
}) async {
  if (marketplaceAdminViewAsUserMode.value) return false;
  return marketplaceAdministratorAccess(
    auth: auth,
    forceRefresh: forceRefresh,
  );
}
