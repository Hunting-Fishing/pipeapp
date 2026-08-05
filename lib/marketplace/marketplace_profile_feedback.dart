import 'package:firebase_core/firebase_core.dart';

String incompleteProfileMessage(Iterable<String> fields) {
  final missing = fields
      .map((field) => field.trim())
      .where((field) => field.isNotEmpty)
      .toList(growable: false);
  if (missing.length == 1 && missing.single == 'Primary community') {
    return 'Please select your primary community on the map before continuing.';
  }
  if (missing.length == 1) {
    return 'Please complete ${missing.single} before continuing.';
  }
  if (missing.isEmpty) {
    return 'Please complete the highlighted profile fields before continuing.';
  }
  final visible = missing.take(3).join(', ');
  final suffix = missing.length > 3 ? ', and ${missing.length - 3} more' : '';
  return 'Please complete the highlighted profile fields before continuing: '
      '$visible$suffix.';
}

String profileOperationErrorMessage(
  Object error, {
  required String fallback,
}) {
  if (error is FirebaseException) {
    switch (error.code.toLowerCase()) {
      case 'unauthenticated':
      case 'user-token-expired':
      case 'invalid-user-token':
        return 'Your sign-in session expired. Sign in again, then retry.';
      case 'permission-denied':
      case 'unauthorized':
        return 'Your profile changes were not accepted. Refresh your sign-in '
            'and try again.';
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
      case 'network-error':
        return 'Pipe Buyer could not reach profile storage. Check your '
            'connection and try again.';
      case 'aborted':
      case 'already-exists':
        return 'Another profile update was detected. Reload the profile and '
            'try again.';
      case 'invalid-argument':
      case 'failed-precondition':
        return 'Some profile information is incomplete or invalid. Review the '
            'highlighted fields and try again.';
      case 'resource-exhausted':
      case 'quota-exceeded':
        return 'Profile storage is temporarily busy. Please try again later.';
    }
  }

  final description = error.toString().toLowerCase();
  if (description.contains('sign in') ||
      description.contains('not signed in') ||
      description.contains('session')) {
    return 'Your sign-in session expired. Sign in again, then retry.';
  }
  return fallback;
}
