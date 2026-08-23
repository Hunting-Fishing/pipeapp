import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web startup owns the only visible branded loading surface', () {
    final web = File('web/index.html').readAsStringSync();
    final nav = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();

    expect(web, contains('id="pipe-startup"'));
    expect(web, contains('id="pipe-service-truck"'));
    expect(web, contains('id="pipe-pumpjack"'));
    expect(web, contains('pipe-pumpjack-rock'));
    expect(web, contains("window.setTimeout(removePipeStartup, 1400);"));
    expect(web, contains("const truck = document.getElementById('pipe-service-truck');"));
    expect(web, contains("const pumpjack = document.getElementById('pipe-pumpjack');"));

    expect(
      nav,
      contains('final child = page; // Web/native startup owns the loading surface.'),
    );
    expect(nav, isNot(contains('final child = appStateNotifier.loading')));
  });

  test('marketplace root retains the recorded enforced auth control gate', () {
    final marketplace = File(
      'lib/marketplace/oil_gas_marketplace.dart',
    ).readAsStringSync();

    expect(marketplace, contains('bool _authResolved = false;'));
    expect(marketplace, contains('void _scheduleAuthGate()'));
    expect(marketplace, contains('Future<void> _showAuth({required bool enforced}) async'));
    expect(
      marketplace,
      contains('if (!_authResolved || FirebaseAuth.instance.currentUser == null)'),
    );
    expect(marketplace, contains('MarketplaceAuthPage()'));
  });
}
