import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_app_check_config.dart';
import 'firebase_runtime_config.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: currentFirebaseWebConfiguration().toFirebaseOptions(),
    );
  } else {
    await Firebase.initializeApp();
  }
  await initFirebaseAppCheck();
}
