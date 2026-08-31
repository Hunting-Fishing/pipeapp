import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_dispatch_subscription_checkout.dart';
import 'marketplace_vip_subscription_checkout.dart';

const marketplaceVipEarlyAccessDuration = Duration(hours: 24);

DateTime? marketplaceAccessDate(dynamic value) {
  final parsed = switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    int milliseconds => DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
      isUtc: true,
    ),
    String text => DateTime.tryParse(text),
    _ => null,
  };
  return parsed?.toUtc();
}

DateTime? marketplaceVipEarlyAccessUntil(Map<String, dynamic> listing) {
  final explicit = marketplaceAccessDate(listing['vipEarlyAccessUntil']);
  if (explicit != null) return explicit;
  if (listing['vipEarlyAccessEnabled'] != true) return null;
  final published =
      marketplaceAccessDate(listing['publishedAt']) ??
      marketplaceAccessDate(listing['createdAt']);
  return published?.add(marketplaceVipEarlyAccessDuration);
}

bool marketplaceVipActive(Map<String, dynamic>? profile, {DateTime? now}) {
  if (profile == null) return false;
  final current = now ?? DateTime.now();
  final nested = profile['membership'] is Map
      ? Map<String, dynamic>.from(profile['membership'] as Map)
      : const <String, dynamic>{};
  final tier =
      '${profile['membershipTier'] ?? profile['subscriptionTier'] ?? nested['tier'] ?? ''}'
          .trim()
          .toLowerCase();
  final status =
      '${profile['vipStatus'] ?? profile['subscriptionStatus'] ?? nested['status'] ?? ''}'
          .trim()
          .toLowerCase();
  final activeFlag =
      profile['vipActive'] == true || profile['isVip'] == true || tier == 'vip';
  if (!activeFlag) return false;
  if (status.isNotEmpty &&
      !const {'active', 'trialing', 'vip'}.contains(status)) {
    return false;
  }
  final expires =
      marketplaceAccessDate(profile['vipExpiresAt']) ??
      marketplaceAccessDate(profile['vipUntil']) ??
      marketplaceAccessDate(nested['expiresAt']);
  return expires == null || expires.isAfter(current);
}

bool marketplaceListingLockedForViewer({
  required Map<String, dynamic> listing,
  required Map<String, dynamic>? viewerProfile,
  String viewerUid = '',
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final sellerUid = '${listing['sellerUid'] ?? listing['ownerUid'] ?? ''}'
      .trim();
  if (viewerUid.isNotEmpty && viewerUid == sellerUid) return false;
  if (marketplaceVipActive(viewerProfile, now: current)) return false;
  final until = marketplaceVipEarlyAccessUntil(listing);
  return until != null && until.isAfter(current);
}

Duration marketplaceVipEarlyAccessRemaining(
  Map<String, dynamic> listing, {
  DateTime? now,
}) {
  final until = marketplaceVipEarlyAccessUntil(listing);
  if (until == null) return Duration.zero;
  final remaining = until.difference(now ?? DateTime.now());
  return remaining.isNegative ? Duration.zero : remaining;
}

String marketplaceVipCountdown(Duration duration) {
  if (duration <= Duration.zero) return 'Available now';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
}

class MarketplaceVipEarlyAccessGate extends StatelessWidget {
  const MarketplaceVipEarlyAccessGate({
    super.key,
    required this.listing,
    required this.child,
    this.onUpgrade,
  });

  final Map<String, dynamic> listing;
  final Widget child;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    if (marketplaceVipEarlyAccessUntil(listing) == null) return child;
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    if (user != null && '${listing['sellerUid'] ?? ''}' == user.uid) {
      return child;
    }
    if (user == null) {
      return _MarketplaceVipGateBody(
        listing: listing,
        locked: marketplaceListingLockedForViewer(
          listing: listing,
          viewerProfile: null,
        ),
        onUpgrade: onUpgrade,
        child: child,
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data();
        return _MarketplaceVipGateBody(
          listing: listing,
          locked: marketplaceListingLockedForViewer(
            listing: listing,
            viewerProfile: profile,
            viewerUid: user.uid,
          ),
          onUpgrade: onUpgrade,
          child: child,
        );
      },
    );
  }
}

