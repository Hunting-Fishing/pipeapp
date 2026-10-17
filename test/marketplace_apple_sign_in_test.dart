import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_auth_page.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  testWidgets('iOS offers Apple sign-in wherever Google sign-in is offered',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: MarketplaceAuthPage()),
      );

      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      final appleButton = tester.widget<SignInWithAppleButton>(
        find.byKey(const Key('marketplace-apple-sign-in')),
      );
      expect(appleButton.onPressed, isNotNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android keeps Google sign-in without an Apple-only control',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const MaterialApp(home: MarketplaceAuthPage()),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('iOS target declares Apple login and export-compliance contracts', () {
    final entitlements =
        File('ios/Runner/Runner.entitlements').readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final authPage =
        File('lib/marketplace/marketplace_auth_page.dart').readAsStringSync();

    expect(
      entitlements,
      contains('<key>com.apple.developer.applesignin</key>'),
    );
    expect(entitlements, contains('<string>Default</string>'));
    expect(project, contains('com.apple.SignInWithApple = {'));
    expect(project, contains('enabled = 1;'));
    expect(authPage, contains('appleSignIn()'));
    expect(
      info.replaceAll('\r\n', '\n'),
      contains('<key>ITSAppUsesNonExemptEncryption</key>\n\t\t<false/>'),
    );
  });
}
