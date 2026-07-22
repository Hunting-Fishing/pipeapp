import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const appCheckWebSiteKey =
    String.fromEnvironment('PIPE_APP_CHECK_WEB_RECAPTCHA_KEY');
const appCheckRequired =
    bool.fromEnvironment('PIPE_APP_CHECK_REQUIRED', defaultValue: false);

enum AppCheckBootstrapDecision {
  activate,
  skipMissingWebKey,
  skipUnsupportedPlatform,
  failMissingWebKey,
  failUnsupportedPlatform,
}

enum AppCheckBootstrapStatus {
  active,
  skippedEmulators,
  skippedMissingWebKey,
  skippedUnsupportedPlatform,
  failed,
}

AppCheckBootstrapDecision appCheckBootstrapDecision({
  required bool isWeb,
  required TargetPlatform platform,
  required bool requiredForThisBuild,
  required String webSiteKey,
}) {
  if (isWeb && webSiteKey.trim().isEmpty) {
    return requiredForThisBuild
        ? AppCheckBootstrapDecision.failMissingWebKey
        : AppCheckBootstrapDecision.skipMissingWebKey;
  }
  final supported = isWeb ||
      platform == TargetPlatform.android ||
      platform == TargetPlatform.iOS ||
      platform == TargetPlatform.macOS;
  if (!supported) {
    return requiredForThisBuild
        ? AppCheckBootstrapDecision.failUnsupportedPlatform
        : AppCheckBootstrapDecision.skipUnsupportedPlatform;
  }
  return AppCheckBootstrapDecision.activate;
}

Future<AppCheckBootstrapStatus> initFirebaseAppCheck({
  bool useEmulators = false,
}) async {
  if (useEmulators) {
    debugPrint('Firebase App Check is disabled for the local emulator suite.');
    return AppCheckBootstrapStatus.skippedEmulators;
  }
  final decision = appCheckBootstrapDecision(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    requiredForThisBuild: appCheckRequired,
    webSiteKey: appCheckWebSiteKey,
  );
  switch (decision) {
    case AppCheckBootstrapDecision.skipMissingWebKey:
      debugPrint(
        'Firebase App Check is staged but inactive on web. '
        'Provide PIPE_APP_CHECK_WEB_RECAPTCHA_KEY after registering the web app.',
      );
      return AppCheckBootstrapStatus.skippedMissingWebKey;
    case AppCheckBootstrapDecision.skipUnsupportedPlatform:
      debugPrint(
        'Firebase App Check is staged but this platform is not enabled in the '
        'current compatible FlutterFire release.',
      );
      return AppCheckBootstrapStatus.skippedUnsupportedPlatform;
    case AppCheckBootstrapDecision.failMissingWebKey:
      throw StateError(
        'This build requires Firebase App Check, but the web reCAPTCHA key '
        'was not provided.',
      );
    case AppCheckBootstrapDecision.failUnsupportedPlatform:
      throw UnsupportedError(
        'This build requires Firebase App Check on an unsupported platform.',
      );
    case AppCheckBootstrapDecision.activate:
      break;
  }

  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb:
          kIsWeb ? ReCaptchaV3Provider(appCheckWebSiteKey.trim()) : null,
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    return AppCheckBootstrapStatus.active;
  } catch (error, stackTrace) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'firebase_app_check',
      context: ErrorDescription('while activating Firebase App Check'),
    ));
    if (appCheckRequired) rethrow;
    return AppCheckBootstrapStatus.failed;
  }
}
