import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/config/public_release_config.dart';

/// The Account > About page, the startup recovery screen, and every structured
/// diagnostic record report `PublicReleaseConfiguration.appVersion`. When that
/// constant drifts from `pubspec.yaml`, support and crash triage silently
/// attribute reports to the wrong build, so the mismatch must fail the build.
void main() {
  test('declared release version matches pubspec', () {
    final pubspec =
        File('pubspec.yaml').readAsStringSync().replaceAll('\r\n', '\n');

    final versionLine = pubspec
        .split('\n')
        .map((line) => line.trimRight())
        .firstWhere(
          (line) => line.startsWith('version:'),
          orElse: () => '',
        );

    expect(
      versionLine,
      isNotEmpty,
      reason: 'pubspec.yaml must declare a top-level version.',
    );

    final declaredVersion = versionLine.substring('version:'.length).trim();

    expect(
      declaredVersion,
      isNotEmpty,
      reason: 'pubspec.yaml version must not be blank.',
    );

    expect(
      PublicReleaseConfiguration.appVersion,
      declaredVersion,
      reason:
          'PublicReleaseConfiguration.appVersion must equal the pubspec version '
          'so release identity, About, and diagnostics report the built release.',
    );
  });

  test('release version uses a build-number suffix', () {
    expect(
      PublicReleaseConfiguration.appVersion,
      matches(RegExp(r'^\d+\.\d+\.\d+\+\d+$')),
      reason:
          'Store uploads require an incrementing build number in the '
          'major.minor.patch+build form.',
    );
  });
}
