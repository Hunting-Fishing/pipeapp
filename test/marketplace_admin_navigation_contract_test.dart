import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account navigation never grants admin visibility by email', () {
    final source =
        File('lib/marketplace/marketplace_account_hub.dart').readAsStringSync();
    expect(source, isNot(contains('jordilwbailey@gmail.com')));
    expect(source, isNot(contains('goldcity4u@icloud.com')));
    expect(source, isNot(contains('isMasterAdmin')));
    expect(source, contains('marketplaceAdministratorState'));
    expect(source, contains('MarketplaceAdministratorState.authorized'));
    expect(source, contains('forceRefresh: true'));
    expect(source, contains('Administrator role not assigned'));
    expect(source, contains('Administrator sign-in requires MFA'));
  });

  test('unauthorized admin screen does not disclose approved identities', () {
    final source = File('lib/marketplace/marketplace_admin_dashboard.dart')
        .readAsStringSync();
    expect(source, isNot(contains('Only master administrator')));
    expect(source, isNot(contains('Current Account:')));
    expect(source, contains('approved administrator account'));
  });
}
