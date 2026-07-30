import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../accessibility/pipe_accessibility_theme.dart';
import '../accessibility/pipe_status_feedback.dart';
import 'diagnostic_reporting.dart';

/// Non-sensitive release context attached to every structured diagnostic.
class AppBuildContext {
  const AppBuildContext({
    required this.environment,
    required this.releaseSha,
    required this.remoteDiagnosticsRequested,
  });

  static const current = AppBuildContext(
    environment: String.fromEnvironment(
      'PIPE_ENV',
      defaultValue: 'development',
    ),
    releaseSha: String.fromEnvironment(
      'PIPE_RELEASE_SHA',
      defaultValue: 'local',
    ),
    remoteDiagnosticsRequested: bool.fromEnvironment(
      'PIPE_REMOTE_DIAGNOSTICS_ENABLED',
      defaultValue: false,
    ),
  );

  final String environment;
  final String releaseSha;
  final bool remoteDiagnosticsRequested;

  Map<String, String> toMap() => {
        'environment': environment,
        'releaseSha': releaseSha,
      };
}

/// Central error boundary used by web, Android, Apple, and desktop builds.
///
/// The console sink is deliberately non-sensitive. A production crash
/// reporting adapter can forward the same structured record after its provider
/// and privacy controls are configured.
class AppDiagnostics {
  AppDiagnostics._();

  static FlutterExceptionHandler? _previousFlutterHandler;
  static ErrorCallback? _previousPlatformHandler;
  static int _correlationSequence = 0;
  static bool _remoteReportingEnabled = false;

  static void install() {
    _previousFlutterHandler ??= FlutterError.onError;
    _previousPlatformHandler ??= PlatformDispatcher.instance.onError;

    FlutterError.onError = (details) {
      record(
        details.exception,
        details.stack,
        subsystem: details.library ?? 'flutter',
        operation: details.context?.toDescription() ?? 'framework_callback',
        fatal: false,
      );
      _previousFlutterHandler?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      record(
        error,
        stackTrace,
        subsystem: 'platform',
        operation: 'uncaught_platform_error',
        fatal: true,
      );
      _previousPlatformHandler?.call(error, stackTrace);
      return true;
    };
  }

  static void run(Future<void> Function() body) {
    runZonedGuarded(
      body,
      (error, stackTrace) => record(
        error,
        stackTrace,
        subsystem: 'zone',
        operation: 'uncaught_async_error',
        fatal: true,
      ),
    );
  }

  /// Enables the native production reporter after Firebase is initialized.
  ///
  /// Collection remains disabled for local, CI, test, web, and unsupported
  /// desktop builds. Reporter startup failures never prevent the app loading.
  static Future<void> initializeRemoteReporting() async {
    try {
      _remoteReportingEnabled = await initializeDiagnosticReporting(
        environment: AppBuildContext.current.environment,
        releaseSha: AppBuildContext.current.releaseSha,
        requested: AppBuildContext.current.remoteDiagnosticsRequested,
      );
    } catch (error) {
      _remoteReportingEnabled = false;
      debugPrint(jsonEncode({
        'type': 'pipe_buyer_diagnostics_status',
        ...AppBuildContext.current.toMap(),
        'enabled': false,
        'status': 'initialization_failed',
        'errorType': error.runtimeType.toString(),
      }));
    }
  }

  static void record(
    Object error,
    StackTrace? stackTrace, {
    required String subsystem,
    required String operation,
    required bool fatal,
  }) {
    final now = DateTime.now().toUtc();
    final record = <String, Object?>{
      'type': 'pipe_buyer_error',
      ...AppBuildContext.current.toMap(),
      'timestamp': now.toIso8601String(),
      'correlationId': _newCorrelationId(now),
      'subsystem': subsystem,
      'operation': operation,
      'fatal': fatal,
      'errorType': error.runtimeType.toString(),
      'message': _safeMessage(error),
      if (kDebugMode && stackTrace != null)
        'stack': stackTrace.toString().split('\n').take(12).join('\n'),
    };
    debugPrint(jsonEncode(record));
    if (_remoteReportingEnabled) {
      unawaited(
        reportDiagnostic(record: record, stackTrace: stackTrace).catchError(
          (Object error) => debugPrint(jsonEncode({
            'type': 'pipe_buyer_diagnostics_status',
            ...AppBuildContext.current.toMap(),
            'enabled': true,
            'status': 'report_failed',
            'errorType': error.runtimeType.toString(),
          })),
        ),
      );
    }
  }

  /// Emits a non-sensitive startup timing record for local and remote
  /// troubleshooting. Stage identifiers and durations never include user data.
  static void recordStartupEvent({
    required String stage,
    required String label,
    required String status,
    required int progressPercent,
    required Duration elapsed,
    Duration? stageElapsed,
    Object? error,
  }) {
    final record = <String, Object?>{
      'type': 'pipe_buyer_startup',
      ...AppBuildContext.current.toMap(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'stage': stage,
      'label': label,
      'status': status,
      'progressPercent': progressPercent.clamp(0, 100),
      'elapsedMs': elapsed.inMilliseconds,
      if (stageElapsed != null) 'stageElapsedMs': stageElapsed.inMilliseconds,
      if (error != null) 'errorType': error.runtimeType.toString(),
    };
    debugPrint(jsonEncode(record));
  }

  static String _newCorrelationId(DateTime timestamp) {
    _correlationSequence = (_correlationSequence + 1) % 1000000;
    return '${timestamp.microsecondsSinceEpoch.toRadixString(36)}-'
        '${_correlationSequence.toRadixString(36).padLeft(4, '0')}';
  }

  static String _safeMessage(Object error) {
    var firstLine = error.toString().split('\n').first.trim();
    if (firstLine.isEmpty) return 'Unexpected application error';
    firstLine = firstLine
        .replaceAll(
          RegExp(
            r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
            caseSensitive: false,
          ),
          '[redacted-email]',
        )
        .replaceAll(
          RegExp(r'https?://\S+', caseSensitive: false),
          '[redacted-url]',
        )
        .replaceAll(
          RegExp(r'\+?\d[\d\s().-]{7,}\d'),
          '[redacted-phone]',
        );
    return firstLine.length <= 500 ? firstLine : firstLine.substring(0, 500);
  }

  @visibleForTesting
  static String safeMessageForTesting(Object error) => _safeMessage(error);

  @visibleForTesting
  static String correlationIdForTesting(DateTime timestamp) =>
      _newCorrelationId(timestamp);
}

/// Safe screen used when Firebase or another required startup service fails.
class PipeStartupFailureApp extends StatelessWidget {
  const PipeStartupFailureApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pipe Buyer',
        theme: PipeAccessibilityTheme.apply(ThemeData.light()),
        darkTheme: PipeAccessibilityTheme.apply(ThemeData.dark()),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: PipeStatusSurface(
                    tone: PipeStatusTone.error,
                    icon: Icons.cloud_off_outlined,
                    title: 'Pipe Buyer could not start',
                    message: 'Check your connection, close and reopen the app, '
                        'then try again. Your marketplace information has not '
                        'been changed. Environment: '
                        '${AppBuildContext.current.environment}.',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
