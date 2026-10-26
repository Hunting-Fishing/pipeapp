import 'package:flutter/material.dart';

import 'pipebuyer_contact_center_dashboard.dart';
import 'pipebuyer_insurance_admin_page.dart';
import 'pipebuyer_insurance_hub_page.dart';
import 'pipebuyer_insurance_provider_apply_page.dart';
import 'pipebuyer_list_services_page.dart';
import 'pipebuyer_partner_admin_page.dart';
import 'pipebuyer_partner_with_us_page.dart';
import 'pipebuyer_yellow_pages_directory_page.dart';

@immutable
class MarketplaceDestinationRequest {
  const MarketplaceDestinationRequest(this.pageIndex);

  final int pageIndex;
}

/// Coordinates top-level marketplace navigation from pages pushed above the
/// tab scaffold and from simple Home intent actions.
class MarketplaceNavigation {
  MarketplaceNavigation._();

  static final ValueNotifier<int> homeRequests = ValueNotifier<int>(0);
  static final ValueNotifier<MarketplaceDestinationRequest?>
  destinationRequests = ValueNotifier<MarketplaceDestinationRequest?>(null);
  static final ValueNotifier<int> wantedRequests = ValueNotifier<int>(0);

  static void goHome(BuildContext context) {
    homeRequests.value++;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static void goToDestination(BuildContext context, int pageIndex) {
    destinationRequests.value = MarketplaceDestinationRequest(pageIndex);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static void goToBrowse(BuildContext context) => goToDestination(context, 1);

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
}
