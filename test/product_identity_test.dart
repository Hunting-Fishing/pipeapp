import 'dart:io';

import 'package:crypto/crypto.dart';
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

  test('quality gate compiles the iOS release target on macOS', () {
    final workflow = source('.github/workflows/quality.yml');
    expect(workflow, contains('ios-compile:'));
    expect(workflow, contains('name: Compile iOS release target'));
    expect(workflow, contains('runs-on: macos-15'));
    expect(workflow, contains('flutter build ios'));
    expect(workflow, contains('--release'));
    expect(workflow, contains('--no-codesign'));
    expect(workflow, contains('build/ios/iphoneos/Runner.app'));
    expect(
      workflow,
      contains(
        'Signing: intentionally disabled; this is compile evidence, '
        'not a distributable candidate',
      ),
    );
  });

  test('launcher icons and splash screens are generated from pinned branding',
      () {
    const masterPath = 'tool/brand/pipe_buyer_app_icon_master_v1.png';
    final master = File(masterPath);
    expect(master.existsSync(), isTrue);
    expect(
      sha256.convert(master.readAsBytesSync()).toString(),
      'd51ebeff1e134a97e691d2f08fba4ea75c185afa0fe46406b367bf5784235ef6',
    );
    final pubspec = source('pubspec.yaml');
    expect(pubspec, contains("image_path: '$masterPath'"));
    expect(pubspec, contains('flutter_native_splash:'));

    final generatedAssets = <String, int>{
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 20000,
      'android/app/src/main/res/drawable-mdpi/splash.png': 50000,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
          'Icon-App-1024x1024@1x.png': 500000,
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png': 50000,
      'web/icons/Icon-512.png': 100000,
      'web/splash/img/light-1x.png': 50000,
      'windows/runner/resources/app_icon.ico': 2000,
    };
    for (final entry in generatedAssets.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: entry.key);
      expect(file.lengthSync(), greaterThan(entry.value), reason: entry.key);
    }

    expect(source('web/manifest.json'), contains('Icon-maskable-512.png'));
    expect(source('android/app/src/main/res/values-v31/styles.xml'),
        contains('@drawable/android12splash'));
    expect(Directory('ios/ImageNotification').existsSync(), isFalse);
    expect(
      File('archive/phase1-disabled/ios-image-notification/README.md')
          .existsSync(),
      isTrue,
    );
  });

  test('Apple privacy manifest declares collected data without tracking', () {
    // Git may check this plist out with CRLF on Windows runners. Normalize the
    // text before asserting structure so the release contract is portable.
    final manifest =
        source('ios/Runner/PrivacyInfo.xcprivacy').replaceAll('\r\n', '\n');
    expect(manifest, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
    expect(manifest, contains('<key>NSPrivacyTrackingDomains</key>'));
    expect(manifest, contains('<key>NSPrivacyCollectedDataTypes</key>'));
    for (final dataType in <String>[
      'NSPrivacyCollectedDataTypeName',
      'NSPrivacyCollectedDataTypeEmailAddress',
      'NSPrivacyCollectedDataTypePhoneNumber',
      'NSPrivacyCollectedDataTypePhysicalAddress',
      'NSPrivacyCollectedDataTypeOtherFinancialInfo',
      'NSPrivacyCollectedDataTypePreciseLocation',
      'NSPrivacyCollectedDataTypeCoarseLocation',
      'NSPrivacyCollectedDataTypeEmailsOrTextMessages',
      'NSPrivacyCollectedDataTypePhotosorVideos',
      'NSPrivacyCollectedDataTypeCustomerSupport',
      'NSPrivacyCollectedDataTypeOtherUserContent',
      'NSPrivacyCollectedDataTypeUserID',
      'NSPrivacyCollectedDataTypeDeviceID',
      'NSPrivacyCollectedDataTypePurchaseHistory',
      'NSPrivacyCollectedDataTypeProductInteraction',
      'NSPrivacyCollectedDataTypeCrashData',
      'NSPrivacyCollectedDataTypeOtherDiagnosticData',
    ]) {
      expect(manifest, contains('<string>$dataType</string>'),
          reason: dataType);
    }
    expect(manifest, isNot(contains('PurposeAnalytics')));
    expect(manifest, isNot(contains('PurposeThirdPartyAdvertising')));
  });
}
