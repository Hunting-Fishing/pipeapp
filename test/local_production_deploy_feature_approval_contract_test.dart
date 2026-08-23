import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('tool/deploy_production_local.ps1')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');

  test('local production deploy requires explicit feature switches', () {
    expect(source, contains('[switch]\$EnableDispatch'));
    expect(source, contains('[switch]\$EnablePaidFeatures'));
    expect(
      source,
      contains("PIPE_ENABLE_DISPATCH = if (\$EnableDispatch.IsPresent) { 'true' } else { 'false' }"),
    );
    expect(
      source,
      contains("PIPE_ENABLE_PAID_FEATURES = if (\$EnablePaidFeatures.IsPresent) { 'true' } else { 'false' }"),
    );
  });

  test('local production build compiles and records both approvals', () {
    expect(source, contains('PIPE_ENABLE_DISPATCH = \$env:PIPE_ENABLE_DISPATCH'));
    expect(
      source,
      contains('PIPE_ENABLE_PAID_FEATURES = \$env:PIPE_ENABLE_PAID_FEATURES'),
    );
    expect(
      source,
      contains('--dispatch-build-enabled \$env:PIPE_ENABLE_DISPATCH'),
    );
    expect(
      source,
      contains('--paid-features-build-enabled \$env:PIPE_ENABLE_PAID_FEATURES'),
    );
    expect(source, contains('Dispatch build approval:'));
    expect(source, contains('Paid features build approval:'));
  });
}
