import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_commerce_components.dart';
import '../core/design/pipe_buyer_modern_cards.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_auth_action_page.dart';
import 'marketplace_home_hero_assets.dart';
import 'marketplace_navigation.dart';

class MarketplaceHomeWelcome extends StatefulWidget {
  const MarketplaceHomeWelcome({
    super.key,
    this.includeIntentAndTrust = true,
  });

  final bool includeIntentAndTrust;

  @override
  State<MarketplaceHomeWelcome> createState() => _MarketplaceHomeWelcomeState();
}

class _MarketplaceHomeWelcomeState extends State<MarketplaceHomeWelcome> {
  String? _dismissedForUid;
  bool _sendingVerification = false;

  Future<void> _resendVerificationEmail(User user) async {
    if (_sendingVerification) return;
    setState(() => _sendingVerification = true);
    try {
      await user.sendEmailVerification(marketplaceEmailActionCodeSettings());
      if (!mounted) return;
      final email = (user.email ?? '').trim();
      PipeFeedback.show(
        context,
        message: email.isEmpty
            ? 'Verification email sent. Check your inbox.'
            : 'Verification email sent to $email.',
        tone: PipeStatusTone.success,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = error.code == 'too-many-requests'
          ? 'A verification email was just sent. Check your inbox or wait a moment before resending.'
          : (error.message ?? 'Could not send verification email right now.');
      PipeFeedback.show(
        context,
        message: message,
        tone: PipeStatusTone.warning,
      );
    } catch (_) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'Could not send verification email right now.',
        tone: PipeStatusTone.warning,
      );
    } finally {
      if (mounted) {
        setState(() => _sendingVerification = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) {
          return MarketplaceHomeDiscoveryHero(
            includeIntentAndTrust: widget.includeIntentAndTrust,
            onBrowse: () => MarketplaceNavigation.goToBrowse(context),
            onSell: () => MarketplaceNavigation.goToSell(context),
            onDispatch: () => MarketplaceNavigation.goToDispatch(context),
            onWanted: () => MarketplaceNavigation.goToWanted(context),
            onSearchServices: () =>
                MarketplaceNavigation.openSearchServices(context),
            onListServices: () =>
                MarketplaceNavigation.openListServices(context),
            onCommercialInsurance: () =>
                MarketplaceNavigation.openInsuranceHub(context),
            onPartnerWithUs: () =>
                MarketplaceNavigation.openPartnerWithUs(context),
          );
        }

        final email = (user.email ?? '').trim();
        final showVerificationReminder = email.isNotEmpty &&
            !user.emailVerified &&
            _dismissedForUid != user.uid;

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
            final hero = MarketplaceHomeDiscoveryHero(
              name: name,
              accountType: accountType,
              includeIntentAndTrust: widget.includeIntentAndTrust,
              onBrowse: () => MarketplaceNavigation.goToBrowse(context),
              onSell: () => MarketplaceNavigation.goToSell(context),
              onDispatch: () => MarketplaceNavigation.goToDispatch(context),
              onWanted: () => MarketplaceNavigation.goToWanted(context),
              onSearchServices: () =>
                  MarketplaceNavigation.openSearchServices(context),
              onListServices: () =>
                  MarketplaceNavigation.openListServices(context),
              onCommercialInsurance: () =>
                  MarketplaceNavigation.openInsuranceHub(context),
              onPartnerWithUs: () =>
                  MarketplaceNavigation.openPartnerWithUs(context),
            );
            if (!showVerificationReminder) {
              return hero;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MarketplaceEmailVerificationReminderBanner(
                  email: email,
                  sending: _sendingVerification,
                  onResend: () => _resendVerificationEmail(user),
                  onOpenVerification: () =>
                      MarketplaceNavigation.openVerificationAndSecurity(
                    context,
                  ),
                  onDismiss: () => setState(() => _dismissedForUid = user.uid),
                ),
                const SizedBox(height: 12),
                hero,
              ],
            );
          },
        );
      },
    );
  }
}

/// Non-blocking, dismissible email verification reminder card.
///
/// Kept Firebase-free so it can be widget-tested independently.
class MarketplaceEmailVerificationReminderBanner extends StatelessWidget {
  const MarketplaceEmailVerificationReminderBanner({
    super.key,
    required this.email,
    required this.onResend,
    required this.onOpenVerification,
    required this.onDismiss,
    this.sending = false,
  });

