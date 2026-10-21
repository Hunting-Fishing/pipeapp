import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/tycoon_engine.dart';
import 'package:oil_gas_tycoon/src/ui/tycoon_game_page.dart';
import 'package:oil_gas_tycoon/src/ui/tycoon_theme.dart';

Future<void> pumpGame(WidgetTester tester, GameEngine engine,
    {double textScale = 1, VoidCallback? changed}) async {
  await tester.pumpWidget(MaterialApp(
    theme: TycoonPalette.theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale), disableAnimations: true),
      child: child!,
    ),
    home: TycoonGamePage(
      engine: engine,
      onChanged: changed ?? () {},
      onReset: () async {},
      onExport: () async {},
      onImport: () async {},
    ),
  ));
  await tester.pumpAndSettle();
}

Finder navigationLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('mobile player produces, sells oil, and advances another shift',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = GameEngine.newGame(companyName: 'Cedar Energy');
    var saves = 0;
    await pumpGame(tester, engine, changed: () => saves++);

    expect(find.text('Cedar Energy'), findsOneWidget);
    expect(find.text('The next great energy empire.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('advance-shift')));
    await tester.pumpAndSettle();
    expect(engine.state.day, 2);
    expect(engine.state.oilInventory, greaterThan(0));
    expect(find.text('Shift 1 complete'), findsOneWidget);
    final produced = engine.state.oilInventory;
    final cashBeforeSale = engine.state.cash;
    await tester.ensureVisible(find.text('Open the Exchange'));
    await tester.tap(find.text('Open the Exchange'));
    await tester.pumpAndSettle();
    expect(find.text('Buy smart. Sell stronger.'), findsOneWidget);

    final sell = find.widgetWithText(FilledButton, 'Sell stock').first;
    await tester.ensureVisible(sell);
    await tester.tap(sell);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final quantityField =
        find.descendant(of: dialog, matching: find.byType(TextField));
    await tester.enterText(quantityField, '$produced');
    await tester.tap(find.descendant(
        of: dialog, matching: find.widgetWithText(FilledButton, 'Sell stock')));
    await tester.pumpAndSettle();
    expect(engine.state.oilInventory, 0);
    expect(engine.state.cash, greaterThan(cashBeforeSale));
    expect(saves, 2);

    await tester.tap(find.byKey(const Key('advance-shift')));
    await tester.pumpAndSettle();
    expect(engine.state.day, 3);
    expect(engine.state.oilInventory, greaterThan(0));
    expect(saves, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trade validation keeps state intact and explains invalid input',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = GameEngine.newGame();
    await pumpGame(tester, engine);
    await tester.tap(navigationLabel('Exchange'));
    await tester.pumpAndSettle();
    final buy = find.widgetWithText(OutlinedButton, 'Buy stock').first;
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    final before = engine.state.cash;
    await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)), '0');
    await tester.tap(find.descendant(
        of: dialog, matching: find.widgetWithText(FilledButton, 'Buy stock')));
    await tester.pumpAndSettle();
    expect(
        find.text('Enter a whole number greater than zero.'), findsOneWidget);
    expect(engine.state.cash, before);
    expect(engine.state.oilInventory, 0);
    await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        '9999999');
    await tester.tap(find.descendant(
        of: dialog, matching: find.widgetWithText(FilledButton, 'Buy stock')));
    await tester.pumpAndSettle();
    expect(engine.state.cash, before);
    expect(dialog, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (const Size(320, 740), 1.0),
    (const Size(320, 740), 2.0),
    (const Size(360, 800), 2.0),
    (const Size(844, 390), 1.0),
    (const Size(1280, 800), 1.0),
  ]) {
    testWidgets(
        'all game screens fit ${scenario.$1.width}x${scenario.$1.height} at text ${scenario.$2}',
        (tester) async {
      tester.view.physicalSize = scenario.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpGame(tester, GameEngine.newGame(), textScale: scenario.$2);
      expect(tester.takeException(), isNull);
      final desktop = scenario.$1.width >= 900;
      for (final label in [
        'Exchange',
        desktop ? 'Fleet & equipment' : 'Fleet',
        'Company',
        'Operations'
      ]) {
        final nav = desktop
            ? find.descendant(
                of: find.byType(NavigationRail), matching: find.text(label))
            : navigationLabel(label);
        await tester.tap(nav);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label top');
        // Every screen's content is built; scroll through it so later content is
        // visible and navigation remains available above the device safe area.
        final scrollable = find.byType(SingleChildScrollView).first;
        await tester.drag(scrollable, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label scrolled');
      }
      await tester.tap(find.byTooltip('Company settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Export backup'), 120,
          scrollable: find
              .descendant(
                  of: find.byType(DraggableScrollableSheet),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.text('Export backup'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Restore backup'), 120,
          scrollable: find
              .descendant(
                  of: find.byType(DraggableScrollableSheet),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.text('Restore backup'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'settings');
    });
  }

  testWidgets('software licenses are reachable from company settings',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpGame(tester, GameEngine.newGame());
    await tester.tap(find.byTooltip('Company settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Licenses'), 140,
        scrollable: find
            .descendant(
                of: find.byType(DraggableScrollableSheet),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('Licenses'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text('Oil & Gas Tycoon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'releasing an asset requires confirmation and cancelling preserves it',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = GameEngine.newGame();
    await pumpGame(tester, engine);
    await tester.tap(navigationLabel('Fleet'));
    await tester.pumpAndSettle();
    final sell = find
        .widgetWithText(TextButton,
            'Sell ${tycoonMoney(engine.assetSaleValue(engine.state.assets.first.id), compact: true)}')
        .first;
    await tester.ensureVisible(sell);
    await tester.tap(sell);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    final assetsBefore = engine.state.assets.length;
    final cashBefore = engine.state.cash;
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(engine.state.assets.length, assetsBefore);
    expect(engine.state.cash, cashBefore);
    expect(tester.takeException(), isNull);
  });
}
