import 'package:cloud_firestore/cloud_firestore.dart';

import 'marketplace_listing_media.dart';
import 'marketplace_money.dart';

/// Public listing context used to make private activity feeds understandable.
///
/// Offer terms are deliberately absent. Those remain in the participant-only
/// `offers` collection and are displayed separately only to the buyer/seller.
class MarketplaceListingActivityContext {
  const MarketplaceListingActivityContext({
    required this.title,
    required this.thumbnailUrl,
    required this.quantity,
    required this.price,
    required this.priceBasis,
    required this.category,
    required this.sellerName,
  });

  factory MarketplaceListingActivityContext.fromMaps({
    required Map<String, dynamic> embedded,
    Map<String, dynamic> listing = const {},
  }) {
    T? value<T>(String listingField, String embeddedField) {
      final current = listing[listingField];
      if (current is T) return current;
      final saved = embedded[embeddedField];
      return saved is T ? saved : null;
    }

    String text(String listingField, String embeddedField) =>
        '${listing[listingField] ?? embedded[embeddedField] ?? ''}'.trim();

    final liveThumbnail = marketplaceListingThumbnailUrl(listing);
    final embeddedThumbnail = '${embedded['listingThumbnailUrl'] ?? ''}'.trim();
    return MarketplaceListingActivityContext(
      title: text('title', 'listingTitle'),
      thumbnailUrl: liveThumbnail ??
          (embeddedThumbnail.isEmpty ? null : embeddedThumbnail),
      quantity: value<num>('quantity', 'listingQuantity')?.toInt(),
      price: value<num>('price', 'listingPrice'),
      priceBasis: text('priceBasis', 'listingPriceBasis'),
      category: text('category', 'listingCategory'),
      sellerName: text('sellerName', 'listingSellerName'),
    );
  }

  final String title;
  final String? thumbnailUrl;
  final int? quantity;
  final num? price;
  final String priceBasis;
  final String category;
  final String sellerName;

  bool get hasListing => title.isNotEmpty;

  String get commerceLine {
    final parts = <String>[];
    if (quantity != null && quantity! > 0) {
      parts.add('$quantity ${quantity == 1 ? 'piece' : 'pieces'}');
    }
    if (price != null && price! >= 0) {
      parts.add(marketplaceMoney(price!));
    } else if (priceBasis.toLowerCase() == 'call for price') {
      parts.add('Call for price');
    }
    if (priceBasis.isNotEmpty && priceBasis.toLowerCase() != 'call for price') {
      parts.add(priceBasis);
    }
    return parts.join(' • ');
  }
}

bool marketplaceHasEmbeddedListingContext(Map<String, dynamic> data) =>
    (data['listingContextVersion'] as num?)?.toInt() == 1;

String marketplaceActivityTypeLabel(Map<String, dynamic> data) {
  final type = '${data['type'] ?? ''}'.trim().toLowerCase();
  return switch (type) {
    'message' => 'Message',
    'offer' => 'Offer',
    'dispatch' || 'dispatch_signup' || 'dispatch_provider_signup' => 'Dispatch',
    'auction' || 'bid' => 'Auction',
    'new_listing_match' ||
    'seller_new_listing' ||
    'wanted_match' =>
      'Marketplace match',
    'score_change' => 'Account standing',
    'device' || 'device_remembered' => 'Account security',
    'catalog_suggestion' => 'Catalog suggestion',
    _ => 'Pipe Buyer activity',
  };
}

String marketplaceNotificationBody(
  Map<String, dynamic> data,
  MarketplaceListingActivityContext listing,
) {
  final body = '${data['body'] ?? data['message'] ?? ''}'.trim();
  if (body.isNotEmpty) return body;
  final title = listing.title.isEmpty ? 'this listing' : listing.title;
  return switch ('${data['type'] ?? ''}'.trim().toLowerCase()) {
    'message' => 'A marketplace member sent you a message about $title.',
    'offer' => 'Open $title to review the private offer details.',
    'new_listing_match' ||
    'seller_new_listing' ||
    'wanted_match' =>
      'A new marketplace match is available for $title.',
    'device' ||
    'device_remembered' =>
      'Review this recent account-security activity.',
    _ => 'Open this update for more information.',
  };
}

String marketplaceActivityTime(Object? value, {DateTime? now}) {
  final date = switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),
    _ => null,
  };
  if (date == null) return '';
  final current = now ?? DateTime.now();
  final difference = current.difference(date);
  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes} min ago';
  if (difference.inDays < 1) return '${difference.inHours} hr ago';
  if (difference.inDays < 7) {
    return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
  }
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String marketplaceGreetingName({
  required Map<String, dynamic> account,
  Map<String, dynamic> publicBusiness = const {},
  Map<String, dynamic> publicSeller = const {},
  String? authDisplayName,
  String? email,
}) {
  final candidates = <Object?>[
    publicBusiness['publicName'],
    account['businessName'],
    account['display_name'],
    account['displayName'],
    account['fullName'],
    account['name'],
    publicSeller['displayName'],
    authDisplayName,
    email?.split('@').first,
  ];
  return candidates
      .map((value) => '${value ?? ''}'.trim())
      .firstWhere((value) => value.isNotEmpty, orElse: () => 'there');
}

/// Returns the highest current buyer-proposed total for a seller listing.
///
/// Only call this with participant-authorized offer documents. Public listing
/// screens must continue to show only the aggregate offer count.
num? marketplaceBestSellerOfferTotal(
  Iterable<Map<String, dynamic>> offers,
) {
  final latestByBuyer = <String, Map<String, dynamic>>{};
  for (final offer in offers) {
    final status = '${offer['status'] ?? ''}'.trim().toLowerCase();
    if (const {'archived', 'cancelled', 'declined', 'expired'}
        .contains(status)) {
      continue;
    }
    final buyerUid = '${offer['buyerUid'] ?? ''}'.trim();
    if (buyerUid.isEmpty || '${offer['proposedByUid'] ?? ''}' != buyerUid) {
      continue;
    }
    final previous = latestByBuyer[buyerUid];
    if (previous == null ||
        _activityMillis(offer['createdAt']) >
            _activityMillis(previous['createdAt'])) {
      latestByBuyer[buyerUid] = offer;
    }
  }
  num? best;
  for (final offer in latestByBuyer.values) {
    final total = offer['offeredTotal'] as num?;
    if (total != null && total >= 0 && (best == null || total > best)) {
      best = total;
    }
  }
  return best;
}

int _activityMillis(Object? value) => switch (value) {
      Timestamp timestamp => timestamp.millisecondsSinceEpoch,
      DateTime date => date.millisecondsSinceEpoch,
      int milliseconds => milliseconds,
      _ => 0,
    };
