import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

const Color _ownerBlue = PipeBuyerColors.industrialBlue;
const Color _offerOrange = PipeBuyerColors.orange;
const Color _priceGreen = PipeBuyerColors.success;
const Color _newTeal = Color(0xFF008C95);
const Color _urgentRed = PipeBuyerColors.danger;
const Color _wantedPurple = Color(0xFF7C3AED);
const Color _neutralBorder = Color(0xFFD8E0E9);
const Color _imageBadgeSurface = Color(0xE6111820);

class MarketplaceListingBadge {
  const MarketplaceListingBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class MarketplaceListingPresentation {
  const MarketplaceListingPresentation({
    required this.borderColor,
    required this.badges,
    this.emphasized = false,
  });

  final Color borderColor;
  final List<MarketplaceListingBadge> badges;
  final bool emphasized;

  Color get shadowColor =>
      emphasized ? borderColor.withValues(alpha: .20) : Colors.transparent;

  static MarketplaceListingPresentation fromMap(
    Map<String, dynamic> data, {
    String? currentUserUid,
    bool isAuction = false,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final sellerUid = '${data['sellerUid'] ?? ''}';
    final isOwner = currentUserUid != null &&
        currentUserUid.isNotEmpty &&
        sellerUid == currentUserUid;
    final saleStatus =
        '${data['saleStatus'] ?? data['offerStatus'] ?? ''}'.toLowerCase();
    final acceptedOfferId = '${data['acceptedOfferId'] ?? ''}';
    final pendingSale = acceptedOfferId.isNotEmpty ||
        saleStatus == 'pending' ||
        saleStatus == 'pending_sale' ||
        saleStatus == 'accepted';
    final activityCount = _intValue(isAuction
        ? data['bidCount']
        : data['pendingOfferCount'] ?? data['offerCount']);
    final currentPrice = _numberValue(data['price']);
    final previousPrice = _firstNumber(data, const [
      'previousPrice',
      'originalPrice',
      'initialPrice',
      'priceBeforeReduction',
    ]);
    final priceWasReduced = !isAuction &&
        currentPrice != null &&
        previousPrice != null &&
        previousPrice > 0 &&
        currentPrice < previousPrice;
    final priceDropPercent = priceWasReduced
        ? ((previousPrice - currentPrice) / previousPrice * 100)
        : 0.0;
    final createdAt = _dateValue(data['createdAt']);
    final isNew = createdAt != null &&
        !createdAt.isAfter(clock) &&
        clock.difference(createdAt).inDays < 7;
    final auctionEnd = _dateValue(data['auctionEndAt']);
    final endsSoon = isAuction &&
        auctionEnd != null &&
        auctionEnd.isAfter(clock) &&
        auctionEnd.difference(clock) <= const Duration(hours: 24);
    final transactionType = '${data['transactionType'] ?? ''}'.toLowerCase();
    final isWanted = transactionType == 'wanted / seeking' ||
        transactionType == 'wanted' ||
        transactionType.contains('seeking');
    final boosted = '${data['boostStatus'] ?? ''}'.toLowerCase() == 'active';
    final verifiedSeller = data['sellerVerified'] == true;

    // Ordering is intentional. On compact image cards only the first few
    // signals are visible, so transactional and trust state comes before
    // promotional/newness signals.
    final badges = <MarketplaceListingBadge>[
      if (isOwner)
        const MarketplaceListingBadge(
          label: 'Your listing',
          icon: Icons.admin_panel_settings_outlined,
          color: _ownerBlue,
        ),
      if (isWanted)
        const MarketplaceListingBadge(
          label: 'Wanted',
          icon: Icons.search_rounded,
          color: _wantedPurple,
        ),
      if (pendingSale)
        const MarketplaceListingBadge(
          label: 'Pending sale',
          icon: Icons.handshake_outlined,
          color: _offerOrange,
        )
      else if (activityCount > 0)
        MarketplaceListingBadge(
          label: isAuction
              ? '$activityCount ${activityCount == 1 ? 'bid' : 'bids'}'
              : '$activityCount ${activityCount == 1 ? 'offer' : 'offers'}',
          icon: isAuction ? Icons.gavel : Icons.local_offer_outlined,
          color: _offerOrange,
        ),
      if (endsSoon)
        const MarketplaceListingBadge(
          label: 'Ends soon',
          icon: Icons.timer_outlined,
          color: _urgentRed,
        ),
      if (verifiedSeller)
        const MarketplaceListingBadge(
          label: 'Verified seller',
          icon: Icons.verified_outlined,
          color: PipeBuyerColors.success,
        ),
      if (priceWasReduced)
        MarketplaceListingBadge(
          label:
              '↓ ${priceDropPercent < 1 ? priceDropPercent.toStringAsFixed(1) : priceDropPercent.toStringAsFixed(0)}% price drop',
          icon: Icons.trending_down,
          color: _priceGreen,
        ),
      if (boosted)
        const MarketplaceListingBadge(
          label: 'Boosted',
          icon: Icons.bolt_rounded,
          color: PipeBuyerColors.orange,
        ),
      if (isNew)
        const MarketplaceListingBadge(
          label: 'New',
          icon: Icons.auto_awesome_outlined,
          color: _newTeal,
        ),
    ];

    final primary = isOwner
        ? _ownerBlue
        : isWanted
            ? _wantedPurple
            : pendingSale
                ? _offerOrange
                : endsSoon
                    ? _urgentRed
                    : priceWasReduced
                        ? _priceGreen
                        : activityCount > 0 || boosted
                            ? _offerOrange
                            : verifiedSeller
                                ? PipeBuyerColors.success
                                : isNew
                                    ? _newTeal
                                    : _neutralBorder;
    return MarketplaceListingPresentation(
      borderColor: primary,
      badges: badges,
      emphasized: badges.isNotEmpty,
    );
  }
}

class MarketplaceListingBadges extends StatelessWidget {
  const MarketplaceListingBadges({
    super.key,
    required this.badges,
    this.compact = false,
    this.maxVisible,
  });

  final List<MarketplaceListingBadge> badges;
  final bool compact;
  final int? maxVisible;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    final limit = (maxVisible ?? (compact ? 3 : 6)).clamp(1, badges.length);
    final visible = badges.take(limit).toList(growable: false);
    final hidden = badges.length - visible.length;

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        ...visible.map((badge) => _BadgePill(badge: badge, compact: compact)),
        if (hidden > 0) _OverflowBadge(hidden: hidden, compact: compact),
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.badge, required this.compact});

