import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_home_hero_assets.dart';
import 'package:pipe_app/marketplace/marketplace_home_welcome.dart';

Future<void> _pumpAndCaptureHero(
  WidgetTester tester, {
  required Size surfaceSize,
  required String expectedBackground,
  required String outputName,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final boundaryKey = GlobalKey();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          key: boundaryKey,
          child: SingleChildScrollView(
            child: SizedBox(
              width: surfaceSize.width,
              child: const MarketplaceHomeDiscoveryHero(
                name: 'Staging Demo Business',
                accountType: 'business',
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(tester.takeException(), isNull);
  expect(find.text('PIPE BUYER WORKSPACE'), findsOneWidget);
  expect(
    find.text('Welcome back, Staging Demo Business. Keep your next deal moving.'),
    findsOneWidget,
  );
  expect(find.text('Business account'), findsOneWidget);
  expect(find.text('Verified Businesses'), findsOneWidget);

  final assetNames = tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .whereType<AssetImage>()
      .map((provider) => provider.assetName)
      .toSet();

  expect(assetNames, contains(expectedBackground));
  if (expectedBackground == MarketplaceHomeHeroAssets.desktopBackground) {
    expect(assetNames, isNot(contains(MarketplaceHomeHeroAssets.mobileBackground)));
  } else {
    expect(assetNames, isNot(contains(MarketplaceHomeHeroAssets.desktopBackground)));
  }

  final boundary = boundaryKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  expect(byteData, isNotNull);

  final directory = Directory('build/acceptance');
  directory.createSync(recursive: true);
  File('${directory.path}/$outputName').writeAsBytesSync(
    byteData!.buffer.asUint8List(),
  );
  image.dispose();
}

void main() {
  testWidgets('desktop marketplace hero uses landscape campaign background',
      (tester) async {
    await _pumpAndCaptureHero(
      tester,
      surfaceSize: const Size(1440, 1000),
      expectedBackground: MarketplaceHomeHeroAssets.desktopBackground,
      outputName: 'marketplace-home-hero-desktop-1440x1000.png',
    );
  });

  testWidgets('mobile marketplace hero uses portrait campaign background',
      (tester) async {
    await _pumpAndCaptureHero(
      tester,
      surfaceSize: const Size(390, 844),
      expectedBackground: MarketplaceHomeHeroAssets.mobileBackground,
      outputName: 'marketplace-home-hero-mobile-390x844.png',
    );
  });
}
