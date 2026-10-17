import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final repository = File(
    'lib/marketplace/marketplace_actions_repository.dart',
  ).readAsStringSync();
  final settlement = File(
    'lib/marketplace/marketplace_auction_settlement.dart',
  ).readAsStringSync();

  test('Timed Buying chat requests the canonical transaction binding', () {
    expect(repository, contains('ensureTimedBuyingConversation'));
    expect(
      repository,
      contains("'marketplaceTransactionId': 'auction_\$normalizedListingId'"),
    );
    expect(repository, contains("'participantUid': normalizedWinnerUid"));
  });

  test('seller settlement UI exposes Message winner through the safe command',
      () {
    expect(settlement, contains("uid == sale['sellerUid']"));
    expect(settlement, contains("const Text('Message winner')"));
    expect(settlement, contains('ensureTimedBuyingConversation('));
    expect(
      settlement,
      contains('MarketplaceDeepLinks.conversation(conversationId)'),
    );
  });
}
