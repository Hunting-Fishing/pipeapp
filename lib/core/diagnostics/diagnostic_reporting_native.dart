import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'diagnostic_reporting_policy.dart';

bool _enabled = false;
Future<void> _reportQueue = Future<void>.value();

Future<bool> initializeDiagnosticReporting({
  required String environment,
  required String releaseSha,
  required bool requested,
}) async {
  if (!shouldEnableRemoteDiagnosticReporting(
    environment: environment,
    requested: requested,
    isWeb: false,
    platform: defaultTargetPlatform,
  )) {
    _enabled = false;
    return false;
  }

  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(true);
  await crashlytics.setCustomKey('environment', environment);
  await crashlytics.setCustomKey('release_sha', releaseSha);
  _enabled = true;
  return true;
}

Future<void> reportDiagnostic({
  required Map<String, Object?> record,
  required StackTrace? stackTrace,
}) {
  if (!_enabled) return Future<void>.value();

  final subsystem = record['subsystem']?.toString() ?? 'application';
  final operation = record['operation']?.toString() ?? 'unknown_operation';
  final correlationId = record['correlationId']?.toString() ?? 'not-assigned';
  final safeMessage =
      record['message']?.toString() ?? 'Unexpected application error';

  final nextReport = _reportQueue.catchError((Object _) {}).then((_) async {
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCustomKey('subsystem', subsystem);
    await crashlytics.setCustomKey('operation', operation);
    await crashlytics.setCustomKey('correlation_id', correlationId);
    await crashlytics.recordError(
      StateError(safeMessage),
      stackTrace ?? StackTrace.empty,
      reason: '$subsystem.$operation',
      fatal: record['fatal'] == true,
    );
  });
  _reportQueue = nextReport;
  return nextReport;
}
