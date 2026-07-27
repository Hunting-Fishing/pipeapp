import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ListingMediaUploadResult {
  const ListingMediaUploadResult(
      {required this.imageUrls, required this.imageHashes, this.videoUrl});

  final List<String> imageUrls;
  final List<String> imageHashes;
  final String? videoUrl;
}

class MarketplaceMediaUploadProgress {
  const MarketplaceMediaUploadProgress({
    required this.completedFiles,
    required this.totalFiles,
    required this.currentFile,
    required this.currentFileProgress,
    required this.attempt,
    required this.maxAttempts,
  });

  final int completedFiles;
  final int totalFiles;
  final String currentFile;
  final double currentFileProgress;
  final int attempt;
  final int maxAttempts;

  double get overallProgress => totalFiles <= 0
      ? 1
      : ((completedFiles + currentFileProgress.clamp(0, 1)) / totalFiles)
          .clamp(0, 1);

  bool get retrying => attempt > 1;
}

class MarketplaceMediaUploadException implements Exception {
  const MarketplaceMediaUploadException({
    required this.code,
    required this.userMessage,
    required this.fileName,
    this.cause,
  });

  final String code;
  final String userMessage;
  final String fileName;
  final Object? cause;

  @override
  String toString() => userMessage;
}

typedef MarketplaceMediaDataUploader = Future<String> Function({
  required String path,
  required Uint8List bytes,
  required String contentType,
  required Duration timeout,
  required void Function(double progress) onProgress,
});

typedef MarketplaceMediaUserIdProvider = String? Function();

class MarketplaceMediaRepository {
  MarketplaceMediaRepository({
    FirebaseStorage? storage,
    MarketplaceMediaDataUploader? uploader,
    MarketplaceMediaUserIdProvider? userIdProvider,
    Duration retryBaseDelay = const Duration(milliseconds: 500),
  })  : _storage = storage,
        _uploader = uploader,
        _userIdProvider = userIdProvider,
        _retryBaseDelay = retryBaseDelay;

  static const maxPhotos = 12;
  static const maxPhotoBytes = 5 * 1024 * 1024;
  static const maxVideoBytes = 25 * 1024 * 1024;
  static const maxUploadAttempts = 3;

  final FirebaseStorage? _storage;
  final MarketplaceMediaDataUploader? _uploader;
  final MarketplaceMediaUserIdProvider? _userIdProvider;
  final Duration _retryBaseDelay;

  Future<List<XFile>> pickPhotos(int existingCount) async {
    final files = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    final available = maxPhotos - existingCount;
    if (available <= 0) return const [];
    final accepted = <XFile>[];
    for (final file in files.take(available)) {
      if (await file.length() <= maxPhotoBytes) accepted.add(file);
    }
    return accepted;
  }

  Future<XFile?> capturePhoto(int existingCount) async {
    if (existingCount >= maxPhotos) return null;
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (file == null || await file.length() > maxPhotoBytes) return null;
    return file;
  }

