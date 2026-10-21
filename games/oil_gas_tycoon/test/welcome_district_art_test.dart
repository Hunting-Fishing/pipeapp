import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/ui/polish/welcome_district_art.dart';

class _DioramaBundle extends CachingAssetBundle {
  _DioramaBundle({this.missing = const {}});

  final Set<String> missing;
  final loaded = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loaded.add(key);
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    if (missing.contains(key)) throw FlutterError('Missing test art: $key');
    return ByteData.sublistView(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='));
  }
}

const _paths = ['pumpjack.png', 'refinery.png', 'storage.png', 'truck.png'];

Future<void> _pump(WidgetTester tester, _DioramaBundle bundle,
    {double width = 288, String? package}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: DefaultAssetBundle(
              bundle: bundle,
              child: MediaQuery(
                  data: const MediaQueryData(
                      textScaler: TextScaler.linear(2),
                      disableAnimations: true),
                  child: Center(
                      child: SizedBox(
                          width: width,
                          child: TycoonWelcomeDistrictArt(
                              pumpjack: _paths[0],
                              refinery: _paths[1],
                              storage: _paths[2],
                              truck: _paths[3],
                              package: package))))))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('welcome diorama resolves and displays all supplied package art',
      (tester) async {
    final bundle = _DioramaBundle();
    await _pump(tester, bundle, package: 'tycoon_art');
    final context = tester.element(find.byType(TycoonWelcomeDistrictArt));
    await tester.runAsync(() => Future.wait(_paths.map((path) => precacheImage(
        AssetImage(path, package: 'tycoon_art', bundle: bundle), context))));
    await tester.pumpAndSettle();

    expect(
        bundle.loaded,
        containsAll(
            _paths.map((path) => 'packages/tycoon_art/$path').toList()));
    expect(tester.widgetList<RawImage>(find.byType(RawImage)).length, 4);
    for (final sprite in tester.widgetList<RawImage>(find.byType(RawImage))) {
      expect(sprite.image, isNotNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('one missing sprite preserves the rest of the welcome scene',
      (tester) async {
    final bundle = _DioramaBundle(missing: {'truck.png'});
    await _pump(tester, bundle);
    final context = tester.element(find.byType(TycoonWelcomeDistrictArt));
    await tester.runAsync(() => Future.wait(_paths.take(3).map(
        (path) => precacheImage(AssetImage(path, bundle: bundle), context))));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);
    expect(tester.widgetList<RawImage>(find.byType(RawImage)).length, 3);
    for (final sprite in tester.widgetList<RawImage>(find.byType(RawImage))) {
      expect(sprite.image, isNotNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'narrow welcome art stays decorative at large text and reduced motion',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final bundle = _DioramaBundle(missing: _paths.toSet());
      for (final width in [48.0, 160.0, 272.0]) {
        await _pump(tester, bundle, width: width);
        expect(tester.getSize(find.byType(TycoonWelcomeDistrictArt)),
            Size(width, 260));
        expect(tester.semantics.simulatedAccessibilityTraversal(),
            isNot(contains(isSemantics(isImage: true))));
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
    }
  });
}
