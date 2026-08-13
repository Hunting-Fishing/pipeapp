import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('administrator skip is onboarding-only and leaves eligibility unchanged',
      () {
    final security = File(
      'lib/marketplace/marketplace_account_security_page.dart',
    ).readAsStringSync();
    final profile = File(
      'lib/marketplace/marketplace_profile_page.dart',
    ).readAsStringSync();
    final commands = File(
      'firebase/functions/marketplace_commands.js',
    ).readAsStringSync();

    expect(security, contains('Skip phone for now'));
    expect(profile, contains('Skip for now'));
    expect(
        security, contains('marketplaceAdministratorRole(forceRefresh: true)'));
    expect(
        profile, contains('marketplaceAdministratorRole(forceRefresh: true)'));
    expect(profile, isNot(contains("'phoneOwnershipVerified': true")));
    expect(profile, isNot(contains("'accountVerified': true")));
    expect(
      commands,
      contains('Number(user.profileCompletion || 0) !== 100'),
    );
    expect(commands, contains('!approvedAccountVerification(user)'));
  });
}
