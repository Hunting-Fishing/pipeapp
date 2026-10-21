import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/audio_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _assets = {
  TycoonSound.tap: 'assets/audio/tap.wav',
  TycoonSound.success: 'assets/audio/success.wav',
  TycoonSound.shift: 'assets/audio/shift.wav',
  TycoonSound.error: 'assets/audio/error.wav',
};

class _MemoryAudioPreferences implements TycoonAudioPreferenceStorage {
  bool? value;
  bool failRead = false;
  bool failWrite = false;
  int reads = 0;
  int activeWrites = 0;
  int maximumActiveWrites = 0;
  final writes = <bool>[];
  Completer<void>? readGate;
  Completer<void>? writeGate;

  @override
  Future<bool?> read() async {
    reads++;
    final snapshot = value;
    await readGate?.future;
    if (failRead) throw StateError('Storage is unavailable');
    return snapshot;
  }

  @override
  Future<void> write(bool enabled) async {
    writes.add(enabled);
    activeWrites++;
    if (activeWrites > maximumActiveWrites) {
      maximumActiveWrites = activeWrites;
    }
    try {
      final gate = writeGate;
      writeGate = null;
      await gate?.future;
      if (failWrite) throw StateError('Storage is full');
      value = enabled;
    } finally {
      activeWrites--;
    }
  }
}

class _FakeAudioBackend implements TycoonAudioBackend {
  final requests = <String>[];
  final started = <String>[];
  Completer<void>? playGate;
  Completer<void>? stopGate;
  bool failPlay = false;
  bool failStop = false;
  bool failDispose = false;
  bool disposed = false;
  int stops = 0;
  int disposals = 0;
  int _generation = 0;

  @override
  Future<void> playAsset(String assetKey) async {
    requests.add(assetKey);
    final generation = _generation;
    await playGate?.future;
    if (failPlay) throw StateError('No audio device');
    if (!disposed && generation == _generation) started.add(assetKey);
  }

  @override
  Future<void> stop() async {
    stops++;
    _generation++;
    await stopGate?.future;
    if (failStop) throw StateError('Audio device disconnected');
  }

