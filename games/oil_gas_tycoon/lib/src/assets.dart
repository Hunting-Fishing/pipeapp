import 'package:flutter/services.dart';

/// Resolves the same offline art and audio in the standalone and embedded game.
class TycoonAssets {
  const TycoonAssets({this.package});

  final String? package;
  static TycoonAssets current = const TycoonAssets();
  static Future<TycoonAssets>? _loading;
  static bool _loaded = false;

  static const sounds = <String, String>{
    'tap': 'assets/audio/tap.wav',
    'success': 'assets/audio/success.wav',
    'shift': 'assets/audio/shift.wav',
    'error': 'assets/audio/error.wav',
  };

  factory TycoonAssets.fromManifest(Iterable<String> keys) => TycoonAssets(
        package:
            keys.contains('packages/oil_gas_tycoon/assets/fonts/LICENSE.txt')
                ? 'oil_gas_tycoon'
                : null,
      );

  static Future<TycoonAssets> load() {
    // Cache the resolved value, not a completed Future tied to an old zone.
    // Each mounted host receives completion in its own async context.
    if (_loaded) return Future<TycoonAssets>.value(current);
    return _loading ??= _readManifest();
  }

  static Future<TycoonAssets> _readManifest() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return current = TycoonAssets.fromManifest(manifest.listAssets());
    } on Object {
      // Optional presentation assets must never prevent a company loading.
      return current;
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  String resolve(String localKey) =>
      package == null ? localKey : 'packages/$package/$localKey';

  String art(String name) => resolve('assets/art/$name.png');

  String equipment(String catalogId) => art(switch (catalogId) {
        'gas_compressor' => 'gas_skid',
        'drill_rig' => 'drilling_rig',
        'tanker' => 'field_tanker',
        'heavy_hauler' => 'heavy_tanker',
        'service_truck' => 'delivery_truck',
        _ => catalogId,
      });

  String business(String catalogId) => art(switch (catalogId) {
        'logistics' => 'warehouse',
        'parts_yard' => 'workshop',
        _ => catalogId,
      });
}
