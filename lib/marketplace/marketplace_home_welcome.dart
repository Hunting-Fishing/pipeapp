import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_commerce_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_home_hero_assets.dart';
import 'marketplace_navigation.dart';

class MarketplaceHomeWelcome extends StatelessWidget {
  const MarketplaceHomeWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return MarketplaceHomeDiscoveryHero(
        onBrowse: () => MarketplaceNavigation.goToBrowse(context),
        onSell: () => MarketplaceNavigation.goToSell(context),
        onDispatch: () => MarketplaceNavigation.goToDispatch(context),
        onWanted: () => MarketplaceNavigation.goToWanted(context),
      );
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
        return MarketplaceHomeDiscoveryHero(
          name: name,
          accountType: accountType,
          onBrowse: () => MarketplaceNavigation.goToBrowse(context),
          onSell: () => MarketplaceNavigation.goToSell(context),
          onDispatch: () => MarketplaceNavigation.goToDispatch(context),
          onWanted: () => MarketplaceNavigation.goToWanted(context),
        );
      },
    );
  }
}

/// Pure presentation surface for the Marketplace welcome campaign.
///
/// The hero intentionally lives inside the page's normal scrolling ListView.
/// The image therefore scrolls naturally with the page instead of behaving as
/// a fixed or parallax background. Keep this Firebase-free for widget testing.
class MarketplaceHomeDiscoveryHero extends StatelessWidget {
  const MarketplaceHomeDiscoveryHero({
    super.key,
    this.name,
    this.accountType = 'personal',
    this.onBrowse,
    this.onSell,
    this.onDispatch,
    this.onWanted,
  });

  final String? name;
  final String accountType;
  final VoidCallback? onBrowse;
  final VoidCallback? onSell;
  final VoidCallback? onDispatch;
  final VoidCallback? onWanted;

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
        MarketplaceHomeIntentActions(
          onBrowse: onBrowse,
          onSell: onSell,
          onDispatch: onDispatch,
          onWanted: onWanted,
        ),
        const SizedBox(height: 12),
        const PipeBuyerTrustBand(
          items: [
            PipeBuyerTrustItemData(
              icon: Icons.verified_user_outlined,
              title: 'Verified Businesses',
              subtitle:
                  'Identity and marketplace readiness are clearly surfaced.',
            ),
            PipeBuyerTrustItemData(
              icon: Icons.forum_outlined,
              title: 'Protected Messaging',
              subtitle: 'Keep negotiations and listing context inside the app.',
            ),
            PipeBuyerTrustItemData(
              icon: Icons.handshake_outlined,
              title: 'Auditable Offers',
              subtitle:
                  'Offer activity stays tied to the correct listing and account.',
            ),
            PipeBuyerTrustItemData(
              icon: Icons.local_shipping_outlined,
              title: 'Dispatch Ready',
              subtitle:
                  'Move from equipment discovery into trucking coordination.',
            ),
          ],
        ),
      ],
    );
  }
}

class MarketplaceHomeIntentActions extends StatelessWidget {
  const MarketplaceHomeIntentActions({
    super.key,
    this.onBrowse,
    this.onSell,
    this.onDispatch,
    this.onWanted,
  });

  final VoidCallback? onBrowse;
  final VoidCallback? onSell;
  final VoidCallback? onDispatch;
  final VoidCallback? onWanted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980 ? 4 : 2;
        const spacing = 10.0;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What do you want to do?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start with one simple action. Pipe Buyer will guide the rest of the workflow.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: PipeBuyerColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: Icons.search_rounded,
                        title: 'Browse inventory',
                        subtitle: 'Find pipe, equipment and industrial assets.',
                        onTap: onBrowse,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: Icons.add_box_outlined,
                        title: 'Sell something',
                        subtitle: 'Create a guided Marketplace listing.',
                        onTap: onSell,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: Icons.local_shipping_outlined,
                        title: 'Request service',
                        subtitle:
                            'Find trucking and industrial service providers.',
                        onTap: onDispatch,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: Icons.campaign_outlined,
                        title: 'Post wanted / RFQ',
                        subtitle: 'Tell the market exactly what you need.',
                        onTap: onWanted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MarketplaceIntentCard extends StatelessWidget {
  const _MarketplaceIntentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PipeBuyerColors.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 118),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.orangeSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: PipeBuyerColors.orangePressed,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  alignment: isMobile ? Alignment.topCenter : Alignment.center,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              // The previous hero used an almost-opaque black wash (up to .86
              // desktop / .78 mobile), which hid the photography and made the
              // mobile first viewport appear black. This deliberately keeps
              // only the minimum contrast needed for white text.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: isMobile
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: .28),
                              Colors.black.withValues(alpha: .16),
                              Colors.black.withValues(alpha: .06),
                              Colors.black.withValues(alpha: .20),
                            ],
                            stops: const [0, .34, .68, 1],
                          )
                        : LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: .42),
                              Colors.black.withValues(alpha: .24),
                              Colors.black.withValues(alpha: .08),
                              Colors.transparent,
                            ],
                            stops: const [0, .38, .72, 1],
                          ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                constraints: BoxConstraints(minHeight: minHeight),
                padding: EdgeInsets.all(isMobile ? 18 : 30),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isMobile ? 600 : 700),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _HeroBrandMark(),
                        SizedBox(height: isMobile ? 22 : 30),
                        Text(
                          signedIn
                              ? 'PIPE BUYER WORKSPACE'
                              : 'INDUSTRIAL MARKETPLACE',
                          style: const TextStyle(
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
                            fontSize: isMobile ? 28 : 40,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.7,
                            shadows: const [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 14 : 15.5,
                            height: 1.42,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 8,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? 20 : 24),
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
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .96),
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
        const Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PIPE BUYER',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 7,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2),
              Text(
                'PIPE · EQUIPMENT · SOLUTIONS',
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .55,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        color: Colors.black.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 0),
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
        color: Colors.black.withValues(alpha: .20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
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
