import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification endpoints use protected server commands', () {
    final service = File(
      'lib/marketplace/marketplace_notification_service.dart',
    ).readAsStringSync();
    final rules = File('firebase/firestore.rules').readAsStringSync();
    final functions = File('firebase/functions/index.js').readAsStringSync();

    expect(service, contains("'registerNotificationEndpoint'"));
    expect(service, contains("'unregisterNotificationEndpoint'"));
    expect(service, contains('PIPE_FIREBASE_WEB_PUSH_VAPID_KEY'));
    expect(rules, contains('match /notification_endpoints/{endpointId}'));
    expect(rules, contains(".hasOnly(['read', 'readAt'])"));
    expect(functions, contains('exports.onUserNotificationCreated'));
    expect(functions, contains('protectedCallableOptions'));
  });

  test('release workflow binds web push to the selected environment', () {
    final workflow = File('.github/workflows/deploy.yml').readAsStringSync();
    final worker = File('web/firebase-messaging-sw.js').readAsStringSync();

    expect(workflow, contains('PIPE_FIREBASE_WEB_PUSH_VAPID_KEY'));
    expect(workflow, contains('configure_firebase_messaging_worker.mjs'));
    expect(workflow, contains('FIREBASE_TOKEN'));
    expect(worker, contains('firebase.messaging()'));
    expect(worker, contains('firebasejs/12.15.0'));
  });
}
