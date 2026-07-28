import 'package:flutter/foundation.dart';

/// Stable, shareable routes for Phase 1 Marketplace entities.
///
/// IDs are encoded as path segments so links remain safe when Firebase
/// document identifiers contain spaces or other URL-sensitive characters.
class MarketplaceDeepLinks {
  MarketplaceDeepLinks._();

  static const listingRouteName = 'marketplace-listing';
  static const auctionRouteName = 'marketplace-auction';
  static const profileRouteName = 'marketplace-profile';
  static const conversationRouteName = 'marketplace-conversation';
  static const dispatchJobRouteName = 'dispatch-job';
  static const privacyRouteName = 'public-privacy';
  static const termsRouteName = 'public-terms';
  static const supportRouteName = 'public-support';
  static const accountDeletionRouteName = 'public-account-deletion';

  static const privacyPath = '/privacy';
  static const termsPath = '/terms';
  static const supportPath = '/support';
  static const accountDeletionPath = '/account-deletion';

  static String listing(String listingId) =>
      '/listings/${Uri.encodeComponent(_requiredId(listingId))}';

  static String auction(String listingId) =>
      '/auctions/${Uri.encodeComponent(_requiredId(listingId))}';

  static String profile(String userUid) =>
      '/profiles/${Uri.encodeComponent(_requiredId(userUid))}';

  static String conversation(String conversationId) =>
      '/conversations/${Uri.encodeComponent(_requiredId(conversationId))}';

  static String dispatchJob(String jobId) =>
      '/dispatch/jobs/${Uri.encodeComponent(_requiredId(jobId))}';

  /// Produces a complete browser URL on web and a stable app route on native.
  /// Native universal-link domains are intentionally not invented here; they
  /// must be configured and approved as part of the release environment.
  static String shareTarget(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    if (!kIsWeb) return normalized;
    final base = Uri.base;
    return base
        .replace(path: normalized, query: null, fragment: null)
        .toString();
  }

  static String _requiredId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.length > 256 ||
        normalized.contains('/')) {
      throw ArgumentError.value(
          value, 'value', 'A valid entity identifier is required.');
    }
    return normalized;
  }
}
