import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import 'profile_photo_picker.dart';

typedef BusinessLogoBytesPicker = Future<Uint8List?> Function();

typedef BusinessLogoBytesUploader = Future<String> Function({
  required Uint8List bytes,
  required String purpose,
});

/// Cross-platform Business Logo picker and uploader for Insurance Providers,
/// Oilfield Directory Businesses, and Corporate Partner Brands.
class PipeBuyerBusinessLogoUploader {
  PipeBuyerBusinessLogoUploader({
    FirebaseFunctions? functions,
    BusinessLogoBytesPicker? pickBytesOverride,
    BusinessLogoBytesUploader? uploadBytesOverride,
  })  : _functions = functions,
        _pickBytesOverride = pickBytesOverride,
        _uploadBytesOverride = uploadBytesOverride;

  static const int maxLogoBytes = 2 * 1024 * 1024;

  FirebaseFunctions? _functions;
  final BusinessLogoBytesPicker? _pickBytesOverride;
  final BusinessLogoBytesUploader? _uploadBytesOverride;

  FirebaseFunctions get _resolvedFunctions =>
      _functions ??= FirebaseFunctions.instance;

  /// Opens the platform image picker and uploads the selected PNG/JPG/WebP
  /// business logo via the `uploadBusinessLogo` Cloud Function.
  ///
  /// Returns `null` if the user cancels file selection.
  Future<String?> pickAndUploadLogo({
    required String purpose,
  }) async {
    final picker = _pickBytesOverride ?? pickProfilePhotoBytes;
    final bytes = await picker();
    if (bytes == null) return null;
    return uploadBytes(bytes: bytes, purpose: purpose);
  }

  Future<String> uploadBytes({
    required Uint8List bytes,
    required String purpose,
  }) async {
    if (bytes.length < 16) {
      throw StateError(
        'Selected file is empty or invalid. Choose a PNG, JPG, or WebP logo.',
      );
    }
    if (bytes.length > maxLogoBytes) {
      throw StateError(
        'Business logo must be 2 MB or smaller. Choose a smaller image.',
      );
    }

    final customUploader = _uploadBytesOverride;
    if (customUploader != null) {
      return customUploader(bytes: bytes, purpose: purpose);
    }

    try {
      final response = await _resolvedFunctions
          .httpsCallable(
        'uploadBusinessLogo',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 40),
        ),
      )
          .call(<String, Object?>{
        'base64Data': base64Encode(bytes),
        'purpose': purpose,
      });
      if (response.data is! Map) {
        throw StateError('Business logo upload returned an invalid response.');
      }
      final map = Map<String, dynamic>.from(response.data as Map);
      final url = '${map['logoUrl'] ?? ''}'.trim();
      if (url.isEmpty) {
        throw StateError('Business logo upload did not return a download URL.');
      }
      return url;
    } on FirebaseFunctionsException catch (error) {
      final msg = error.message?.trim();
      if (error.code != 'internal' &&
          msg != null &&
          msg.isNotEmpty &&
          msg.toLowerCase() != error.code.toLowerCase()) {
        throw StateError(msg);
      }
      throw StateError(switch (error.code) {
        'invalid-argument' =>
          'Choose a valid PNG, JPG, or WebP logo image (up to 2 MB).',
        'resource-exhausted' =>
          'Too many logo uploads recently. Please wait a moment and try again.',
        _ => 'Business logo upload is temporarily unavailable. Try again.',
      });
    }
  }

  /// Validates an optional `https://` logo URL (or empty string).
  static String? validateLogoUrl(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 1000) {
      return 'Logo URL cannot exceed 1000 characters.';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority) {
      return 'Enter a valid https:// logo URL.';
    }
    final host = uri.host.toLowerCase();
    final isLocal =
        uri.scheme == 'http' && (host == '127.0.0.1' || host == 'localhost');
    if (uri.scheme != 'https' && !isLocal) {
      return 'Logo URL must start with https://.';
    }
    if (!isLocal && !host.contains('.')) {
      return 'Enter a valid https:// logo URL.';
    }
    return null;
  }
}
