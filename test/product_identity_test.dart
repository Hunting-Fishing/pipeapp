import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('release surfaces use the Pipe Buyer product name', () {
    final publicSurfaces = <String>[
      'android/app/src/main/res/values/strings.xml',
      'ios/Runner/Info.plist',
      'web/index.html',
      'web/manifest.json',
      'windows/runner/Runner.rc',
      'windows/runner/main.cpp',
      'linux/my_application.cc',
      'macos/Runner/Configs/AppInfo.xcconfig',
    ];
    for (final path in publicSurfaces) {
      final content = source(path);
      expect(content, contains('Pipe Buyer'), reason: path);
      expect(content, isNot(contains('VehicleAppPageTemplates')), reason: path);
      expect(content, isNot(contains('Built with FlutterFlow')), reason: path);
    }
    final androidManifest = source('android/app/src/main/AndroidManifest.xml');
    expect(androidManifest, contains('android:label="@string/app_name"'));
    expect(androidManifest, isNot(contains('VehicleAppPageTemplates')));
  });

  test('mobile media permissions explain user-initiated access', () {
    final android = source('android/app/src/main/AndroidManifest.xml');
    final ios = source('ios/Runner/Info.plist');
    expect(android, contains('android.permission.CAMERA'));
    expect(android, isNot(contains('requestLegacyExternalStorage')));
    expect(ios, contains('NSCameraUsageDescription'));
    expect(ios, contains('NSPhotoLibraryUsageDescription'));
    expect(ios, contains('NSLocationWhenInUseUsageDescription'));
  });

  test('Android release builds never fall back to debug signing', () {
    final gradle = source('android/app/build.gradle');
    expect(gradle, isNot(contains('signingConfig signingConfigs.debug')));
    expect(gradle, isNot(contains('signingConfig = signingConfigs.debug')));
    expect(gradle, contains('releaseSigningFields'));
    expect(gradle, contains('releaseSigningConfigured'));
    expect(gradle, contains('Android release signing is not configured'));
  });
}
