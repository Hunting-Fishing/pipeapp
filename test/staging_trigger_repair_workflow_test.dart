import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File(
    '.github/workflows/repair-staging-protect-auction-reserve.yml',
  ).readAsStringSync().replaceAll('\r\n', '\n');

  test('staging trigger repair stays manual and exact-SHA bound', () {
    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, isNot(contains('\n  push:')));
    expect(workflow, isNot(contains('\n  pull_request:')));
    expect(workflow, contains(r'ref: ${{ inputs.commit_sha }}'));
    expect(workflow, contains(r'actual_sha="$(git rev-parse HEAD)"'));
    expect(workflow, contains('git merge-base --is-ancestor'));
  });

  test('repair is hard locked to the staging project and identity', () {
    expect(workflow, contains('environment: staging'));
    expect(workflow, contains('pipebuyer-5c77f'));
    expect(workflow, contains('flutter-flow-pipe'));
    expect(
      workflow,
      contains('firebase functions:delete protectAuctionReserve'),
    );
    expect(workflow, contains('--region us-central1'));
  });

  test('repair inventories before deletion and proves absence after', () {
    final inventoryBefore = workflow.indexOf(
      'build/staging-functions-before-repair.json',
    );
    final assessment = workflow.indexOf(
      'assess build/staging-functions-before-repair.json',
    );
    final deletion = workflow.indexOf(
      'firebase functions:delete protectAuctionReserve',
    );
    final inventoryAfter = workflow.indexOf(
      'build/staging-functions-after-repair.json',
    );
    final absence = workflow.indexOf(
      'assert-absent build/staging-functions-after-repair.json',
    );

    expect(inventoryBefore, greaterThan(-1));
    expect(assessment, greaterThan(inventoryBefore));
    expect(deletion, greaterThan(assessment));
    expect(inventoryAfter, greaterThan(deletion));
    expect(absence, greaterThan(inventoryAfter));
  });

  test('repair retains before and after evidence', () {
    expect(workflow, contains('if: \${{ always() }}'));
    expect(workflow, contains('retention-days: 30'));
    for (final evidencePath in <String>[
      'build/staging-functions-before-repair.json',
      'build/staging-trigger-repair-assessment.json',
      'build/staging-functions-after-repair.json',
      'build/staging-trigger-repair-result.json',
    ]) {
      expect(workflow, contains(evidencePath));
    }
  });
}
