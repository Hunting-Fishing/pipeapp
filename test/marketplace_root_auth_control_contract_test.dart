import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed-out marketplace root is controlled by the auth route', () {
    final source = File(
      'lib/marketplace/oil_gas_marketplace.dart',
    ).readAsStringSync();

    final stateStart = source.indexOf(
      'class _OilGasMarketplaceAppState extends State<OilGasMarketplaceApp>',
    );
    final stateEnd = source.indexOf(
      'class _MarketplaceAuthControlBackdrop extends StatelessWidget',
      stateStart,
    );

    expect(stateStart, greaterThanOrEqualTo(0));
    expect(stateEnd, greaterThan(stateStart));

    final state = source.substring(stateStart, stateEnd);

    expect(state, contains('bool _authResolved = false;'));
    expect(state, contains('bool _authGateScheduled = false;'));
    expect(state, contains('bool _authRouteOpen = false;'));
    expect(state, contains('FirebaseAuth.instance.authStateChanges()'));
    expect(state, contains('_authResolved = true;'));
    expect(state, contains('void _scheduleAuthGate()'));
    expect(state, contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(state, contains('unawaited(_showAuth(enforced: true));'));
    expect(
      state,
      contains('if (!_authResolved || FirebaseAuth.instance.currentUser == null)'),
    );
    expect(state, contains('return const _MarketplaceAuthControlBackdrop();'));
    expect(state, contains('MarketplaceAuthPage()'));
    expect(state, contains('enforced &&'));
    expect(state, contains('FirebaseAuth.instance.currentUser == null'));
  });

  test('signed-out control does not replace the existing auth flow', () {
    final authSource = File(
      'lib/marketplace/marketplace_auth_page.dart',
    ).readAsStringSync();

    expect(
      authSource,
      contains('FirebaseAuth.instance.signInWithEmailAndPassword'),
    );
    expect(
      authSource,
      contains('FirebaseAuth.instance.createUserWithEmailAndPassword'),
    );
    expect(
      authSource,
      contains('MarketplaceAccountSecurityPage('),
    );
  });
}
