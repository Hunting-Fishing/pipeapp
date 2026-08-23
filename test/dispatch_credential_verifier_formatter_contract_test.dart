import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('credential reminder command contract survives dart format line wrapping', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_credentials.dart',
    ).readAsStringSync();
    final verifier = File(
      'tool/verify_dispatch_credential_intelligence.ps1',
    ).readAsStringSync();

    final reminderCommand = RegExp(
      r"_commands\s*\.\s*execute\s*\(\s*'syncDispatchCredentialReminderSchedule'",
      multiLine: true,
      dotAll: true,
    );

    expect(reminderCommand.hasMatch(source), isTrue);
    expect(
      verifier,
      contains('Formatter-tolerant structural contracts'),
    );
    expect(
      verifier,
      contains('Credential reminder schedule command contract'),
    );
    expect(
      verifier,
      isNot(contains('"_commands.execute(\'syncDispatchCredentialReminderSchedule\'"')),
    );
  });
}
