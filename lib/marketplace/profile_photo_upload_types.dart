typedef ProfilePhotoProgress = void Function(double progress);

class ProfilePhotoUploadException implements Exception {
  const ProfilePhotoUploadException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}
