import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'industrial_icon_assets.dart';

const marketplaceVipEarlyAccessDuration = Duration(hours: 24);

DateTime? marketplaceAccessDate(dynamic value) => switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime date => date,
      int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),
      String text => DateTime.tryParse(text),
      _ => null,
    };

DateTime? marketplaceVipEarlyAccessUntil(Map<String, dynamic> listing) {
  final explicit = marketplaceAccessDate(listing['vipEarlyAccessUntil']);
  if (explicit != null) return explicit;
  if (listing['vipEarlyAccessEnabled'] == false) return null;
  final published = marketplaceAccessDate(listing['publishedAt']) ??
      marketplaceAccessDate(listing['createdAt']);
  return published?.add(marketplaceVipEarlyAccessDuration);
}

bool marketplaceVipActive(
  Map<String, dynamic>? profile, {
  DateTime? now,
}) {
  if (profile == null) return false;
  final current = now ?? DateTime.now();
  final nested = profile['membership'] is Map
      ? Map<String, dynamic>.from(profile['membership'] as Map)
      : const <String, dynamic>{};
  final tier = '${profile['membershipTier'] ?? profile['subscriptionTier'] ?? nested['tier'] ?? ''}'
      .trim()
      .toLowerCase();
  final status = '${profile['vipStatus'] ?? profile['subscriptionStatus'] ?? nested['status'] ?? ''}'
      .trim()
      .toLowerCase();
  final activeFlag = profile['vipActive'] == true ||
      profile['isVip'] == true ||
      tier == 'vip';
  if (!activeFlag) return false;
  if (status.isNotEmpty && !const {'active', 'trialing', 'vip'}.contains(status)) {
    return false;
  }
  final expires = marketplaceAccessDate(profile['vipExpiresAt']) ??
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
  final sellerUid = '${listing['sellerUid'] ?? listing['ownerUid'] ?? ''}'.trim();
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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && '${listing['sellerUid'] ?? ''}' == user.uid) return child;
    if (marketplaceVipEarlyAccessUntil(listing) == null) return child;
    if (user == null) {
      return _MarketplaceVipGateBody(
        listing: listing,
        locked: marketplaceListingLockedForViewer(
          listing: listing,
          viewerProfile: null,
        ),
        child: child,
        onUpgrade: onUpgrade,
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data();
        return _MarketplaceVipGateBody(
          listing: listing,
          locked: marketplaceListingLockedForViewer(
            listing: listing,
            viewerProfile: profile,
            viewerUid: user.uid,
          ),
          child: child,
          onUpgrade: onUpgrade,
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
  State<_MarketplaceVipGateBody> createState() => _MarketplaceVipGateBodyState();
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
    if (oldWidget.locked != widget.locked || oldWidget.listing != widget.listing) {
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                                builder: (_) => const MarketplaceSubscriptionPlansDialog(),
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

class MarketplaceSubscriptionPlansDialog extends StatelessWidget {
  const MarketplaceSubscriptionPlansDialog({super.key});

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
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose marketplace priority access or Dispatch membership. Provider checkout remains separate from marketplace transactions.',
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
                    final cards = const [
                      _SubscriptionPlanCard(
                        title: 'VIP Membership',
                        eyebrow: 'MARKETPLACE PRIORITY',
                        artworkLabel: 'Pipe, Tubing & Materials',
                        icon: Icons.workspace_premium_rounded,
                        premium: true,
                        benefits: [
                          '24-hour early access to every newly published listing',
                          'Locked-listing countdowns show when inventory opens publicly',
                          'Priority marketplace alerts and enhanced offer intelligence foundation',
                        ],
                      ),
                      _SubscriptionPlanCard(
                        title: 'Dispatch Monthly',
                        eyebrow: 'FLEXIBLE DISPATCH ACCESS',
                        artworkLabel: 'Transport & Hauling',
                        icon: Icons.local_shipping_outlined,
                        benefits: [
                          'Dispatch membership billed monthly when provider checkout is enabled',
                          'Load, carrier, quote and awarded-job workflows',
                          'Provider-managed billing; marketplace transaction funds remain separate',
                        ],
                      ),
                      _SubscriptionPlanCard(
                        title: 'Dispatch Yearly',
                        eyebrow: 'ANNUAL DISPATCH ACCESS',
                        artworkLabel: 'Semi Truck',
                        icon: Icons.calendar_month_outlined,
                        benefits: [
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
    required this.title,
    required this.eyebrow,
    required this.artworkLabel,
    required this.icon,
    required this.benefits,
    this.premium = false,
  });

  final String title;
  final String eyebrow;
  final String artworkLabel;
  final IconData icon;
  final List<String> benefits;
  final bool premium;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: premium ? const Color(0xFF101721) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: premium
                ? const Color(0xFFFFB21A).withValues(alpha: .72)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: premium ? Colors.white.withValues(alpha: .04) : PipeBuyerColors.canvas,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: IndustrialAssetIcon(
                    label: artworkLabel,
                    size: 112,
                    borderRadius: 12,
                    fallback: Icon(
                      icon,
                      size: 58,
                      color: premium ? const Color(0xFFFFB21A) : PipeBuyerColors.orange,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 13),
            Text(
              eyebrow,
              style: TextStyle(
                color: premium ? const Color(0xFFFFC44D) : PipeBuyerColors.orangePressed,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: premium ? Colors.white : null,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final benefit in benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 17,
                      color: premium ? const Color(0xFFFFC44D) : PipeBuyerColors.success,
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
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$title checkout will use the configured provider billing flow. No marketplace transaction funds are processed by this button.',
                    ),
                  ),
                ),
                icon: Icon(icon),
                label: const Text('View plan readiness'),
              ),
            ),
          ],
        ),
      );
}
