import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/assets.dart';
import 'package:oil_gas_tycoon/src/audio_feedback.dart';
import 'package:oil_gas_tycoon/src/tycoon_engine.dart';
import 'package:oil_gas_tycoon/src/ui/tycoon_game_page.dart';
import 'package:oil_gas_tycoon/src/ui/tycoon_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpGame(WidgetTester tester, GameEngine engine,
    {VoidCallback? onChanged}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: TycoonPalette.theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: TycoonGamePage(
      engine: engine,
      onChanged: onChanged ?? () {},
      onReset: () async {},
      onExport: () async {},
      onImport: () async {},
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _sheetText(String text) => find.descendant(
    of: find.byType(DraggableScrollableSheet), matching: find.text(text));

Finder _dialogText(String text) =>
    find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _openLease(WidgetTester tester, LeaseSpec lease) async {
  await _tap(tester, find.byKey(Key('district-site-${lease.id}')));
  expect(find.byType(DraggableScrollableSheet), findsOneWidget);
  expect(_sheetText(lease.name), findsWidgets);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('district site opens management and pause changes the real well',
      (tester) async {
    final engine = GameEngine.newGame();
    final lease = engine.state.leases.first;
    final cash = engine.state.cash;
    var saves = 0;
    await _pumpGame(tester, engine, onChanged: () => saves++);
    await _openLease(tester, TycoonCatalog.lease(lease.id));
    expect(_sheetText('Manage well'), findsOneWidget);
    expect(lease.running, isTrue);
    expect(saves, 0);

    await _tap(tester, _sheetText('Pause'));
    expect(lease.running, isFalse);
    expect(engine.state.cash, cash);
    expect(saves, 1);
    expect(_sheetText('PAUSED'), findsOneWidget);
    expect(_sheetText('Start well'), findsOneWidget);
    expect(_sheetText('Pause'), findsNothing);

    await _tap(tester, _sheetText('Start well'));
    expect(lease.running, isTrue);
    expect(saves, 2);
    expect(_sheetText('READY TO PRODUCE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'map purchase confirms, preserves cancellation, then acquires once',
      (tester) async {
    final engine = GameEngine.newGame();
    final spec = TycoonCatalog.leases
        .firstWhere((spec) => !engine.state.leases.any((l) => l.id == spec.id));
    final cost = engine.leasePurchaseCost(spec.id);
    final milestone =
        engine.objectives.firstWhere((goal) => goal.id == 'second_lease');
    final before = jsonEncode(engine.state.toJson());
    final cash = engine.state.cash;
    var saves = 0;
    await _pumpGame(tester, engine, onChanged: () => saves++);
    await _openLease(tester, spec);
    final acquire = 'Acquire · ${tycoonMoney(cost)}';
    await _tap(tester, _sheetText(acquire));
    expect(_dialogText('Acquire ${spec.name}?'), findsOneWidget);
    expect(jsonEncode(engine.state.toJson()), before);
    await _tap(tester, _dialogText('Keep playing'));
    expect(jsonEncode(engine.state.toJson()), before);
    expect(saves, 0);

    await _tap(tester, _sheetText(acquire));
    await _tap(tester, _dialogText('Acquire lease'));
    expect(engine.state.cash, cash - cost + milestone.reward);
    expect(engine.state.completedObjectives, contains(milestone.id));
    expect(engine.state.leases.where((l) => l.id == spec.id), hasLength(1));
    expect(saves, 1);
    expect(_sheetText(acquire), findsNothing);
    expect(_sheetText('UNDEVELOPED'), findsOneWidget);
    expect(
        _sheetText('Develop this site, then assign compatible equipment and '
            'an operator.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final alreadyOwned in [false, true]) {
    testWidgets(
        'pending map purchase revalidates ${alreadyOwned ? 'ownership' : 'cash'}',
        (tester) async {
      final engine = GameEngine.newGame();
      final spec = TycoonCatalog.leases.firstWhere(
          (spec) => !engine.state.leases.any((lease) => lease.id == spec.id));
      final cost = engine.leasePurchaseCost(spec.id);
      var saves = 0;
      await _pumpGame(tester, engine, onChanged: () => saves++);
      await _openLease(tester, spec);
      await _tap(tester, _sheetText('Acquire · ${tycoonMoney(cost)}'));

      // The confirmation is deliberately stale: the engine remains the source
      // of truth when the user finally confirms it.
      if (alreadyOwned) {
        expect(engine.acquireLease(spec.id).success, isTrue);
      } else {
        engine.state.cash = cost - 1;
      }
      final beforeConfirmation = jsonEncode(engine.state.toJson());
      await _tap(tester, _dialogText('Acquire lease'));
      expect(jsonEncode(engine.state.toJson()), beforeConfirmation);
      expect(saves, 0);
      expect(
          _sheetText(alreadyOwned
              ? 'You already own this lease.'
              : 'This lease costs $cost, before development.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sound setting starts off, persists, and never autoplays',
      (tester) async {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channels = [
      MethodChannel('xyz.luan/audioplayers'),
      MethodChannel('xyz.luan/audioplayers.global'),
      MethodChannel('xyz.luan/audioplayers.global/events'),
    ];
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add('${channel.name}/${call.method}');
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    final engine = GameEngine.newGame();
    final before = jsonEncode(engine.state.toJson());
    var saves = 0;
    await _pumpGame(tester, engine, onChanged: () => saves++);
    await _tap(tester, find.byTooltip('Company settings'));
    final toggle = find.byKey(const Key('sound-effects-toggle'));
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await _tap(tester, toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    var preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(TycoonAudioFeedback.preferenceKey), isTrue);
    expect(calls, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _pumpGame(tester, engine, onChanged: () => saves++);
    await _tap(tester, find.byTooltip('Company settings'));
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await _tap(tester, toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(TycoonAudioFeedback.preferenceKey), isFalse);
    expect(calls, isEmpty);
    expect(jsonEncode(engine.state.toJson()), before);
    expect(saves, 0);
    expect(tester.takeException(), isNull);
  });

  test('actual asset manifest resolves every catalogue illustration and cue',
      () async {
    // This also runs from the Pipeapp root to exercise real package-prefixed
    // assets, rather than relying on a synthetic embedded manifest.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys = manifest.listAssets().toSet();
    final resolver = TycoonAssets.fromManifest(keys);
    final bundledLicense = resolver.resolve('assets/fonts/LICENSE.txt');
    expect(keys, contains(bundledLicense));
    final images = <String>{
      for (final spec in TycoonCatalog.assets) resolver.equipment(spec.id),
      for (final spec in TycoonCatalog.businesses) resolver.business(spec.id),
    };
    for (final key in images) {
      expect(keys, contains(key), reason: 'Missing catalogue art: $key');
      final data = await rootBundle.load(key);
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(0), reason: key);
      expect(frame.image.height, greaterThan(0), reason: key);
      frame.image.dispose();
      codec.dispose();
    }
    for (final sound in TycoonSound.values) {
      final local = TycoonAssets.sounds[sound.name];
      expect(local, isNotNull, reason: 'Unmapped cue: $sound');
      final key = resolver.resolve(local!);
      expect(keys, contains(key), reason: 'Missing local sound: $key');
      final data = await rootBundle.load(key);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      expect(bytes.length, greaterThan(44), reason: key);
      expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF', reason: key);
      expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE', reason: key);
    }
  });
}
