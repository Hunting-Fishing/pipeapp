import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_navigation.dart';
import 'package:pipe_app/marketplace/marketplace_grouped_navigation.dart';
import 'package:pipe_app/marketplace/marketplace_home_welcome.dart';
import 'package:pipe_app/marketplace/pipebuyer_country_flag_icon.dart';
import 'package:pipe_app/marketplace/pipebuyer_list_services_page.dart';
import 'package:pipe_app/marketplace/pipebuyer_yellow_pages_client.dart';
import 'package:pipe_app/marketplace/pipebuyer_yellow_pages_directory_page.dart';
import 'package:pipe_app/marketplace/pipebuyer_yellow_pages_taxonomy.dart';
import 'package:pipe_app/marketplace/regional_phone_field.dart';

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
    String continentCode = '',
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
        'companyName':
            i == 0 ? 'Apex Permian Hydrovac' : 'Northern Rig Service ${i + 1}',
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
  test(
      'Oilfield Directory taxonomy covers Global Continents, 197 Countries, Popular Quick-Search + A-Z, Town Index, Towing, and clean Pipe & OCTG icon',
      () {
    expect(PipeBuyerYellowPagesTaxonomy.categories.length, 24);
    expect(PipeBuyerYellowPagesTaxonomy.continents.length, 7);
    expect(PipeBuyerYellowPagesTaxonomy.countries.length, 197);

    final naCountries =
        PipeBuyerYellowPagesTaxonomy.countriesForContinent('north_america');
    expect(naCountries.length, 23);
    expect(naCountries.first.name, 'Antigua and Barbuda');
    expect(naCountries.last.name, 'United States');
    // Popular countries remain in their exact alphabetical spot in the A-Z list:
    final naNames = naCountries.map((c) => c.name).toList();
    expect(naNames.indexOf('Canada'), lessThan(naNames.indexOf('Mexico')));
    expect(
      naNames.indexOf('Mexico'),
      lessThan(naNames.indexOf('Trinidad and Tobago')),
    );
    expect(
      naNames.indexOf('Trinidad and Tobago'),
      lessThan(naNames.indexOf('United States')),
    );

    // Popular Quick-Search pins Canada & United States first for North America:
    final naPopular = PipeBuyerYellowPagesTaxonomy.popularCountriesForContinent(
      'north_america',
    );
    expect(naPopular.map((c) => c.code).take(4), ['CA', 'US', 'MX', 'TT']);

    // Middle East countries also appear in Asia A-Z:
    final meCodes = PipeBuyerYellowPagesTaxonomy.countriesForContinent(
      'middle_east',
    ).map((c) => c.code);
    final asiaCodes = PipeBuyerYellowPagesTaxonomy.countriesForContinent('asia')
        .map((c) => c.code);
    expect(meCodes, containsAll(['AE', 'SA', 'QA', 'KW', 'OM']));
    expect(asiaCodes, containsAll(['AE', 'SA', 'QA', 'KW', 'OM', 'SG', 'MY']));

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
      'Vac, Hydrovac & Fluid',
    );
    final pipeCat = PipeBuyerYellowPagesTaxonomy.byCode('pipe_octg_supply')!;
    expect(pipeCat.icon, Icons.plumbing_outlined);
    expect(
      PipeBuyerYellowPagesTaxonomy.conciseCategoryLabel(pipeCat.label),
      'Pipe, OCTG & Casing',
    );
    final towCat = PipeBuyerYellowPagesTaxonomy.byCode('trucking_heavy_haul')!;
    expect(towCat.label, 'Trucking, Towing, Winch & Heavy Haul');
    expect(towCat.shortLabel, 'Trucking, Towing & Winch');
    expect(PipeBuyerYellowPagesTaxonomy.oilfieldHubs.length, greaterThan(150));
    expect(
      PipeBuyerYellowPagesTaxonomy.oilfieldHubs.any(
        (h) => h.city == 'Nisku' && h.regionCode == 'AB',
      ),
      isTrue,
    );
    expect(
      PipeBuyerYellowPagesTaxonomy.oilfieldHubs.any(
        (h) => h.city == 'Midland' && h.regionCode == 'TX',
      ),
      isTrue,
    );
    expect(
      PipeBuyerYellowPagesTaxonomy.oilfieldHubs.any(
        (h) => h.city == 'Aberdeen' && h.countryCode == 'GB',
      ),
      isTrue,
    );
    expect(
      PipeBuyerYellowPagesTaxonomy.oilfieldHubs.any(
        (h) => h.city == 'Abu Dhabi' && h.countryCode == 'AE',
      ),
      isTrue,
    );
    expect(PipeBuyerYellowPagesTaxonomy.oilfieldHubs.length, greaterThan(240));
    expect(
        PipeBuyerYellowPagesTaxonomy.basins.length, greaterThanOrEqualTo(35));
    expect(
      PipeBuyerYellowPagesTaxonomy.certifications.length,
      greaterThanOrEqualTo(12),
    );
    for (final intlCode in <String>[
      'GB',
      'NO',
      'AE',
      'SA',
      'BR',
      'AU',
      'MX',
      'TT',
      'IN',
      'NG',
    ]) {
      expect(
        PipeBuyerYellowPagesTaxonomy.regionsForCountry(intlCode),
        isNotEmpty,
        reason: 'Expected sub-regions for $intlCode',
      );
    }
    expect(
      PipeBuyerYellowPagesTaxonomy.formatLocationLabel(
        city: 'Midland',
        regionCode: 'TX',
        countryCode: 'US',
      ),
      'Midland, TX',
    );
    expect(
      PipeBuyerYellowPagesTaxonomy.formatLocationLabel(
        city: 'Aberdeen',
        regionCode: 'SCT',
        countryCode: 'GB',
      ),
      'Aberdeen, SCT, UK',
    );
    expect(
      PipeBuyerYellowPagesTaxonomy.formatLocationLabel(
        city: 'Doha',
        regionCode: 'QA',
        countryCode: 'QA',
      ),
      'Doha, Qatar',
    );
  });

  test(
      'PipeBuyerCountryFlagIcon supplies pure vector 3:2 SVG flags for all 197 directory countries and 195+ phone regions',
      () {
    expect(
        PipeBuyerCountryFlagIcon.supportedFlagCount, greaterThanOrEqualTo(250));
    for (final country in PipeBuyerYellowPagesTaxonomy.countries) {
      final svg = PipeBuyerCountryFlagIcon.svgForCountry(country.code);
      expect(
        svg,
        isNotNull,
        reason:
            'Missing SVG flag for directory country ${country.code} (${country.name})',
      );
      expect(svg, startsWith('<svg '));
    }
    for (final region in phoneRegions) {
      final svg = PipeBuyerCountryFlagIcon.svgForCountry(region.code);
      expect(
        svg,
        isNotNull,
        reason:
            'Missing SVG flag for phone region ${region.code} (${region.name})',
      );
      expect(svg, startsWith('<svg '));
    }
    expect(PipeBuyerCountryFlagIcon.svgForCountry('UK'), isNotNull);
    expect(PipeBuyerCountryFlagIcon.svgForCountry('UAE'), isNotNull);
    expect(PipeBuyerCountryFlagIcon.svgForCountry('USA'), isNotNull);
    expect(PipeBuyerCountryFlagIcon.svgForCountry('KSA'), isNotNull);
  });

  test(
      'PipeBuyerYellowPagesAccess resolves agent, manager, and administrator privileges',
      () {
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
    expect(find.textContaining('Oilfield Directory'), findsOneWidget);

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
      'Left sidebar grouped navigation exposes Search for Services, List Services, and Directory Admin controls',
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
    expect(find.text('Directory Admin'), findsOneWidget);

    await tester.tap(find.text('Search for Services'));
    await tester.tap(find.text('List Services'));
    await tester.tap(find.text('Directory Admin'));
    await tester.pump();

    expect(searchTapped, 1);
    expect(listTapped, 1);
    expect(adminTapped, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Oilfield Directory renders unified wrapping dropdown filters, zero Claim buttons, and desktop + mobile responsive views',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1500, 960);
    await tester.binding.setSurfaceSize(const Size(1500, 960));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: PipeBuyerYellowPagesDirectoryPage(
          client: _FakeYellowPagesClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('PIPEBUYER OILFIELD DIRECTORY • SEARCH SERVICES'),
      findsOneWidget,
    );
    expect(find.textContaining('Yellow Pages'), findsNothing);
    expect(find.textContaining('Claim'), findsNothing);
    expect(find.textContaining('12,762 verified service providers'),
        findsOneWidget);

    // Unified wrapping filter dropdown boxes
    expect(find.text('FILTER BY SERVICE'), findsOneWidget);
    expect(find.text('WORLD REGION & COUNTRY'), findsOneWidget);
    expect(find.text('All Global (Worldwide)'), findsOneWidget);
    expect(find.text('FILTER BY TOWN / CITY'), findsOneWidget);
    expect(find.text('ALPHABETICAL & SORT'), findsOneWidget);
    expect(find.text('BASIN & OPTIONS'), findsOneWidget);

    // Country flag icons render on directory cards
    expect(find.byType(PipeBuyerCountryFlagIcon), findsWidgets);

    // Open World Region & Country modal and verify Continents + Popular Quick-Search + A-Z + Flags
    await tester.tap(find.text('WORLD REGION & COUNTRY'));
    await tester.pumpAndSettle();
    expect(
      find.text('Filter by World Region, Country & State/Province'),
      findsOneWidget,
    );
    expect(find.text('North America'), findsOneWidget);
    expect(find.text('Middle East'), findsOneWidget);
    expect(find.text('Europe'), findsOneWidget);
    expect(find.text('Asia'), findsOneWidget);
    expect(
      find.text('POPULAR OIL & GAS COUNTRIES — QUICK SEARCH'),
      findsOneWidget,
    );
    expect(find.byType(PipeBuyerCountryFlagIcon), findsWidgets);
    await tester.tap(find.text('North America'));
    await tester.pumpAndSettle();
    expect(
      find.text('Show All North America (23 Countries)'),
      findsOneWidget,
    );
    expect(find.text('Canada'), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Grid View'), findsOneWidget);
    expect(find.text('Lines View'), findsOneWidget);
    expect(find.text('Auto (5/row)'), findsOneWidget);
    expect(find.text('6/row'), findsOneWidget);

    // Switch to 6/row grid density
    await tester.tap(find.text('6/row'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Open Town / City picker dialog
    await tester.tap(find.text('FILTER BY TOWN / CITY'));
    await tester.pumpAndSettle();
    expect(find.text('Filter by Town / City'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Open Alphabetical & Sort dialog
    await tester.tap(find.text('ALPHABETICAL & SORT'));
    await tester.pumpAndSettle();
    expect(find.text('Alphabetical Filter & Sort Order'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Switch to High-Density Lines View on desktop
    await tester.tap(find.text('Lines View'));
    await tester.pumpAndSettle();
    expect(find.text('COMPANY NAME'), findsOneWidget);
    expect(find.text('PRIMARY SERVICES & CATEGORIES'), findsOneWidget);
    expect(find.text('Apex Permian Hydrovac'), findsOneWidget);
    expect(find.textContaining('Claim'), findsNothing);
    expect(tester.takeException(), isNull);

    // Resize to mobile phone (390x844) and verify both Lines View and Grid View have zero overflow
    tester.view.physicalSize = const Size(390, 844);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.text('OILFIELD DIRECTORY'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Grid'));
    await tester.pumpAndSettle();
    expect(find.text('Apex Permian Hydrovac'), findsOneWidget);
    expect(find.textContaining('Claim'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'List Services page renders country flag icons in Popular Quick-Select, 197-country dropdown, and phone prefix',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PipeBuyerListServicesPage(
          client: _FakeYellowPagesClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Popular Oil & Gas Markets (Quick Select):'),
      findsOneWidget,
    );
    expect(
      find.text('Submit Service Listing (Verified Pro)', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(PipeBuyerCountryFlagIcon), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
