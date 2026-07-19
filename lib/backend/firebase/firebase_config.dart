import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_app_check_config.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: "AIzaSyAMm0HnXVq6UOERnPNP9SKqGtyV_-H--u8",
            authDomain: "flutter-flow-pipe.firebaseapp.com",
            projectId: "flutter-flow-pipe",
            storageBucket: "flutter-flow-pipe.firebasestorage.app",
            messagingSenderId: "426221783223",
            appId: "1:426221783223:web:179633eb8c8378e6e26532",
            measurementId: "G-YL926V0FD9"));
  } else {
    await Firebase.initializeApp();
  }
  await initFirebaseAppCheck();
}
