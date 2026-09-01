from pathlib import Path

journey_path = Path('lib/marketplace/marketplace_journey_status.dart')
journey = journey_path.read_text(encoding='utf-8')

anchor = "MarketplaceJourneyStatus marketplaceTransactionJourneyStatus(\n"
insert = """MarketplaceJourneyStatus marketplaceWantedJourneyStatus(
  Map<String, dynamic> listing,
) {
  final status = '${listing['status'] ?? listing['wantedStatus'] ?? 'active'}'
      .trim()
      .toLowerCase();
  final matchCount = (listing['matchCount'] as num?)?.toInt() ?? 0;
  final responseCount = (listing['responseCount'] as num?)?.toInt() ?? 0;
  final hasMatchActivity = matchCount > 0 || responseCount > 0;

  switch (status) {
    case 'active':
    case 'open':
      if (hasMatchActivity) {
        return const MarketplaceJourneyStatus(
          currentStatus: 'Wanted request open • matches available',
          nextAction:
              'Review the suggested Marketplace matches and contact a seller when the inventory fits your request. Pause the request if you are not actively buying.',
          responsibleParty: 'Buyer (you)',
          tone: MarketplaceJourneyTone.info,
        );
      }
      return const MarketplaceJourneyStatus(
        currentStatus: 'Wanted request open • matching in progress',
        nextAction:
            'Keep the request details current. Pipe Buyer will continue matching new supply listings and notify you when a suitable match appears.',
        responsibleParty: 'Pipe Buyer matching',
        tone: MarketplaceJourneyTone.info,
      );
    case 'paused':
      return const MarketplaceJourneyStatus(
        currentStatus: 'Wanted request paused',
        nextAction:
            'Reactivate the request when you want matching to resume, or mark it fulfilled if the inventory need has been met.',
        responsibleParty: 'Buyer (you)',
        tone: MarketplaceJourneyTone.warning,
      );
    case 'fulfilled':
      return const MarketplaceJourneyStatus(
        currentStatus: 'Wanted request fulfilled',
        nextAction:
            'No matching action is required. Create a new Wanted request later if you need additional inventory.',
        responsibleParty: 'No action required',
        tone: MarketplaceJourneyTone.success,
      );
    case 'archived':
      return const MarketplaceJourneyStatus(
        currentStatus: 'Wanted request archived',
        nextAction:
            'No action is required. Create a new Wanted request if you need this inventory again.',
        responsibleParty: 'No action required',
        tone: MarketplaceJourneyTone.neutral,
      );
    case 'expired':
      return const MarketplaceJourneyStatus(
        currentStatus: 'Wanted request expired',
        nextAction:
            'Use Renew to create a fresh active request if you still need the inventory.',
        responsibleParty: 'Buyer (you)',
        tone: MarketplaceJourneyTone.warning,
      );
    default:
      return const MarketplaceJourneyStatus(
        currentStatus: 'Wanted request status needs review',
        nextAction:
            'Refresh this request or contact Pipe Buyer support before changing its lifecycle.',
        responsibleParty: 'Pipe Buyer support',
        tone: MarketplaceJourneyTone.warning,
      );
  }
}

""" + anchor
if journey.count(anchor) != 1:
    raise SystemExit(f'journey transaction anchor mismatch: {journey.count(anchor)}')
journey = journey.replace(anchor, insert, 1)
journey_path.write_text(journey, encoding='utf-8')

account_path = Path('lib/marketplace/marketplace_account_hub.dart')
account = account_path.read_text(encoding='utf-8')

old = "import 'marketplace_listing_lifecycle.dart';\nimport 'marketplace_listing_insights.dart';\n"
new = "import 'marketplace_listing_lifecycle.dart';\nimport 'marketplace_journey_status.dart';\nimport 'marketplace_listing_insights.dart';\n"
if account.count(old) != 1:
    raise SystemExit(f'account import anchor mismatch: {account.count(old)}')
account = account.replace(old, new, 1)

old = """  Widget _listingLifecycleCard(Map<String, dynamic> data) {
    final status = '${data['status'] ?? 'active'}';
    final isWanted = data['transactionType'] == 'Wanted / Seeking';
    final busy = _listingActionBusy != null;
"""
new = """  Widget _listingLifecycleCard(Map<String, dynamic> data) {
    final status = '${data['status'] ?? 'active'}';
    final isWanted = data['transactionType'] == 'Wanted / Seeking';
    final wantedJourneyStatus =
        isWanted ? marketplaceWantedJourneyStatus(data) : null;
    final busy = _listingActionBusy != null;
"""
if account.count(old) != 1:
    raise SystemExit(f'account lifecycle state anchor mismatch: {account.count(old)}')
