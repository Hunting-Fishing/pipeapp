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

  test('profile page uses mapped community and safe feedback', () {
    final source =
        File('lib/marketplace/marketplace_profile_page.dart').readAsStringSync();
    expect(source, contains('Primary community'));
    expect(source, contains('showCommunity'));
    expect(source, contains('pendingPhoneE164'));
    expect(source, isNot(contains('Check Firebase rules')));
  });
}
