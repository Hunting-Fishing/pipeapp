import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TycoonSound { tap, success, shift, error }

/// A small boundary for testing feedback without speakers or platform channels.
/// Implementations must cancel a pending start when [stop] or [dispose] is called.
abstract interface class TycoonAudioBackend {
  Future<void> playAsset(String assetKey);
  Future<void> stop();
  Future<void> dispose();
}

abstract interface class TycoonAudioPreferenceStorage {
  Future<bool?> read();
  Future<void> write(bool enabled);
}

class _PreferencesAudioStorage implements TycoonAudioPreferenceStorage {
  @override
  Future<bool?> read() async => (await SharedPreferences.getInstance())
      .getBool(TycoonAudioFeedback.preferenceKey);

  @override
  Future<void> write(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(
        TycoonAudioFeedback.preferenceKey, enabled)) {
      throw StateError('Device storage did not accept the audio preference.');
    }
  }
}

/// Optional, local sound effects. The game never waits for a sound to succeed.
///
/// Call [load] once when the screen opens. Loading or enabling sound does not
/// play anything or create an audio player; only an explicit [play] can do so.
/// [assets] contains Flutter asset keys, including `assets/`. An embedded host
/// can supply [resolveAssetPath] to add its `packages/oil_gas_tycoon/` prefix.
class TycoonAudioFeedback extends ChangeNotifier {
  TycoonAudioFeedback({
    required Map<TycoonSound, String> assets,
    String Function(String)? resolveAssetPath,
    TycoonAudioPreferenceStorage? preferenceStorage,
    TycoonAudioBackend Function()? backendFactory,
  })  : _assets = Map.unmodifiable(assets),
        _resolveAssetPath = resolveAssetPath ?? _identityPath,
        _preferences = preferenceStorage ?? _PreferencesAudioStorage(),
        _backendFactory = backendFactory ?? _AudioplayersFeedbackBackend.new;

  static const preferenceKey = 'pipebuyer.oil_gas_tycoon.audio.enabled';
  static const _operationTimeout = Duration(seconds: 3);

  final Map<TycoonSound, String> _assets;
  final String Function(String) _resolveAssetPath;
  final TycoonAudioPreferenceStorage _preferences;
  final TycoonAudioBackend Function() _backendFactory;
  TycoonAudioBackend? _backend;
  Future<void>? _loading;
  Future<void>? _writing;
  Future<void>? _stopping;
  bool? _preferenceToWrite;
  bool _enabled = false;
  bool _busy = false;
  bool _unavailable = false;
  bool _disposed = false;
  bool _backendClosed = false;
  int _preferenceRevision = 0;

  bool get enabled => _enabled;

  static String _identityPath(String path) => path;

  Future<void> load() =>
      _disposed ? Future<void>.value() : (_loading ??= _loadPreference());

  Future<void> _loadPreference() async {
    final revision = _preferenceRevision;
    try {
      final saved = await _preferences.read();
      // A slow storage read must not undo a more recent user toggle.
      if (_disposed || revision != _preferenceRevision || saved == null) return;
      if (_enabled != saved) {
        _enabled = saved;
        notifyListeners();
      }
    } on Object {
      // Audio is optional; unreadable settings leave the current choice alone.
    }
  }

  /// Changes the current session immediately and saves the latest choice.
  /// Storage failures never interrupt a game action or turn sound on by default.
  Future<void> setEnabled(bool value) {
    if (_disposed) return Future<void>.value();
    _preferenceRevision++;
    if (_enabled != value) {
      _enabled = value;
      if (!value) unawaited(_stopCurrent());
      notifyListeners();
    }
    // One pending preference is enough, even while storage is slow.
    _preferenceToWrite = value;
    return _writing ??= _writePreferences().whenComplete(() => _writing = null);
  }

  Future<void> _writePreferences() async {
    while (_preferenceToWrite != null) {
      final value = _preferenceToWrite!;
      _preferenceToWrite = null;
      try {
        await _preferences.write(value);
      } on Object {
        // The session setting still works if local storage is unavailable.
      }
    }
  }

