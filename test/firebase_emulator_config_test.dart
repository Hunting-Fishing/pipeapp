import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/backend/firebase/firebase_emulator_config.dart';

void main() {
  test('local and development environments use Firebase emulators', () {
    for (final environment in [
      'local',
      'development',
      'local-verification',
      'continuous-integration',
      'test',
    ]) {
      expect(shouldUseFirebaseEmulators(environment), isTrue);
    }
    for (final environment in [
      'staging',
      'production',
    ]) {
      expect(shouldUseFirebaseEmulators(environment), isFalse);
    }
  });

  test('web and desktop use loopback by default', () {
    final web = resolveFirebaseEmulatorConfiguration(
      environment: 'local',
      isWeb: true,
      platform: TargetPlatform.android,
    );
    final windows = resolveFirebaseEmulatorConfiguration(
      environment: 'local',
      isWeb: false,
      platform: TargetPlatform.windows,
    );

    expect(web.host, '127.0.0.1');
    expect(windows.host, '127.0.0.1');
  });

  test('Android emulator uses its host bridge by default', () {
    final configuration = resolveFirebaseEmulatorConfiguration(
      environment: 'local',
      isWeb: false,
      platform: TargetPlatform.android,
    );

    expect(configuration.host, '10.0.2.2');
    expect(configuration.authPort, 9099);
    expect(configuration.firestorePort, 8080);
    expect(configuration.functionsPort, 5001);
    expect(configuration.storagePort, 9199);
  });

  test('a physical device can use an explicit development-machine host', () {
    final configuration = resolveFirebaseEmulatorConfiguration(
      environment: 'local',
      isWeb: false,
      platform: TargetPlatform.android,
      hostOverride: '192.168.1.25',
    );

    expect(configuration.host, '192.168.1.25');
  });

  test('non-local environments cannot resolve emulator endpoints', () {
    expect(
      () => resolveFirebaseEmulatorConfiguration(
        environment: 'production',
        isWeb: true,
        platform: TargetPlatform.windows,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
