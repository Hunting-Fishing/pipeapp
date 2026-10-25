import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_navigation.dart';
import 'package:pipe_app/marketplace/marketplace_grouped_navigation.dart';
import 'package:pipe_app/marketplace/marketplace_home_welcome.dart';
import 'package:pipe_app/marketplace/pipebuyer_yellow_pages_client.dart';
import 'package:pipe_app/marketplace/pipebuyer_yellow_pages_directory_page.dart';
import 'package:pipe_app/marketplace/pipebuyer_yellow_pages_taxonomy.dart';

class _FakeYellowPagesClient extends PipeBuyerYellowPagesClient {
  @override
  Future<PipeBuyerYellowPagesAccess> getAccess() async {
    return const PipeBuyerYellowPagesAccess(
      authorized: false,
      role: null,
      isAdmin: false,
      reason: 'signed_out',
    );
  }

  @override
  Future<PipeBuyerYellowPagesPage<Map<String, dynamic>>> searchPublic({
    String query = '',
    String countryCode = '',
    String regionCode = '',
    String city = '',
    String categoryCode = '',
    String basin = '',
    String certification = '',
    bool emergency24x7 = false,
    bool paidOnly = false,
    String tierFilter = '',
    bool hasTollFree = false,
    String startsWith = '',
    String sortBy = 'priority',
    int offset = 0,
    int pageSize = 60,
  }) async {
    final sample = List<Map<String, dynamic>>.generate(
      12,
      (i) => <String, dynamic>{
        'companyId': 'comp-$i',
        'companyName': i == 0
            ? 'Apex Permian Hydrovac'
            : 'Northern Rig Service ${i + 1}',
        'effectiveTier': i == 0
            ? 'featured_platinum'
            : (i == 1 ? 'paid_verified' : 'free_verified'),
        'city': i.isEven ? 'Midland' : 'Nisku',
        'regionCode': i.isEven ? 'TX' : 'AB',
        'countryCode': i.isEven ? 'US' : 'CA',
        'publicPhone': '(403) 555-01${i.toString().padLeft(2, '0')}',
        'categories': const ['Vacuum, Hydrovac & Fluid Hauling'],
        'services': const ['Hydrovac', 'Water Hauling'],
        'basins': i.isEven ? const ['Permian Basin'] : const ['WCSB'],
        'emergency24x7': i < 2,
      },
    );
    return PipeBuyerYellowPagesPage<Map<String, dynamic>>(
      items: sample,
      totalMatched: 12762,
    );
  }
}

