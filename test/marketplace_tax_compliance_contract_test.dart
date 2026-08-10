import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tax profile and admin compliance routes require authentication', () {
    final nav = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();

    expect(nav, contains("path: '/account/tax-profile'"));
    expect(nav, contains("path: '/admin/tax-compliance'"));
    expect(
      nav,
      contains(
        "name: 'marketplaceTaxProfile',\n          path: '/account/tax-profile',\n          requireAuth: true",
      ),
    );
    expect(
      nav,
      contains(
        "name: 'marketplaceTaxComplianceAdmin',\n          path: '/admin/tax-compliance',\n          requireAuth: true",
      ),
    );
  });

  test('user tax profile uses protected callable commands', () {
    final source = File(
      'lib/marketplace/marketplace_tax_profile_page.dart',
    ).readAsStringSync();

    expect(source, contains("getMarketplaceTaxProfile"));
    expect(source, contains("updateMarketplaceTaxProfile"));
    expect(source, contains("submitMarketplaceTaxExemptionClaim"));
    expect(source, isNot(contains("collection('business_tax_profiles')")));
    expect(source, contains('PST number does not automatically'));
  });

  test('private exemption evidence never creates a download token', () {
    final source = File(
      'lib/marketplace/marketplace_tax_compliance_admin_page.dart',
    ).readAsStringSync();
    final storageRules = File('firebase/storage.rules').readAsStringSync();

    expect(source, isNot(contains('getDownloadURL')));
    expect(source, contains('getData(15 * 1024 * 1024)'));
    expect(storageRules, contains('match /business_documents/{userId}/{fileName}'));
    expect(storageRules, contains('allow read: if isOwner(userId) || isAdmin();'));
  });

  test('tax responsibility terms preserve statutory platform obligations', () {
    final terms = File(
      'docs/MARKETPLACE_TAX_INFORMATION_AND_EXEMPTION_TERMS.md',
    ).readAsStringSync();

    expect(terms, contains('To the fullest extent permitted by applicable law'));
    expect(terms, contains('indemnify, reimburse and hold harmless Pipe Buyer'));
    expect(terms, contains('Statutory obligations are not disclaimed'));
    expect(terms, contains('Nothing in these terms excludes, transfers or limits'));
    expect(terms, contains('Recovery, reserves, set-off and payout holds'));
  });

  test('checkout blocks open tax recovery holds and snapshots tax policy', () {
    final source = File(
      'firebase/functions/stripe_checkout_commands.js',
    ).readAsStringSync();

    expect(source, contains('taxComplianceHold === true'));
    expect(source, contains('taxComplianceSnapshot'));
    expect(source, contains('taxResponsibilityTermsVersion'));
    expect(source, contains('tax_id_collection[enabled]'));
  });
}
