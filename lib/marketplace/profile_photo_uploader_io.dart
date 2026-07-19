import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'profile_photo_upload_types.dart';

Future<String> uploadProfilePhotoImpl({
  required Uint8List bytes,
  required String userId,
  required String idToken,
  required String storageBucket,
  required ProfilePhotoProgress onProgress,
}) async {
  final reference = FirebaseStorage.instance.ref(
      'profile_media/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.png');
  final task = reference.putData(
      bytes,
      SettableMetadata(
          contentType: 'image/png', cacheControl: 'public,max-age=3600'));
  StreamSubscription<TaskSnapshot>? subscription;
  try {
    subscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes <= 0) return;
      onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
    });
    await task;
    onProgress(1);
    return reference.getDownloadURL();
  } on FirebaseException catch (error) {
    throw ProfilePhotoUploadException(
        error.code, error.message ?? 'The profile photo upload failed.');
  } finally {
    await subscription?.cancel();
  }
}
