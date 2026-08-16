import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dispatch profile persistence uses existing owner-scoped business records', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_company_profile_repository.dart',
    ).readAsStringSync();

    expect(source, contains("collection('dispatch_carriers')"));
    expect(source, contains("collection('public_business_profiles')"));
    expect(source, contains("collection('business_private')"));
    expect(source, contains("'dispatchProfile': publicProfile"));
    expect(source, contains("'dispatchProfile': privateProfile"));
  });

  test('legal company identity is not copied into the public Dispatch projection', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_company_profile_repository.dart',
    ).readAsStringSync();

    final publicStart = source.indexOf('final publicProfile = <String, dynamic>{');
    final privateStart = source.indexOf('final privateProfile = <String, dynamic>{');
    expect(publicStart, greaterThanOrEqualTo(0));
    expect(privateStart, greaterThan(publicStart));

    final publicBlock = source.substring(publicStart, privateStart);
    expect(publicBlock, isNot(contains("'companyName'")));
    expect(publicBlock, isNot(contains('ownerUid')));
    expect(publicBlock, isNot(contains('email')));
    expect(publicBlock, isNot(contains('phone')));
    expect(publicBlock, isNot(contains('insurance')));

    final privateBlock = source.substring(privateStart);
    expect(privateBlock, contains("'companyName': draft.companyName.trim()"));
  });

  test('registered provider wiring opens company editor without removing signup', () {
    final source =
        File('tool/apply_dispatch_phase3_profile_persistence.mjs')
            .readAsStringSync();

    expect(source, contains('MarketplaceDispatchCompanyProfilePage()'));
    expect(source, contains('_CarrierEnrollment(repo: repo)'));
    expect(source, contains('accountState.providerRegistered'));
    expect(source, contains('FirebaseAuth.instance.authStateChanges()'));
  });
}
