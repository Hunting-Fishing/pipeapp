import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const Color _ownerBlue = Color(0xFF0878E8);
const Color _offerOrange = Color(0xFFF08A00);
const Color _priceGreen = Color(0xFF0B9F67);
const Color _newTeal = Color(0xFF008C95);
const Color _urgentRed = Color(0xFFD94040);
const Color _neutralBorder = Color(0xFFD8E0E9);

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

    final badges = <MarketplaceListingBadge>[
      if (isOwner)
        const MarketplaceListingBadge(
            label: 'Your listing',
            icon: Icons.admin_panel_settings_outlined,
            color: _ownerBlue),
      if (pendingSale)
        const MarketplaceListingBadge(
            label: 'Pending sale',
            icon: Icons.handshake_outlined,
            color: _offerOrange)
      else if (activityCount > 0)
        MarketplaceListingBadge(
            label: isAuction
                ? '$activityCount ${activityCount == 1 ? 'bid' : 'bids'}'
                : '$activityCount ${activityCount == 1 ? 'offer' : 'offers'}',
            icon: isAuction ? Icons.gavel : Icons.local_offer_outlined,
            color: _offerOrange),
      if (priceWasReduced)
        MarketplaceListingBadge(
            label:
                '↓ ${priceDropPercent < 1 ? priceDropPercent.toStringAsFixed(1) : priceDropPercent.toStringAsFixed(0)}% price drop',
            icon: Icons.trending_down,
            color: _priceGreen),
      if (isNew)
        const MarketplaceListingBadge(
            label: 'New', icon: Icons.auto_awesome_outlined, color: _newTeal),
      if (endsSoon)
        const MarketplaceListingBadge(
            label: 'Ends soon', icon: Icons.timer_outlined, color: _urgentRed),
    ];

    final primary = isOwner
        ? _ownerBlue
        : pendingSale
            ? _offerOrange
            : priceWasReduced
                ? _priceGreen
                : activityCount > 0
                    ? _offerOrange
                    : endsSoon
                        ? _urgentRed
                        : isNew
                            ? _newTeal
                            : _neutralBorder;
    return MarketplaceListingPresentation(
        borderColor: primary, badges: badges, emphasized: badges.isNotEmpty);
  }
}

class MarketplaceListingBadges extends StatelessWidget {
  const MarketplaceListingBadges({
    super.key,
    required this.badges,
    this.compact = false,
  });

  final List<MarketplaceListingBadge> badges;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: badges
          .map((badge) => Container(
                padding: EdgeInsets.symmetric(
                    horizontal: compact ? 7 : 9, vertical: compact ? 3 : 4),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: badge.color.withValues(alpha: .52), width: .8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(badge.icon, size: compact ? 12 : 14, color: badge.color),
                  const SizedBox(width: 4),
                  Text(badge.label,
                      style: TextStyle(
                          color: badge.color,
                          fontSize: compact ? 9.5 : 10.5,
                          fontWeight: FontWeight.w800)),
                ]),
              ))
          .toList(),
    );
  }
}

Future<void> showMarketplaceListingLegend(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Listing color key',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Borders make important listing activity easier to recognize. A card can show more than one badge.',
                  style: TextStyle(color: Color(0xFF66758A))),
            ),
            const SizedBox(height: 16),
            ...const [
              MarketplaceListingBadge(
                  label: 'Your listing',
                  icon: Icons.admin_panel_settings_outlined,
                  color: _ownerBlue),
              MarketplaceListingBadge(
                  label: 'Offers, bids, or pending sale',
                  icon: Icons.handshake_outlined,
                  color: _offerOrange),
              MarketplaceListingBadge(
                  label: 'Price reduced',
                  icon: Icons.trending_down,
                  color: _priceGreen),
              MarketplaceListingBadge(
                  label: 'New listing',
                  icon: Icons.auto_awesome_outlined,
                  color: _newTeal),
              MarketplaceListingBadge(
                  label: 'Auction ending soon',
                  icon: Icons.timer_outlined,
                  color: _urgentRed),
            ].map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(children: [
                    Container(
                        width: 6,
                        height: 34,
                        decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(6))),
                    const SizedBox(width: 10),
                    Icon(item.icon, color: item.color, size: 21),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(item.label,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                )),
          ]),
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
