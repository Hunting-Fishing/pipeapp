import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pipe_app/marketplace/marketplace_media_repository.dart';

void main() {
  test('retryable media failures preserve monotonic byte progress', () async {
    var attempts = 0;
    final progress = <MarketplaceMediaUploadProgress>[];
    final repository = MarketplaceMediaRepository(
      userIdProvider: () => 'seller-1',
      retryBaseDelay: Duration.zero,
      uploader: ({
        required path,
        required bytes,
        required contentType,
        required timeout,
        required onProgress,
      }) async {
        attempts++;
        onProgress(.4);
        if (attempts == 1) {
          throw FirebaseException(
            plugin: 'firebase_storage',
            code: 'retry-limit-exceeded',
          );
        }
        onProgress(1);
        return 'https://storage.example/$path';
      },
    );

    final result = await repository.upload(
      listingId: 'listing-1',
      photos: [
        XFile.fromData(
          Uint8List.fromList([1, 2, 3, 4]),
          name: 'pipe.jpg',
          mimeType: 'image/jpeg',
        ),
      ],
      onProgress: progress.add,
    );

    expect(attempts, 2);
    expect(result.imageUrls.single,
        'https://storage.example/listing_media/seller-1/listing-1/photo_1.jpg');
    expect(result.imageHashes.single, hasLength(64));
    expect(progress.any((value) => value.retrying), isTrue);
    expect(progress.last.overallProgress, 1);
    for (var index = 1; index < progress.length; index++) {
      expect(progress[index].overallProgress,
          greaterThanOrEqualTo(progress[index - 1].overallProgress));
    }
  });

  test('authorization failures stop without unsafe retries', () async {
    var attempts = 0;
    final repository = MarketplaceMediaRepository(
      userIdProvider: () => 'seller-1',
      retryBaseDelay: Duration.zero,
      uploader: ({
        required path,
        required bytes,
        required contentType,
        required timeout,
        required onProgress,
      }) async {
        attempts++;
        throw FirebaseException(
          plugin: 'firebase_storage',
          code: 'unauthorized',
        );
      },
    );

    await expectLater(
      repository.upload(
        listingId: 'listing-1',
        photos: [
          XFile.fromData(Uint8List.fromList([1]), name: 'private.jpg'),
        ],
      ),
      throwsA(
        isA<MarketplaceMediaUploadException>()
            .having((error) => error.code, 'code', 'unauthorized')
            .having((error) => error.userMessage, 'message',
                contains('not authorized')),
      ),
    );
    expect(attempts, 1);
  });

  test('upload revalidates photo size before reaching storage', () async {
    var uploaderCalled = false;
    final repository = MarketplaceMediaRepository(
      userIdProvider: () => 'seller-1',
      retryBaseDelay: Duration.zero,
      uploader: ({
        required path,
        required bytes,
        required contentType,
        required timeout,
        required onProgress,
      }) async {
        uploaderCalled = true;
        return 'https://storage.example/$path';
      },
    );

    await expectLater(
      repository.upload(
        listingId: 'listing-1',
        photos: [
          XFile.fromData(
            Uint8List(MarketplaceMediaRepository.maxPhotoBytes + 1),
            name: 'oversize.jpg',
          ),
        ],
      ),
      throwsA(
        isA<MarketplaceMediaUploadException>()
            .having((error) => error.code, 'code', 'photo-too-large'),
      ),
    );
    expect(uploaderCalled, isFalse);
  });
}
