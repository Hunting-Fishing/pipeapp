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
}
