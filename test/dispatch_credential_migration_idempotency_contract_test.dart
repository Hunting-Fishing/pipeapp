import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'tool/apply_dispatch_credential_intelligence.ps1',
  ).readAsStringSync();

  test('credential migration detects installed intelligence semantically', () {
    expect(
      source.contains(
        r'''$currentCredential.Contains('class DispatchCredentialReminderSettings')''',
      ),
      isTrue,
    );
    expect(
      source.contains(
        r'''$currentCredential.Contains('syncDispatchCredentialReminderSchedule')''',
      ),
      isTrue,
    );
    expect(
      source.contains(r'''$currentCredential.Contains('coverageLimit')'''),
      isTrue,
    );
    expect(
      source.contains(r'''$currentCredential.Contains('Analytics & alerts')'''),
      isTrue,
    );
  });

  test('credential migration does not depend on one-line Tab formatting', () {
    expect(
      source.contains(
        '''Tab(icon: Icon(Icons.insights_outlined), text: 'Analytics & alerts')''',
      ),
      isFalse,
    );
  });
}
