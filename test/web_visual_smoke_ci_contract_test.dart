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

  test('debug token remains protected and required only when App Check is active', () {
    const tokenSecret =
        r'PIPE_APP_CHECK_WEB_DEBUG_TOKEN: ${{ secrets.PIPE_APP_CHECK_WEB_DEBUG_TOKEN }}';
    final visualJobIndex = workflow.indexOf('  visual-acceptance:');

    expect(visualJobIndex, greaterThan(-1));
    expect(tokenSecret.allMatches(workflow), hasLength(1));
    expect(workflow.indexOf('PIPE_APP_CHECK_WEB_DEBUG_TOKEN:'),
        greaterThan(visualJobIndex));
    expect(
      workflow.substring(visualJobIndex),
      contains(r'PIPE_APP_CHECK_MODE: ${{ inputs.app_check_mode }}'),
    );
    expect(
      workflow.substring(visualJobIndex),
      contains("\$env:PIPE_APP_CHECK_MODE -ne 'disabled' -and"),
    );
    expect(
      workflow.substring(visualJobIndex),
      contains(
        '[string]::IsNullOrWhiteSpace('
        '\$env:PIPE_APP_CHECK_WEB_DEBUG_TOKEN)',
      ),
    );
    expect(
      workflow,
      contains(
        'PIPE_APP_CHECK_WEB_DEBUG_TOKEN is required when App Check is observe '
        'or enforce.',
      ),
    );
    expect(
      workflow,
      isNot(
        contains(
          'PIPE_APP_CHECK_WEB_DEBUG_TOKEN is not configured in the selected '
          'GitHub Environment.',
        ),
      ),
    );
    expect(
      workflow.substring(visualJobIndex),
      contains('App Check: disabled for this release; no CI debug token required'),
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
