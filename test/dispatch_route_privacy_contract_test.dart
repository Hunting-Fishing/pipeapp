import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dispatch route analytics are server owned', () {
    final repository = File(
      'lib/marketplace/marketplace_dispatch_repository.dart',
    ).readAsStringSync();
    expect(repository, isNot(contains("'distanceSource':")));
    expect(repository, isNot(contains("'distanceKm':")));

    final policy = File(
      'firebase/functions/dispatch_command_policy.js',
    ).readAsStringSync();
    expect(policy, contains('rejectClientRouteFields'));
    expect(policy, contains('Route distance is calculated by Pipe Buyer'));
  });

  test('exact Dispatch route records have participant-only rules', () {
    final rules = File('firebase/firestore.rules').readAsStringSync();
    expect(rules, contains('match /dispatch_job_private/{jobId}'));
    expect(rules, contains('resource.data.createdByUid == request.auth.uid'));
    expect(rules, contains('.data.awardedCarrierUid == request.auth.uid'));
    expect(rules, contains('allow create, update, delete: if false;'));
  });
}
