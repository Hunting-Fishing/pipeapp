import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web startup owns the only visible branded loading surface', () {
    final web = File('web/index.html').readAsStringSync();
    final nav = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();

    expect(web, contains('id="pipe-startup"'));
    expect(web, contains('id="pipe-startup-progress"'));
    expect(web, contains('class="pipe-startup-card"'));
    expect(
        web,
        contains(
            '<div class="pipe-startup-label">Marketplace · Dispatch</div>'));
    expect(
        web, contains('<div class="pipe-startup-sublabel">Timed Buying</div>'));
    expect(web, contains("window.setTimeout(removePipeStartup, 1400);"));
    expect(web, isNot(contains('id="pipe-service-truck"')));
    expect(web, isNot(contains('id="pipe-pumpjack"')));
    expect(web, isNot(contains('id="pipe-route-telemetry"')));

    expect(
      nav,
      contains(
          'final child = page; // Web/native startup owns the loading surface.'),
    );
    expect(nav, isNot(contains('final child = appStateNotifier.loading')));
  });

  test(
      'web startup enforces mobile safe-areas, dynamic viewport height, and 44px touch targets',
      () {
    final web = File('web/index.html').readAsStringSync();

    expect(web, contains('viewport-fit=cover'));
    expect(web, contains('height: 100dvh;'));
    expect(web, contains('env(safe-area-inset-top'));
    expect(web, contains('env(safe-area-inset-bottom'));
    expect(web, contains('@media (max-width: 640px)'));
    expect(web, contains('min-height: 44px;'));
    expect(web, contains('@media (max-width: 359px)'));
    expect(web,
        contains('@media (max-height: 520px) and (orientation: landscape)'));
    expect(web, contains('href="https://www.pipebuyer.com/partner"'));
    expect(web, contains('href="https://www.pipebuyer.com/insurance"'));
    expect(web, contains('href="https://www.pipebuyer.com/privacy"'));
    expect(web, contains('href="https://www.pipebuyer.com/terms"'));
  });

  test('marketplace root retains the recorded enforced auth control gate', () {
    final marketplace = File(
      'lib/marketplace/oil_gas_marketplace.dart',
    ).readAsStringSync();

    expect(marketplace, contains('bool _authResolved = false;'));
    expect(marketplace, contains('void _scheduleAuthGate()'));
    expect(marketplace,
        contains('Future<void> _showAuth({required bool enforced}) async'));
    expect(
      marketplace,
      contains(
          'if (!_authResolved || FirebaseAuth.instance.currentUser == null)'),
    );
    expect(marketplace, contains('MarketplaceAuthPage()'));
  });
}