account = account.replace(old, new, 1)

old = """                Chip(label: Text(status.replaceAll('_', ' ').toUpperCase())),
              ]),
              const SizedBox(height: 6),
"""
new = """                Chip(label: Text(status.replaceAll('_', ' ').toUpperCase())),
              ]),
              if (wantedJourneyStatus != null) ...[
                const SizedBox(height: 10),
                MarketplaceJourneyStatusCard(status: wantedJourneyStatus),
              ],
              const SizedBox(height: 6),
"""
if account.count(old) != 1:
    raise SystemExit(f'account lifecycle card anchor mismatch: {account.count(old)}')
account = account.replace(old, new, 1)
account_path.write_text(account, encoding='utf-8')

test_path = Path('test/marketplace_journey_status_test.dart')
test = test_path.read_text(encoding='utf-8')

anchor = "  group('transaction journey status', () {\n"
insert = """  group('Wanted journey status', () {
    test('open request with no activity keeps matching responsibility clear', () {
      final status = marketplaceWantedJourneyStatus({
        'status': 'active',
        'matchCount': 0,
        'responseCount': 0,
      });

      expect(status.currentStatus, 'Wanted request open • matching in progress');
      expect(status.responsibleParty, 'Pipe Buyer matching');
      expect(status.nextAction, contains('continue matching'));
    });

    test('open request with matches tells buyer to review them', () {
      final status = marketplaceWantedJourneyStatus({
        'status': 'active',
        'matchCount': 3,
        'responseCount': 1,
      });

      expect(status.currentStatus, 'Wanted request open • matches available');
      expect(status.responsibleParty, 'Buyer (you)');
      expect(status.nextAction, contains('Review the suggested Marketplace matches'));
    });

    test('paused request assigns reactivate or fulfill decision to buyer', () {
      final status = marketplaceWantedJourneyStatus({'status': 'paused'});

      expect(status.currentStatus, 'Wanted request paused');
      expect(status.responsibleParty, 'Buyer (you)');
      expect(status.nextAction, contains('Reactivate'));
      expect(status.nextAction, contains('mark it fulfilled'));
    });

    test('fulfilled request is terminal without calling it sold', () {
      final status = marketplaceWantedJourneyStatus({'status': 'fulfilled'});

      expect(status.currentStatus, 'Wanted request fulfilled');
      expect(status.currentStatus, isNot(contains('sold')));
      expect(status.responsibleParty, 'No action required');
      expect(status.tone, MarketplaceJourneyTone.success);
    });

    test('expired request points to the existing renew path', () {
      final status = marketplaceWantedJourneyStatus({'status': 'expired'});

      expect(status.currentStatus, 'Wanted request expired');
      expect(status.responsibleParty, 'Buyer (you)');
      expect(status.nextAction, contains('Use Renew'));
    });

    test('unknown Wanted state fails safe to support', () {
      final status = marketplaceWantedJourneyStatus({'status': 'mystery'});

      expect(status.currentStatus, 'Wanted request status needs review');
      expect(status.responsibleParty, 'Pipe Buyer support');
    });
  });

""" + anchor
if test.count(anchor) != 1:
    raise SystemExit(f'test transaction group anchor mismatch: {test.count(anchor)}')
test = test.replace(anchor, insert, 1)

anchor = "  testWidgets('journey card exposes the three simple user questions', (\n"
insert = """  test('Wanted owner lifecycle wires the shared guidance card', () {
    final accountHub = File(
      'lib/marketplace/marketplace_account_hub.dart',
    ).readAsStringSync();

    expect(accountHub, contains("import 'marketplace_journey_status.dart';"));
    expect(accountHub, contains('marketplaceWantedJourneyStatus(data)'));
    expect(
      accountHub,
      contains('MarketplaceJourneyStatusCard(status: wantedJourneyStatus)'),
    );
    expect(accountHub, contains("_transitionListing('mark_fulfilled')"));
    expect(accountHub, contains("_transitionListing('pause')"));
    expect(accountHub, contains("_transitionListing('activate')"));
  });

""" + anchor
if test.count(anchor) != 1:
    raise SystemExit(f'test widget anchor mismatch: {test.count(anchor)}')
test = test.replace(anchor, insert, 1)
test_path.write_text(test, encoding='utf-8')
