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

/// Checks if current user is an administrator via custom claims or primary admin email
Future<bool> marketplaceAdministratorAccess({
  FirebaseAuth? auth,
  bool forceRefresh = false,
}) async {
  final user = (auth ?? FirebaseAuth.instance).currentUser;
  if (user == null) return false;
  if (user.email?.toLowerCase().trim() == 'jordilwbailey@gmail.com') {
    return true;
  }
  try {
    final result = await user.getIdTokenResult(forceRefresh);
    return marketplaceAdministratorClaims(result.claims);
  } on FirebaseAuthException {
    return false;
  }
}
