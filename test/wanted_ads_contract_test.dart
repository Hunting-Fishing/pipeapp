import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final accountHub = File(
    'lib/marketplace/marketplace_account_hub.dart',
  ).readAsStringSync();
  final rules = File('firebase/firestore.rules').readAsStringSync();

  test('wanted owner view uses the one bounded match collection', () {
    expect(accountHub, contains(".collection('wanted_matches')"));
    expect(accountHub, contains("? 'wantedListingId'"));
    expect(accountHub, contains(": 'supplyListingId'"));
    expect(accountHub, contains(".orderBy('score', descending: true)"));
    expect(accountHub, contains('.limit(30)'));
    expect(accountHub, contains("execute('manageWantedMatch'"));
    expect(accountHub, contains('Contact seller'));
    expect(accountHub, contains('Contact buyer'));
    expect(accountHub, contains('Dismissed matches'));
    expect(accountHub, contains('Match activity'));
  });

  test('wanted lifecycle is distinct from sale and auction controls', () {
    expect(accountHub, contains("_transitionListing('mark_fulfilled')"));
    expect(accountHub, contains('!isAuction && !isWanted'));
    expect(accountHub, contains('Mark request fulfilled'));
  });

  test('wanted match data is not client writable', () {
    expect(rules, contains('match /wanted_matches/{matchId}'));
    expect(rules, contains('resource.data.wantedOwnerUid'));
    expect(rules, contains('resource.data.sellerUid'));
    expect(rules, contains('match /events/{eventId}'));
  });
}
