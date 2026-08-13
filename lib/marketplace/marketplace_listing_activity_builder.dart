import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'marketplace_activity_presentation.dart';

typedef MarketplaceListingActivityWidgetBuilder = Widget Function(
  BuildContext context,
  MarketplaceListingActivityContext listing,
);

/// Uses the denormalized context on new activity documents and falls back to
/// the public listing for older conversations and notifications.
class MarketplaceListingActivityBuilder extends StatelessWidget {
  const MarketplaceListingActivityBuilder({
    super.key,
    required this.listingId,
    required this.embedded,
    required this.builder,
  });

  final String listingId;
  final Map<String, dynamic> embedded;
  final MarketplaceListingActivityWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final saved = MarketplaceListingActivityContext.fromMaps(
      embedded: embedded,
    );
    if (listingId.isEmpty || marketplaceHasEmbeddedListingContext(embedded)) {
      return builder(context, saved);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('public_listings')
          .doc(listingId)
          .snapshots(),
      builder: (context, snapshot) => builder(
        context,
        MarketplaceListingActivityContext.fromMaps(
          embedded: embedded,
          listing: snapshot.data?.data() ?? const {},
        ),
      ),
    );
  }
}

class MarketplaceListingActivityThumbnail extends StatelessWidget {
  const MarketplaceListingActivityThumbnail({
    super.key,
    required this.listing,
    required this.fallbackIcon,
    this.badgeIcon,
    this.size = 54,
  });

  final MarketplaceListingActivityContext listing;
  final IconData fallbackIcon;
  final IconData? badgeIcon;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: listing.thumbnailUrl == null
                ? Icon(fallbackIcon, color: const Color(0xFF0F5BB5))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      listing.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(fallbackIcon, color: const Color(0xFF0F5BB5)),
                    ),
                  ),
          ),
          if (badgeIcon != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: size * .19,
                backgroundColor: const Color(0xFF0878E8),
                child: Icon(badgeIcon, size: size * .21, color: Colors.white),
              ),
            ),
        ]),
      );
}
