import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

const _developmentEnvironments = {
  'development',
  'local',
  'local-verification',
  'continuous-integration',
  'test',
};
const _controlledEnvironments = {'staging', 'production'};

/// The single Firebase project approved to hold live Pipe App data.
///
/// Keep this identifier explicit so a native release cannot silently initialize
/// from an unrelated Google Services file.
const productionFirebaseProjectId = 'flutter-flow-pipe';

/// The isolated Firebase project approved for pre-production rehearsals.
const stagingFirebaseProjectId = 'pipebuyer-5c77f';

const _stagingAndroidConfiguration = FirebaseOptions(
  apiKey: 'AIzaSyC03JAXaMDKcCbEJCah6OLh7sUNRrFB_y0',
  appId: '1:975213611830:android:f99d4787d155aeaaa70197',
  messagingSenderId: '975213611830',
  projectId: stagingFirebaseProjectId,
  storageBucket: 'pipebuyer-5c77f.firebasestorage.app',
);

const _stagingIosConfiguration = FirebaseOptions(
  apiKey: 'AIzaSyB0ctcIPB0WpzojivD2Ei5jXIDNzugh48k',
  appId: '1:975213611830:ios:0018f5911fb98aaaa70197',
  messagingSenderId: '975213611830',
  projectId: stagingFirebaseProjectId,
  storageBucket: 'pipebuyer-5c77f.firebasestorage.app',
  iosBundleId: 'Pipe.Buyerapp',
);

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

String normalizeFirebaseEnvironment(String environment) {
  final normalizedEnvironment = environment.trim().toLowerCase();
  if (!_developmentEnvironments.contains(normalizedEnvironment) &&
      !_controlledEnvironments.contains(normalizedEnvironment)) {
    throw ArgumentError.value(
      environment,
      'environment',
      'Use local, development, staging, or production.',
    );
  }
  return normalizedEnvironment;
}

String? expectedNativeFirebaseProjectId({
  required String environment,
  String declaredProjectId = '',
}) {
  final normalizedEnvironment = normalizeFirebaseEnvironment(environment);
  if (!_controlledEnvironments.contains(normalizedEnvironment)) {
    return null;
  }

  final normalizedProjectId = declaredProjectId.trim();
  if (normalizedProjectId.isEmpty) {
    throw StateError(
      'PIPE_FIREBASE_PROJECT_ID is required for a native '
      '$normalizedEnvironment build.',
    );
  }
  final expectedProjectId = normalizedEnvironment == 'staging'
      ? stagingFirebaseProjectId
      : productionFirebaseProjectId;
  if (normalizedProjectId != expectedProjectId) {
    throw StateError(
      'Native $normalizedEnvironment is approved only for Firebase project '
      '$expectedProjectId, not $normalizedProjectId.',
    );
  }
  return expectedProjectId;
}

/// Returns the checked-in public Firebase registration for an isolated native
/// staging build. Production continues to use the platform Google Services
/// files so release signing and provider configuration remain unchanged.
FirebaseOptions stagingNativeFirebaseOptions(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.android:
      return _stagingAndroidConfiguration;
    case TargetPlatform.iOS:
      return _stagingIosConfiguration;
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      throw UnsupportedError(
        'Native Firebase staging is supported only on Android and iOS.',
      );
  }
}

void ensureInitializedFirebaseProjectMatches({
  required String environment,
  required String actualProjectId,
  String declaredProjectId = '',
}) {
  final expectedProjectId = expectedNativeFirebaseProjectId(
    environment: environment,
    declaredProjectId: declaredProjectId,
  );
  if (expectedProjectId != null &&
      actualProjectId.trim() != expectedProjectId) {
    throw StateError(
      'The installed Firebase app targets ${actualProjectId.trim()}, but '
      '$environment requires $expectedProjectId.',
    );
  }
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
  final normalizedEnvironment = normalizeFirebaseEnvironment(environment);
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
      _controlledEnvironments.contains(normalizedEnvironment);

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

  final configuredProjectId = supplied['PIPE_FIREBASE_PROJECT_ID']!;
  if (normalizedEnvironment == 'production' &&
      configuredProjectId != productionFirebaseProjectId) {
    throw StateError(
      'Web production is approved only for Firebase project '
      '$productionFirebaseProjectId, not $configuredProjectId.',
    );
  }
  if (normalizedEnvironment == 'staging' &&
      configuredProjectId == productionFirebaseProjectId) {
    throw StateError(
      'Staging cannot use the production Firebase project '
      '$productionFirebaseProjectId.',
    );
  }

  return FirebaseWebConfiguration(
    apiKey: supplied['PIPE_FIREBASE_API_KEY']!,
    authDomain: supplied['PIPE_FIREBASE_AUTH_DOMAIN']!,
    projectId: configuredProjectId,
    storageBucket: supplied['PIPE_FIREBASE_STORAGE_BUCKET']!,
    messagingSenderId: supplied['PIPE_FIREBASE_MESSAGING_SENDER_ID']!,
    appId: supplied['PIPE_FIREBASE_WEB_APP_ID']!,
    measurementId: measurementId.trim(),
  );
}

String resolveFirebaseEnvironment(String environment) {
  final candidate = environment.trim();
  return normalizeFirebaseEnvironment(candidate.isEmpty ? 'local' : candidate);
}

String currentFirebaseEnvironment() => resolveFirebaseEnvironment(
      const String.fromEnvironment('PIPE_ENV'),
    );

String currentFirebaseProjectId() => const String.fromEnvironment(
      'PIPE_FIREBASE_PROJECT_ID',
    );

FirebaseWebConfiguration currentFirebaseWebConfiguration() =>
    resolveFirebaseWebConfiguration(
      environment: currentFirebaseEnvironment(),
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