void main() {
  test('Yellow Pages taxonomy covers Canada and USA oilfield regions and categories', () {
    expect(PipeBuyerYellowPagesTaxonomy.categories.length, 24);
    final caRegions = PipeBuyerYellowPagesTaxonomy.regionsForCountry('CA');
    final usRegions = PipeBuyerYellowPagesTaxonomy.regionsForCountry('US');
    expect(caRegions.any((r) => r.regionCode == 'AB'), isTrue);
    expect(caRegions.any((r) => r.regionCode == 'BC'), isTrue);
    expect(caRegions.any((r) => r.regionCode == 'SK'), isTrue);
    expect(usRegions.any((r) => r.regionCode == 'TX'), isTrue);
    expect(usRegions.any((r) => r.regionCode == 'ND'), isTrue);
    expect(usRegions.any((r) => r.regionCode == 'OK'), isTrue);
    expect(
      PipeBuyerYellowPagesTaxonomy.byCode('vacuum_hydrovac_fluid')?.shortLabel,
      'Vac & Hydrovac',
    );
  });

  test('PipeBuyerYellowPagesAccess resolves agent, manager, and administrator privileges', () {
    final admin = PipeBuyerYellowPagesAccess.fromJson(const {
      'authorized': true,
      'role': 'administrator',
      'isAdmin': true,
    });
    expect(admin.isAdministrator, isTrue);
    expect(admin.isManager, isTrue);
    expect(admin.isAgent, isTrue);

    final agent = PipeBuyerYellowPagesAccess.fromJson(const {
      'authorized': true,
      'role': 'agent',
      'isAdmin': false,
    });
    expect(agent.isAdministrator, isFalse);
    expect(agent.isManager, isFalse);
    expect(agent.isAgent, isTrue);
  });

  testWidgets(
      'Home What do you want to do? renders Search for services and List services actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var searchTapped = 0;
    var listTapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarketplaceHomeIntentActions(
              onBrowse: () {},
              onSell: () {},
              onDispatch: () {},
              onWanted: () {},
              onSearchServices: () => searchTapped += 1,
              onListServices: () => listTapped += 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text('What do you want to do?'), findsOneWidget);
    expect(find.text('Search for services'), findsOneWidget);
    expect(find.text('List services'), findsOneWidget);

    await tester.tap(find.text('Search for services'));
    await tester.tap(find.text('List services'));
    await tester.pump();

    expect(searchTapped, 1);
    expect(listTapped, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Dispatch navigation and customer home expose Search for Services and List Services',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MarketplaceDispatchNavigation(
                selected: DispatchSection.dashboard,
                accountState:
                    DispatchAccountState.fromCarrierProfile(exists: false),
                onSelected: (_) {},
                onProviderAction: () {},
              ),
              Expanded(
                child: MarketplaceDispatchCustomerHome(
                  onRequestService: () {},
                  onBrowseDirectory: () {},
                  onBrowseJobs: () {},
                  onListBusiness: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Search for Services'), findsAtLeastNWidgets(2));
    expect(find.text('List Services (Priority Ad)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Left sidebar grouped navigation exposes Search for Services, List Services, and Admin controls',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var searchTapped = 0;
    var listTapped = 0;
    var adminTapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 268,
            height: 820,
            child: MarketplaceGroupedNavigation(
              selectedPageIndex: 0,
              marketplaceEnabled: true,
              auctionsEnabled: true,
              dispatchEnabled: true,
              isAdmin: true,
              onDestinationSelected: (_) {},
              onWanted: () {},
              onSearchServices: () => searchTapped += 1,
              onListServices: () => listTapped += 1,
              onYellowPagesAdmin: () => adminTapped += 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text('SERVICES & DIRECTORY'), findsOneWidget);
    expect(find.text('Search for Services'), findsOneWidget);
    expect(find.text('List Services'), findsOneWidget);
    expect(find.text('Yellow Pages Admin'), findsOneWidget);

    await tester.tap(find.text('Search for Services'));
    await tester.tap(find.text('List Services'));
    await tester.tap(find.text('Yellow Pages Admin'));
    await tester.pump();

    expect(searchTapped, 1);
    expect(listTapped, 1);
    expect(adminTapped, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Directory page renders 4-6 responsive Grid View, Lines View, and enhanced filters cleanly',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PipeBuyerYellowPagesDirectoryPage(
          client: _FakeYellowPagesClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('12,762 verified service providers'), findsOneWidget);
    expect(find.text('Grid View'), findsOneWidget);
    expect(find.text('Lines View'), findsOneWidget);
    expect(find.text('Auto (5/row)'), findsOneWidget);
    expect(find.text('6/row'), findsOneWidget);

    // Switch to 6/row grid density
    await tester.tap(find.text('6/row'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Expand More Filters & A-Z drawer
    await tester.tap(find.text('More Filters & A–Z'));
    await tester.pumpAndSettle();
    expect(find.text('A–Z INDEX:'), findsOneWidget);
    expect(find.text('Has Toll-Free (1-800)'), findsOneWidget);

    // Switch to High-Density Lines View
    await tester.tap(find.text('Lines View'));
    await tester.pumpAndSettle();
    expect(find.text('COMPANY NAME'), findsOneWidget);
    expect(find.text('PRIMARY SERVICES & CATEGORIES'), findsOneWidget);
    expect(find.text('Apex Permian Hydrovac'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