  Future<XFile?> pickVideo() async {
    final file = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 45),
    );
    if (file == null || await file.length() > maxVideoBytes) return null;
    return file;
  }

  Future<ListingMediaUploadResult> upload({
    required String listingId,
    required List<XFile> photos,
    XFile? video,
    void Function(MarketplaceMediaUploadProgress progress)? onProgress,
  }) async {
    final uid =
        _userIdProvider?.call() ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in required to upload media.');
    final imageUrls = <String>[];
    final imageHashes = <String>[];
    final total = photos.length + (video == null ? 0 : 1);
    var completed = 0;
    for (var index = 0; index < photos.length; index++) {
      final file = photos[index];
      final extension = _extension(file.name, 'jpg');
      final bytes = await file.readAsBytes();
      if (bytes.length > maxPhotoBytes) {
        throw MarketplaceMediaUploadException(
          code: 'photo-too-large',
          fileName: file.name,
          userMessage:
              '${file.name} is larger than 5 MB. Remove it or choose a smaller photo.',
        );
      }
      imageHashes.add(sha256.convert(bytes).toString());
      imageUrls.add(await _uploadWithRetry(
        path: 'listing_media/$uid/$listingId/photo_${index + 1}.$extension',
        bytes: bytes,
        contentType: _imageContentType(extension),
        timeout: const Duration(seconds: 60),
        fileName: file.name,
        completedFiles: completed,
        totalFiles: total,
        onProgress: onProgress,
      ));
      completed++;
      onProgress?.call(MarketplaceMediaUploadProgress(
        completedFiles: completed,
        totalFiles: total,
        currentFile: file.name,
        currentFileProgress: 0,
        attempt: 1,
        maxAttempts: maxUploadAttempts,
      ));
    }
    String? videoUrl;
    if (video != null) {
      final extension = _extension(video.name, 'mp4');
      final bytes = await video.readAsBytes();
      if (bytes.length > maxVideoBytes) {
        throw MarketplaceMediaUploadException(
          code: 'video-too-large',
          fileName: video.name,
          userMessage:
              '${video.name} is larger than 25 MB. Remove it or choose a smaller video.',
        );
      }
      videoUrl = await _uploadWithRetry(
        path: 'listing_media/$uid/$listingId/video.$extension',
        bytes: bytes,
        contentType: _videoContentType(extension),
        timeout: const Duration(seconds: 90),
        fileName: video.name,
        completedFiles: completed,
        totalFiles: total,
        onProgress: onProgress,
      );
      completed++;
      onProgress?.call(MarketplaceMediaUploadProgress(
        completedFiles: completed,
        totalFiles: total,
        currentFile: video.name,
        currentFileProgress: 0,
        attempt: 1,
        maxAttempts: maxUploadAttempts,
      ));
    }
    return ListingMediaUploadResult(
        imageUrls: imageUrls, imageHashes: imageHashes, videoUrl: videoUrl);
  }

  Future<String> _uploadWithRetry({
    required String path,
    required Uint8List bytes,
    required String contentType,
    required Duration timeout,
    required String fileName,
    required int completedFiles,
    required int totalFiles,
    required void Function(MarketplaceMediaUploadProgress progress)? onProgress,
  }) async {
    Object? lastError;
    var highestProgress = 0.0;
    for (var attempt = 1; attempt <= maxUploadAttempts; attempt++) {
      try {
        return await _putData(
          path: path,
          bytes: bytes,
          contentType: contentType,
          timeout: timeout,
          onProgress: (value) {
            highestProgress = math.max(highestProgress, value.clamp(0, 1));
            onProgress?.call(MarketplaceMediaUploadProgress(
              completedFiles: completedFiles,
              totalFiles: totalFiles,
              currentFile: fileName,
              currentFileProgress: highestProgress,
              attempt: attempt,
              maxAttempts: maxUploadAttempts,
            ));
          },
        );
      } catch (error) {
        lastError = error;
        final code = _errorCode(error);
        if (attempt == maxUploadAttempts || !_retryable(code)) {
          throw MarketplaceMediaUploadException(
            code: code,
            fileName: fileName,
            cause: error,
            userMessage: _uploadErrorMessage(code, fileName),
          );
        }
        onProgress?.call(MarketplaceMediaUploadProgress(
          completedFiles: completedFiles,
          totalFiles: totalFiles,
          currentFile: fileName,
          currentFileProgress: highestProgress,
          attempt: attempt + 1,
          maxAttempts: maxUploadAttempts,
        ));
        await Future<void>.delayed(_retryBaseDelay * attempt);
      }
    }
    throw MarketplaceMediaUploadException(
      code: 'unknown',
      fileName: fileName,
      cause: lastError,
      userMessage:
          '$fileName could not be uploaded. Check your connection and retry the private draft.',
    );
  }

  Future<String> _putData({
    required String path,
    required Uint8List bytes,
    required String contentType,
    required Duration timeout,
    required void Function(double progress) onProgress,
  }) async {
    if (_uploader != null) {
      return _uploader!(
        path: path,
        bytes: bytes,
        contentType: contentType,
        timeout: timeout,
        onProgress: onProgress,
      );
    }
    final reference = (_storage ?? FirebaseStorage.instance).ref(path);
    final task = reference.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    StreamSubscription<TaskSnapshot>? subscription;
    try {
      subscription = task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes <= 0) return;
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      });
      await task.timeout(timeout);
      onProgress(1);
      return await reference
          .getDownloadURL()
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      await task.cancel();
      rethrow;
    } finally {
      await subscription?.cancel();
    }
  }

  String _errorCode(Object error) {
    if (error is FirebaseException) return error.code;
    if (error is TimeoutException) return 'timeout';
    return 'unknown';
  }

  bool _retryable(String code) => const {
        'network-error',
        'network-request-failed',
        'retry-limit-exceeded',
        'timeout',
        'unknown',
      }.contains(code);

  String _uploadErrorMessage(String code, String fileName) => switch (code) {
        'unauthenticated' =>
          'Your session expired while uploading $fileName. Sign in again, then retry the private draft.',
        'unauthorized' ||
        'permission-denied' =>
          'Your account is not authorized to upload $fileName. Refresh your account and retry.',
        'quota-exceeded' =>
          'Media storage is temporarily at capacity. Your listing remains a private draft; retry later.',
        'canceled' =>
          '$fileName was not fully uploaded. Your listing remains a private draft and can be retried.',
        _ =>
          '$fileName could not be uploaded after $maxUploadAttempts attempts. Check your connection and retry the private draft.',
      };

  String _extension(String name, String fallback) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? fallback : name.substring(dot + 1).toLowerCase();
  }

  String _imageContentType(String extension) =>
      extension == 'png' ? 'image/png' : 'image/jpeg';

  String _videoContentType(String extension) =>
      extension == 'mov' ? 'video/quicktime' : 'video/mp4';
}
