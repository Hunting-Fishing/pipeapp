import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/tycoon_engine.dart';
import 'package:oil_gas_tycoon/src/ui/polish/district_map.dart';
import 'package:oil_gas_tycoon/src/ui/tycoon_theme.dart';

Future<void> _pump(WidgetTester tester, GameEngine game,
    {required ValueChanged<LeaseSpec> onSelect,
    double scale = 1,
    bool reduceMotion = false,
    String? selectedLeaseId}) async {
  await tester.pumpWidget(MaterialApp(
      theme: TycoonPalette.theme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion),
          child: child!),
      home: Scaffold(
          body: SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TycoonDistrictMap(
                      engine: game,
                      selectedLeaseId: selectedLeaseId,
                      onLeaseSelected: onSelect))))));
  await tester.pumpAndSettle();
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'district selection opens the requested lease without changing economy',
      (tester) async {
    _size(tester, const Size(1100, 850));
    final game = GameEngine.newGame();
    final before = jsonEncode(game.state.toJson());
    final selected = <String>[];
    await _pump(tester, game, onSelect: (lease) => selected.add(lease.id));
    expect(find.text('1 OWNED'), findsOneWidget);
    expect(find.text('1 READY'), findsOneWidget);
    expect(find.byKey(const Key('district-site-cedar')), findsOneWidget);
    expect(find.byKey(const Key('district-site-dry_creek')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('district-site-dry_creek')));
    expect(selected, ['dry_creek']);
    final detail = find.byKey(const Key('district-selection'));
    expect(find.descendant(of: detail, matching: find.text('Dry Creek Gas')),
        findsOneWidget);
    expect(find.descendant(of: detail, matching: find.text('Available')),
        findsOneWidget);
    await _tap(tester, find.byKey(const Key('district-open-selected')));
    expect(selected, ['dry_creek', 'dry_creek']);
    expect(jsonEncode(game.state.toJson()), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('district markers reflect repairs, pause, and depletion',
      (tester) async {
    _size(tester, const Size(1100, 850));
    final game = GameEngine.newGame();
    await _pump(tester, game, onSelect: (_) {});
    final marker = find.byKey(const Key('district-site-cedar'));
    expect(tester.widget<Semantics>(marker).properties.label,
        contains('Ready to produce'));
    game.state.assets.first.condition = 20;
    await _pump(tester, game, onSelect: (_) {});
    expect(tester.widget<Semantics>(marker).properties.label,
        contains('Repair needed'));
    expect(find.text('0 READY'), findsOneWidget);
    game.state.assets.first.condition = 100;
    game.state.leases.first.running = false;
    await _pump(tester, game, onSelect: (_) {});
    expect(
        tester.widget<Semantics>(marker).properties.label, contains('Paused'));
    game.state.leases.first.reserves = 0;
    game.state.leaseReserves['cedar'] = 0;
    await _pump(tester, game, onSelect: (_) {});
    expect(tester.widget<Semantics>(marker).properties.label,
        contains('Depleted'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused sites show setup and repair blockers before pause',
      (tester) async {
    _size(tester, const Size(1100, 850));
    final game = GameEngine.newGame();
    final lease = game.state.leases.first;
    final asset = game.state.assets.firstWhere((a) => a.id == lease.assetId);
    final operatorId = lease.employeeId;
    final marker = find.byKey(Key('district-site-${lease.id}'));
    lease.running = false;
    lease.assetId = null;
    await _pump(tester, game, onSelect: (_) {});
    expect(tester.widget<Semantics>(marker).properties.label,
        contains('Needs equipment'));

    lease.assetId = asset.id;
    lease.employeeId = null;
    await _pump(tester, game, onSelect: (_) {});
    expect(tester.widget<Semantics>(marker).properties.label,
        contains('Needs operator'));

    lease.employeeId = operatorId;
    asset.condition = 20;
    await _pump(tester, game, onSelect: (_) {});
    expect(tester.widget<Semantics>(marker).properties.label,
        contains('Repair needed'));

    asset.condition = 100;
    await _pump(tester, game, onSelect: (_) {});
    expect(
        tester.widget<Semantics>(marker).properties.label, contains('Paused'));
    expect(find.text('0 READY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('external selection stays synchronized with the detail card',
      (tester) async {
    _size(tester, const Size(900, 850));
    final game = GameEngine.newGame();
    await _pump(tester, game, onSelect: (_) {}, selectedLeaseId: 'cedar');
    await _pump(tester, game, onSelect: (_) {}, selectedLeaseId: 'summit');
    final detail = find.byKey(const Key('district-selection'));
    expect(find.descendant(of: detail, matching: find.text('Summit Gas')),
        findsOneWidget);
    expect(
        tester
            .widget<Semantics>(find.byKey(const Key('district-site-summit')))
            .properties
            .selected,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [const Size(320, 844), const Size(844, 390)]) {
    testWidgets(
        'all district sites remain reachable at $viewport with 200 percent text',
        (tester) async {
      _size(tester, viewport);
      final game = GameEngine.newGame();
      final selected = <String>[];
      await _pump(tester, game,
          onSelect: (lease) => selected.add(lease.id),
          scale: 2,
          reduceMotion: true);
      for (final lease in TycoonCatalog.leases) {
        await _tap(tester, find.byKey(Key('district-site-${lease.id}')));
        expect(selected.last, lease.id);
        expect(tester.takeException(), isNull);
      }
      expect(selected, TycoonCatalog.leases.map((lease) => lease.id).toList());
      if (viewport.width < 740) {
        await _tap(tester, find.byKey(const Key('district-pan-left')));
        await _tap(tester, find.byKey(const Key('district-pan-right')));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
