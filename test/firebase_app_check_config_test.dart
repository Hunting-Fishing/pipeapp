import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/backend/firebase/firebase_app_check_config.dart';

void main() {
  test('local emulator mode skips App Check before Firebase access', () async {
    expect(
      await initFirebaseAppCheck(useEmulators: true),
      AppCheckBootstrapStatus.skippedEmulators,
    );
  });

  test('web activation requires a registered reCAPTCHA site key', () {
    expect(
      appCheckBootstrapDecision(
        isWeb: true,
        platform: TargetPlatform.android,
        requiredForThisBuild: false,
        webSiteKey: '',
      ),
      AppCheckBootstrapDecision.skipMissingWebKey,
    );
    expect(
      appCheckBootstrapDecision(
        isWeb: true,
        platform: TargetPlatform.android,
        requiredForThisBuild: true,
        webSiteKey: '',
      ),
      AppCheckBootstrapDecision.failMissingWebKey,
    );
  });

  test('registered web and supported mobile clients activate App Check', () {
    expect(
      appCheckBootstrapDecision(
        isWeb: true,
        platform: TargetPlatform.android,
        requiredForThisBuild: true,
        webSiteKey: 'registered-public-site-key',
      ),
      AppCheckBootstrapDecision.activate,
    );
    expect(
      appCheckBootstrapDecision(
        isWeb: false,
        platform: TargetPlatform.iOS,
        requiredForThisBuild: true,
        webSiteKey: '',
      ),
      AppCheckBootstrapDecision.activate,
    );
  });

  test('unsupported desktop builds cannot claim enforcement readiness', () {
    expect(
      appCheckBootstrapDecision(
        isWeb: false,
        platform: TargetPlatform.windows,
        requiredForThisBuild: false,
        webSiteKey: '',
      ),
      AppCheckBootstrapDecision.skipUnsupportedPlatform,
    );
    expect(
      appCheckBootstrapDecision(
        isWeb: false,
        platform: TargetPlatform.linux,
        requiredForThisBuild: true,
        webSiteKey: '',
      ),
      AppCheckBootstrapDecision.failUnsupportedPlatform,
    );
  });
}