  final String email;
  final bool sending;
  final VoidCallback onResend;
  final VoidCallback onOpenVerification;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PipeBuyerColors.orange.withValues(alpha: .35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: PipeBuyerColors.orangeSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.mark_email_unread_outlined,
                size: 20,
                color: PipeBuyerColors.orangePressed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confirm your email when convenient',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'We sent a verification link to $email. You have full access to browse Pipe Buyer now, and can manage verification anytime under Account > Verification & Security.',
                    style: const TextStyle(
                      color: PipeBuyerColors.muted,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: sending ? null : onResend,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.outgoing_mail, size: 16),
                        label: Text(
                          sending ? 'Sending…' : 'Resend email',
                        ),
                      ),
                      TextButton(
                        onPressed: onOpenVerification,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Verification & Security'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss reminder',
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
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
    this.includeIntentAndTrust = true,
    this.onBrowse,
    this.onSell,
    this.onDispatch,
    this.onWanted,
    this.onSearchServices,
    this.onListServices,
    this.onCommercialInsurance,
    this.onPartnerWithUs,
  });

  final String? name;
  final String accountType;
  final bool includeIntentAndTrust;
  final VoidCallback? onBrowse;
  final VoidCallback? onSell;
  final VoidCallback? onDispatch;
  final VoidCallback? onWanted;
  final VoidCallback? onSearchServices;
  final VoidCallback? onListServices;
  final VoidCallback? onCommercialInsurance;
  final VoidCallback? onPartnerWithUs;

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
          title: title,
          subtitle: subtitle,
          compactHeight: !includeIntentAndTrust,
        ),
        if (includeIntentAndTrust) ...[
          const SizedBox(height: 12),
          MarketplaceHomeIntentActions(
            onBrowse: onBrowse,
            onSell: onSell,
            onDispatch: onDispatch,
            onWanted: onWanted,
            onSearchServices: onSearchServices,
            onListServices: onListServices,
            onCommercialInsurance: onCommercialInsurance,
            onPartnerWithUs: onPartnerWithUs,
          ),
          const SizedBox(height: 12),
          const PipeBuyerTrustBand(
            items: [
              PipeBuyerTrustItemData(
                icon: LucideIcons.shieldCheck,
                title: 'Verified Businesses',
                subtitle:
                    'Identity and marketplace readiness are clearly surfaced.',
              ),
              PipeBuyerTrustItemData(
                icon: LucideIcons.messageSquareLock,
                title: 'Protected Messaging',
                subtitle:
                    'Keep negotiations and listing context inside the app.',
              ),
              PipeBuyerTrustItemData(
                icon: LucideIcons.fileCheck2,
                title: 'Auditable Offers',
                subtitle:
                    'Offer activity stays tied to the correct listing and account.',
              ),
              PipeBuyerTrustItemData(
                icon: LucideIcons.truck,
                title: 'Dispatch Ready',
                subtitle:
                    'Move from equipment discovery into trucking coordination.',
              ),
            ],
          ),
        ],
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
    this.onSearchServices,
    this.onListServices,
    this.onCommercialInsurance,
    this.onPartnerWithUs,
  });

  final VoidCallback? onBrowse;
  final VoidCallback? onSell;
  final VoidCallback? onDispatch;
  final VoidCallback? onWanted;
  final VoidCallback? onSearchServices;
  final VoidCallback? onListServices;
  final VoidCallback? onCommercialInsurance;
  final VoidCallback? onPartnerWithUs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
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
                        icon: LucideIcons.search,
                        title: 'Browse inventory',
                        subtitle: 'Find pipe, equipment and industrial assets.',
                        onTap: onBrowse,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: LucideIcons.packagePlus,
                        title: 'Sell something',
                        subtitle: 'Create a guided Marketplace listing.',
                        onTap: onSell,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: LucideIcons.building2,
                        title: 'Search for services',
                        subtitle:
                            'Search Oil & Gas providers, training & crew hotels worldwide.',
                        onTap: onSearchServices,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: LucideIcons.badgeCheck,
                        title: 'List services',
                        subtitle:
                            'Get Priority Verified placement in the Oilfield Directory.',
                        onTap: onListServices,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: LucideIcons.truck,
                        title: 'Request service',
                        subtitle:
                            'Find trucking and industrial service providers.',
                        onTap: onDispatch,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: LucideIcons.megaphone,
                        title: 'Post wanted / RFQ',
                        subtitle: 'Tell the market exactly what you need.',
                        onTap: onWanted,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: LucideIcons.shield,
                        title: 'Commercial insurance',
                        subtitle:
                            'Compare MSA-ready fleet, rig, cargo & liability rates.',
                        onTap: onCommercialInsurance,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MarketplaceIntentCard(
                        icon: LucideIcons.handshake,
                        title: 'Partner with us',
                        subtitle:
                            'Sponsor placements, OEM fleet showcases & corporate advertising.',
                        onTap: onPartnerWithUs,
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
    return PipeBuyerInteractiveCard(
      onTap: onTap,
      borderRadius: 14,
      backgroundColor: PipeBuyerColors.field,
      borderColor: const Color(0xFFE2E8F0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 112),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PipeBuyerColors.studioSlate,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PipeBuyerColors.studioRim),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: PipeBuyerColors.orange,
                ),
              ),
              const Gap(10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Gap(4),
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
    );
  }
}

class _MarketplaceHomeHeroSurface extends StatelessWidget {
  const _MarketplaceHomeHeroSurface({
    required this.signedIn,
    required this.title,
    required this.subtitle,
    this.compactHeight = false,
  });

  final bool signedIn;
  final String title;
  final String subtitle;
  final bool compactHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile =
            constraints.maxWidth < MarketplaceHomeHeroAssets.mobileBreakpoint;
        final imagePath = isMobile
            ? MarketplaceHomeHeroAssets.mobileBackground
            : MarketplaceHomeHeroAssets.desktopBackground;
        final minHeight = compactHeight
            ? (isMobile ? 210.0 : 240.0)
            : (isMobile
                ? MarketplaceHomeHeroAssets.mobileMinHeight
                : MarketplaceHomeHeroAssets.desktopMinHeight);

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xBD0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/pipe_buyer_logo_on_dark.png',
            height: 40,
            fit: BoxFit.contain,
            semanticLabel: 'Pipe Buyer',
          ),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 24,
            color: Colors.white.withValues(alpha: 0.22),
          ),
          const SizedBox(width: 12),
          const Flexible(
            child: Text(
              'PIPE · EQUIPMENT · SOLUTIONS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .65,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
