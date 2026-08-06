import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile persistence handles a missing private user document', () {
    final source = File(
      'lib/marketplace/marketplace_profile_repository.dart',
    ).readAsStringSync();
    expect(source, contains('runTransaction'));
    expect(source, contains("'userScore': 70"));
    expect(source, contains("'accountVerified': false"));
    expect(source, contains("'primaryCommunityLocation'"));
    expect(source, contains("'primaryCommunityGeoPoint'"));
  });

  test('profile page uses predictive mapped community and safe feedback', () {
    final profileSource =
        File('lib/marketplace/marketplace_profile_page.dart').readAsStringSync();
    final selectorSource = File(
      'lib/marketplace/marketplace_primary_community_selector.dart',
    ).readAsStringSync();

    expect(profileSource, contains('MarketplacePrimaryCommunitySelector'));
    expect(profileSource, contains('pendingPhoneE164'));
    expect(profileSource, isNot(contains('Check Firebase rules')));

    expect(selectorSource, contains('Primary community or operating area'));
    expect(selectorSource, contains('OpenAddressAutocomplete'));
    expect(selectorSource, contains('showCommunity'));
    expect(selectorSource, contains('Check or adjust map pin'));
  });
}
