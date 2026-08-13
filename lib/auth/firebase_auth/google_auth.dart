import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

const _googleScopes = <String>['profile', 'email'];
final _googleSignIn = GoogleSignIn.instance;
Future<void>? _googleSignInInitialization;

Future<void> _ensureGoogleSignInInitialized() =>
    _googleSignInInitialization ??= _googleSignIn.initialize();

Future<UserCredential?> googleSignInFunc() async {
  if (kIsWeb) {
    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
  }

  await _ensureGoogleSignInInitialized();
  try {
    await _googleSignIn.signOut();
  } catch (_) {
    // A stale or missing native session should not block account selection.
  }

  late final GoogleSignInAccount account;
  try {
    account = await _googleSignIn.authenticate(scopeHint: _googleScopes);
  } on GoogleSignInException catch (error) {
    if (error.code == GoogleSignInExceptionCode.canceled) {
      return null;
    }
    rethrow;
  }

  final idToken = account.authentication.idToken;
  if (idToken == null) {
    throw FirebaseAuthException(
      code: 'missing-google-id-token',
      message: 'Google sign-in did not return an ID token.',
    );
  }

  final credential = GoogleAuthProvider.credential(idToken: idToken);
  return FirebaseAuth.instance.signInWithCredential(credential);
}

Future<void> signOutWithGoogle() async {
  if (kIsWeb) {
    return;
  }
  await _ensureGoogleSignInInitialized();
  await _googleSignIn.signOut();
}
