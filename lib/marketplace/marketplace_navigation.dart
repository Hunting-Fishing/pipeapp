import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_scoped_staff_dashboard.dart';
import 'pipebuyer_contact_center_dashboard.dart';
import 'pipebuyer_insurance_admin_page.dart';
import 'pipebuyer_insurance_hub_page.dart';
import 'pipebuyer_insurance_provider_apply_page.dart';
import 'pipebuyer_list_services_page.dart';
import 'pipebuyer_partner_admin_page.dart';
import 'pipebuyer_partner_with_us_page.dart';
import 'pipebuyer_shop_admin_page.dart';
import 'pipebuyer_shop_store_page.dart';
import 'pipebuyer_shop_vendor_apply_page.dart';
import 'pipebuyer_yellow_pages_directory_page.dart';

@immutable
class MarketplaceDestinationRequest {
  const MarketplaceDestinationRequest(this.pageIndex);

  final int pageIndex;
}

enum PipeBuyerGlobalHub {
  home,
  browse,
  sell,
  servicesDirectory,
  listServices,
  insurance,
  partnerWithUs,
  dispatch,
}

/// Coordinates top-level marketplace navigation from pages pushed above the
/// tab scaffold and from simple Home intent actions.
class MarketplaceNavigation {
  MarketplaceNavigation._();

  static final ValueNotifier<int> homeRequests = ValueNotifier<int>(0);
  static final ValueNotifier<MarketplaceDestinationRequest?>
      destinationRequests = ValueNotifier<MarketplaceDestinationRequest?>(null);
  static final ValueNotifier<int> wantedRequests = ValueNotifier<int>(0);
  static final ValueNotifier<int?> accountSubTabRequests = ValueNotifier<int?>(
    null,
  );
  static final ValueNotifier<String?> browseSearchRequests =
      ValueNotifier<String?>(null);

  static void goHome(BuildContext context) {
    homeRequests.value++;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static void goToDestination(BuildContext context, int pageIndex) {
    destinationRequests.value = MarketplaceDestinationRequest(pageIndex);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static void goToAccount(BuildContext context, {int? subTabIndex}) {
    if (subTabIndex != null) {
      accountSubTabRequests.value = subTabIndex;
    }
    goToDestination(context, 5);
  }

  /// Opens the Account section directly on the Verification & Security tab.
  static void openVerificationAndSecurity(BuildContext context) =>
      goToAccount(context, subTabIndex: 2);

  static void goToBrowse(BuildContext context) => goToDestination(context, 1);

  static void goToBrowseWithSearch(BuildContext context, String query) {
    browseSearchRequests.value = query.trim();
    goToDestination(context, 1);
  }

  static void goToSell(BuildContext context) => goToDestination(context, 2);

  static void goToDispatch(BuildContext context) => goToDestination(context, 7);

  static void goToWanted(BuildContext context) {
    wantedRequests.value++;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static Future<void> openSearchServices(
    BuildContext context, {
    String initialQuery = '',
    String initialCategoryCode = '',
    String initialCountryCode = '',
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PipeBuyerYellowPagesDirectoryPage(
          initialQuery: initialQuery,
          initialCategoryCode: initialCategoryCode,
          initialCountryCode: initialCountryCode,
        ),
      ),
    );
  }

  static Future<bool?> openListServices(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PipeBuyerListServicesPage(),
      ),
    );
  }

  static Future<void> openYellowPagesAdmin(
    BuildContext context, {
    String initialSearchQuery = '',
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PipeBuyerContactCenterDashboard(
          initialSearchQuery: initialSearchQuery,
        ),
      ),
    );
  }

  static Future<void> openPartnerWithUs(
    BuildContext context, {
    PartnerPageSection initialSection = PartnerPageSection.overview,
    String initialCategoryFilter = '',
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PipeBuyerPartnerWithUsPage(
          initialSection: initialSection,
          initialCategoryFilter: initialCategoryFilter,
        ),
      ),
    );
  }

  static Future<void> openPartnerAdmin(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PipeBuyerPartnerAdminPage(),
      ),
    );
  }

  static Future<void> openInsuranceHub(
    BuildContext context, {
    InsuranceHubTab initialTab = InsuranceHubTab.browseProviders,
    String initialQuery = '',
    String initialCoverageLine = '',
    String initialCountryCode = '',
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PipeBuyerInsuranceHubPage(
          initialTab: initialTab,
          initialQuery: initialQuery,
          initialCoverageLine: initialCoverageLine,
          initialCountryCode: initialCountryCode,
        ),
      ),
    );
  }

  static Future<bool?> openInsuranceProviderApply(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PipeBuyerInsuranceProviderApplyPage(),
      ),
    );
  }

  static Future<void> openInsuranceAdmin(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PipeBuyerInsuranceAdminPage(),
      ),
    );
  }

  /// Opens the Account section directly on the Admin Portal tab (index 7).
  static void openAdminPortalTab(BuildContext context) =>
      goToAccount(context, subTabIndex: 7);

  static Future<void> openShopStore(
    BuildContext context, {
    String initialQuery = '',
    String initialCategoryCode = '',
    String initialBrand = '',
    String initialSourceCode = '',
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PipeBuyerShopStorePage(
          initialQuery: initialQuery,
          initialCategoryCode: initialCategoryCode,
          initialBrand: initialBrand,
          initialSourceCode: initialSourceCode,
        ),
      ),
    );
  }

  static Future<bool?> openShopVendorApply(
    BuildContext context, {
    String initialTrack = 'industrial_distributor',
    String initialBrand = '',
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PipeBuyerShopVendorApplyPage(
          initialTrack: initialTrack,
          initialBrand: initialBrand,
        ),
      ),
    );
  }

  static Future<void> openShopAdmin(
    BuildContext context, {
    int initialTabIndex = 0,
    String initialSection = '',
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PipeBuyerShopAdminPage(
          initialTabIndex: initialTabIndex,
          initialSection: initialSection,
        ),
      ),
    );
  }

  static Future<void> openScopedStaffAdmin(
    BuildContext context, {
    int initialShopTabIndex = 1,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MarketplaceScopedStaffDashboard(
          initialShopTabIndex: initialShopTabIndex,
        ),
      ),
    );
  }
}

