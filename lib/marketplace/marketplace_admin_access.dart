import 'package:firebase_auth/firebase_auth.dart';

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

/// Checks whether the current user has the complete administrator claim set.
///
/// Administrator access is never inferred from an email address or public
/// profile data. The token must contain the approved administrator role and
/// evidence that the current sign-in used a second factor.
Future<bool> marketplaceAdministratorAccess({
  FirebaseAuth? auth,
  bool forceRefresh = false,
}) async {
  final user = (auth ?? FirebaseAuth.instance).currentUser;
  if (user == null) return false;

  try {
    final result = await user.getIdTokenResult(forceRefresh);
    return marketplaceAdministratorClaims(result.claims);
  } on FirebaseAuthException {
    return false;
  }
}
