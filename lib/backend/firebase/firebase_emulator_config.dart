import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

const firebaseEmulatorHostOverride = String.fromEnvironment(
  'PIPE_FIREBASE_EMULATOR_HOST',
);

class FirebaseEmulatorConfiguration {
  const FirebaseEmulatorConfiguration({
    required this.host,
    this.authPort = 9099,
    this.firestorePort = 8080,
    this.functionsPort = 5001,
    this.storagePort = 9199,
  });

  final String host;
  final int authPort;
  final int firestorePort;
  final int functionsPort;
  final int storagePort;
}

bool shouldUseFirebaseEmulators(String environment) => const {
      'local',
      'development',
      'local-verification',
      'continuous-integration',
      'test',
    }.contains(environment.trim().toLowerCase());

FirebaseEmulatorConfiguration resolveFirebaseEmulatorConfiguration({
  required String environment,
  required bool isWeb,
  required TargetPlatform platform,
  String hostOverride = '',
}) {
  if (!shouldUseFirebaseEmulators(environment)) {
    throw StateError(
      'Firebase emulators can be configured only for a non-production '
      'development or verification environment.',
    );
  }

  final explicitHost = hostOverride.trim();
  final host = explicitHost.isNotEmpty
      ? explicitHost
      : !isWeb && platform == TargetPlatform.android
          ? '10.0.2.2'
          : '127.0.0.1';
  return FirebaseEmulatorConfiguration(host: host);
}

Future<bool> configureFirebaseEmulators(String environment) async {
  if (!shouldUseFirebaseEmulators(environment)) return false;

  final configuration = resolveFirebaseEmulatorConfiguration(
    environment: environment,
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    hostOverride: firebaseEmulatorHostOverride,
  );
  await FirebaseAuth.instance.useAuthEmulator(
    configuration.host,
    configuration.authPort,
  );
  FirebaseFirestore.instance.useFirestoreEmulator(
    configuration.host,
    configuration.firestorePort,
  );
  FirebaseFunctions.instance.useFunctionsEmulator(
    configuration.host,
    configuration.functionsPort,
  );
  await FirebaseStorage.instance.useStorageEmulator(
    configuration.host,
    configuration.storagePort,
  );
  return true;
}
