import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_app_check_config.dart';
import 'firebase_runtime_config.dart';

Future initFirebase() async {
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
    await Firebase.initializeApp();
    ensureInitializedFirebaseProjectMatches(
      environment: environment,
      declaredProjectId: declaredProjectId,
      actualProjectId: Firebase.app().options.projectId,
    );
  }
  await initFirebaseAppCheck();
}
