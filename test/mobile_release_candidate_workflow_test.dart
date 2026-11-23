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
      contains(
        'Requested version \$BUILD_NAME+\$BUILD_NUMBER does not match '
        'pubspec.yaml \$declared_version.',
      ),
    );
    expect(
      workflow,
      contains(
        'Update the source-controlled release version before building a store '
        'candidate.',
      ),
    );
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
    expect(workflow, contains('java-version: 21'));
    expect(workflow, isNot(contains(r'$RUNNER_TEMP/store_password')));
    final androidBuildStep = workflow.substring(
      workflow.indexOf('- name: Build and verify signed Android candidate'),
      workflow.indexOf('- name: Remove Android signing material'),
    );
    expect(
      androidBuildStep,
      contains(r'STORE_PASS="$(echo -n "$ANDROID_UPLOAD_STORE_PASSWORD"'),
    );
    expect(
      androidBuildStep,
      contains(r'KEY_ALIAS="$(echo -n "$ANDROID_UPLOAD_KEY_ALIAS"'),
    );
    expect(
      androidBuildStep.indexOf('STORE_PASS='),
      lessThan(androidBuildStep.indexOf('jarsigner -verify -strict')),
    );
    expect(
      androidBuildStep.indexOf('KEY_ALIAS='),
      lessThan(androidBuildStep.indexOf('keytool -exportcert')),
    );
    expect(workflow, contains('jarsigner -verify -strict -verbose -certs'));
    expect(
      workflow,
      contains('-keystore "\$RUNNER_TEMP/upload-keystore.jks"'),
    );
    expect(workflow, contains("grep -Fq 'jar verified.'"));
    expect(workflow, contains('keytool -exportcert'));
    expect(workflow, contains('keytool -printcert -jarfile'));
    expect(
      workflow,
      contains('cmp -s "\$expected_certificate" "\$candidate_certificate"'),
    );
    expect(workflow, isNot(contains("grep -c 'META-INF/'")));
    expect(
      workflow,
      contains(
        "signatureVerification: "
        "'jarsigner-strict-and-upload-certificate-match'",
      ),
    );
    expect(workflow, contains("applicationId: 'Pipe.Buyerapp'"));
    expect(workflow, contains("candidateId: 'android-aab'"));
    expect(
      workflow.indexOf('jarsigner -verify -strict'),
      lessThan(workflow.indexOf("signatureVerified: true")),
    );
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
    expect(workflow, contains('--export-options-plist='));
    // FLUTTER_XCODE_* env-var exports must not be used — they spread provisioning
    // profile assignment to every SPM dependency target which cannot accept one.
    expect(workflow, isNot(contains('export FLUTTER_XCODE_CODE_SIGN_STYLE')));
    expect(workflow,
        isNot(contains('export FLUTTER_XCODE_PROVISIONING_PROFILE_SPECIFIER')));
    expect(
        workflow, isNot(contains('export FLUTTER_XCODE_CODE_SIGN_IDENTITY')));
    expect(workflow, contains('codesign --verify --deep --strict'));
    expect(workflow, contains("candidateId: 'ios-ipa'"));
    expect(
      workflow,
      contains(
        'Print :Entitlements:com.apple.developer.applesignin:0',
      ),
    );
    expect(
      workflow,
      contains(
        'Provisioning profile must include Sign in with Apple with the Default entitlement.',
      ),
    );
    expect(
      workflow.indexOf('profile_apple_sign_in='),
      lessThan(workflow.indexOf('flutter build ipa')),
    );
    expect(
      workflow,
      contains(
        'Print :Entitlements:com.apple.developer.associated-domains',
      ),
    );
    expect(
      workflow,
      contains(
        'Provisioning profile must include Associated Domains for applinks:pipebuyer.com and applinks:www.pipebuyer.com.',
      ),
    );
    expect(
      workflow,
      contains(r"applinks:pipebuyer\.com[[:space:]]*$"),
    );
    expect(
      workflow,
      contains(r"applinks:www\.pipebuyer\.com[[:space:]]*$"),
    );
    expect(
      workflow.indexOf('profile_associated_domains='),
      lessThan(workflow.indexOf('flutter build ipa')),
    );
    expect(
      workflow.indexOf(
        'Provisioning profile must include Associated Domains',
      ),
      lessThan(workflow.indexOf('flutter build ipa')),
    );
    expect(workflow, contains('codesign -d --entitlements :-'));
    expect(workflow, contains('ios-embedded-entitlements.plist'));
    final appleCandidateStep = workflow.substring(
      workflow.indexOf(
        '- name: Install signing material and build Apple candidate',
      ),
      workflow.indexOf('- name: Upload signed IPA to App Store Connect'),
    );
    for (final entitlement in <String>[
      'Exported IPA is missing the production Push Notifications entitlement.',
      'Exported IPA is missing the Sign in with Apple entitlement.',
      'Exported IPA is missing the production App Attest entitlement.',
      'Exported IPA is missing one or more required Associated Domains.',
    ]) {
      expect(appleCandidateStep, contains(entitlement));
      expect(
        appleCandidateStep.indexOf(entitlement),
        lessThan(appleCandidateStep.indexOf("signatureVerified: true")),
      );
    }
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
    expect(workflow, contains('xcrun altool --upload-app'));
    expect(workflow, contains('continue-on-error: false'));
    final appleUploadStep = workflow.substring(
      workflow.indexOf('- name: Upload signed IPA to App Store Connect'),
      workflow.indexOf('- name: Record staging Apple upload boundary'),
    );
    expect(
      appleUploadStep,
      contains("if: inputs.target_environment == 'production'"),
    );
    final stagingBoundaryStep = workflow.substring(
      workflow.indexOf('- name: Record staging Apple upload boundary'),
      workflow.indexOf('- name: Remove Apple signing material'),
    );
    expect(
      stagingBoundaryStep,
      contains("if: inputs.target_environment == 'staging'"),
    );
    expect(
      stagingBoundaryStep,
      contains('The signed staging IPA was not uploaded to App Store Connect.'),
    );
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
    expect(workflow, isNot(contains(r'Got: \`$GUARD\`')));
    expect(
      'The protected guard value was not logged.'.allMatches(workflow),
      hasLength(2),
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

  test('both signed candidates require the public support address', () {
    expect(
      r'PIPE_PUBLIC_SUPPORT_EMAIL: ${{ vars.PIPE_PUBLIC_SUPPORT_EMAIL }}'
          .allMatches(workflow),
      hasLength(2),
    );
    expect(
      '--dart-define="PIPE_PUBLIC_SUPPORT_EMAIL=\$PIPE_PUBLIC_SUPPORT_EMAIL"'
          .allMatches(workflow),
      hasLength(2),
    );
  });
}
