import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

String marketplaceCommandErrorMessage(
  Object error, {
  String fallback = 'The marketplace action could not be completed. Try again.',
}) {
  final raw = switch (error) {
    StateError state => state.message.toString(),
    ArgumentError argument => argument.message?.toString() ?? '',
    _ => '',
  };
  final message = raw.trim().replaceFirst(RegExp(r'^Bad state:\s*'), '');
  if (message.isEmpty ||
      message.length > 220 ||
      RegExp(r'(FIRESTORE|firebasejs|gstatic|stack trace|#\d+)',
              caseSensitive: false)
          .hasMatch(message)) {
    return fallback;
  }
  return message;
}

class MarketplaceCommandClient {
  MarketplaceCommandClient({FirebaseFunctions? functions, FirebaseAuth? auth})
      : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<Map<String, dynamic>> execute(
    String command,
    Map<String, Object?> payload, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_auth.currentUser == null) {
      throw StateError('Sign in to continue.');
    }
    try {
      final response = await _functions
          .httpsCallable(
            command,
            options: HttpsCallableOptions(timeout: timeout),
          )
          .call(payload);
      if (response.data is! Map) {
        throw StateError('The server returned an invalid response.');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (error) {
      final fallback = switch (error.code) {
        'unauthenticated' => 'Your session expired. Sign in and try again.',
        'permission-denied' =>
          'Your account is not authorized to complete this action.',
        'resource-exhausted' =>
          'Too many requests were made in a short period. Wait and try again.',
        'failed-precondition' =>
          'This action is not available until the account requirements are complete.',
        'deadline-exceeded' ||
        'unavailable' =>
          'The marketplace service is temporarily unavailable. Try again.',
        'not-found' ||
        'unimplemented' =>
          'This marketplace service is being updated. Refresh and try again.',
        _ => 'The marketplace action could not be completed.',
      };
      throw StateError(
        error.message?.trim().isNotEmpty == true ? error.message! : fallback,
      );
    }
  }
}
