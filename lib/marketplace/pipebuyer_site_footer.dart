import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_about_page.dart';
import 'marketplace_navigation.dart';
import 'marketplace_public_information.dart';
import 'pipebuyer_partner_with_us_page.dart';

enum PipeBuyerFooterSurface {
  home,
  directory,
  partner,
  insurance,
  about,
  publicInfo,
}

/// Shared responsive site footer for Pipe Buyer pages.
///
/// Highlights the "Partner With Us" corporate program (OEM vehicles & crew
/// trucks, brand promotions, site advertising, product showcases, and oilfield
/// discounts) alongside Marketplace, Oilfield Directory, and Trust/Legal links.
class PipeBuyerSiteFooter extends StatelessWidget {
  const PipeBuyerSiteFooter({
    super.key,
    this.currentSurface = PipeBuyerFooterSurface.home,
    this.onOpenPartnerWithUs,
    this.onOpenPartnerShowcase,
  });

  final PipeBuyerFooterSurface currentSurface;
  final VoidCallback? onOpenPartnerWithUs;
  final VoidCallback? onOpenPartnerShowcase;

  void _openPartner(
    BuildContext context, {
    PartnerPageSection section = PartnerPageSection.overview,
    String categoryFilter = '',
  }) {
    if (section == PartnerPageSection.showcase &&
        onOpenPartnerShowcase != null) {
      onOpenPartnerShowcase!();
      return;
    }
    if (onOpenPartnerWithUs != null &&
        section != PartnerPageSection.showcase) {
      onOpenPartnerWithUs!();
      return;
    }
    MarketplaceNavigation.openPartnerWithUs(
      context,
      initialSection: section,
      initialCategoryFilter: categoryFilter,
    );
  }

