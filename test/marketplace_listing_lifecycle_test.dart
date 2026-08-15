import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_listing_lifecycle.dart';

void main() {
  final now = DateTime.utc(2026, 8, 15, 12);

  test('active listing shows days remaining', () {
    final lifecycle = MarketplaceListingLifecycle.fromMap({
      'status': 'active',
      'expiresAt': now.add(const Duration(days: 12)),
    }, now: now);
    expect(lifecycle.expired, isFalse);
    expect(lifecycle.daysRemaining, 12);
    expect(lifecycle.expiringSoon, isFalse);
  });

  test('three-day window becomes expiring soon', () {
    final lifecycle = MarketplaceListingLifecycle.fromMap({
      'status': 'active',
      'expiresAt': now.add(const Duration(days: 2, hours: 2)),
    }, now: now);
    expect(lifecycle.expired, isFalse);
    expect(lifecycle.expiringSoon, isTrue);
    expect(lifecycle.daysRemaining, 3);
  });

  test('expired status remains explicit', () {
    final lifecycle = MarketplaceListingLifecycle.fromMap({
      'status': 'expired',
      'renewalCount': 2,
    }, now: now);
    expect(lifecycle.expired, isTrue);
    expect(lifecycle.renewalCount, 2);
    expect(lifecycle.ownerLabel, contains('Expired'));
  });
}
