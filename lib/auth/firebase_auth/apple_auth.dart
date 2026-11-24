import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Generates a cryptographically secure random nonce, to be included in a
/// credential request.
String generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)])
      .join();
}

/// Returns the sha256 hash of [input] in hex notation.
String sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

Future<UserCredential> appleSignIn() async {
  if (kIsWeb) {
    final provider = OAuthProvider("apple.com")
      ..addScope('email')
      ..addScope('name');

    // Sign in the user with Firebase.
    return await FirebaseAuth.instance.signInWithPopup(provider);
  }
  // To prevent replay attacks with the credential returned from Apple, we
  // include a nonce in the credential request. When signing in in with
  // Firebase, the nonce in the id token returned by Apple, is expected to
  // match the sha256 hash of `rawNonce`.
  final rawNonce = generateNonce();
  final nonce = sha256ofString(rawNonce);

  // Request credential for the currently signed in Apple account.
  final appleCredential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: nonce,
  );

  // Create an `OAuthCredential` from the credential returned by Apple.
  final identityToken = appleCredential.identityToken;
  if (identityToken == null) {
    throw StateError('Apple did not return an identity token.');
  }
  final oauthCredential = AppleAuthProvider.credentialWithIDToken(
    identityToken,
    rawNonce,
    AppleFullPersonName(
      givenName: appleCredential.givenName,
      familyName: appleCredential.familyName,
    ),
  );

  // Sign in the user with Firebase. If the nonce we generated earlier does
  // not match the nonce in `appleCredential.identityToken`, sign in will fail.
  final user =
      await FirebaseAuth.instance.signInWithCredential(oauthCredential);

  final displayName = [appleCredential.givenName, appleCredential.familyName]
      .where((name) => name != null)
      .join(' ');

  // The display name does not automatically come with the user.
  if (displayName.isNotEmpty) {
    await user.user?.updateDisplayName(displayName);
  }

  return user;
}

bool userUsesAppleProvider(User user) =>
    user.providerData.any((provider) => provider.providerId == 'apple.com');

/// Reauthenticates an Apple-linked user and revokes the fresh Apple
/// authorization before an immediate account-deletion request is queued.
/// Firebase does not retain the Apple authorization code, so it must be
/// obtained again at deletion time.
Future<void> revokeAppleAuthorizationForAccountDeletion({
  required bool requiredByServer,
}) async {
  var user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('Sign in again before deleting your account.');
  }
  await user.reload();
  user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('Sign in again before deleting your account.');
  }
  if (!userUsesAppleProvider(user)) {
    if (requiredByServer) {
      throw StateError(
        'The server requires Apple authorization revocation, but the refreshed '
        'account providers did not include Apple. Start deletion again or use '
        'the public deletion-request email.',
      );
    }
    return;
  }
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.macOS)) {
    throw StateError(
      'Apple-linked account deletion must be completed in the Pipe Buyer '
      'app on an Apple device, or through the deletion-request email on the '
      'public account-deletion page.',
    );
  }

  final rawNonce = generateNonce();
  final appleCredential = await SignInWithApple.getAppleIDCredential(
    scopes: const [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: sha256ofString(rawNonce),
  );
  final authorizationCode = appleCredential.authorizationCode.trim();
  final identityToken = appleCredential.identityToken;
  if (authorizationCode.isEmpty || identityToken == null) {
    throw StateError(
      'Apple did not return the authorization needed to delete this account.',
    );
  }

  final credential = AppleAuthProvider.credentialWithIDToken(
    identityToken,
    rawNonce,
    AppleFullPersonName(
      givenName: appleCredential.givenName,
      familyName: appleCredential.familyName,
    ),
  );
  await user.reauthenticateWithCredential(credential);
  // Refresh the Firebase credential before the destructive Apple revocation.
  // If this fails, the account retains its Apple authorization and the caller
  // can retry safely. The refreshed auth_time is then available to the
  // short-lived backend sequencing check after revocation succeeds.
  await user.getIdToken(true);
  await FirebaseAuth.instance.revokeTokenWithAuthorizationCode(
    authorizationCode,
  );
}
