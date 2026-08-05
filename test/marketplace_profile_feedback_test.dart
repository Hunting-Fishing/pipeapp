import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_profile_feedback.dart';

void main() {
  test('primary community has a specific incomplete-profile message', () {
    expect(
      incompleteProfileMessage(const ['Primary community']),
      'Please select your primary community on the map before continuing.',
    );
  });

  test('save errors never expose backend implementation wording', () {
    final message = profileOperationErrorMessage(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      fallback: 'Unable to save.',
    );
    expect(message.toLowerCase(), isNot(contains('firebase')));
    expect(message.toLowerCase(), isNot(contains('rules')));
    expect(message, contains('Refresh your sign-in'));
  });

  test('network failures provide a retryable connection message', () {
    final message = profileOperationErrorMessage(
      FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      fallback: 'Unable to save.',
    );
    expect(message, contains('Check your connection'));
  });
}
