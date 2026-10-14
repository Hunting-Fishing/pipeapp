import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pipe_app/marketplace/marketplace_image_normalizer.dart';

img.Image _sample({int width = 64, int height = 48}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 80, 20));
  img.fillRect(
    image,
    x1: 0,
    y1: 0,
    x2: width ~/ 2,
    y2: height ~/ 2,
    color: img.ColorRgb8(20, 80, 200),
  );
  return image;
}

Uint8List _isoBmff(String brand) {
  final bytes = BytesBuilder();
  bytes.add([0, 0, 0, 24]);
  bytes.add('ftyp'.codeUnits);
  bytes.add(brand.codeUnits);
  bytes.add(List<int>.filled(12, 0));
  return bytes.toBytes();
}

void main() {
  group('detectImageFormat reads the bytes, not the file name', () {
    test('recognises every format a phone or browser can hand over', () {
      final sample = _sample();
      expect(detectImageFormat(img.encodeJpg(sample)), DetectedImageFormat.jpeg);
      expect(detectImageFormat(img.encodePng(sample)), DetectedImageFormat.png);
      expect(detectImageFormat(img.encodeGif(sample)), DetectedImageFormat.gif);
      expect(detectImageFormat(img.encodeBmp(sample)), DetectedImageFormat.bmp);
      expect(detectImageFormat(img.encodeTiff(sample)), DetectedImageFormat.tiff);
      expect(detectImageFormat(_isoBmff('heic')), DetectedImageFormat.heif);
      expect(detectImageFormat(_isoBmff('mif1')), DetectedImageFormat.heif);
      expect(detectImageFormat(_isoBmff('avif')), DetectedImageFormat.avif);
      expect(
        detectImageFormat(
          Uint8List.fromList([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]),
        ),
        DetectedImageFormat.webp,
      );
    });

    test('treats unknown and empty data as unknown', () {
      expect(detectImageFormat(Uint8List(0)), DetectedImageFormat.unknown);
      expect(
        detectImageFormat(Uint8List.fromList([1, 2, 3, 4, 5])),
        DetectedImageFormat.unknown,
      );
      expect(detectImageFormat(_isoBmff('mp42')), DetectedImageFormat.unknown);
    });
  });

  group('normalizeImageForUpload', () {
    test('passes a normal JPEG through byte for byte', () async {
      final jpeg = img.encodeJpg(_sample());
      final result = await normalizeImageForUpload(jpeg, fileName: 'a.jpg');
      expect(result.converted, isFalse);
      expect(result.extension, 'jpg');
      expect(result.contentType, 'image/jpeg');
      expect(result.bytes, same(jpeg));
    });

    test('passes a normal PNG through byte for byte', () async {
      final png = img.encodePng(_sample());
      final result = await normalizeImageForUpload(png, fileName: 'a.png');
      expect(result.converted, isFalse);
      expect(result.extension, 'png');
      expect(result.contentType, 'image/png');
      expect(result.bytes, same(png));
    });

    test('ignores a wrong file extension and trusts the real format', () async {
      final gif = img.encodeGif(_sample());
      final result = await normalizeImageForUpload(gif, fileName: 'photo.jpg');
      expect(result.converted, isTrue);
      expect(detectImageFormat(result.bytes), DetectedImageFormat.jpeg);
    });

    for (final entry in <String, Uint8List Function(img.Image)>{
      'GIF': img.encodeGif,
      'BMP': img.encodeBmp,
      'TIFF': img.encodeTiff,
    }.entries) {
      test('converts ${entry.key} to an upright, bounded JPEG', () async {
        final source = entry.value(_sample(width: 3000, height: 1500));
        final result = await normalizeImageForUpload(
          source,
          fileName: 'phone.${entry.key.toLowerCase()}',
          maxBytes: 8 * 1024 * 1024,
        );
        expect(result.converted, isTrue);
        expect(result.extension, 'jpg');
        expect(result.contentType, 'image/jpeg');
        expect(detectImageFormat(result.bytes), DetectedImageFormat.jpeg);
        final decoded = img.decodeJpg(result.bytes)!;
        expect(decoded.width, 2000, reason: 'longest side is capped');
        expect(decoded.height, 1000, reason: 'aspect ratio is kept');
      });
    }

    test('converts a WebP photo to JPEG', () async {
      // Smallest valid lossless WebP (1x1).
      final webp = base64Decode('UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==');
      final result = await normalizeImageForUpload(webp, fileName: 'a.webp');
      expect(result.converted, isTrue);
      expect(detectImageFormat(result.bytes), DetectedImageFormat.jpeg);
    });

    test('re-encodes an oversized JPEG instead of rejecting it', () async {
      final big = img.encodeJpg(_sample(width: 2400, height: 1800), quality: 100);
      final result = await normalizeImageForUpload(
        big,
        fileName: 'big.jpg',
        maxBytes: big.length - 1,
      );
      expect(result.converted, isTrue);
      expect(result.bytes.length, lessThan(big.length));
    });

    test('reports an image that cannot be made small enough', () async {
      final png = img.encodePng(_sample());
      expect(
        () => normalizeImageForUpload(png, fileName: 'x.png', maxBytes: 8),
        throwsA(isA<ImageTooLargeException>()),
      );
    });

    test('gives a friendly HEIC message when the device cannot decode it', () async {
      Object? error;
      try {
        await normalizeImageForUpload(_isoBmff('heic'), fileName: 'IMG_1.HEIC');
      } catch (e) {
        error = e;
      }
      expect(error, isA<UnsupportedImageFormatException>());
      final message = (error! as UnsupportedImageFormatException).userMessage;
      expect(message, contains('IMG_1.HEIC'));
      expect(message, contains('HEIC'));
      expect(message, contains('Most Compatible'));
    });

    test('rejects files that are not photos', () async {
      expect(
        () => normalizeImageForUpload(
          Uint8List.fromList(utf8.encode('not an image')),
          fileName: 'notes.txt',
        ),
        throwsA(isA<UnsupportedImageFormatException>()),
      );
    });
  });
}