  final MarketplaceListingBadge badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = compact ? Colors.white : badge.color;
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: compact
            ? _imageBadgeSurface
            : badge.color.withValues(alpha: .085),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: compact
              ? badge.color.withValues(alpha: .82)
              : badge.color.withValues(alpha: .28),
          width: compact ? 1.1 : .9,
        ),
        boxShadow: compact
            ? const [
                BoxShadow(
                  color: Color(0x30000000),
                  blurRadius: 7,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 15 : 17,
            height: compact ? 15 : 17,
            decoration: BoxDecoration(
              color: compact
                  ? badge.color.withValues(alpha: .95)
                  : badge.color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              badge.icon,
              size: compact ? 10 : 11,
              color: compact ? Colors.white : badge.color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            badge.label,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 9.5 : 10.5,
              letterSpacing: compact ? .12 : 0,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverflowBadge extends StatelessWidget {
  const _OverflowBadge({required this.hidden, required this.compact});

  final int hidden;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 9,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: compact
              ? _imageBadgeSurface
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: .78),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: compact ? Colors.white38 : Theme.of(context).dividerColor,
          ),
          boxShadow: compact
              ? const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          '+$hidden',
          style: TextStyle(
            color: compact
                ? Colors.white
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: .70),
            fontSize: compact ? 9.5 : 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

Future<void> showMarketplaceListingLegend(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 40,
                      child: Icon(
                        Icons.layers_outlined,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Listing signals',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Fast visual cues for trust, offers, pricing and urgency.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Signals summarize marketplace activity. Always open the listing for the full details and current transaction state.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .64),
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 18),
            ...const [
              MarketplaceListingBadge(
                label: 'Your listing',
                icon: Icons.admin_panel_settings_outlined,
                color: _ownerBlue,
              ),
              MarketplaceListingBadge(
                label: 'Wanted / seeking inventory',
                icon: Icons.search_rounded,
                color: _wantedPurple,
              ),
              MarketplaceListingBadge(
                label: 'Offers, bids, or pending sale',
                icon: Icons.handshake_outlined,
                color: _offerOrange,
              ),
              MarketplaceListingBadge(
                label: 'Auction ending soon',
                icon: Icons.timer_outlined,
                color: _urgentRed,
              ),
              MarketplaceListingBadge(
                label: 'Verified seller',
                icon: Icons.verified_outlined,
                color: PipeBuyerColors.success,
              ),
              MarketplaceListingBadge(
                label: 'Price reduced',
                icon: Icons.trending_down,
                color: _priceGreen,
              ),
              MarketplaceListingBadge(
                label: 'Boosted visibility',
                icon: Icons.bolt_rounded,
                color: PipeBuyerColors.orange,
              ),
              MarketplaceListingBadge(
                label: 'New listing',
                icon: Icons.auto_awesome_outlined,
                color: _newTeal,
              ),
            ].map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: .055),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: item.color.withValues(alpha: .18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(item.icon, color: item.color, size: 21),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

int _intValue(dynamic value) => (value as num?)?.toInt() ?? 0;

num? _numberValue(dynamic value) {
  if (value is num) return value;
  return num.tryParse('${value ?? ''}'.replaceAll(RegExp(r'[^0-9.-]'), ''));
}

num? _firstNumber(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = _numberValue(data[key]);
    if (value != null) return value;
  }
  return null;
}

DateTime? _dateValue(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
