import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Directory exposes functional business actions', () {
    final directory = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync();
    final actions = File(
      'lib/marketplace/marketplace_dispatch_directory_actions.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/marketplace/marketplace_actions_repository.dart',
    ).readAsStringSync();
    final communication = File(
      'firebase/functions/communication_commands.js',
    ).readAsStringSync();
    final functionsIndex = File(
      'firebase/functions/index.js',
    ).readAsStringSync();

    expect(
      directory,
      contains('MarketplaceDispatchDirectoryBusinessActions('),
    );
    for (final marker in [
      "label: const Text('Get Quote')",
      "label: const Text('Message')",
      "label: const Text('View Business')",
      "tooltip: 'Call published business phone'",
      "tooltip: 'Email published business address'",
      "tooltip: 'Open business website'",
      "title: Text('Report Business')",
      "targetType: 'profile'",
      'GET QUOTE REQUEST',
    ]) {
      expect(actions, contains(marker), reason: 'Missing action marker: $marker');
    }

    expect(repository, contains('Future<String> openBusinessConversation'));
    expect(repository, contains("_commands.execute('openBusinessConversation'"));
    expect(communication, contains('function businessConversationIdFor('));
    expect(communication, contains('const openBusinessConversation = secured('));
    expect(communication, contains('contextType: "business"'));
    expect(communication, contains('memberUids'));
    expect(functionsIndex, contains('exports.openBusinessConversation = onCall('));
  });

  test('membership and reputation are independent dual rings', () {
    final badge = File(
      'lib/marketplace/marketplace_reputation_badge.dart',
    ).readAsStringSync();

    for (final marker in [
      'MarketplaceMembershipTier.standard',
      'MarketplaceMembershipTier.bronze',
      'MarketplaceMembershipTier.silver',
      'MarketplaceMembershipTier.gold',
      'MarketplaceMembershipTier.vip',
      'border: Border.all(color: membershipTier.color, width: 4)',
      'border: Border.all(color: summary.reputationColor, width: 4)',
      'Blue — New / building history',
      'Dark green — 90–100 Excellent',
      'Yellow — 70–79 Good',
      'Orange — 60–69 Watch',
      'Red — below 60 At risk',
      'Membership is not the same as reputation',
      'Raw user reports do not automatically reduce a score',
      'Building reputation',
    ]) {
      expect(badge, contains(marker), reason: 'Missing reputation marker: $marker');
    }
  });
}