  @override
  Future<void> dispose() async {
    disposals++;
    disposed = true;
    _generation++;
    if (failDispose) throw StateError('Audio device disconnected');
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts muted and never creates a player while disabled', () async {
    var creations = 0;
    final preferences = _MemoryAudioPreferences();
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: preferences,
      backendFactory: () {
        creations++;
        return _FakeAudioBackend();
      },
    );
    expect(audio.enabled, isFalse);
    audio.play(TycoonSound.tap);
    await audio.load();
    await audio.load();
    for (final cue in TycoonSound.values) {
      audio.play(cue);
    }
    audio.dispose();
    await _settle();
    expect(preferences.reads, 1);
    expect(creations, 0);
  });

  test('loads the saved choice without playing or creating a player', () async {
    var creations = 0;
    var notifications = 0;
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: _MemoryAudioPreferences()..value = true,
      backendFactory: () {
        creations++;
        return _FakeAudioBackend();
      },
    );
    addTearDown(audio.dispose);
    audio.addListener(() => notifications++);
    await audio.load();
    expect(audio.enabled, isTrue);
    expect(notifications, 1);
    expect(creations, 0);
    await audio.setEnabled(false);
    await audio.setEnabled(true);
    expect(creations, 0);
  });

  test('persists its own preference without changing company save data',
      () async {
    const companyKey = 'pipebuyer.oil_gas_tycoon.v1';
    SharedPreferences.setMockInitialValues({companyKey: 'company snapshot'});
    final first = TycoonAudioFeedback(assets: _assets);
    await first.load();
    await first.setEnabled(true);
    first.dispose();
    final second = TycoonAudioFeedback(assets: _assets);
    addTearDown(second.dispose);
    await second.load();
    expect(second.enabled, isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(TycoonAudioFeedback.preferenceKey), isTrue);
    expect(preferences.getString(companyKey), 'company snapshot');
    await second.setEnabled(false);
    expect(preferences.getBool(TycoonAudioFeedback.preferenceKey), isFalse);
  });

  test('a slow preference read cannot undo a newer user choice', () async {
    final gate = Completer<void>();
    final preferences = _MemoryAudioPreferences()
      ..value = true
      ..readGate = gate;
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: preferences,
    );
    addTearDown(audio.dispose);
    final loading = audio.load();
    await audio.setEnabled(false);
    gate.complete();
    await loading;
    expect(audio.enabled, isFalse);
    expect(preferences.value, isFalse);
  });

  test('rapid preference changes serialize and keep only the latest pending',
      () async {
    final gate = Completer<void>();
    final preferences = _MemoryAudioPreferences()..writeGate = gate;
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: preferences,
    );
    addTearDown(audio.dispose);
    final changes = <Future<void>>[audio.setEnabled(true)];
    for (var index = 0; index < 100; index++) {
      changes.add(audio.setEnabled(index.isEven));
    }
    expect(audio.enabled, isFalse);
    expect(preferences.writes, [true]);
    gate.complete();
    await Future.wait(changes);
    expect(preferences.value, isFalse);
    expect(preferences.writes, [true, false]);
    expect(preferences.maximumActiveWrites, 1);
  });

  test('storage failures preserve the session choice and later writes work',
      () async {
    final preferences = _MemoryAudioPreferences()
      ..failRead = true
      ..failWrite = true;
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: preferences,
    );
    addTearDown(audio.dispose);
    await audio.load();
    expect(audio.enabled, isFalse);
    await audio.setEnabled(true);
    expect(audio.enabled, isTrue);
    expect(preferences.value, isNull);
    preferences.failWrite = false;
    await audio.setEnabled(false);
    expect(preferences.value, isFalse);
  });

  test('creates one backend on demand and resolves embedded asset keys',
      () async {
    final backend = _FakeAudioBackend();
    var creations = 0;
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: _MemoryAudioPreferences(),
      resolveAssetPath: (path) => 'packages/oil_gas_tycoon/$path',
      backendFactory: () {
        creations++;
        return backend;
      },
    );
    addTearDown(audio.dispose);
    await audio.setEnabled(true);
    expect(creations, 0);
    for (final cue in TycoonSound.values) {
      audio.play(cue);
      await _settle();
    }
    expect(creations, 1);
    expect(backend.started,
        _assets.values.map((path) => 'packages/oil_gas_tycoon/$path').toList());
  });

  test('unmapped cues and remote or unsafe paths never reach the backend',
      () async {
    var creations = 0;
    for (final path in [
      'https://example.invalid/sound.wav',
      '//example.invalid/sound.wav',
      'data:audio/wav;base64,AAAA',
      '/tmp/sound.wav',
      '../sound.wav',
      'assets/%2e%2e/sound.wav',
      r'assets\sound.wav',
      'assets/sound.wav?remote=1',
    ]) {
      final audio = TycoonAudioFeedback(
        assets: {TycoonSound.tap: path},
        preferenceStorage: _MemoryAudioPreferences(),
        backendFactory: () {
          creations++;
          return _FakeAudioBackend();
        },
      );
      await audio.setEnabled(true);
      audio.play(TycoonSound.success);
      audio.play(TycoonSound.tap);
      audio.dispose();
      expect(creations, 0, reason: 'Rejected asset path: $path');
    }
    expect(creations, 0);
  });

  test('busy sound requests are dropped without a backlog', () async {
    final gate = Completer<void>();
    final backend = _FakeAudioBackend()..playGate = gate;
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: _MemoryAudioPreferences(),
      backendFactory: () => backend,
    );
    addTearDown(audio.dispose);
    await audio.setEnabled(true);
    audio.play(TycoonSound.shift);
    for (var index = 0; index < 100; index++) {
      audio.play(TycoonSound.tap);
    }
    expect(backend.requests, [_assets[TycoonSound.shift]]);
    gate.complete();
    await _settle();
    expect(backend.started, [_assets[TycoonSound.shift]]);
    audio.play(TycoonSound.success);
    await _settle();
    expect(backend.requests,
        [_assets[TycoonSound.shift], _assets[TycoonSound.success]]);
  });

  test('muting cancels a pending start and holds new cues until stop finishes',
      () async {
    final playing = Completer<void>();
    final stopping = Completer<void>();
    final backend = _FakeAudioBackend()
      ..playGate = playing
      ..stopGate = stopping;
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: _MemoryAudioPreferences(),
      backendFactory: () => backend,
    );
    addTearDown(audio.dispose);
    await audio.setEnabled(true);
    audio.play(TycoonSound.tap);
    await audio.setEnabled(false);
    expect(backend.stops, 1);
    audio.play(TycoonSound.error);
    await audio.setEnabled(true);
    playing.complete();
    await _settle();
    audio.play(TycoonSound.shift);
    expect(backend.requests, [_assets[TycoonSound.tap]]);
    expect(backend.started, isEmpty);
    stopping.complete();
    await _settle();
    audio.play(TycoonSound.success);
    await _settle();
    expect(backend.started, [_assets[TycoonSound.success]]);
  });

  test('playback failures are isolated and do not poison subsequent cues',
      () async {
    final backend = _FakeAudioBackend()..failPlay = true;
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: _MemoryAudioPreferences(),
      backendFactory: () => backend,
    );
    addTearDown(audio.dispose);
    await audio.setEnabled(true);
    expect(() => audio.play(TycoonSound.error), returnsNormally);
    await _settle();
    expect(audio.enabled, isTrue);
    expect(backend.stops, 1);
    backend.failPlay = false;
    audio.play(TycoonSound.success);
    await _settle();
    expect(backend.started, [_assets[TycoonSound.success]]);
  });

  test('factory and resolver failures do not escape into caller actions',
      () async {
    var failResolver = true;
    var failFactory = true;
    final backend = _FakeAudioBackend();
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: _MemoryAudioPreferences(),
      resolveAssetPath: (path) {
        if (failResolver) throw StateError('Missing package assets');
        return path;
      },
      backendFactory: () {
        if (failFactory) throw StateError('Unsupported audio platform');
        return backend;
      },
    );
    addTearDown(audio.dispose);
    await audio.setEnabled(true);
    expect(() => audio.play(TycoonSound.tap), returnsNormally);
    failResolver = false;
    expect(() => audio.play(TycoonSound.tap), returnsNormally);
    await _settle();
    failFactory = false;
    audio.play(TycoonSound.tap);
    await _settle();
    expect(backend.started, [_assets[TycoonSound.tap]]);
  });

  test('stop and disposal failures remain isolated and retire the backend',
      () async {
    final backend = _FakeAudioBackend()
      ..failStop = true
      ..failDispose = true;
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: _MemoryAudioPreferences(),
      backendFactory: () => backend,
    );
    await audio.setEnabled(true);
    audio.play(TycoonSound.tap);
    await _settle();
    await audio.setEnabled(false);
    await _settle();
    await audio.setEnabled(true);
    audio.play(TycoonSound.tap);
    await _settle();
    expect(backend.requests, hasLength(1));
    expect(backend.disposals, 1);
    expect(audio.dispose, returnsNormally);
    expect(backend.disposals, 1);
  });

  test('dispose cancels delayed audio, suppresses notifications, and is final',
      () async {
    final playGate = Completer<void>();
    final readGate = Completer<void>();
    final backend = _FakeAudioBackend()..playGate = playGate;
    final preferences = _MemoryAudioPreferences()
      ..value = true
      ..readGate = readGate;
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: preferences,
      backendFactory: () => backend,
    );
    var notifications = 0;
    audio.addListener(() => notifications++);
    final loading = audio.load();
    await audio.setEnabled(true);
    audio.play(TycoonSound.tap);
    audio.dispose();
    audio.dispose();
    await audio.setEnabled(false);
    audio.play(TycoonSound.success);
    readGate.complete();
    playGate.complete();
    await loading;
    await _settle();
    expect(notifications, 1);
    expect(backend.started, isEmpty);
    expect(backend.requests, hasLength(1));
    expect(backend.disposals, 1);
    expect(preferences.writes, [true]);
  });

  testWidgets('a hung playback is retired without queuing or starting late',
      (tester) async {
    final gate = Completer<void>();
    final backend = _FakeAudioBackend()..playGate = gate;
    var creations = 0;
    final audio = TycoonAudioFeedback(
      assets: _assets,
      preferenceStorage: _MemoryAudioPreferences(),
      backendFactory: () {
        creations++;
        return backend;
      },
    );
    await audio.setEnabled(true);
    audio.play(TycoonSound.shift);
    await tester.pump(const Duration(seconds: 4));
    expect(backend.disposals, 1);
    audio.play(TycoonSound.tap);
    gate.complete();
    await tester.pump();
    expect(backend.started, isEmpty);
    expect(backend.requests, hasLength(1));
    expect(creations, 1);
    audio.dispose();
    await tester.pump();
  });
}
