import 'package:flutter/foundation.dart';

bool shouldEnableRemoteDiagnosticReporting({
  required String environment,
  required bool requested,
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (!requested ||
      isWeb ||
      (environment != 'staging' && environment != 'production')) {
    return false;
  }
  return switch (platform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS =>
      true,
    _ => false,
  };
}
