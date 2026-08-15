import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_commerce_components.dart';
import '../core/design/pipe_buyer_theme.dart';

class MarketplaceHomeWelcome extends StatelessWidget {
  const MarketplaceHomeWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _MarketplaceHomeDiscoveryHero();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final candidates = [
          data['displayName'],
          data['display_name'],
          data['businessName'],
          user.displayName,
          user.email?.split('@').first,
        ];
        final name = candidates
            .map((value) => '${value ?? ''}'.trim())
            .firstWhere(
              (value) => value.isNotEmpty,
              orElse: () => 'Pipe Buyer member',
            );
        final accountType = '${data['accountType'] ?? 'personal'}';
        return _MarketplaceHomeDiscoveryHero(
          name: name,
          accountType: accountType,
        );
      },
    );
  }
}

class _MarketplaceHomeDiscoveryHero extends StatelessWidget {
  const _MarketplaceHomeDiscoveryHero({
    this.name,
    this.accountType = 'personal',
  });

  final String? name;
  final String accountType;

  bool get _signedIn => name != null && name!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final title = _signedIn
        ? 'Welcome back, $name. Keep your next deal moving.'
        : 'Find. Connect. Move. Industrial inventory across North America.';
    final subtitle = _signedIn
        ? 'Find inventory, manage listings, negotiate offers and coordinate Dispatch from one Pipe Buyer workspace.'
        : 'Buy and sell pipe, oilfield equipment, heavy equipment, portable buildings, vehicles and hauling services in one industry-focused marketplace.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PipeBuyerHeroPanel(
          eyebrow: _signedIn ? 'Pipe Buyer workspace' : 'Industrial marketplace',
          title: title,
          subtitle: subtitle,
          minHeight: _signedIn ? 320 : 350,
          trailing: _HeroIdentityPanel(
            signedIn: _signedIn,
            accountType: accountType,
          ),
        ),
        const SizedBox(height: 12),
        const PipeBuyerTrustBand(
          items: [
            PipeBuyerTrustItemData(
              icon: Icons.verified_user_outlined,
              title: 'Verified Businesses',
              subtitle: 'Identity and marketplace readiness are clearly surfaced.',
            ),
            PipeBuyerTrustItemData(
              icon: Icons.forum_outlined,
              title: 'Protected Messaging',
              subtitle: 'Keep negotiations and listing context inside the app.',
            ),
            PipeBuyerTrustItemData(
              icon: Icons.handshake_outlined,
              title: 'Auditable Offers',
              subtitle: 'Offer activity stays tied to the correct listing and account.',
            ),
            PipeBuyerTrustItemData(
              icon: Icons.local_shipping_outlined,
              title: 'Dispatch Ready',
              subtitle: 'Move from equipment discovery into trucking coordination.',
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroIdentityPanel extends StatelessWidget {
  const _HeroIdentityPanel({
    required this.signedIn,
    required this.accountType,
  });

  final bool signedIn;
  final String accountType;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 330),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(
                  'assets/images/pipe_buyer_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PIPE BUYER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .35,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'PIPE · EQUIPMENT · SOLUTIONS',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          const _HeroCapability(
            icon: Icons.horizontal_rule_rounded,
            label: 'Pipe & tubing marketplace',
          ),
          const SizedBox(height: 9),
          const _HeroCapability(
            icon: Icons.precision_manufacturing_outlined,
            label: 'Heavy equipment & field assets',
          ),
          const SizedBox(height: 9),
          const _HeroCapability(
            icon: Icons.cabin_outlined,
            label: 'Portable buildings & crew sites',
          ),
          const SizedBox(height: 9),
          const _HeroCapability(
            icon: Icons.local_shipping_outlined,
            label: 'Trucking & Dispatch workflows',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _HeroChip(
                icon: signedIn
                    ? Icons.person_outline_rounded
                    : Icons.public_rounded,
                label: signedIn
                    ? accountType == 'business'
                        ? 'Business account'
                        : 'Marketplace account'
                    : 'North America first',
              ),
              const _HeroChip(
                icon: Icons.event_available_outlined,
                label: '30-day listing lifecycle',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCapability extends StatelessWidget {
  const _HeroCapability({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: PipeBuyerColors.orange.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: PipeBuyerColors.orange, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: PipeBuyerColors.orange, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}
