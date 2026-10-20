import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'tycoon_engine.dart';

/// Small boundary that lets saves be tested without a device or platform channel.
abstract interface class TycoonSaveStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PreferencesSaveStorage implements TycoonSaveStorage {
  PreferencesSaveStorage(this.preferences);

  final SharedPreferences preferences;

  static Future<PreferencesSaveStorage> open() async =>
      PreferencesSaveStorage(await SharedPreferences.getInstance());

  @override
  Future<String?> read(String key) async => preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    if (!await preferences.setString(key, value)) {
      throw StateError('Device storage did not accept the save.');
    }
  }
}

class TycoonSaveLoad {
  const TycoonSaveLoad({this.state, this.warning});

  final GameState? state;
  final String? warning;
}

/// Serializes writes, retains the last good save, and never resets corrupt data
/// silently. All imported game data is validated by the engine before use.
class TycoonSaveStore {
  TycoonSaveStore(this.storage);

  static const primaryKey = 'pipebuyer.oil_gas_tycoon.v1';
  static const backupKey = 'pipebuyer.oil_gas_tycoon.v1.backup';
  static const maximumSaveBytes = 512 * 1024;
  static const format = 'oil-gas-tycoon';

  final TycoonSaveStorage storage;
  Future<void> _pending = Future<void>.value();
  String? _lastValid;

  static String encode(GameState state) => jsonEncode({
        'format': format,
        'version': 1,
        'game': state.toJson(),
      });

  static GameState decode(String source) {
    if (source.length > maximumSaveBytes ||
        utf8.encode(source).length > maximumSaveBytes) {
      throw const FormatException('This backup is too large.');
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != format ||
        decoded['version'] != 1 ||
        decoded['game'] is! Map<String, dynamic>) {
      throw const FormatException(
          'Choose an Oil & Gas Tycoon version 1 backup.');
    }
    return GameState.fromJson(decoded['game'] as Map<String, dynamic>);
  }

  Future<TycoonSaveLoad> load() async {
    await _pending;
    final primary = await storage.read(primaryKey);
    if (primary != null) {
      try {
        final state = decode(primary);
        _lastValid = primary;
        return TycoonSaveLoad(state: state);
      } on Object {
        // Retain the unreadable primary until the player saves or imports.
      }
    }
    final backup = await storage.read(backupKey);
    if (backup != null) {
      try {
        final state = decode(backup);
        _lastValid = backup;
        return TycoonSaveLoad(
          state: state,
          warning: 'Recovered your previous save. The most recent action may '
              'need to be repeated. Export a backup in Settings to keep a copy.',
        );
      } on Object {
        // Both copies remain available until the user explicitly starts again.
      }
    }
    return TycoonSaveLoad(
      warning: primary != null || backup != null
          ? 'Your saved company could not be read. Restore an exported backup '
              'or start a new company below.'
          : null,
    );
  }

  Future<void> save(GameState state) {
    // Take the snapshot immediately; later player actions must not change the
    // state associated with a queued save.
    final snapshot = encode(state);
    if (utf8.encode(snapshot).length > maximumSaveBytes) {
      return Future<void>.error(StateError('The saved company is too large.'));
    }
    final operation = _pending.then((_) async {
      final previous = _lastValid;
      if (previous != null) await storage.write(backupKey, previous);
      await storage.write(primaryKey, snapshot);
      _lastValid = snapshot;
    });
    // A failed write is reported to its caller but cannot poison later saves.
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> flush() => _pending;
}