  /// Plays at most one cue at a time. Busy cues are dropped, never queued.
  void play(TycoonSound cue) {
    if (_disposed || !_enabled || _busy || _stopping != null || _unavailable) {
      return;
    }
    try {
      final asset = _assets[cue];
      if (asset == null) return;
      final path = _resolveAssetPath(asset);
      if (!_isLocalAsset(path)) return;
      _busy = true;
      unawaited(_play(path));
    } on Object {
      // A host's asset resolver must not be able to break an economic action.
    }
  }

  static bool _isLocalAsset(String path) {
    final uri = Uri.tryParse(path);
    return path.isNotEmpty &&
        !path.startsWith('/') &&
        !path.contains('\\') &&
        uri != null &&
        !uri.hasScheme &&
        !uri.hasAuthority &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        path.split('/').every((part) {
          // Uri normalizes dot segments, so inspect the original path too.
          final decoded = Uri.decodeComponent(part);
          return decoded.isNotEmpty &&
              decoded != '.' &&
              decoded != '..' &&
              !decoded.contains('/') &&
              !decoded.contains('\\');
        });
  }

  Future<void> _play(String path) async {
    try {
      final backend = _backend ??= _backendFactory();
      await backend.playAsset(path).timeout(_operationTimeout);
    } on TimeoutException {
      // Do not accumulate commands behind a hung platform operation. Retiring
      // the backend also cancels any delayed start if the platform recovers.
      _unavailable = true;
      unawaited(_closeBackend());
    } on Object {
      unawaited(_stopCurrent());
    } finally {
      _busy = false;
    }
  }

  Future<void> _stopCurrent() {
    if (_backend == null || _backendClosed) return Future<void>.value();
    return _stopping ??= _stop().whenComplete(() => _stopping = null);
  }

  Future<void> _stop() async {
    try {
      await _backend!.stop().timeout(_operationTimeout);
    } on Object {
      _unavailable = true;
      unawaited(_closeBackend());
    }
  }

  Future<void> _closeBackend() async {
    final backend = _backend;
    if (backend == null || _backendClosed) return;
    _backendClosed = true;
    try {
      await backend.dispose().timeout(_operationTimeout);
    } on Object {
      // Disposal is best effort if the platform itself is unavailable.
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_closeBackend());
    super.dispose();
  }
}

/// Serializes native operations and invalidates pending starts synchronously.
/// There is no preload, remote source, or background loop. On iOS the plugin
/// applies the ambient category to this app's shared AVAudioSession, so native
/// integration must verify mixing alongside any other host audio features.
class _AudioplayersFeedbackBackend implements TycoonAudioBackend {
  AudioPlayer? _player;
  Future<void> _commands = Future<void>.value();
  Future<void>? _stopTask;
  Future<void>? _disposeTask;
  bool _configured = false;
  bool _disposed = false;
  int _generation = 0;

  Future<void> _serial(Future<void> Function() action) {
    final operation = _commands.then((_) => action());
    _commands = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<void> playAsset(String assetKey) {
    final generation = _generation;
    bool mayStart() => !_disposed && generation == _generation;
    return _serial(() async {
      if (!mayStart()) return;
      final player = _player ??= (AudioPlayer()
        ..audioCache = AudioCache(prefix: '')
        ..positionUpdater = null);
      if (!_configured) {
        await player.setAudioContext(AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          // Ambient mixes with other audio and respects the iOS silent switch.
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ));
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(0.35);
        _configured = true;
      }
      if (!mayStart()) return;
      await player.stop();
      if (!mayStart()) return;
      // Preparing a source does not start playback. Check cancellation again
      // afterwards so muting or leaving during asset loading cannot autoplay.
      await player.setSource(AssetSource(assetKey));
      if (mayStart()) await player.resume();
    });
  }

  @override
  Future<void> stop() {
    _generation++;
    if (_disposed) return Future<void>.value();
    return _stopTask ??= _serial(() async {
      if (!_disposed) await _player?.stop();
    }).whenComplete(() => _stopTask = null);
  }

  @override
  Future<void> dispose() {
    _disposed = true;
    _generation++;
    return _disposeTask ??= _serial(() async {
      await _player?.dispose();
      _player = null;
    });
  }
}
