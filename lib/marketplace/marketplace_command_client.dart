import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MarketplaceCommandClient {
  MarketplaceCommandClient({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Future<Map<String, dynamic>> execute(
    String command,
    Map<String, Object?> payload,
  ) async {
    if (_auth.currentUser == null) {
      throw StateError('Sign in to continue.');
    }
    try {
      final response = await _functions
          .httpsCallable(
            command,
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 30),
            ),
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
