import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:pipe_app/backend/firebase/firebase_runtime_config.dart';

void main() {
  test('local options retain installed metadata before emulator redirection',
      () {
    final configuration = resolveFirebaseWebConfiguration(
      environment: 'local',
    );

    expect(configuration.projectId, productionFirebaseProjectId);
    expect(configuration.appId, isNotEmpty);
  });

  test('an unspecified build environment resolves to local', () {
    expect(resolveFirebaseEnvironment(''), 'local');
  });

  test('staging fails closed without an explicit project', () {
    expect(
      () => resolveFirebaseWebConfiguration(environment: 'staging'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('PIPE_FIREBASE_PROJECT_ID'),
        ),
      ),
    );
  });

  test('unoverridden web production uses approved production project', () {
    final configuration = resolveFirebaseWebConfiguration(environment: 'production');
    expect(configuration.projectId, productionFirebaseProjectId);
  });

  test('a partial override is rejected instead of mixing projects', () {
    expect(
      () => resolveFirebaseWebConfiguration(
        environment: 'development',
        projectId: 'partial-project',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('an unknown environment cannot silently use development', () {
    expect(
      () => resolveFirebaseWebConfiguration(environment: 'produciton'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('native staging is locked to the isolated Firebase project', () {
    expect(
      () => expectedNativeFirebaseProjectId(environment: 'staging'),
      throwsA(isA<StateError>()),
    );
    expect(
      () => expectedNativeFirebaseProjectId(
        environment: 'staging',
        declaredProjectId: productionFirebaseProjectId,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      expectedNativeFirebaseProjectId(
        environment: 'staging',
        declaredProjectId: stagingFirebaseProjectId,
      ),
      stagingFirebaseProjectId,
    );
  });

  test('native staging registrations match the isolated project', () {
    final android = stagingNativeFirebaseOptions(TargetPlatform.android);
    final ios = stagingNativeFirebaseOptions(TargetPlatform.iOS);

    expect(android.projectId, stagingFirebaseProjectId);
    expect(android.appId, contains(':android:'));
    expect(ios.projectId, stagingFirebaseProjectId);
    expect(ios.appId, contains(':ios:'));
    expect(ios.iosBundleId, 'Pipe.Buyerapp');
  });

  test('native production requires the explicitly approved project', () {
    expect(
      () => expectedNativeFirebaseProjectId(environment: 'production'),
      throwsA(isA<StateError>()),
    );
    expect(
      () => expectedNativeFirebaseProjectId(
        environment: 'production',
        declaredProjectId: 'unrelated-project',
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      expectedNativeFirebaseProjectId(
        environment: 'production',
        declaredProjectId: productionFirebaseProjectId,
      ),
      productionFirebaseProjectId,
    );
  });

  test('development and CI native builds may use installed platform files', () {
    for (final environment in [
      'development',
      'local-verification',
      'continuous-integration',
      'test',
    ]) {
      expect(
        () => expectedNativeFirebaseProjectId(environment: environment),
        returnsNormally,
      );
    }
  });

  test('initialized native production project must match its declaration', () {
    expect(
      () => ensureInitializedFirebaseProjectMatches(
        environment: 'production',
        declaredProjectId: productionFirebaseProjectId,
        actualProjectId: 'different-project',
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      () => ensureInitializedFirebaseProjectMatches(
        environment: 'production',
        declaredProjectId: productionFirebaseProjectId,
        actualProjectId: productionFirebaseProjectId,
      ),
      returnsNormally,
    );
  });

  test('a complete controlled configuration maps to Firebase options', () {
    final configuration = resolveFirebaseWebConfiguration(
      environment: 'staging',
      apiKey: 'public-web-api-key',
      authDomain: 'pipe-staging.firebaseapp.com',
      projectId: 'pipe-staging',
      storageBucket: 'pipe-staging.firebasestorage.app',
      messagingSenderId: '123456789',
      appId: '1:123456789:web:abcdef',
      measurementId: 'G-STAGING',
    );
    final options = configuration.toFirebaseOptions();

    expect(options.projectId, 'pipe-staging');
    expect(options.storageBucket, 'pipe-staging.firebasestorage.app');
    expect(options.measurementId, 'G-STAGING');
  });

  test('web production is locked to the approved Firebase project', () {
    FirebaseWebConfiguration productionConfiguration(String projectId) =>
        resolveFirebaseWebConfiguration(
          environment: 'production',
          apiKey: 'public-web-api-key',
          authDomain: '$projectId.firebaseapp.com',
          projectId: projectId,
          storageBucket: '$projectId.firebasestorage.app',
          messagingSenderId: '426221783223',
          appId: '1:426221783223:web:abcdef',
        );

    expect(
      () => productionConfiguration('unrelated-project'),
      throwsA(isA<StateError>()),
    );
    expect(
      productionConfiguration(productionFirebaseProjectId).projectId,
      productionFirebaseProjectId,
    );
  });

  test('web staging cannot target the production Firebase project', () {
    expect(
      () => resolveFirebaseWebConfiguration(
        environment: 'staging',
        apiKey: 'public-web-api-key',
        authDomain: 'flutter-flow-pipe.firebaseapp.com',
        projectId: productionFirebaseProjectId,
        storageBucket: 'flutter-flow-pipe.firebasestorage.app',
        messagingSenderId: '426221783223',
        appId: '1:426221783223:web:abcdef',
      ),
      throwsA(isA<StateError>()),
    );
  });
}
