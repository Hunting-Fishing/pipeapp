import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tool/verify.ps1` exists so a developer can prove a change is green before
/// spending a GitHub Actions run on it. That promise only holds while the local
/// gate runs everything the `Quality` workflow runs.
///
/// When the two drift, work passes locally and fails in CI, which costs a full
/// Windows + macOS pipeline to discover something a local run should have caught.
/// This contract fails the build instead.
void main() {
  final workflow = File('.github/workflows/quality.yml')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');
  final localGate =
      File('tool/verify.ps1').readAsStringSync().replaceAll('\r\n', '\n');

  final nodeTestPattern = RegExp(r'tool/[A-Za-z0-9_]+_test\.mjs');

  test('local gate runs every node test the Quality workflow runs', () {
    final workflowTests =
        nodeTestPattern.allMatches(workflow).map((m) => m.group(0)!).toSet();

    expect(
      workflowTests,
      isNotEmpty,
      reason: 'Expected quality.yml to declare at least one node test. '
          'If the workflow changed shape, update this contract deliberately.',
    );

    final localTests =
        nodeTestPattern.allMatches(localGate).map((m) => m.group(0)!).toSet();

    final missing = workflowTests.difference(localTests).toList()..sort();

    expect(
      missing,
      isEmpty,
      reason: 'tool/verify.ps1 does not run: ${missing.join(', ')}. '
          'A developer running the local gate would see green and then fail in '
          'CI. Add these to verify.ps1 rather than removing them from CI.',
    );
  });

  test('local gate runs the analyzer and the Flutter suite', () {
    expect(localGate, contains('dart analyze lib test'));
    expect(localGate, contains('flutter test'));
  });
}
