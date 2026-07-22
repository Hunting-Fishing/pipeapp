import 'diagnostic_reporting_stub.dart'
    if (dart.library.io) 'diagnostic_reporting_native.dart' as implementation;

Future<bool> initializeDiagnosticReporting({
  required String environment,
  required String releaseSha,
  required bool requested,
}) =>
    implementation.initializeDiagnosticReporting(
      environment: environment,
      releaseSha: releaseSha,
      requested: requested,
    );

Future<void> reportDiagnostic({
  required Map<String, Object?> record,
  required StackTrace? stackTrace,
}) =>
    implementation.reportDiagnostic(
      record: record,
      stackTrace: stackTrace,
    );
