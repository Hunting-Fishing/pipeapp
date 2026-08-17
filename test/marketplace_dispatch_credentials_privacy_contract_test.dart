import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dispatch credentials persist only to private business data', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_credentials.dart',
    ).readAsStringSync();

    expect(source, contains("collection('business_private')"));
    expect(source, isNot(contains("collection('public_business_profiles')")));
    expect(source, isNot(contains("collection('dispatch_carriers')")));
    expect(source, contains("'dispatchCredentials': values"));
  });

  test('credential evidence uses the existing private business document path', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_credentials.dart',
    ).readAsStringSync();
    final storageRules = File('firebase/storage.rules').readAsStringSync();

    expect(
      source,
      contains("'business_documents/\$uid/dispatch_credential_\${type.code}_evidence'"),
    );
    expect(storageRules, contains('match /business_documents/{userId}/{fileName}'));
    expect(storageRules, contains('allow read: if isOwner(userId) || isAdmin();'));
  });

  test('public company profile projection contains no credential secrets', () {
    final profileSource = File(
      'lib/marketplace/marketplace_dispatch_company_profile.dart',
    ).readAsStringSync();
    final repositorySource = File(
      'lib/marketplace/marketplace_dispatch_company_profile_repository.dart',
    ).readAsStringSync();

    expect(profileSource, isNot(contains('documentStoragePath')));
    expect(profileSource, isNot(contains('referenceNumber')));
    expect(profileSource, isNot(contains('dispatchCredentials')));
    expect(repositorySource, isNot(contains('dispatchCredentials')));
  });

  test('Company Profile wires the private credentials manager', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_company_profile_page.dart',
    ).readAsStringSync();

    expect(source, contains("import 'marketplace_dispatch_credentials.dart';"));
    expect(source, contains('MarketplaceDispatchCredentialsPage()'));
    expect(source, contains('Manage credentials'));
    expect(source, contains('Supporting evidence stays out of the public Directory profile.'));
  });
}
