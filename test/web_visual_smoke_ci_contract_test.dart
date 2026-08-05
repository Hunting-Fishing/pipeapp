import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('tool/web_visual_smoke.ps1')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');
  final workflow = File('.github/workflows/deploy.yml')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');

  test('CI App Check token is injected before the live page loads', () {
    final injectionIndex = script.indexOf(
      "-Method 'Page.addScriptToEvaluateOnNewDocument'",
    );
    final navigationIndex = script.indexOf("-Method 'Page.navigate'");

    expect(injectionIndex, greaterThan(-1));
    expect(navigationIndex, greaterThan(injectionIndex));
    expect(
      script,
      contains('self.FIREBASE_APPCHECK_DEBUG_TOKEN = \$debugTokenLiteral;'),
    );
    expect(
      script,
      contains(
        '[ValidateRange(1, 60)][int]\$TimeoutSeconds = 30',
      ),
    );
  });

  test('debug token remains a protected visual-job secret only', () {
    expect(
      r'PIPE_APP_CHECK_WEB_DEBUG_TOKEN: ${{ secrets.PIPE_APP_CHECK_WEB_DEBUG_TOKEN }}'
          .allMatches(workflow),
      hasLength(1),
    );
    expect(
      workflow,
      contains(
        'PIPE_APP_CHECK_WEB_DEBUG_TOKEN is not configured in the selected '
        'GitHub Environment.',
      ),
    );
    expect(
      workflow.indexOf('PIPE_APP_CHECK_WEB_DEBUG_TOKEN:'),
      greaterThan(workflow.indexOf('visual-acceptance:')),
    );
    expect(script, isNot(contains('Write-Host \$AppCheckDebugToken')));
    expect(script, isNot(contains('Write-Output \$AppCheckDebugToken')));
  });

  test('production acceptance uses the canonical domain and branding pages', () {
    expect(workflow, contains("'https://www.pipebuyer.com'"));
    for (final path in <String>['/about', '/privacy', '/terms']) {
      expect(workflow, contains("'$path'"));
    }
    expect(
      workflow,
      contains('Public release page \$publicUrl returned HTTP'),
    );
    expect(
      workflow,
      contains('Public release page \$publicUrl does not identify Pipe Buyer.'),
    );
  });
}
