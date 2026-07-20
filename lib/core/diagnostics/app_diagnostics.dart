import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Non-sensitive release context attached to every structured diagnostic.
class AppBuildContext {
  const AppBuildContext({
    required this.environment,
    required this.releaseSha,
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
  );

  final String environment;
  final String releaseSha;

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

  static void record(
    Object error,
    StackTrace? stackTrace, {
    required String subsystem,
    required String operation,
    required bool fatal,
  }) {
    final record = <String, Object?>{
      'type': 'pipe_buyer_error',
      ...AppBuildContext.current.toMap(),
      'subsystem': subsystem,
      'operation': operation,
      'fatal': fatal,
      'errorType': error.runtimeType.toString(),
      'message': _safeMessage(error),
      if (kDebugMode && stackTrace != null)
        'stack': stackTrace.toString().split('\n').take(12).join('\n'),
    };
    debugPrint(jsonEncode(record));
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
}

/// Safe screen used when Firebase or another required startup service fails.
class PipeStartupFailureApp extends StatelessWidget {
  const PipeStartupFailureApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pipe Buyer',
        home: Scaffold(
          backgroundColor: const Color(0xFFF7FAFE),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  margin: const EdgeInsets.all(20),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          size: 48,
                          color: Colors.deepOrange,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Pipe Buyer could not start',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Check your connection, close and reopen the app, '
                          'then try again. Your marketplace information has '
                          'not been changed.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Environment: ${AppBuildContext.current.environment}',
                          style: const TextStyle(
                            color: Color(0xFF66758A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
