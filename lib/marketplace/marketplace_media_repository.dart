import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'marketplace_image_normalizer.dart';

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

  /// Phones save 8-25 MB originals. They are scaled and re-encoded to fit
  /// [maxPhotoBytes] before upload, so the picker accepts much larger files.
  static const maxRawPhotoBytes = 40 * 1024 * 1024;
  static const maxVideoBytes = 100 * 1024 * 1024;

  /// Containers phones record video in: MP4/M4V (Android, iPhone), MOV (iPhone),
  /// 3GP/3G2 (older Android), WebM.
  static const videoExtensions = {'mp4', 'mov', 'm4v', '3gp', '3g2', 'webm'};
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
      if (await file.length() <= maxRawPhotoBytes) accepted.add(file);
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
    if (file == null || await file.length() > maxRawPhotoBytes) return null;
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
      final normalized = await _normalizePhoto(file);
      final bytes = normalized.bytes;
      imageHashes.add(sha256.convert(bytes).toString());
      imageUrls.add(await _uploadWithRetry(
        path:
            'listing_media/$uid/$listingId/photo_${index + 1}.${normalized.extension}',
        bytes: bytes,
        contentType: normalized.contentType,
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
      if (!videoExtensions.contains(extension)) {
        throw MarketplaceMediaUploadException(
          code: 'unsupported-video-format',
          fileName: video.name,
          userMessage:
              '${video.name} is not a video format Pipe Buyer accepts. Choose an MP4, MOV, M4V, 3GP or WebM video.',
        );
      }
      final bytes = await video.readAsBytes();
      if (bytes.length > maxVideoBytes) {
        throw MarketplaceMediaUploadException(
          code: 'video-too-large',
          fileName: video.name,
          userMessage:
              '${video.name} is larger than 100 MB. Trim it or choose a shorter video.',
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

  /// Reads the photo's real format from its bytes and converts anything other
  /// than a normal JPEG/PNG (WebP, GIF, HEIC/AVIF where decodable, BMP, TIFF,
  /// oversized files) into a JPEG every viewer can display.
  Future<NormalizedImage> _normalizePhoto(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > maxRawPhotoBytes) {
      throw MarketplaceMediaUploadException(
        code: 'photo-too-large',
        fileName: file.name,
        userMessage:
            '${file.name} is larger than 40 MB. Remove it or choose a smaller photo.',
      );
    }
    try {
      return await normalizeImageForUpload(
        bytes,
        fileName: file.name,
        maxBytes: maxPhotoBytes,
      );
    } on UnsupportedImageFormatException catch (error) {
      throw MarketplaceMediaUploadException(
        code: 'unsupported-photo-format',
        fileName: file.name,
        userMessage: error.userMessage,
      );
    } on ImageTooLargeException {
      throw MarketplaceMediaUploadException(
        code: 'photo-too-large',
        fileName: file.name,
        userMessage:
            '${file.name} is still too large after it was shrunk. Choose a smaller photo.',
      );
    }
  }

  String _videoContentType(String extension) => switch (extension) {
        'mov' => 'video/quicktime',
        'm4v' => 'video/x-m4v',
        '3gp' => 'video/3gpp',
        '3g2' => 'video/3gpp2',
        'webm' => 'video/webm',
        _ => 'video/mp4',
      };
}
