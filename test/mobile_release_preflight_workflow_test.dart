import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('.github/workflows/mobile-release-preflight.yml')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');

  test('mobile preflight compiles both native release targets', () {
    expect(source, contains('pull_request:'));
    expect(source, contains('workflow_dispatch:'));
    expect(source, contains('android-release-compile:'));
    expect(source, contains('flutter build appbundle'));
    expect(source, contains('ios-release-compile:'));
    expect(source, contains('runs-on: macos-26'));
    expect(source, contains('flutter build ios'));
    expect(source, contains('--no-codesign'));
    expect(source, contains('sdk_major" -lt 26'));
  });

  test('release-control-only changes trigger and run contract tests', () {
    for (final path in <String>[
      'firebase.json',
      'tool/mobile_link_associations.mjs',
      '.github/workflows/deploy.yml',
      '.github/workflows/mobile-release-candidate.yml',
    ]) {
      expect(source, contains('- $path'));
    }
    expect(source, contains('Verify mobile release-control contracts'));
    expect(source, contains('test/deployment_workflow_test.dart'));
    expect(
      source,
      contains('test/mobile_release_candidate_workflow_test.dart'),
    );
    expect(
      source,
      contains('node --test tool/mobile_link_associations_test.mjs'),
    );
  });

  test('Android preflight uses disposable signing and real verification', () {
    expect(source, contains('mobile-preflight.jks'));
    expect(source, contains('jarsigner -verify -verbose -certs'));
    expect(source, contains("grep -Fq 'jar verified.'"));
    expect(source, contains('rm -f android/key.properties'));
    expect(source, contains('The key was disposable'));
  });

  test('preflight cannot publish or retain distribution artifacts', () {
    expect(source, isNot(contains('actions/upload-artifact')));
    expect(source, isNot(contains('altool --upload-app')));
    expect(source, isNot(contains('fastlane pilot')));
    expect(source, isNot(contains('upload-google-play')));
    expect(source, isNot(contains('ANDROID_UPLOAD_KEYSTORE_BASE64')));
    expect(source, isNot(contains('IOS_DISTRIBUTION_CERTIFICATE_BASE64')));
    expect(source, contains('No artifact was retained or uploaded.'));
  });
}
