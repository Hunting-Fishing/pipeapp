import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web startup uses one Pipe Buyer logo surface with public identity', () {
    final source = File('web/index.html').readAsStringSync();

    expect(source, contains('id="pipe-startup"'));
    expect(source, contains('assets/assets/images/pipe_buyer_logo.png'));
    expect(source, contains('<h1 class="pipe-startup-title">Pipe Buyer</h1>'));
    expect(source, contains('Application Purpose &amp; Identity:'));
    expect(source, contains('B2B industrial marketplace'));
    expect(source, contains('timed auctions'));
    expect(source, contains('freight trucking dispatch'));
    expect(source, contains('href="https://www.pipebuyer.com/privacy"'));
    expect(source, contains('href="https://www.pipebuyer.com/terms"'));
    expect(source, contains("window.addEventListener('flutter-first-frame'"));
    expect(source, isNot(contains('<header style=')));
    expect(source, isNot(contains('splash-card')));
    expect(source, isNot(contains('serviceWorker.getRegistrations')));
  });

  test('normal Flutter startup performs one runApp after bootstrap', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('WidgetsFlutterBinding.ensureInitialized();'));
    expect(source, contains('await _bootstrapPipeBuyer(startupMonitor);'));
    expect(
      source.indexOf('WidgetsFlutterBinding.ensureInitialized();'),
      greaterThan(source.indexOf('AppDiagnostics.run(() async {')),
    );
    expect(
      source,
      isNot(contains('runApp(PipeStartupMonitorApp(monitor: startupMonitor));\n  AppDiagnostics.run')),
    );
    expect(source, isNot(contains('Duration(milliseconds: 3000)'));
    expect(source, contains('_appStateNotifier.stopShowingSplashImage();'));
  });
}
