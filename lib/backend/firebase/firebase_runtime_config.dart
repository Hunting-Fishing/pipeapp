import 'package:firebase_core/firebase_core.dart';

const _developmentWebConfiguration = FirebaseWebConfiguration(
  apiKey: 'AIzaSyAMm0HnXVq6UOERnPNP9SKqGtyV_-H--u8',
  authDomain: 'flutter-flow-pipe.firebaseapp.com',
  projectId: 'flutter-flow-pipe',
  storageBucket: 'flutter-flow-pipe.firebasestorage.app',
  messagingSenderId: '426221783223',
  appId: '1:426221783223:web:179633eb8c8378e6e26532',
  measurementId: 'G-YL926V0FD9',
);

class FirebaseWebConfiguration {
  const FirebaseWebConfiguration({
    required this.apiKey,
    required this.authDomain,
    required this.projectId,
    required this.storageBucket,
    required this.messagingSenderId,
    required this.appId,
    this.measurementId = '',
  });

  final String apiKey;
  final String authDomain;
  final String projectId;
  final String storageBucket;
  final String messagingSenderId;
  final String appId;
  final String measurementId;

  FirebaseOptions toFirebaseOptions() => FirebaseOptions(
        apiKey: apiKey,
        authDomain: authDomain,
        projectId: projectId,
        storageBucket: storageBucket,
        messagingSenderId: messagingSenderId,
        appId: appId,
        measurementId: measurementId.isEmpty ? null : measurementId,
      );
}

FirebaseWebConfiguration resolveFirebaseWebConfiguration({
  required String environment,
  String apiKey = '',
  String authDomain = '',
  String projectId = '',
  String storageBucket = '',
  String messagingSenderId = '',
  String appId = '',
  String measurementId = '',
}) {
  final normalizedEnvironment = environment.trim().toLowerCase();
  const developmentEnvironments = {
    'development',
    'local',
    'local-verification',
    'continuous-integration',
    'test',
  };
  const controlledEnvironments = {'staging', 'production'};
  if (!developmentEnvironments.contains(normalizedEnvironment) &&
      !controlledEnvironments.contains(normalizedEnvironment)) {
    throw ArgumentError.value(
      environment,
      'environment',
      'Use development, staging, or production.',
    );
  }
  final supplied = <String, String>{
    'PIPE_FIREBASE_API_KEY': apiKey.trim(),
    'PIPE_FIREBASE_AUTH_DOMAIN': authDomain.trim(),
    'PIPE_FIREBASE_PROJECT_ID': projectId.trim(),
    'PIPE_FIREBASE_STORAGE_BUCKET': storageBucket.trim(),
    'PIPE_FIREBASE_MESSAGING_SENDER_ID': messagingSenderId.trim(),
    'PIPE_FIREBASE_WEB_APP_ID': appId.trim(),
  };
  final hasAnyOverride = supplied.values.any((value) => value.isNotEmpty);
  final controlledEnvironment =
      controlledEnvironments.contains(normalizedEnvironment);

  if (!hasAnyOverride && !controlledEnvironment) {
    return _developmentWebConfiguration;
  }

  final missing = supplied.entries
      .where((entry) => entry.value.isEmpty)
      .map((entry) => entry.key)
      .toList(growable: false);
  if (missing.isNotEmpty) {
    throw StateError(
      'Firebase configuration is incomplete for $normalizedEnvironment. '
      'Missing build values: ${missing.join(', ')}.',
    );
  }

  return FirebaseWebConfiguration(
    apiKey: supplied['PIPE_FIREBASE_API_KEY']!,
    authDomain: supplied['PIPE_FIREBASE_AUTH_DOMAIN']!,
    projectId: supplied['PIPE_FIREBASE_PROJECT_ID']!,
    storageBucket: supplied['PIPE_FIREBASE_STORAGE_BUCKET']!,
    messagingSenderId: supplied['PIPE_FIREBASE_MESSAGING_SENDER_ID']!,
    appId: supplied['PIPE_FIREBASE_WEB_APP_ID']!,
    measurementId: measurementId.trim(),
  );
}

FirebaseWebConfiguration currentFirebaseWebConfiguration() =>
    resolveFirebaseWebConfiguration(
      environment: const String.fromEnvironment(
        'PIPE_ENV',
        defaultValue: 'development',
      ),
      apiKey: const String.fromEnvironment('PIPE_FIREBASE_API_KEY'),
      authDomain: const String.fromEnvironment('PIPE_FIREBASE_AUTH_DOMAIN'),
      projectId: const String.fromEnvironment('PIPE_FIREBASE_PROJECT_ID'),
      storageBucket:
          const String.fromEnvironment('PIPE_FIREBASE_STORAGE_BUCKET'),
      messagingSenderId:
          const String.fromEnvironment('PIPE_FIREBASE_MESSAGING_SENDER_ID'),
      appId: const String.fromEnvironment('PIPE_FIREBASE_WEB_APP_ID'),
      measurementId:
          const String.fromEnvironment('PIPE_FIREBASE_MEASUREMENT_ID'),
    );
