import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/app.dart';
import 'package:oil_gas_tycoon/src/save_store.dart';
import 'package:oil_gas_tycoon/src/tycoon_engine.dart';
import 'package:oil_gas_tycoon/src/ui/tycoon_game_page.dart';
import 'package:oil_gas_tycoon/src/ui/tycoon_theme.dart';

import 'save_store_test.dart' show MemorySaveStorage;

Future<void> mountHost(WidgetTester tester, TycoonSaveStore store,
    {GameEngine? initialEngine,
    VoidCallback? onExit,
    Size size = const Size(900, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: TycoonPalette.theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: OilGasTycoonScreen(
        saveStore: store, initialEngine: initialEngine, onExit: onExit),
  ));
  await tester.pumpAndSettle();
}

GameEngine displayedGame(WidgetTester tester) =>
    tester.widget<TycoonGamePage>(find.byType(TycoonGamePage)).engine;

Future<void> setting(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Company settings'));
  await tester.pumpAndSettle();
  final item = find.text(label);
  await tester.ensureVisible(item);
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> reviewBackup(WidgetTester tester, GameState imported,
    {bool welcome = false}) async {
  if (welcome) {
    final restore = find.text('Restore a backup');
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
  } else {
    await setting(tester, 'Restore backup');
  }
  final input = find.descendant(
      of: find.byType(AlertDialog), matching: find.byType(TextField));
  await tester.enterText(input, TycoonSaveStore.encode(imported));
  await tester.tap(find.text('Review backup'));
  await tester.pumpAndSettle();
  expect(find.text('Restore this company?'), findsOneWidget);
  expect(find.textContaining(imported.companyName), findsWidgets);
}

void main() {
  testWidgets(
      'first mobile session names a company, plays, saves, and resumes the exact game',
      (tester) async {
    final memory = MemorySaveStorage();
    final store = TycoonSaveStore(memory);
    await mountHost(tester, store, size: const Size(390, 844));
    expect(find.text('Your company starts here'), findsOneWidget);
    final name = find.byType(TextFormField);
    await tester.ensureVisible(name);
    await tester.enterText(name, '  Prairie Star Energy  ');
    await tester.ensureVisible(find.text('Start my company'));
    await tester.tap(find.text('Start my company'));
    await tester.pumpAndSettle();
    expect(find.text('Prairie Star Energy'), findsOneWidget);
    await tester.tap(find.byKey(const Key('advance-shift')));
    await tester.pumpAndSettle();
    final played = displayedGame(tester).state.toJson();
    expect(played['day'], 2);
    expect(played['oilInventory'], greaterThan(0));
    await store.flush();
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.primaryKey]!)
            .toJson(),
        played);

    // Destroy the host to represent closing/reopening the app, retaining only
    // its device storage rather than the in-memory engine.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await mountHost(tester, TycoonSaveStore(memory),
        size: const Size(390, 844));
    expect(displayedGame(tester).state.toJson(), played);
    expect(find.text('Prairie Star Energy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'invalid backup and cancelled new-company flow preserve current progress',
      (tester) async {
    final memory = MemorySaveStorage();
    final original = GameEngine.newGame(companyName: 'Original Energy');
    original.advanceDay();
    final store = TycoonSaveStore(memory);
    await store.save(original.state);
    final saved = memory.values[TycoonSaveStore.primaryKey];
    await mountHost(tester, store);
    await setting(tester, 'Restore backup');
    final dialog = find.byType(AlertDialog);
    await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        '{bad backup');
    await tester.tap(find.text('Review backup'));
    await tester.pumpAndSettle();
    expect(find.textContaining('That backup could not be restored'),
        findsOneWidget);
    expect(displayedGame(tester).state.companyName, 'Original Energy');
    expect(memory.values[TycoonSaveStore.primaryKey], saved);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await setting(tester, 'Start a new company');
    expect(find.text('Start a new company?'), findsOneWidget);
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
        'Unwanted Reset');
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(displayedGame(tester).state.toJson(), original.state.toJson());
    expect(memory.values[TycoonSaveStore.primaryKey], saved);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'reviewed backup restoration replaces the company and retains a recovery copy',
      (tester) async {
    final memory = MemorySaveStorage();
    final old = GameEngine.newGame(companyName: 'Old Fields');
    final restored =
        GameEngine.newGame(companyName: 'Northern Fields', seed: 77);
    restored.advanceDay();
    restored.advanceDay();
    final store = TycoonSaveStore(memory);
    await store.save(old.state);
    await mountHost(tester, store);
    await reviewBackup(tester, restored.state);
    await tester.tap(find.text('Restore company'));
    await tester.pumpAndSettle();
    expect(displayedGame(tester).state.toJson(), restored.state.toJson());
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.primaryKey]!)
            .toJson(),
        restored.state.toJson());
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.backupKey]!)
            .toJson(),
        old.state.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed saving offers keep playing, export, and explicit leave choices',
      (tester) async {
    final memory = MemorySaveStorage();
    final original = GameEngine.newGame(companyName: 'Unsaved Energy');
    final store = TycoonSaveStore(memory);
    await store.save(original.state);
    var exits = 0;
    await mountHost(tester, store, onExit: () => exits++);
    memory.failKey = TycoonSaveStore.primaryKey;
    await tester.tap(find.byKey(const Key('advance-shift')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open the Exchange'));
    await tester.tap(find.text('Open the Exchange'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('This change could not be saved'), findsOneWidget);

    await setting(tester, 'Return to Pipe Buyer');
    expect(find.text('Your latest changes are not saved'), findsOneWidget);
    expect(exits, 0);
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(exits, 0);
    expect(displayedGame(tester).state.day, 2);
    await setting(tester, 'Return to Pipe Buyer');
    await tester.tap(find.text('Export backup'));
    await tester.pumpAndSettle();
    expect(find.text('Export company backup'), findsOneWidget);
    final backupText = tester
        .widget<SelectableText>(find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(SelectableText)))
        .data!;
    expect(TycoonSaveStore.decode(backupText).day, 2);
    expect(exits, 0);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await setting(tester, 'Return to Pipe Buyer');
    await tester.tap(find.text('Leave anyway'));
    await tester.pumpAndSettle();
    expect(exits, 1);
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.primaryKey]!).day,
        1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a failed import write keeps both displayed and stored original company',
      (tester) async {
    final memory = MemorySaveStorage();
    final old = GameEngine.newGame(companyName: 'Retained Energy');
    final incoming = GameEngine.newGame(companyName: 'Incoming Energy');
    incoming.advanceDay();
    final store = TycoonSaveStore(memory);
    await store.save(old.state);
    await mountHost(tester, store);
    await reviewBackup(tester, incoming.state);
    memory.failKey = TycoonSaveStore.primaryKey;
    await tester.tap(find.text('Restore company'));
    await tester.pumpAndSettle();
    expect(displayedGame(tester).state.toJson(), old.state.toJson());
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.primaryKey]!)
            .toJson(),
        old.state.toJson());
    expect(find.textContaining('Your current company is still open'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'embedded system Back uses the same failed-save decision before popping the game route',
      (tester) async {
    final memory = MemorySaveStorage();
    final store = TycoonSaveStore(memory);
    await store
        .save(GameEngine.newGame(companyName: 'Back Guard Energy').state);
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: TycoonPalette.theme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!),
      home: Builder(
          builder: (context) => Scaffold(
              body: Center(
                  child: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (routeContext) => OilGasTycoonScreen(
                                  saveStore: store,
                                  onExit: () =>
                                      Navigator.of(routeContext).pop()))),
                      child: const Text('Open tycoon'))))),
    ));
    await tester.tap(find.text('Open tycoon'));
    await tester.pumpAndSettle();
    memory.failKey = TycoonSaveStore.primaryKey;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Your latest changes are not saved'), findsOneWidget);
    expect(find.byType(TycoonGamePage), findsOneWidget);
    await tester.tap(find.text('Keep playing'));
    await tester.pumpAndSettle();
    expect(find.text('Back Guard Energy'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave anyway'));
    await tester.pumpAndSettle();
    expect(find.text('Open tycoon'), findsOneWidget);
    expect(find.byType(TycoonGamePage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'slow restore blocks game actions, keyboard, exit and lifecycle overwrites',
      (tester) async {
    final memory = MemorySaveStorage();
    final old = GameEngine.newGame(companyName: 'Before Import');
    final incoming = GameEngine.newGame(companyName: 'After Import');
    for (var day = 0; day < 5; day++) {
      incoming.advanceDay();
    }
    final store = TycoonSaveStore(memory);
    await store.save(old.state);
    var exits = 0;
    await mountHost(tester, store, onExit: () => exits++);
    await reviewBackup(tester, incoming.state);
    final gate = Completer<void>();
    memory.gate = gate;
    await tester.tap(find.text('Restore company'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Restoring your company…'), findsOneWidget);
    expect(displayedGame(tester).state.day, 1);
    await tester.tap(find.byKey(const Key('advance-shift')),
        warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 100));
    expect(displayedGame(tester).state.day, 1);
    expect(exits, 0);
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.primaryKey]!)
            .companyName,
        'Before Import');
    gate.complete();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await store.flush();
    expect(displayedGame(tester).state.toJson(), incoming.state.toJson());
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.primaryKey]!)
            .toJson(),
        incoming.state.toJson());
    expect(find.text('Restoring your company…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'slow restore from welcome prevents an accidental new company replacing the backup',
      (tester) async {
    final memory = MemorySaveStorage();
    final store = TycoonSaveStore(memory);
    final incoming = GameEngine.newGame(companyName: 'Restored Starter');
    incoming.advanceDay();
    await mountHost(tester, store);
    await tester.enterText(
        find.byType(TextFormField), 'Accidental New Company');
    await reviewBackup(tester, incoming.state, welcome: true);
    final gate = Completer<void>();
    memory.gate = gate;
    await tester.tap(find.text('Restore company'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Restoring your company…'), findsOneWidget);
    await tester.tap(find.text('Start my company'), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 100));
    expect(memory.values[TycoonSaveStore.primaryKey], isNull);
    gate.complete();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await store.flush();
    expect(displayedGame(tester).state.toJson(), incoming.state.toJson());
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.primaryKey]!)
            .toJson(),
        incoming.state.toJson());
    expect(tester.takeException(), isNull);
  });
}
