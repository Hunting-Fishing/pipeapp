import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:pipe_app/marketplace/marketplace_media_repository.dart';

class _Upload {
  _Upload(this.path, this.contentType, this.length);

  final String path;
  final String contentType;
  final int length;
}

MarketplaceMediaRepository _repository(List<_Upload> uploads) {
  return MarketplaceMediaRepository(
    userIdProvider: () => 'seller-1',
    retryBaseDelay: Duration.zero,
    uploader: ({
      required path,
      required bytes,
      required contentType,
      required timeout,
      required onProgress,
    }) async {
      uploads.add(_Upload(path, contentType, bytes.length));
      return 'https://storage.example/$path';
    },
  );
}

img.Image _sample() {
  final image = img.Image(width: 120, height: 80);
  img.fill(image, color: img.ColorRgb8(30, 120, 200));
  return image;
}

void main() {
  group('phone photo formats', () {
    test('a GIF or BMP is converted and stored as a real JPEG', () async {
      for (final entry in <String, Uint8List>{
        'phone.gif': img.encodeGif(_sample()),
        'phone.bmp': img.encodeBmp(_sample()),
      }.entries) {
        final uploads = <_Upload>[];
        final result = await _repository(uploads).upload(
          listingId: 'listing-1',
          photos: [XFile.fromData(entry.value, name: entry.key)],
        );
        expect(uploads.single.path,
            'listing_media/seller-1/listing-1/photo_1.jpg', reason: entry.key);
        expect(uploads.single.contentType, 'image/jpeg', reason: entry.key);
        expect(result.imageHashes.single, hasLength(64));
      }
    });

    test('a normal PNG keeps its type', () async {
      final uploads = <_Upload>[];
      await _repository(uploads).upload(
        listingId: 'listing-1',
        photos: [XFile.fromData(img.encodePng(_sample()), name: 'shot.png')],
      );
      expect(uploads.single.path, endsWith('photo_1.png'));
      expect(uploads.single.contentType, 'image/png');
    });

    test('the real format wins over a wrong file name', () async {
      final uploads = <_Upload>[];
      await _repository(uploads).upload(
        listingId: 'listing-1',
        photos: [
          XFile.fromData(img.encodeGif(_sample()), name: 'IMG_0001.JPG'),
        ],
      );
      expect(uploads.single.path, endsWith('photo_1.jpg'));
      expect(uploads.single.contentType, 'image/jpeg');
    });

    test('a file that is not a photo is refused before any upload', () async {
      final uploads = <_Upload>[];
      await expectLater(
        _repository(uploads).upload(
          listingId: 'listing-1',
          photos: [
            XFile.fromData(Uint8List.fromList([9, 9, 9, 9, 9]), name: 'x.jpg'),
          ],
        ),
        throwsA(
          isA<MarketplaceMediaUploadException>()
              .having((e) => e.code, 'code', 'unsupported-photo-format'),
        ),
      );
      expect(uploads, isEmpty);
    });

    test('the picker accepts raw phone photos far larger than the stored size', () {
      expect(MarketplaceMediaRepository.maxRawPhotoBytes,
          greaterThan(MarketplaceMediaRepository.maxPhotoBytes * 4));
    });
  });

  group('phone video formats', () {
    test('every phone container is accepted and labelled correctly', () async {
      const expected = {
        'mp4': 'video/mp4',
        'mov': 'video/quicktime',
        'm4v': 'video/x-m4v',
        '3gp': 'video/3gpp',
        '3g2': 'video/3gpp2',
        'webm': 'video/webm',
      };
      expect(MarketplaceMediaRepository.videoExtensions, expected.keys.toSet());
      for (final entry in expected.entries) {
        final uploads = <_Upload>[];
        final result = await _repository(uploads).upload(
          listingId: 'listing-1',
          photos: const [],
          video: XFile.fromData(
            Uint8List.fromList(List<int>.filled(32, 7)),
            name: 'walkaround.${entry.key.toUpperCase()}',
          ),
        );
        expect(uploads.single.path,
            'listing_media/seller-1/listing-1/video.${entry.key}');
        expect(uploads.single.contentType, entry.value);
        expect(result.videoUrl, isNotNull);
      }
    });

    test('a video format phones do not produce is refused before upload', () async {
      final uploads = <_Upload>[];
      await expectLater(
        _repository(uploads).upload(
          listingId: 'listing-1',
          photos: const [],
          video: XFile.fromData(Uint8List(16), name: 'clip.avi'),
        ),
        throwsA(
          isA<MarketplaceMediaUploadException>()
              .having((e) => e.code, 'code', 'unsupported-video-format'),
        ),
      );
      expect(uploads, isEmpty);
    });

    test('the video limit is 100 MB', () async {
      expect(MarketplaceMediaRepository.maxVideoBytes, 100 * 1024 * 1024);
      final uploads = <_Upload>[];
      await expectLater(
        _repository(uploads).upload(
          listingId: 'listing-1',
          photos: const [],
          video: XFile.fromData(
            Uint8List(MarketplaceMediaRepository.maxVideoBytes + 1),
            name: 'long.mp4',
          ),
        ),
        throwsA(
          isA<MarketplaceMediaUploadException>()
              .having((e) => e.code, 'code', 'video-too-large')
              .having((e) => e.userMessage, 'message', contains('100 MB')),
        ),
      );
      expect(uploads, isEmpty);
    });
  });
}
