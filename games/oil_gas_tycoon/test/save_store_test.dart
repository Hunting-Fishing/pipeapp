import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/save_store.dart';
import 'package:oil_gas_tycoon/src/tycoon_engine.dart';

class MemorySaveStorage implements TycoonSaveStorage {
  final values = <String, String>{};
  String? failKey;
  Completer<void>? gate;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
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
    final next = GameEngine(restored.state!);
    expect(next.advanceDay().success, isTrue);
    await store.save(next.state);
    expect(
        TycoonSaveStore.decode(memory.values[TycoonSaveStore.backupKey]!).day,
        1);
    expect((await store.load()).state!.day, 2);
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
