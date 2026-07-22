import 'dart:typed_data';

import 'profile_photo_upload_types.dart';
import 'profile_photo_uploader_io.dart'
    if (dart.library.html) 'profile_photo_uploader_web.dart';

export 'profile_photo_upload_types.dart';

Future<String> uploadProfilePhoto({
  required Uint8List bytes,
  required String userId,
  required String idToken,
  required String storageBucket,
  required ProfilePhotoProgress onProgress,
}) =>
    uploadProfilePhotoImpl(
      bytes: bytes,
      userId: userId,
      idToken: idToken,
      storageBucket: storageBucket,
      onProgress: onProgress,
    );
