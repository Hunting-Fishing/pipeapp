import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final dashboard = File(
    'lib/marketplace/marketplace_admin_dashboard.dart',
  ).readAsStringSync();
  final manager = File(
    'lib/marketplace/marketplace_admin_role_manager.dart',
  ).readAsStringSync();

  test('generic user profile roles cannot pretend to grant Administrator', () {
    expect(dashboard.contains('Set Role: Administrator'), isFalse);
    expect(dashboard.contains('Administrator access management'), isTrue);
    expect(dashboard.contains('MarketplaceAdminRoleManager'), isTrue);
  });

  test('Flutter administrator surfaces do not hard-code approved identities', () {
    expect(dashboard.contains('jordilwbailey@gmail.com'), isFalse);
    expect(dashboard.contains('goldcity4u@icloud.com'), isFalse);
    expect(manager.contains('jordilwbailey@gmail.com'), isFalse);
    expect(manager.contains('goldcity4u@icloud.com'), isFalse);
    expect(manager.contains("'listAdministratorRoles'"), isTrue);
    expect(manager.contains("'manageAdministratorRole'"), isTrue);
  });
}
