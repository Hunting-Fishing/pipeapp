import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow =
      File('.github/workflows/mobile-release-candidate.yml').readAsStringSync();

  test('mobile candidates require an explicit protected main commit', () {
    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, isNot(contains('\n  pull_request:')));
    expect(workflow, isNot(contains('\n  push:')));
    expect(workflow, contains('release_sha:'));
    expect(workflow, contains(r'^[0-9a-f]{40}$'));
    expect(workflow, contains('git merge-base --is-ancestor'));
    expect(workflow, contains('origin/main'));
    expect(
      workflow,
      contains("format('mobile-release-{0}', inputs.target_environment)"),
    );
    expect(
      workflow,
      contains(r'${{ secrets.MOBILE_RELEASE_ENVIRONMENT_GUARD }}'),
    );
    expect(
      'The protected mobile release environment guard does not match the '
              'selected environment.'
          .allMatches(workflow)
          .length,
      2,
    );
    expect(workflow, contains('cancel-in-progress: false'));
  });

  test('Android candidate fails closed and verifies its upload signature', () {
    for (final secret in <String>[
      'ANDROID_UPLOAD_KEYSTORE_BASE64',
      'ANDROID_UPLOAD_STORE_PASSWORD',
      'ANDROID_UPLOAD_KEY_ALIAS',
      'ANDROID_UPLOAD_KEY_PASSWORD',
    ]) {
      expect(workflow, contains('\${{ secrets.$secret }}'));
    }
    expect(workflow, contains('flutter build appbundle'));
    expect(workflow, contains('jarsigner -verify -strict'));
    expect(workflow, contains('keytool -printcert -jarfile'));
    expect(workflow, contains('applicationId: \'Pipe.Buyerapp\''));
    expect(workflow, contains("candidateId: 'android-aab'"));
  });

  test('Apple candidate uses manual distribution signing and verifies IPA', () {
    for (final secret in <String>[
      'IOS_DISTRIBUTION_CERTIFICATE_BASE64',
      'IOS_DISTRIBUTION_CERTIFICATE_PASSWORD',
      'IOS_PROVISIONING_PROFILE_BASE64',
      'IOS_EXPORT_OPTIONS_PLIST_BASE64',
    ]) {
      expect(workflow, contains('\${{ secrets.$secret }}'));
    }
    expect(workflow, contains('flutter build ipa'));
    expect(workflow, contains('FLUTTER_XCODE_CODE_SIGN_STYLE=Manual'));
    expect(workflow, contains('FLUTTER_XCODE_DEVELOPMENT_TEAM'));
    expect(workflow, contains('FLUTTER_XCODE_PROVISIONING_PROFILE_SPECIFIER'));
    expect(workflow,
        contains("FLUTTER_XCODE_CODE_SIGN_IDENTITY='Apple Distribution'"));
    expect(workflow, contains('codesign --verify --deep --strict'));
    expect(workflow, contains("candidateId: 'ios-ipa'"));
  });

  test('candidate evidence is SHA-bound, retained, and not store-approved', () {
    expect(
        workflow,
        contains(
            r'PIPE_RELEASE_SHA: ${{ needs.preflight.outputs.release_sha }}'));
    expect(workflow, contains('--dart-define=PIPE_APP_CHECK_REQUIRED=true'));
    expect(workflow, contains('signatureVerified: true'));
    expect(workflow, contains('storeValidated: false'));
    expect(workflow, contains('actions/upload-artifact@v4.6.2'));
    expect(workflow, contains('retention-days: 14'));
    expect(workflow, contains('compression-level: 0'));
    expect(workflow, contains('if: always()'));
    expect(workflow, isNot(contains('altool --upload-app')));
    expect(workflow, isNot(contains('play.google.com')));
  });

  test('controlled Firebase project guards apply to both candidates', () {
    expect(
      'Production candidates must target flutter-flow-pipe.'
          .allMatches(workflow)
          .length,
      2,
    );
    expect(
      'Staging candidates cannot target the production Firebase project.'
          .allMatches(workflow)
          .length,
      2,
    );
    for (final variable in <String>[
      'PIPE_FIREBASE_API_KEY',
      'PIPE_FIREBASE_AUTH_DOMAIN',
      'PIPE_FIREBASE_PROJECT_ID',
      'PIPE_FIREBASE_STORAGE_BUCKET',
      'PIPE_FIREBASE_MESSAGING_SENDER_ID',
      'PIPE_FIREBASE_WEB_APP_ID',
    ]) {
      expect(workflow, contains(variable));
    }
  });
}
