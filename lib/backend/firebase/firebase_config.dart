import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_app_check_config.dart';
import 'firebase_emulator_config.dart';
import 'firebase_runtime_config.dart';

Future initFirebase({Future<void> Function()? onCoreInitialized}) async {
  final environment = currentFirebaseEnvironment();
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
  await onCoreInitialized?.call();
  final usingEmulators = await configureFirebaseEmulators(environment);
  await initFirebaseAppCheck(useEmulators: usingEmulators);
}
