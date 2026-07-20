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
    ensureNativeFirebaseEnvironmentSupported(environment);
    await Firebase.initializeApp();
  }
  await initFirebaseAppCheck();
}