  void _openPublicInfo(
    BuildContext context,
    MarketplacePublicInformationKind kind,
  ) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MarketplacePublicInformationPage(kind: kind),
      ),
    );
  }

  void _openAbout(BuildContext context) {
    if (currentSurface == PipeBuyerFooterSurface.about) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MarketplaceAboutPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Pipe Buyer site footer',
      child: Container(
        key: const Key('pipebuyer-site-footer'),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PipeBuyerColors.ink,
              PipeBuyerColors.charcoal,
              PipeBuyerColors.graphite,
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: PipeBuyerColors.orange.withValues(alpha: 0.36),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 3,
              color: PipeBuyerColors.orange,
            ),
            if (currentSurface != PipeBuyerFooterSurface.partner)
              _PartnerSpotlightBanner(
                onPartnerWithUs: () => _openPartner(
                  context,
                  section: PartnerPageSection.apply,
                ),
                onExploreDeals: () => _openPartner(
                  context,
                  section: PartnerPageSection.showcase,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 820;
                  final medium = constraints.maxWidth >= 520;

                  final brandBlock = _FooterBrandColumn(
                    onPartnerTap: () => _openPartner(context),
                  );

                  final marketplaceCol = _FooterLinkColumn(
                    heading: 'MARKETPLACE & DIRECTORY',
                    links: [
                      _FooterLinkItem(
                        label: 'Browse Marketplace',
                        icon: Icons.storefront_outlined,
                        onTap: () => MarketplaceNavigation.goToBrowse(context),
                      ),
                      _FooterLinkItem(
                        label: 'Oilfield Directory',
                        icon: Icons.manage_search_rounded,
                        onTap: () =>
                            MarketplaceNavigation.openSearchServices(context),
                      ),
                      _FooterLinkItem(
                        label: 'List Services',
                        icon: Icons.workspace_premium_outlined,
                        onTap: () =>
                            MarketplaceNavigation.openListServices(context),
                      ),
                      _FooterLinkItem(
                        key: const Key('footer-link-commercial-insurance'),
                        label: 'Commercial Insurance',
                        icon: Icons.shield_outlined,
                        onTap: () =>
                            MarketplaceNavigation.openInsuranceHub(context),
                      ),
                      _FooterLinkItem(
                        label: 'Dispatch & Hauling',
                        icon: Icons.local_shipping_outlined,
                        onTap: () =>
                            MarketplaceNavigation.goToDispatch(context),
                      ),
                    ],
                  );

                  final partnerCol = _FooterLinkColumn(
                    heading: 'PARTNER WITH US',
                    links: [
                      _FooterLinkItem(
                        key: const Key('footer-link-partner-with-us'),
                        label: 'Partner With Us',
                        icon: Icons.handshake_outlined,
                        highlight: true,
                        onTap: () => _openPartner(context),
                      ),
                      _FooterLinkItem(
                        label: 'OEM Fleet & Crew Trucks',
                        icon: Icons.directions_car_filled_outlined,
                        onTap: () => _openPartner(
                          context,
                          section: PartnerPageSection.showcase,
                          categoryFilter: 'oem_fleet_crew_trucks',
                        ),
                      ),
                      _FooterLinkItem(
                        label: 'Oilfield Deals & Discounts',
                        icon: Icons.local_offer_outlined,
                        onTap: () => _openPartner(
                          context,
                          section: PartnerPageSection.showcase,
                        ),
                      ),
                      _FooterLinkItem(
                        label: 'Advertise & Sell Products',
                        icon: Icons.campaign_outlined,
                        onTap: () => _openPartner(
                          context,
                          section: PartnerPageSection.apply,
                        ),
                      ),
                      _FooterLinkItem(
                        key: const Key('footer-link-insurance-carrier-apply'),
                        label: 'Insurance Carrier Onboarding',
                        icon: Icons.domain_add_outlined,
                        onTap: () =>
                            MarketplaceNavigation.openInsuranceProviderApply(
                          context,
                        ),
                      ),
                    ],
                  );

                  final companyCol = _FooterLinkColumn(
                    heading: 'COMPANY & TRUST',
                    links: [
                      if (currentSurface != PipeBuyerFooterSurface.about)
                        _FooterLinkItem(
                          label: 'About',
                          icon: Icons.info_outline_rounded,
                          onTap: () => _openAbout(context),
                        ),
                      _FooterLinkItem(
                        label: 'Privacy',
                        icon: Icons.privacy_tip_outlined,
                        onTap: () => _openPublicInfo(
                          context,
                          MarketplacePublicInformationKind.privacy,
                        ),
                      ),
                      _FooterLinkItem(
                        label: 'Terms',
                        icon: Icons.description_outlined,
                        onTap: () => _openPublicInfo(
                          context,
                          MarketplacePublicInformationKind.terms,
                        ),
                      ),
                      _FooterLinkItem(
                        label: 'Help & Support',
                        icon: Icons.support_agent_outlined,
                        onTap: () => _openPublicInfo(
                          context,
                          MarketplacePublicInformationKind.support,
                        ),
                      ),
                    ],
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 13, child: brandBlock),
                        const SizedBox(width: 24),
                        Expanded(flex: 9, child: marketplaceCol),
                        const SizedBox(width: 20),
                        Expanded(flex: 10, child: partnerCol),
                        const SizedBox(width: 20),
                        Expanded(flex: 8, child: companyCol),
                      ],
                    );
                  }

                  if (medium) {
                    final colWidth = (constraints.maxWidth - 20) / 2;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        brandBlock,
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: [
                            SizedBox(width: colWidth, child: partnerCol),
                            SizedBox(width: colWidth, child: marketplaceCol),
                            SizedBox(width: colWidth, child: companyCol),
                          ],
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      brandBlock,
                      const SizedBox(height: 18),
                      partnerCol,
                      const SizedBox(height: 16),
                      marketplaceCol,
                      const SizedBox(height: 16),
                      companyCol,
                    ],
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.26),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                ),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    '© 2026 Pipe Buyer. Built for oilfield, fleet, and industrial commerce.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  InkWell(
                    onTap: () => _openPartner(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'OEMs, Brands & Dealers: Partner With Us →',
                        style: TextStyle(
                          color: PipeBuyerColors.orange,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerSpotlightBanner extends StatelessWidget {
  const _PartnerSpotlightBanner({
    required this.onPartnerWithUs,
    required this.onExploreDeals,
  });

  final VoidCallback onPartnerWithUs;
  final VoidCallback onExploreDeals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: PipeBuyerColors.orange.withValues(alpha: 0.10),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 720;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.orange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'PARTNER WITH US',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'OEM FLEETS • ADVERTISING • OILFIELD DEALS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Promote Your Brand, Showcase Crew Trucks & Sell Direct to the Oilfield',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'We partner with OEM vehicle makers, commercial truck dealers, equipment manufacturers, and suppliers to advertise, showcase products, and deliver exclusive oilfield fleet deals.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );

          final buttons = Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('footer-partner-with-us-cta'),
                onPressed: onPartnerWithUs,
                style: FilledButton.styleFrom(
                  backgroundColor: PipeBuyerColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.handshake_outlined, size: 18),
                label: const Text('Partner With Us'),
              ),
              OutlinedButton.icon(
                key: const Key('footer-explore-partner-deals-cta'),
                onPressed: onExploreDeals,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.local_offer_outlined, size: 17),
                label: const Text('View Oilfield Deals'),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 14),
                buttons,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              buttons,
            ],
          );
        },
      ),
    );
  }
}

class _FooterBrandColumn extends StatelessWidget {
  const _FooterBrandColumn({required this.onPartnerTap});

  final VoidCallback onPartnerTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PipeBuyerColors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'PB',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PIPE BUYER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'PIPE • EQUIPMENT • SOLUTIONS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PipeBuyerColors.orange,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Connecting oilfield operators, contractors, OEM fleet programs, and verified industrial suppliers across North America and global energy basins.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onPartnerTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 15,
                  color: PipeBuyerColors.orange,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Commercial Brand & OEM Inquiries Open',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterLinkItem {
  const _FooterLinkItem({
    this.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlight = false,
  });

  final Key? key;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;
}

class _FooterLinkColumn extends StatelessWidget {
  const _FooterLinkColumn({
    required this.heading,
    required this.links,
  });

  final String heading;
  final List<_FooterLinkItem> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in links)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: InkWell(
              key: item.key,
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 15,
                      color: item.highlight
                          ? PipeBuyerColors.orange
                          : Colors.white60,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: item.highlight
                              ? PipeBuyerColors.orange
                              : Colors.white.withValues(alpha: 0.88),
                          fontSize: 12.5,
                          fontWeight: item.highlight
                              ? FontWeight.w900
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
