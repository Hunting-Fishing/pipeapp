import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/diagnostics/app_diagnostics.dart';

void main() {
  test('build context always exposes non-empty release diagnostics', () {
    expect(AppBuildContext.current.environment, isNotEmpty);
    expect(AppBuildContext.current.releaseSha, isNotEmpty);
    expect(
      AppBuildContext.current.toMap(),
      containsPair('environment', AppBuildContext.current.environment),
    );
    expect(
      AppBuildContext.current.toMap(),
      containsPair('releaseSha', AppBuildContext.current.releaseSha),
    );
  });

  testWidgets('startup failure screen is safe and actionable', (tester) async {
    await tester.pumpWidget(const PipeStartupFailureApp());

    expect(find.text('Pipe Buyer could not start'), findsOneWidget);
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.textContaining('Environment:'), findsOneWidget);
    expect(find.textContaining('Firebase'), findsNothing);
  });

  test('diagnostics redact common personal identifiers', () {
    final message = AppDiagnostics.safeMessageForTesting(
      Exception(
        'Upload failed for buyer@example.com, +1 (250) 555-1212 at '
        'https://storage.example.test/private/avatar.jpg?token=secret',
      ),
    );

    expect(message, contains('[redacted-email]'));
    expect(message, contains('[redacted-phone]'));
    expect(message, contains('[redacted-url]'));
    expect(message, isNot(contains('buyer@example.com')));
    expect(message, isNot(contains('555-1212')));
    expect(message, isNot(contains('token=secret')));
  });
}
