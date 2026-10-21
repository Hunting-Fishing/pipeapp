import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oil_gas_tycoon/src/ui/polish/asset_illustration.dart';

class _ArtBundle extends CachingAssetBundle {
  _ArtBundle(this.imageKey);

  final String imageKey;
  final loaded = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loaded.add(key);
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    if (key != imageKey) throw FlutterError('Missing test art: $key');
    return ByteData.sublistView(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='));
  }
}

Future<void> _pump(WidgetTester tester, Widget illustration,
    {required AssetBundle bundle, double width = 280}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: DefaultAssetBundle(
              bundle: bundle,
              child: MediaQuery(
                  data: const MediaQueryData(
                      textScaler: TextScaler.linear(2),
                      disableAnimations: true),
                  child: Center(
                      child: SizedBox(width: width, child: illustration)))))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bundled art renders once with its accessible image label',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final bundle = _ArtBundle('assets/art/pumpjack.png');
      await _pump(
          tester,
          const TycoonAssetIllustration(
              path: 'assets/art/pumpjack.png',
              semanticLabel: 'Pumpjack equipment',
              fallbackIcon: Icons.oil_barrel_outlined),
          bundle: bundle);
      await tester.runAsync(() => precacheImage(
          AssetImage('assets/art/pumpjack.png', bundle: bundle),
          tester.element(find.byType(TycoonAssetIllustration))));
      await tester.pumpAndSettle();

      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(find.byIcon(Icons.oil_barrel_outlined), findsNothing);
      expect(find.bySemanticsLabel('Pumpjack equipment'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('Pumpjack equipment')),
          matchesSemantics(label: 'Pumpjack equipment', isImage: true));
      expect(tester.getSize(find.byType(TycoonAssetIllustration)),
          const Size(280, 140));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('package sprites resolve through the requested asset package',
      (tester) async {
    final bundle = _ArtBundle('packages/tycoon_art/assets/art/haul_truck.png');
    await _pump(
        tester,
        const TycoonAssetIllustration(
            path: 'assets/art/haul_truck.png',
            package: 'tycoon_art',
            height: 100,
            compact: true,
            fallbackIcon: Icons.local_shipping_outlined),
        bundle: bundle);
    await tester.runAsync(() => precacheImage(
        AssetImage('assets/art/haul_truck.png',
            package: 'tycoon_art', bundle: bundle),
        tester.element(find.byType(TycoonAssetIllustration))));
    await tester.pumpAndSettle();

    expect(bundle.loaded,
        contains('packages/tycoon_art/assets/art/haul_truck.png'));
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing art has a safe fallback within narrow catalog cells',
      (tester) async {
    final bundle = _ArtBundle('unused.png');
    for (final width in [24.0, 56.0, 120.0, 288.0]) {
      await _pump(
          tester,
          const TycoonAssetIllustration(
              path: 'missing.png',
              height: 64,
              compact: true,
              semanticLabel: 'Delivery truck',
              fallbackIcon: Icons.local_shipping_outlined),
          bundle: bundle,
          width: width);
      expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget);
      expect(tester.getSize(find.byType(TycoonAssetIllustration)),
          Size(width, 64));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('decorative illustrations add no unlabeled image semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
          tester,
          const TycoonAssetIllustration(
              path: 'missing.png', fallbackIcon: Icons.factory_outlined),
          bundle: _ArtBundle('unused.png'));

      expect(tester.semantics.simulatedAccessibilityTraversal(),
          isNot(contains(isSemantics(isImage: true))));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
