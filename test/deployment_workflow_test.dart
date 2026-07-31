import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File('.github/workflows/deploy.yml')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');

  test('Firebase deployment stays manual and release-SHA bound', () {
    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, isNot(contains('\n  push:')));
    expect(workflow, isNot(contains('\n  pull_request:')));
    expect(workflow, contains(r'ref: ${{ inputs.commit_sha }}'));
    expect(workflow, contains(r'actual_sha="$(git rev-parse HEAD)"'));
    expect(workflow, contains('git merge-base --is-ancestor'));
  });

  test('both jobs require the matching protected environment guard', () {
    expect(
      'PIPE_DEPLOY_ENVIRONMENT_GUARD:'.allMatches(workflow),
      hasLength(2),
    );
    expect(
      workflow,
      contains(r'${{ secrets.PIPE_DEPLOY_ENVIRONMENT_GUARD }}'),
    );
    expect(
      workflow,
      contains(
        'The protected deployment environment guard does not match '
        r'$PIPE_ENV.',
      ),
    );
    expect(
      workflow,
      contains(
        'The protected deployment environment guard does not match the '
        'selected environment.',
      ),
    );
  });

  test('deployment uses keyless identity and exact Firebase project guards',
      () {
    expect(workflow,
        contains('permissions:\n  contents: read\n  id-token: write'));
    expect(workflow, contains('google-github-actions/auth@v3'));
    expect(
        workflow, contains(r'${{ vars.GOOGLE_WORKLOAD_IDENTITY_PROVIDER }}'));
    expect(workflow, contains(r'${{ vars.GOOGLE_DEPLOY_SERVICE_ACCOUNT }}'));
    expect(workflow, isNot(contains('service_account_key')));
    expect(workflow, contains('flutter-flow-pipe'));
    expect(workflow, contains('Staging cannot deploy to the production'));
    expect(workflow, contains('Production releases require App Check enforce'));
  });

  test('deployment proves full-service parity and retains visual evidence', () {
    expect(
      workflow,
      contains(
        '--only auth,hosting,functions,firestore:rules,'
        'firestore:indexes,storage',
      ),
    );
    expect(workflow, contains('firebase functions:list'));
    expect(workflow, contains('node tool/function_parity.mjs'));
    expect(workflow, contains('visual-acceptance:'));
    expect(workflow, contains('mobile-390x844.png'));
    expect(workflow, contains('desktop-1440x1000.png'));
    expect(workflow, contains('retention-days: 30'));
  });

  test('deployment retains exact-release machine-readable evidence', () {
    expect(
      workflow,
      contains(
        '--message "Pipe Buyer \$PIPE_ENV \$PIPE_RELEASE_SHA workflow '
        r'${{ github.run_id }}"',
      ),
    );
    expect(
      workflow,
      contains(
        '--non-interactive 2>&1 | tee build/firebase-deploy.log',
      ),
    );
    expect(
      workflow,
      contains(
        'name: firebase-release-evidence-'
        r'${{ inputs.environment }}-${{ inputs.commit_sha }}-'
        r'${{ github.run_id }}',
      ),
    );
    for (final evidencePath in <String>[
      'build/release-manifest.json',
      'build/firebase-deploy.log',
      'build/deployed-functions.json',
      'build/function-parity-marketplace.json',
      'build/function-parity-agent.json',
    ]) {
      expect(workflow, contains(evidencePath));
    }
  });

  test('controlled web releases require a public support address', () {
    expect(
      workflow,
      contains(
          r'PIPE_PUBLIC_SUPPORT_EMAIL: ${{ vars.PIPE_PUBLIC_SUPPORT_EMAIL }}'),
    );
    expect(workflow, contains('PIPE_PUBLIC_SUPPORT_EMAIL\n'));
    expect(
      workflow,
      contains(
          '--dart-define=PIPE_PUBLIC_SUPPORT_EMAIL=\$PIPE_PUBLIC_SUPPORT_EMAIL'),
    );
  });
}
