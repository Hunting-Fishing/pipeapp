import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/config/public_release_config.dart';
import 'package:pipe_app/core/startup/pipe_startup_monitor.dart';

void main() {
  test('startup progress is milestone-driven and never moves backwards', () {
    final monitor = PipeStartupMonitor();
    addTearDown(monitor.dispose);

    expect(monitor.progressPercent, 32);
    monitor.startStage(
      id: 'configuration',
      label: 'Validating configuration',
      progress: .40,
    );
    monitor.startStage(
      id: 'firebase',
      label: 'Connecting services',
      progress: .54,
    );

    expect(monitor.progressPercent, 54);
    expect(monitor.history.map((stage) => stage.id),
        containsAllInOrder(['flutter_startup', 'configuration']));
    expect(
      () => monitor.startStage(
        id: 'invalid',
        label: 'Invalid regression',
        progress: .20,
      ),
      throwsArgumentError,
    );
  });

  test('startup watchdog identifies a delayed stage', () async {
    final monitor = PipeStartupMonitor(
      slowStageThreshold: const Duration(milliseconds: 15),
      tickInterval: const Duration(milliseconds: 5),
    );
    addTearDown(monitor.dispose);

    await Future<void>.delayed(const Duration(milliseconds: 35));

    expect(monitor.isDelayed, isTrue);
    expect(monitor.stageId, 'flutter_startup');
  });

  testWidgets('startup screen exposes progress, version, and current task',
      (tester) async {
    final monitor = PipeStartupMonitor();
    monitor.startStage(
      id: 'firebase_core',
      label: 'Connecting to Pipe Buyer services',
      progress: .54,
    );

    await tester.pumpWidget(PipeStartupMonitorApp(monitor: monitor));

    expect(find.text('Preparing Pipe Buyer'), findsOneWidget);
    expect(find.text('Connecting to Pipe Buyer services'), findsWidgets);
    expect(find.text('54%'), findsOneWidget);
    expect(
      find.text(PublicReleaseConfiguration.formattedReleaseLabel),
      findsOneWidget,
    );
    expect(find.text('Startup details'), findsOneWidget);
    monitor.dispose();
  });

  testWidgets('startup failure remains safe while retaining a diagnostic type',
      (tester) async {
    final monitor = PipeStartupMonitor();
    addTearDown(monitor.dispose);
    monitor.fail(
      Exception(
        'Firebase failed for buyer@example.com at '
        'https://private.example.test/token',
      ),
    );

    await tester.pumpWidget(PipeStartupMonitorApp(monitor: monitor));

    expect(find.text('Pipe Buyer could not start'), findsOneWidget);
    expect(find.textContaining('information has not been changed'),
        findsOneWidget);
    expect(find.textContaining('buyer@example.com'), findsNothing);
    expect(find.textContaining('private.example.test'), findsNothing);
    expect(monitor.diagnosticSummary, contains('Failure type: _Exception'));
    expect(monitor.diagnosticSummary, isNot(contains('buyer@example.com')));
  });

  test('web bootstrap exposes real loader milestones and recovery controls',
      () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('role="progressbar"'));
    expect(html, contains('id="splash-percent"'));
    expect(html, contains('id="splash-version"'));
    expect(html, contains('Startup details'));
    expect(html, contains('onEntrypointLoaded'));
    expect(html, contains('Flutter engine initialized'));
    expect(html, contains('Repair cache and reload'));
    expect(html, contains('navigator.serviceWorker.getRegistrations()'));
    expect(html, contains('Reload application'));
    expect(html, contains('flutter-first-frame'));
    expect(html, contains('removeSplashFromWeb();'));
  });
}
