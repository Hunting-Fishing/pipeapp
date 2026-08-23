import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('administration portal exposes the protected Dispatch billing route', () {
    final source = File(
      'lib/marketplace/marketplace_admin_transaction_portal.dart',
    ).readAsStringSync();

    expect(source, contains('length: 5'));
    expect(source, contains("text: 'Dispatch Billing'"));
    expect(source, contains("'/admin/dispatch-billing'"));
    expect(source, contains('Open Dispatch Billing Operations'));
    expect(source, contains('_DispatchBillingShortcut'));
  });

  test('Dispatch shortcut does not add direct financial Firestore writes', () {
    final source = File(
      'lib/marketplace/marketplace_admin_transaction_portal.dart',
    ).readAsStringSync();
    final shortcutStart = source.indexOf('class _DispatchBillingShortcut');

    expect(shortcutStart, greaterThanOrEqualTo(0));
    final shortcut = source.substring(shortcutStart);
    expect(shortcut, isNot(contains('FirebaseFirestore')));
    expect(shortcut, isNot(contains('.set(')));
    expect(shortcut, isNot(contains('.update(')));
    expect(shortcut, isNot(contains('.delete(')));
  });
}
