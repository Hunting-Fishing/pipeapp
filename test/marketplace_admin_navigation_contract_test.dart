import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account navigation never grants admin visibility by email', () {
    final source =
        File('lib/marketplace/marketplace_account_hub.dart').readAsStringSync();
    expect(source, isNot(contains('jordilwbailey@gmail.com')));
    expect(source, isNot(contains('goldcity4u@icloud.com')));
    expect(source, isNot(contains('isMasterAdmin')));
    expect(source, contains('marketplaceAdministratorState'));
    expect(source, contains('MarketplaceAdministratorState.authorized'));
    expect(source, contains('forceRefresh: true'));
    expect(source, contains('Administrator role not assigned'));
    expect(source, contains('Administrator sign-in requires MFA'));
  });

  test('unauthorized admin screen does not disclose approved identities', () {
    final source = File('lib/marketplace/marketplace_admin_dashboard.dart')
        .readAsStringSync();
    expect(source, isNot(contains('Only master administrator')));
    expect(source, isNot(contains('Current Account:')));
    expect(source, contains('approved administrator account'));
  });

  test(
      'admin portals live exclusively inside Admin Dashboard and never clutter customer navigation or directories',
      () {
    final groupedNav = File(
      'lib/marketplace/marketplace_grouped_navigation.dart',
    ).readAsStringSync();
    final marketplaceShell = File(
      'lib/marketplace/oil_gas_marketplace.dart',
    ).readAsStringSync();
    final yellowPages = File(
      'lib/marketplace/pipebuyer_yellow_pages_directory_page.dart',
    ).readAsStringSync();
    final partnerPage = File(
      'lib/marketplace/pipebuyer_partner_with_us_page.dart',
    ).readAsStringSync();
    final insuranceHub = File(
      'lib/marketplace/pipebuyer_insurance_hub_page.dart',
    ).readAsStringSync();
    final adminDashboard = File(
      'lib/marketplace/marketplace_admin_dashboard.dart',
    ).readAsStringSync();

    // Customer navigation & customer directories keep normal user links and omit * Admin links
    expect(groupedNav, contains("'Search for Services'"));
    expect(groupedNav, contains("'List Services'"));
    expect(groupedNav, contains("'Commercial Insurance'"));
    expect(groupedNav, isNot(contains('Directory Admin')));
    expect(groupedNav, isNot(contains('Insurance Admin')));
    expect(groupedNav, isNot(contains('Partner Admin')));

    expect(marketplaceShell, isNot(contains("label: 'Directory Admin'")));
    expect(marketplaceShell, isNot(contains("label: 'Insurance Admin'")));
    expect(marketplaceShell, isNot(contains("label: 'Partner Admin'")));

    expect(yellowPages, isNot(contains('Directory Admin')));
    expect(partnerPage, isNot(contains('Partner Admin')));
    expect(insuranceHub, isNot(contains('Insurance Admin')));

    // All specialized admin portals and "View What Everyone Else Sees" live inside Admin Dashboard
    expect(
      adminDashboard,
      contains('Oilfield Directory Admin & Flagged Businesses'),
    );
    expect(adminDashboard, contains('Commercial & Oilfield Insurance Admin'));
    expect(adminDashboard, contains('Partner With Us & OEM Showcases Queue'));
    expect(adminDashboard, contains('View What Everyone Else Sees'));
  });
}
