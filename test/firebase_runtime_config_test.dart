import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/backend/firebase/firebase_runtime_config.dart';

void main() {
  test('legacy development fallback resolves to the approved live project', () {
    final configuration = resolveFirebaseWebConfiguration(
      environment: 'development',
    );

    expect(configuration.projectId, productionFirebaseProjectId);
    expect(configuration.appId, isNotEmpty);
  });

  test('staging and production fail closed without an explicit project', () {
    for (final environment in ['staging', 'production']) {
      expect(
        () => resolveFirebaseWebConfiguration(environment: environment),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('PIPE_FIREBASE_PROJECT_ID'),
          ),
        ),
      );
    }
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

  test('native staging fails closed until its Firebase app is installed', () {
    expect(
      () => expectedNativeFirebaseProjectId(environment: 'staging'),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          contains('staging'),
        ),
      ),
    );
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
