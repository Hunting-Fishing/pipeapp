import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_app_check_config.dart';
import 'firebase_emulator_config.dart';
import 'firebase_runtime_config.dart';

typedef FirebaseStartupProgress = void Function(
  String stageId,
  String label,
  double progress,
);

Future initFirebase({
  Future<void> Function()? onCoreInitialized,
  FirebaseStartupProgress? onStartupProgress,
}) async {
  onStartupProgress?.call(
    'firebase_configuration',
    'Checking secure service configuration',
    .46,
  );
  final environment = currentFirebaseEnvironment();
  onStartupProgress?.call(
    'firebase_core',
    'Connecting to Pipe Buyer services',
    .54,
  );
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: currentFirebaseWebConfiguration().toFirebaseOptions(),
    );
  } else {
    final declaredProjectId = currentFirebaseProjectId();
    expectedNativeFirebaseProjectId(
      environment: environment,
      declaredProjectId: declaredProjectId,
    );
    await Firebase.initializeApp(
      options: environment == 'staging'
          ? stagingNativeFirebaseOptions(defaultTargetPlatform)
          : null,
    );
    ensureInitializedFirebaseProjectMatches(
      environment: environment,
      declaredProjectId: declaredProjectId,
      actualProjectId: Firebase.app().options.projectId,
    );
  }
  onStartupProgress?.call(
    'diagnostic_reporting',
    'Starting protected diagnostics',
    .62,
  );
  await onCoreInitialized?.call();
  onStartupProgress?.call(
    'service_routing',
    'Checking service routing',
    .68,
  );
  final usingEmulators = await configureFirebaseEmulators(environment);
  onStartupProgress?.call(
    'app_integrity',
    'Verifying application integrity',
    .74,
  );
  await initFirebaseAppCheck(useEmulators: usingEmulators);
  onStartupProgress?.call(
    'firebase_ready',
    'Secure services are ready',
    .78,
  );
}
