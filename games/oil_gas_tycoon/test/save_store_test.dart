import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/save_store.dart';
import 'package:oil_gas_tycoon/src/tycoon_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemorySaveStorage implements TycoonSaveStorage {
  final values = <String, String>{};
  final writeAttempts = <String>[];
  String? failKey;
  Completer<void>? gate;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writeAttempts.add(key);
    final wait = gate;
    if (wait != null) {
      gate = null;
      await wait.future;
    }
    if (failKey == key) throw StateError('Storage is full');
    values[key] = value;
  }
}

void main() {
  test('new install has no invented progress or recovery warning', () async {
    final result = await TycoonSaveStore(MemorySaveStorage()).load();
    expect(result.state, isNull);
    expect(result.warning, isNull);
  });

  test('produced and traded company resumes with all state intact', () async {
    final memory = MemorySaveStorage();
    final engine = GameEngine.newGame(companyName: 'North Star Energy');
    expect(engine.advanceDay().success, isTrue);
    expect(engine.state.oilInventory, greaterThan(0));
    expect(
        engine.tradeCommodity(Commodity.oil, 50, buy: false).success, isTrue);
    await TycoonSaveStore(memory).save(engine.state);
    final loaded = await TycoonSaveStore(memory).load();
    expect(loaded.state!.toJson(), engine.state.toJson());
    expect(loaded.warning, isNull);
  });

  test('rapid actions save their own snapshots in order, latest wins',
      () async {
    final memory = MemorySaveStorage();
    final gate = Completer<void>();
    memory.gate = gate;
    final store = TycoonSaveStore(memory);
    final engine = GameEngine.newGame();
    final firstDay = engine.state.day;
    final first = store.save(engine.state);
    expect(engine.advanceDay().success, isTrue);
    final second = store.save(engine.state);
    expect(engine.advanceDay().success, isTrue);
    final third = store.save(engine.state);
    gate.complete();
    await Future.wait([first, second, third]);
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.primaryKey]!).day,
        firstDay + 2);
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.backupKey]!).day,
        firstDay + 1);
  });

  test('unchanged lifecycle saves retain the previous meaningful recovery copy',
      () async {
    final memory = MemorySaveStorage();
    final store = TycoonSaveStore(memory);
    final engine = GameEngine.newGame();
    await store.save(engine.state);
    expect(engine.advanceDay().success, isTrue);
    await store.save(engine.state);
    final saved = Map<String, String>.from(memory.values);
    memory.writeAttempts.clear();

    expect(
        await Future.wait([
          store.save(engine.state),
          store.save(engine.state),
          store.save(engine.state),
        ]),
        everyElement(isFalse));

    expect(memory.writeAttempts, isEmpty);
    expect(memory.values, saved);
    expect(TycoonSaveStore.decode(saved[TycoonSaveStore.backupKey]!).day, 1);
  });

  test('closing an unchanged older session cannot overwrite newer progress',
      () async {
    final memory = MemorySaveStorage();
    final current = TycoonSaveStore(memory);
    final activeGame = GameEngine.newGame();
    await current.save(activeGame.state);
    final older = TycoonSaveStore(memory);
    final oldGame = GameEngine((await older.load()).state!);

    expect(activeGame.advanceDay().success, isTrue);
    await current.save(activeGame.state);
    expect(activeGame.advanceDay().success, isTrue);
    await current.save(activeGame.state);
    final saved = Map<String, String>.from(memory.values);
    memory.writeAttempts.clear();

    await older.save(oldGame.state);
    await older.save(oldGame.state);

    expect(memory.writeAttempts, isEmpty);
    expect(memory.values, saved);
    expect((await TycoonSaveStore(memory).load()).state!.day, 3);
    expect(TycoonSaveStore.decode(saved[TycoonSaveStore.backupKey]!).day, 2);
  });

  test('changed stale sessions reject before either write and can reload safely',
      () async {
    final memory = MemorySaveStorage();
    final current = TycoonSaveStore(memory);
    final activeGame = GameEngine.newGame();
    await current.save(activeGame.state);
    final stale = TycoonSaveStore(memory);
    final staleGame = GameEngine((await stale.load()).state!);
    expect(activeGame.advanceDay().success, isTrue);
    await current.save(activeGame.state);
    expect(activeGame.advanceDay().success, isTrue);
    await current.save(activeGame.state);
    final saved = Map<String, String>.from(memory.values);
    memory.writeAttempts.clear();

    expect(staleGame.advanceDay().success, isTrue);
    final exportable = TycoonSaveStore.encode(staleGame.state);
    await expectLater(stale.save(staleGame.state),
        throwsA(isA<TycoonSaveConflict>()));
    await expectLater(stale.save(staleGame.state),
        throwsA(isA<TycoonSaveConflict>()));
    await stale.flush();
    expect(memory.writeAttempts, isEmpty);
    expect(memory.values, saved);
    expect(TycoonSaveStore.encode(staleGame.state), exportable);

    final resumed = GameEngine((await stale.load()).state!);
    expect(resumed.state.day, 3);
    expect(resumed.advanceDay().success, isTrue);
    await stale.save(resumed.state);
    expect((await TycoonSaveStore(memory).load()).state!.day, 4);
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.backupKey]!).day,
        3);
  });

  test('two welcome sessions cannot replace the company started in the other',
      () async {
    final memory = MemorySaveStorage();
    final first = TycoonSaveStore(memory);
    final second = TycoonSaveStore(memory);
    expect((await first.load()).state, isNull);
    expect((await second.load()).state, isNull);
    await first.save(GameEngine.newGame(companyName: 'First Company').state);
    final saved = Map<String, String>.from(memory.values);
    memory.writeAttempts.clear();

    await expectLater(
        second.save(GameEngine.newGame(companyName: 'Second Company').state),
        throwsA(isA<TycoonSaveConflict>()));

    expect(memory.writeAttempts, isEmpty);
    expect(memory.values, saved);
  });

  test('explicit replacement checks conflicts even for an unchanged snapshot',
      () async {
    final memory = MemorySaveStorage();
    final current = TycoonSaveStore(memory);
    final active = GameEngine.newGame();
    await current.save(active.state);
    final older = TycoonSaveStore(memory);
    final oldState = (await older.load()).state!;
    expect(active.advanceDay().success, isTrue);
    await current.save(active.state);
    final saved = Map<String, String>.from(memory.values);
    memory.writeAttempts.clear();

    expect(await older.save(oldState), isFalse);
    await expectLater(older.save(oldState, explicitReplace: true),
        throwsA(isA<TycoonSaveConflict>()));

    expect(memory.writeAttempts, isEmpty);
    expect(memory.values, saved);
  });

  test('unchanged legacy sessions preserve the original schema bytes',
      () async {
    final legacy =
        File('test/fixtures/legacy_v1_company.json').readAsStringSync();
    final memory = MemorySaveStorage()
      ..values[TycoonSaveStore.primaryKey] = legacy;
    final store = TycoonSaveStore(memory);
    final loaded = await store.load();
    expect(TycoonSaveStore.encode(loaded.state!), isNot(legacy));

    await store.save(loaded.state!);

    expect(memory.writeAttempts, isEmpty);
    expect(memory.values, {TycoonSaveStore.primaryKey: legacy});
  });

  test('preferences reads refresh values changed outside the cached instance',
      () async {
    SharedPreferences.setMockInitialValues({TycoonSaveStore.primaryKey: 'old'});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final preferences = await SharedPreferences.getInstance();
    final storage = PreferencesSaveStorage(preferences);
    expect(preferences.getString(TycoonSaveStore.primaryKey), 'old');

    SharedPreferences.setMockInitialValues({TycoonSaveStore.primaryKey: 'new'});
    expect(preferences.getString(TycoonSaveStore.primaryKey), 'old');
    expect(await storage.read(TycoonSaveStore.primaryKey), 'new');
  });

  test('corrupt primary recovers last good company and reports lost action',
      () async {
    final memory = MemorySaveStorage();
    final engine = GameEngine.newGame(companyName: 'Recovered Energy');
    final store = TycoonSaveStore(memory);
    await store.save(engine.state);
    expect(engine.advanceDay().success, isTrue);
    await store.save(engine.state);
    memory.values[TycoonSaveStore.primaryKey] = '{partial write';
    final recovered = await TycoonSaveStore(memory).load();
    expect(recovered.state!.day, 1);
    expect(recovered.state!.companyName, 'Recovered Energy');
    expect(recovered.warning, contains('Recovered'));
    expect(memory.values[TycoonSaveStore.primaryKey], '{partial write');
  });

  test('two corrupt copies are not silently erased or replaced', () async {
    final memory = MemorySaveStorage();
    memory.values[TycoonSaveStore.primaryKey] = 'bad primary';
    memory.values[TycoonSaveStore.backupKey] = 'bad backup';
    final previous = Map<String, String>.from(memory.values);
    final loaded = await TycoonSaveStore(memory).load();
    expect(loaded.state, isNull);
    expect(loaded.warning, contains('could not be read'));
    expect(memory.values, previous);
  });

  test('explicit new company after corrupt reload uses the observed baseline',
      () async {
    final memory = MemorySaveStorage();
    final store = TycoonSaveStore(memory);
    await store.save(GameEngine.newGame(companyName: 'Previous Company').state);
    memory.values[TycoonSaveStore.primaryKey] = 'bad primary';
    memory.values[TycoonSaveStore.backupKey] = 'bad backup';
    final loaded = await store.load();
    expect(loaded.state, isNull);

    final replacement = GameEngine.newGame(companyName: 'Fresh Company');
    await store.save(replacement.state);

    expect((await TycoonSaveStore(memory).load()).state!.toJson(),
        replacement.state.toJson());
    expect(memory.values[TycoonSaveStore.backupKey], 'bad backup',
        reason: 'A previously loaded company is not a valid recovery baseline.');
  });

  test('failed primary write leaves prior company recoverable; retry succeeds',
      () async {
    final memory = MemorySaveStorage();
    final engine = GameEngine.newGame();
    final store = TycoonSaveStore(memory);
    await store.save(engine.state);
    expect(engine.advanceDay().success, isTrue);
    memory.failKey = TycoonSaveStore.primaryKey;
    await expectLater(store.save(engine.state), throwsStateError);
    final persisted = await TycoonSaveStore(memory).load();
    expect(persisted.state!.day, 1);
    memory.failKey = null;
    await store.save(engine.state);
    expect((await TycoonSaveStore(memory).load()).state!.day, 2);
  });

  test('failed recovery write does not replace the primary', () async {
    final memory = MemorySaveStorage();
    final engine = GameEngine.newGame();
    final store = TycoonSaveStore(memory);
    await store.save(engine.state);
    expect(engine.advanceDay().success, isTrue);
    memory.failKey = TycoonSaveStore.backupKey;
    await expectLater(store.save(engine.state), throwsStateError);
    expect((await TycoonSaveStore(memory).load()).state!.day, 1);
  });

  test('recovery remains valid after a corrupt primary is overwritten',
      () async {
    final memory = MemorySaveStorage();
    final engine = GameEngine.newGame();
    memory.values[TycoonSaveStore.primaryKey] = 'broken';
    memory.values[TycoonSaveStore.backupKey] =
        TycoonSaveStore.encode(engine.state);
    final store = TycoonSaveStore(memory);
    final restored = await store.load();
    final previous = Map<String, String>.from(memory.values);
    await store.save(restored.state!);
    expect(memory.writeAttempts, isEmpty);
    expect(memory.values, previous);
    final next = GameEngine(restored.state!);
    expect(next.advanceDay().success, isTrue);
    await store.save(next.state);
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.backupKey]!).day,
        1);
    expect((await store.load()).state!.day, 2);
  });

  test('a recovered session cannot overwrite a newly repaired primary',
      () async {
    final memory = MemorySaveStorage();
    final game = GameEngine.newGame();
    memory.values[TycoonSaveStore.primaryKey] = 'broken';
    memory.values[TycoonSaveStore.backupKey] = TycoonSaveStore.encode(game.state);
    final recoveredStore = TycoonSaveStore(memory);
    final recovered = GameEngine((await recoveredStore.load()).state!);
    final currentStore = TycoonSaveStore(memory);
    final current = GameEngine((await currentStore.load()).state!);
    expect(current.advanceDay().success, isTrue);
    await currentStore.save(current.state);
    final saved = Map<String, String>.from(memory.values);
    memory.writeAttempts.clear();

    expect(recovered.advanceDay().success, isTrue);
    await expectLater(recoveredStore.save(recovered.state),
        throwsA(isA<TycoonSaveConflict>()));

    expect(memory.writeAttempts, isEmpty);
    expect(memory.values, saved);
  });

  test('explicit restoration can repair an unchanged recovered snapshot',
      () async {
    final valid = TycoonSaveStore.encode(GameEngine.newGame().state);
    final memory = MemorySaveStorage()
      ..values[TycoonSaveStore.primaryKey] = 'broken'
      ..values[TycoonSaveStore.backupKey] = valid;
    final store = TycoonSaveStore(memory);
    final recovered = (await store.load()).state!;

    expect(await store.save(recovered), isFalse);
    expect(memory.values[TycoonSaveStore.primaryKey], 'broken');
    expect(await store.save(recovered, explicitReplace: true), isTrue);

    expect(memory.values[TycoonSaveStore.primaryKey], valid);
    expect(memory.values[TycoonSaveStore.backupKey], valid);
    expect((await TycoonSaveStore(memory).load()).warning, isNull);
  });

  test('imports reject foreign, future, oversized, and invalid game data', () {
    final valid = TycoonSaveStore.encode(GameEngine.newGame().state);
    final future = jsonDecode(valid) as Map<String, dynamic>;
    future['version'] = 999;
    final invalid = jsonDecode(valid) as Map<String, dynamic>;
    (invalid['game'] as Map<String, dynamic>)['cash'] = 'infinite';
    final tooLarge = 'x' * (TycoonSaveStore.maximumSaveBytes + 1);
    for (final source in [
      '{}',
      'null',
      '[]',
      jsonEncode(future),
      jsonEncode(invalid),
      tooLarge
    ]) {
      expect(() => TycoonSaveStore.decode(source), throwsFormatException);
    }
  });

  test('backup export imports independently of device storage', () {
    final engine = GameEngine.newGame(companyName: 'A & B Energy');
    expect(engine.advanceDay().success, isTrue);
    final portable = TycoonSaveStore.encode(engine.state);
    final imported = GameEngine(TycoonSaveStore.decode(portable));
    expect(imported.state.toJson(), engine.state.toJson());
    expect(imported.advanceDay().success, isTrue);
    expect(imported.state.day, engine.state.day + 1);
  });
}