/// Persistent cross-hub navigation strip displayed in the AppBar of secondary
/// hubs (Services Directory, List Services, Commercial Insurance, Partner With Us)
/// so users always retain one-click access to every core Pipe Buyer surface.
class PipeBuyerGlobalHubBar extends StatelessWidget
    implements PreferredSizeWidget {
  const PipeBuyerGlobalHubBar({
    super.key,
    required this.currentHub,
  });

  final PipeBuyerGlobalHub currentHub;

  @override
  Size get preferredSize => const Size.fromHeight(42);

  @override
  Widget build(BuildContext context) {
    const items = <({
      PipeBuyerGlobalHub hub,
      String label,
      IconData icon,
    })>[
      (
        hub: PipeBuyerGlobalHub.home,
        label: 'Home',
        icon: Icons.home_outlined,
      ),
      (
        hub: PipeBuyerGlobalHub.browse,
        label: 'Browse Inventory',
        icon: Icons.storefront_outlined,
      ),
      (
        hub: PipeBuyerGlobalHub.sell,
        label: 'Sell / RFQ',
        icon: Icons.add_box_outlined,
      ),
      (
        hub: PipeBuyerGlobalHub.servicesDirectory,
        label: 'Services Directory',
        icon: Icons.manage_search_rounded,
      ),
      (
        hub: PipeBuyerGlobalHub.listServices,
        label: 'List Services',
        icon: Icons.workspace_premium_outlined,
      ),
      (
        hub: PipeBuyerGlobalHub.insurance,
        label: 'Commercial Insurance',
        icon: Icons.shield_outlined,
      ),
      (
        hub: PipeBuyerGlobalHub.partnerWithUs,
        label: 'Partner With Us',
        icon: Icons.handshake_outlined,
      ),
      (
        hub: PipeBuyerGlobalHub.dispatch,
        label: 'Dispatch',
        icon: Icons.local_shipping_outlined,
      ),
    ];

    return Container(
      height: 42,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _GlobalHubPill(
                label: items[i].label,
                icon: items[i].icon,
                selected: items[i].hub == currentHub,
                onTap: () => _handleHubTap(context, items[i].hub),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleHubTap(BuildContext context, PipeBuyerGlobalHub target) {
    if (target == currentHub) return;
    switch (target) {
      case PipeBuyerGlobalHub.home:
        MarketplaceNavigation.goHome(context);
      case PipeBuyerGlobalHub.browse:
        MarketplaceNavigation.goToBrowse(context);
      case PipeBuyerGlobalHub.sell:
        MarketplaceNavigation.goToSell(context);
      case PipeBuyerGlobalHub.dispatch:
        MarketplaceNavigation.goToDispatch(context);
      case PipeBuyerGlobalHub.servicesDirectory:
        MarketplaceNavigation.openSearchServices(context);
      case PipeBuyerGlobalHub.listServices:
        MarketplaceNavigation.openListServices(context);
      case PipeBuyerGlobalHub.insurance:
        MarketplaceNavigation.openInsuranceHub(context);
      case PipeBuyerGlobalHub.partnerWithUs:
        MarketplaceNavigation.openPartnerWithUs(context);
    }
  }
}

class _GlobalHubPill extends StatelessWidget {
  const _GlobalHubPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? PipeBuyerColors.orange
          : Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : const Color(0xFFCBD5E1),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFE2E8F0),
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
