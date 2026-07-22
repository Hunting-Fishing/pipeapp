Future<bool> initializeDiagnosticReporting({
  required String environment,
  required String releaseSha,
  required bool requested,
}) async =>
    false;

Future<void> reportDiagnostic({
  required Map<String, Object?> record,
  required StackTrace? stackTrace,
}) async {}
