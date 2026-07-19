import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart';

class ListingMediaUploadResult {
  const ListingMediaUploadResult(
      {required this.imageUrls, required this.imageHashes, this.videoUrl});

  final List<String> imageUrls;
  final List<String> imageHashes;
  final String? videoUrl;
}

class MarketplaceMediaRepository {
  MarketplaceMediaRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  static const maxPhotos = 12;
  static const maxPhotoBytes = 5 * 1024 * 1024;
  static const maxVideoBytes = 25 * 1024 * 1024;

  final FirebaseStorage _storage;

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
    void Function(int completed, int total)? onProgress,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in required to upload media.');
    final imageUrls = <String>[];
    final imageHashes = <String>[];
    final total = photos.length + (video == null ? 0 : 1);
    var completed = 0;
    for (var index = 0; index < photos.length; index++) {
      final file = photos[index];
      final extension = _extension(file.name, 'jpg');
      final bytes = await file.readAsBytes();
      imageHashes.add(sha256.convert(bytes).toString());
      final reference = _storage
          .ref('listing_media/$uid/$listingId/photo_${index + 1}.$extension');
      await reference
          .putData(bytes,
              SettableMetadata(contentType: _imageContentType(extension)))
          .timeout(const Duration(seconds: 45));
      imageUrls.add(await reference.getDownloadURL());
      completed++;
      onProgress?.call(completed, total);
    }
    String? videoUrl;
    if (video != null) {
      final extension = _extension(video.name, 'mp4');
      final reference =
          _storage.ref('listing_media/$uid/$listingId/video.$extension');
      await reference
          .putData(await video.readAsBytes(),
              SettableMetadata(contentType: _videoContentType(extension)))
          .timeout(const Duration(seconds: 60));
      videoUrl = await reference.getDownloadURL();
      completed++;
      onProgress?.call(completed, total);
    }
    return ListingMediaUploadResult(
        imageUrls: imageUrls, imageHashes: imageHashes, videoUrl: videoUrl);
  }

  String _extension(String name, String fallback) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? fallback : name.substring(dot + 1).toLowerCase();
  }

  String _imageContentType(String extension) =>
      extension == 'png' ? 'image/png' : 'image/jpeg';

  String _videoContentType(String extension) =>
      extension == 'mov' ? 'video/quicktime' : 'video/mp4';
}
