import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/tycoon_engine.dart';
import 'package:oil_gas_tycoon/src/ui/tycoon_game_page.dart';
import 'package:oil_gas_tycoon/src/ui/tycoon_theme.dart';

Finder _inSheet(Finder matching) =>
    find.descendant(of: find.byType(BottomSheet), matching: matching);

Finder _sellButton() => _inSheet(find.ancestor(
    of: find.textContaining('Sell lease ·'),
    matching: find.byType(TextButton)));

void _expectIndependentButton(WidgetTester tester, Finder button,
    {required String label}) {
  final node = tester.getSemantics(button);
  expect(node, isSemantics(label: label, isButton: true, hasTapAction: true));
  // A web progress bar hides descendant controls from the accessibility tree.
  // Native semantics can still contain their nodes, so check their ancestry.
  for (var parent = node.parent; parent != null; parent = parent.parent) {
    expect(parent.role, isNot(SemanticsRole.progressBar),
        reason: '$label must not be a child of the reserves progress bar.');
  }
}

Future<void> _showActions(WidgetTester tester) async {
  await tester.ensureVisible(_sellButton());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'district sheet exposes independent actions before and after feedback',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      final game = GameEngine.newGame();
      var saves = 0;
      await tester.pumpWidget(MaterialApp(
          theme: TycoonPalette.theme,
          home: TycoonGamePage(
              engine: game,
              onChanged: () => saves++,
              onReset: () async {},
              onExport: () async {},
              onImport: () async {})));
      await tester.pumpAndSettle();
      final marker = find.byKey(const Key('district-site-cedar'));
      await tester.ensureVisible(marker);
      await tester.tap(marker);
      await tester.pumpAndSettle();
      await _showActions(tester);

      final manage =
          _inSheet(find.widgetWithText(OutlinedButton, 'Manage well'));
      final pause = _inSheet(find.widgetWithText(FilledButton, 'Pause'));
      final sell = _sellButton();
      _expectIndependentButton(tester, manage, label: 'Manage well');
      _expectIndependentButton(tester, pause, label: 'Pause');
      _expectIndependentButton(tester, sell,
          label: tester.getSemantics(sell).label);

      tester.semantics.tap(find.semantics.byLabel('Manage well'));
      await tester.pumpAndSettle();
      expect(find.text('Set up Cedar Creek'), findsOneWidget);
      tester.semantics.tap(find.semantics.byLabel('Cancel'));
      await tester.pumpAndSettle();
      expect(saves, 0);

      tester.semantics.tap(find.semantics.byLabel('Pause'));
      await tester.pumpAndSettle();
      expect(game.state.leases.first.running, isFalse);
      expect(saves, 1);
      await _showActions(tester);
      _expectIndependentButton(tester, manage, label: 'Manage well');
      _expectIndependentButton(
          tester, _inSheet(find.widgetWithText(FilledButton, 'Start well')),
          label: 'Start well');
      _expectIndependentButton(tester, sell,
          label: tester.getSemantics(sell).label);

      final feedback = find.semantics.byLabel('Cedar Creek paused.');
      expect(feedback, findsOneWidget);
      expect(feedback.evaluate().single, isSemantics(isLiveRegion: true));
      expect(feedback.evaluate().single.role, isNot(SemanticsRole.progressBar));

      tester.semantics.tap(find.semantics.byLabel('Start well'));
      await tester.pumpAndSettle();
      expect(game.state.leases.first.running, isTrue);
      expect(saves, 2);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
