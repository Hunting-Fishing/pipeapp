import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Image formats phones and cameras produce, detected from the file's bytes
/// (never from its name, which phones and browsers often get wrong).
enum DetectedImageFormat { jpeg, png, gif, webp, bmp, tiff, heif, avif, unknown }

/// A photo that is safe to upload and to show in any browser or app.
class NormalizedImage {
  const NormalizedImage({
    required this.bytes,
    required this.extension,
    required this.contentType,
    required this.converted,
  });

  final Uint8List bytes;

  /// `jpg` or `png`: the only image types stored for listings.
  final String extension;
  final String contentType;

  /// True when the original was re-encoded (different format, too large, or
  /// transparent). False when the original bytes are uploaded unchanged.
  final bool converted;
}

class UnsupportedImageFormatException implements Exception {
  const UnsupportedImageFormatException(this.fileName, this.format);

  final String fileName;
  final DetectedImageFormat format;

  String get userMessage {
    final heic = format == DetectedImageFormat.heif ||
        format == DetectedImageFormat.avif;
    return heic
        ? '$fileName is a ${format == DetectedImageFormat.avif ? 'AVIF' : 'HEIC'} '
            'photo this browser cannot read. Use the Pipe Buyer app or Safari, '
            'or set your camera to Most Compatible, then choose the photo again.'
        : '$fileName is not a photo format Pipe Buyer can read. Choose a JPEG, '
            'PNG, WebP, GIF, BMP or TIFF photo.';
  }

  @override
  String toString() => 'UnsupportedImageFormatException($fileName, $format)';
}

class ImageTooLargeException implements Exception {
  const ImageTooLargeException(this.fileName, this.maxBytes);

  final String fileName;
  final int maxBytes;

  @override
  String toString() => 'ImageTooLargeException($fileName, $maxBytes)';
}

DetectedImageFormat detectImageFormat(Uint8List b) {
  bool startsWith(List<int> signature, [int offset = 0]) {
    if (b.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (b[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xFF, 0xD8, 0xFF])) return DetectedImageFormat.jpeg;
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return DetectedImageFormat.png;
  }
  if (startsWith('GIF8'.codeUnits)) return DetectedImageFormat.gif;
  if (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)) {
    return DetectedImageFormat.webp;
  }
  if (startsWith('BM'.codeUnits)) return DetectedImageFormat.bmp;
  if (startsWith(const [0x49, 0x49, 0x2A, 0x00]) ||
      startsWith(const [0x4D, 0x4D, 0x00, 0x2A])) {
    return DetectedImageFormat.tiff;
  }
  if (startsWith('ftyp'.codeUnits, 4) && b.length >= 12) {
    final brand = String.fromCharCodes(b.sublist(8, 12));
    if (brand == 'avif' || brand == 'avis') return DetectedImageFormat.avif;
    const heif = {
      'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'hevm', 'hevs', //
      'mif1', 'msf1', 'heif',
    };
    if (heif.contains(brand)) return DetectedImageFormat.heif;
  }
  return DetectedImageFormat.unknown;
}

/// Turns any photo a phone can produce into a JPEG or PNG that every viewer can
/// display. JPEG and PNG within [maxBytes] pass through byte-for-byte. Other
/// formats (WebP, GIF, BMP, TIFF, and HEIC/AVIF where the device can decode
/// them) are re-encoded as JPEG, oriented upright, scaled to [maxDimension],
/// and flattened onto white if they had transparency.
Future<NormalizedImage> normalizeImageForUpload(
  Uint8List bytes, {
  required String fileName,
  int maxBytes = 5 * 1024 * 1024,
  int maxDimension = 2000,
}) async {
  final format = detectImageFormat(bytes);
  if (format == DetectedImageFormat.unknown) {
    throw UnsupportedImageFormatException(fileName, format);
  }
  if (bytes.length <= maxBytes) {
    if (format == DetectedImageFormat.jpeg) {
      return NormalizedImage(
        bytes: bytes,
        extension: 'jpg',
        contentType: 'image/jpeg',
        converted: false,
      );
    }
    if (format == DetectedImageFormat.png) {
      return NormalizedImage(
        bytes: bytes,
        extension: 'png',
        contentType: 'image/png',
        converted: false,
      );
    }
  }

  final _Pixels? pixels = switch (format) {
    DetectedImageFormat.heif ||
    DetectedImageFormat.avif =>
      await _decodeWithPlatformCodec(bytes),
    _ => await _decodeWithDart(bytes),
  };
  if (pixels == null) {
    throw UnsupportedImageFormatException(fileName, format);
  }

  for (final quality in const [88, 75, 60]) {
    final jpeg = await _encode(pixels, maxDimension, quality);
    if (jpeg.length <= maxBytes) {
      return NormalizedImage(
        bytes: jpeg,
        extension: 'jpg',
        contentType: 'image/jpeg',
        converted: true,
      );
    }
  }
  throw ImageTooLargeException(fileName, maxBytes);
}

class _Pixels {
  const _Pixels(this.width, this.height, this.rgba, this.encoded);

  final int width;
  final int height;

  /// Raw RGBA when decoded by the platform codec; null when [encoded] holds the
  /// original bytes for the pure-Dart decoder.
  final Uint8List? rgba;
  final Uint8List? encoded;
}

Future<_Pixels?> _decodeWithDart(Uint8List bytes) async {
  // Probe cheaply first so unreadable files fail fast without a full decode.
  final decoder = img.findDecoderForData(bytes);
  if (decoder == null) return null;
  final info = decoder.startDecode(bytes);
  if (info == null) return null;
  return _Pixels(info.width, info.height, null, bytes);
}

Future<_Pixels?> _decodeWithPlatformCodec(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    final result = data == null
        ? null
        : _Pixels(
            frame.image.width,
            frame.image.height,
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            null,
          );
    frame.image.dispose();
    codec.dispose();
    return result;
  } catch (_) {
    return null;
  }
}

Future<Uint8List> _encode(_Pixels pixels, int maxDimension, int quality) {
  final job = _EncodeJob(pixels, maxDimension, quality);
  return kIsWeb ? Future.value(_encodeJob(job)) : compute(_encodeJob, job);
}

class _EncodeJob {
  const _EncodeJob(this.pixels, this.maxDimension, this.quality);

  final _Pixels pixels;
  final int maxDimension;
  final int quality;
}

Uint8List _encodeJob(_EncodeJob job) {
  final pixels = job.pixels;
  img.Image? image;
  if (pixels.rgba != null) {
    image = img.Image.fromBytes(
      width: pixels.width,
      height: pixels.height,
      bytes: pixels.rgba!.buffer,
      bytesOffset: pixels.rgba!.offsetInBytes,
      numChannels: 4,
    );
  } else {
    image = img.decodeImage(pixels.encoded!);
    if (image != null) image = img.bakeOrientation(image);
  }
  if (image == null) throw StateError('The photo could not be decoded.');

  final longest = math.max(image.width, image.height);
  if (longest > job.maxDimension) {
    image = image.width >= image.height
        ? img.copyResize(image, width: job.maxDimension)
        : img.copyResize(image, height: job.maxDimension);
  }
  // JPEG has no transparency: flatten onto white so transparent areas do not
  // turn black.
  final flat = img.Image(width: image.width, height: image.height);
  img.fill(flat, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(flat, image);
  return img.encodeJpg(flat, quality: job.quality);
}
