import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/backend/firebase/firebase_runtime_config.dart';

void main() {
  test('development uses the existing development project by default', () {
    final configuration = resolveFirebaseWebConfiguration(
      environment: 'development',
    );

    expect(configuration.projectId, 'flutter-flow-pipe');
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
}
