import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

const firebaseEmulatorHostOverride = String.fromEnvironment(
  'PIPE_FIREBASE_EMULATOR_HOST',
);
const firebaseAuthEmulatorPort = int.fromEnvironment(
  'PIPE_FIREBASE_AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);
const firebaseFirestoreEmulatorPort = int.fromEnvironment(
  'PIPE_FIREBASE_FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);
const firebaseFunctionsEmulatorPort = int.fromEnvironment(
  'PIPE_FIREBASE_FUNCTIONS_EMULATOR_PORT',
  defaultValue: 5001,
);
const firebaseStorageEmulatorPort = int.fromEnvironment(
  'PIPE_FIREBASE_STORAGE_EMULATOR_PORT',
  defaultValue: 9199,
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

int _validPort(int value, String label) {
  if (value < 1 || value > 65535) {
    throw StateError('$label must be a TCP port from 1 to 65535.');
  }
  return value;
}

FirebaseEmulatorConfiguration resolveFirebaseEmulatorConfiguration({
  required String environment,
  required bool isWeb,
  required TargetPlatform platform,
  String hostOverride = '',
  int authPort = 9099,
  int firestorePort = 8080,
  int functionsPort = 5001,
  int storagePort = 9199,
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
  return FirebaseEmulatorConfiguration(
    host: host,
    authPort: _validPort(authPort, 'Auth emulator port'),
    firestorePort: _validPort(firestorePort, 'Firestore emulator port'),
    functionsPort: _validPort(functionsPort, 'Functions emulator port'),
    storagePort: _validPort(storagePort, 'Storage emulator port'),
  );
}

Future<bool> configureFirebaseEmulators(String environment) async {
  if (!shouldUseFirebaseEmulators(environment)) return false;

  final configuration = resolveFirebaseEmulatorConfiguration(
    environment: environment,
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    hostOverride: firebaseEmulatorHostOverride,
    authPort: firebaseAuthEmulatorPort,
    firestorePort: firebaseFirestoreEmulatorPort,
    functionsPort: firebaseFunctionsEmulatorPort,
    storagePort: firebaseStorageEmulatorPort,
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
