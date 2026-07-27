import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

bool marketplaceAdministratorClaims(Map<String, dynamic>? claims) {
  final values = claims ?? const <String, dynamic>{};
  final firebase = values['firebase'];
  final secondFactor = firebase is Map
      ? firebase['sign_in_second_factor']?.toString().trim()
      : null;
  return values['admin'] == true &&
      values['role'] == 'administrator' &&
      secondFactor != null &&
      secondFactor.isNotEmpty;
}

/// Reads only signed Firebase Authentication claims. Public profile fields and
/// email addresses are intentionally never accepted as administrator proof.
Future<bool> marketplaceAdministratorAccess({
  FirebaseAuth? auth,
  bool forceRefresh = false,
}) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) return false;
  final user = (auth ?? FirebaseAuth.instance).currentUser;
  if (user == null) return false;
  try {
    final result = await user.getIdTokenResult(forceRefresh);
    return marketplaceAdministratorClaims(result.claims);
  } on FirebaseAuthException {
    return false;
  }
}
