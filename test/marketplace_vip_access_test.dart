import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_vip_access.dart';

void main() {
  final now = DateTime.utc(2026, 8, 14, 12);

  test('flagged new listings receive a 24 hour VIP window', () {
    final listing = <String, dynamic>{
      'vipEarlyAccessEnabled': true,
      'publishedAt': Timestamp.fromDate(now),
      'sellerUid': 'seller-1',
    };
    expect(
      marketplaceVipEarlyAccessUntil(listing),
      now.add(const Duration(hours: 24)),
    );
  });

  test('existing unflagged listings remain public', () {
    final listing = <String, dynamic>{
      'createdAt': Timestamp.fromDate(now),
      'sellerUid': 'seller-1',
    };
    expect(marketplaceVipEarlyAccessUntil(listing), isNull);
  });

  test('standard viewer is locked while VIP viewer and seller are not', () {
    final listing = <String, dynamic>{
      'sellerUid': 'seller-1',
      'vipEarlyAccessEnabled': true,
      'vipEarlyAccessUntil': Timestamp.fromDate(now.add(const Duration(hours: 8))),
    };
    final standard = <String, dynamic>{
      'membershipTier': 'standard',
      'vipActive': false,
    };
    final vip = <String, dynamic>{
      'membershipTier': 'vip',
      'vipActive': true,
      'vipStatus': 'active',
      'vipExpiresAt': Timestamp.fromDate(now.add(const Duration(days: 10))),
    };

    expect(
      marketplaceListingLockedForViewer(
        listing: listing,
        viewerProfile: standard,
        viewerUid: 'buyer-1',
        now: now,
      ),
      isTrue,
    );
    expect(
      marketplaceListingLockedForViewer(
        listing: listing,
        viewerProfile: vip,
        viewerUid: 'buyer-1',
        now: now,
      ),
      isFalse,
    );
    expect(
      marketplaceListingLockedForViewer(
        listing: listing,
        viewerProfile: standard,
        viewerUid: 'seller-1',
        now: now,
      ),
      isFalse,
    );
  });

  test('listing automatically unlocks after early access expires', () {
    final listing = <String, dynamic>{
      'sellerUid': 'seller-1',
      'vipEarlyAccessEnabled': true,
      'vipEarlyAccessUntil': Timestamp.fromDate(now.subtract(const Duration(minutes: 1))),
    };
    expect(
      marketplaceListingLockedForViewer(
        listing: listing,
        viewerProfile: const {'membershipTier': 'standard'},
        viewerUid: 'buyer-1',
        now: now,
      ),
      isFalse,
    );
  });

  test('VIP expiry is honored', () {
    expect(
      marketplaceVipActive({
        'vipActive': true,
        'vipStatus': 'active',
        'vipExpiresAt': Timestamp.fromDate(now.subtract(const Duration(seconds: 1))),
      }, now: now),
      isFalse,
    );
  });

  test('countdown is concise for teaser cards', () {
    expect(
      marketplaceVipCountdown(const Duration(hours: 5, minutes: 7)),
      '5h 07m',
    );
    expect(
      marketplaceVipCountdown(const Duration(minutes: 7, seconds: 3)),
      '7m 03s',
    );
  });
}
