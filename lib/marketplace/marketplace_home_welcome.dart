import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_commerce_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_home_hero_assets.dart';

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
        _MarketplaceHomeHeroSurface(
          signedIn: _signedIn,
          accountType: accountType,
          title: title,
          subtitle: subtitle,
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

class _MarketplaceHomeHeroSurface extends StatelessWidget {
  const _MarketplaceHomeHeroSurface({
    required this.signedIn,
    required this.accountType,
    required this.title,
    required this.subtitle,
  });

  final bool signedIn;
  final String accountType;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile =
            constraints.maxWidth < MarketplaceHomeHeroAssets.mobileBreakpoint;
        final imagePath = isMobile
            ? MarketplaceHomeHeroAssets.mobileBackground
            : MarketplaceHomeHeroAssets.desktopBackground;
        final minHeight = isMobile
            ? MarketplaceHomeHeroAssets.mobileMinHeight
            : MarketplaceHomeHeroAssets.desktopMinHeight;

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  alignment:
                      isMobile ? Alignment.center : Alignment.centerRight,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: isMobile
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: .78),
                              Colors.black.withValues(alpha: .58),
                              Colors.black.withValues(alpha: .28),
                              Colors.black.withValues(alpha: .52),
                            ],
                            stops: const [0, .38, .7, 1],
                          )
                        : LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: .86),
                              Colors.black.withValues(alpha: .70),
                              Colors.black.withValues(alpha: .28),
                              Colors.black.withValues(alpha: .08),
                            ],
                            stops: const [0, .42, .72, 1],
                          ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                constraints: BoxConstraints(minHeight: minHeight),
                padding: EdgeInsets.all(isMobile ? 20 : 30),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? 620 : 700,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _HeroBrandMark(),
                        SizedBox(height: isMobile ? 26 : 30),
                        Text(
                          signedIn
                              ? 'PIPE BUYER WORKSPACE'
                              : 'INDUSTRIAL MARKETPLACE',
                          style: TextStyle(
                            color: PipeBuyerColors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 29 : 40,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.7,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .92),
                            fontSize: isMobile ? 14 : 15.5,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? 22 : 25),
                        const Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _HeroCapabilityChip(
                              icon: Icons.horizontal_rule_rounded,
                              label: 'Pipe & tubing',
                            ),
                            _HeroCapabilityChip(
                              icon: Icons.precision_manufacturing_outlined,
                              label: 'Heavy equipment',
                            ),
                            _HeroCapabilityChip(
                              icon: Icons.cabin_outlined,
                              label: 'Buildings & crew sites',
                            ),
                            _HeroCapabilityChip(
                              icon: Icons.local_shipping_outlined,
                              label: 'Trucking & Dispatch',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
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
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroBrandMark extends StatelessWidget {
  const _HeroBrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/pipe_buyer_logo.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PIPE BUYER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
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
      ],
    );
  }
}

class _HeroCapabilityChip extends StatelessWidget {
  const _HeroCapabilityChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .34),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: PipeBuyerColors.orange, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .16)),
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
}