class _MarketplaceVipGateBody extends StatefulWidget {
  const _MarketplaceVipGateBody({
    required this.listing,
    required this.locked,
    required this.child,
    this.onUpgrade,
  });

  final Map<String, dynamic> listing;
  final bool locked;
  final Widget child;
  final VoidCallback? onUpgrade;

  @override
  State<_MarketplaceVipGateBody> createState() =>
      _MarketplaceVipGateBodyState();
}

class _MarketplaceVipGateBodyState extends State<_MarketplaceVipGateBody> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _MarketplaceVipGateBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locked != widget.locked ||
        oldWidget.listing != widget.listing) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    if (!widget.locked) return;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = marketplaceVipEarlyAccessRemaining(widget.listing);
    if (!widget.locked || remaining <= Duration.zero) return widget.child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x6B0D1117), Color(0xE80D1117)],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xF2181E26),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: PipeBuyerColors.orange.withValues(alpha: .72),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x52000000),
                          blurRadius: 16,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFFFC44D),
                          size: 30,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'VIP EARLY ACCESS',
                          style: TextStyle(
                            color: Color(0xFFFFC44D),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'VIP members see new listings 24 hours early',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Public in ${marketplaceVipCountdown(remaining)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              if (widget.onUpgrade != null) {
                                widget.onUpgrade!();
                                return;
                              }
                              showDialog<void>(
                                context: context,
                                builder: (_) =>
                                    const MarketplaceSubscriptionPlansDialog(),
                              );
                            },
                            icon: const Icon(Icons.lock_open_rounded),
                            label: const Text('Unlock with VIP'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MarketplaceSubscriptionPlansDialog extends StatefulWidget {
  const MarketplaceSubscriptionPlansDialog({super.key});

  @override
  State<MarketplaceSubscriptionPlansDialog> createState() =>
      _MarketplaceSubscriptionPlansDialogState();
}

class _MarketplaceSubscriptionPlansDialogState
    extends State<MarketplaceSubscriptionPlansDialog> {
  String _selectedPlan = 'monthly';

  void _selectPlan(String plan) {
    if (_selectedPlan == plan) return;
    setState(() => _selectedPlan = plan);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920, maxHeight: 760),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pipe Buyer memberships',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Select a plan to see its full details, promo code entry and secure checkout.',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final cards = [
                  _SubscriptionPlanCard(
                    planKey: 'vip',
                    title: 'VIP Membership',
                    eyebrow: 'MARKETPLACE PRIORITY',
                    artworkAsset:
                        'assets/images/membership_vip_subscription.svg',
                    icon: Icons.workspace_premium_rounded,
                    premium: true,
                    selected: _selectedPlan == 'vip',
                    onTap: () => _selectPlan('vip'),
                    benefits: const [
                      '24-hour early access to every newly published listing',
                      'Locked-listing countdowns show when inventory opens publicly',
                      'Priority marketplace alerts and enhanced offer intelligence foundation',
                    ],
                  ),
                  _SubscriptionPlanCard(
                    planKey: 'monthly',
                    title: 'Dispatch Monthly',
                    eyebrow: 'FLEXIBLE DISPATCH ACCESS',
                    artworkAsset:
                        'assets/images/membership_dispatch_monthly_subscription.svg',
                    icon: Icons.local_shipping_outlined,
                    selected: _selectedPlan == 'monthly',
                    onTap: () => _selectPlan('monthly'),
                    benefits: const [
                      'Dispatch membership billed monthly when provider checkout is enabled',
                      'Load, carrier, quote and awarded-job workflows',
                      'Provider-managed billing; marketplace transaction funds remain separate',
                    ],
                  ),
                  _SubscriptionPlanCard(
                    planKey: 'yearly',
                    title: 'Dispatch Yearly',
                    eyebrow: 'ANNUAL DISPATCH ACCESS',
                    artworkAsset:
                        'assets/images/membership_dispatch_yearly_subscription.svg',
                    icon: Icons.calendar_month_outlined,
                    selected: _selectedPlan == 'yearly',
                    onTap: () => _selectPlan('yearly'),
                    benefits: const [
                      'Annual Dispatch membership option',
                      'Same operational Dispatch tools with annual renewal cadence',
                      'Current pricing is supplied by the configured billing catalog',
                    ],
                  ),
                ];
                if (width >= 790) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < cards.length; index++) ...[
                        Expanded(child: cards[index]),
                        if (index < cards.length - 1) const SizedBox(width: 12),
                      ],
                    ],
                  );
                }
                return Column(
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      cards[index],
                      if (index < cards.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _SubscriptionPlanCard extends StatelessWidget {
  const _SubscriptionPlanCard({
    required this.planKey,
    required this.title,
    required this.eyebrow,
    required this.artworkAsset,
    required this.icon,
    required this.benefits,
    required this.selected,
    required this.onTap,
    this.premium = false,
  });

  final String planKey;
  final String title;
  final String eyebrow;
  final String artworkAsset;
  final IconData icon;
  final List<String> benefits;
  final bool premium;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? PipeBuyerColors.orange
        : premium
            ? const Color(0xFFFFB21A).withValues(alpha: .55)
            : Theme.of(context).dividerColor;
    final foreground = premium ? Colors.white : null;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title membership plan',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.all(selected ? 16 : 14),
            decoration: BoxDecoration(
              color: premium
                  ? const Color(0xFF101721)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: borderColor,
                width: selected ? 2.2 : 1,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 16,
                        offset: Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, artworkConstraints) {
                    final cardWidth = artworkConstraints.maxWidth;
                    final artworkHeight = selected
                        ? (cardWidth * .82).clamp(220.0, 280.0).toDouble()
                        : (cardWidth * .62).clamp(170.0, 210.0).toDouble();
                    final artworkMaxWidth = selected
                        ? (cardWidth * .72).clamp(160.0, 240.0).toDouble()
                        : (cardWidth * .66).clamp(145.0, 205.0).toDouble();
                    return AnimatedContainer(
                      key: ValueKey('membership-artwork-$title-$selected'),
                      duration: const Duration(milliseconds: 180),
                      height: artworkHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: premium
                            ? Colors.white.withValues(alpha: .04)
                            : PipeBuyerColors.canvas,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: artworkMaxWidth,
                          height: artworkHeight - 12,
                          child: SvgPicture.asset(
                            artworkAsset,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            semanticsLabel: '$title membership artwork',
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eyebrow,
                            style: TextStyle(
                              color: premium
                                  ? const Color(0xFFFFC44D)
                                  : PipeBuyerColors.orangePressed,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected ? Icons.check_circle_rounded : icon,
                      color: selected
                          ? PipeBuyerColors.orange
                          : premium
                              ? const Color(0xFFFFC44D)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: selected ? 24 : 21,
                    ),
                  ],
                ),
                if (!selected) ...[
                  const SizedBox(height: 10),
                  Text(
                    benefits.first,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: premium ? Colors.white70 : null,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 17,
                        color: premium
                            ? const Color(0xFFFFC44D)
                            : PipeBuyerColors.orangePressed,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Select to view details, promo code & checkout',
                          style: TextStyle(
                            color: premium ? Colors.white70 : null,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: premium
                          ? Colors.white.withValues(alpha: .06)
                          : PipeBuyerColors.orange.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'SELECTED PLAN',
                      style: TextStyle(
                        color: premium
                            ? const Color(0xFFFFC44D)
                            : PipeBuyerColors.orangePressed,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final benefit in benefits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 17,
                            color: premium
                                ? const Color(0xFFFFC44D)
                                : PipeBuyerColors.success,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              benefit,
                              style: TextStyle(
                                color: premium ? Colors.white70 : null,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (planKey == 'monthly')
                    const DispatchSubscriptionCheckoutButton(plan: 'monthly')
                  else if (planKey == 'yearly')
                    const DispatchSubscriptionCheckoutButton(plan: 'yearly')
                  else
                    const VipSubscriptionCheckoutButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}