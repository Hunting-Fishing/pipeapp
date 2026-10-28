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
  _FakeYellowPagesClient({
    this.counts = PipeBuyerYellowPagesDirectoryCounts.empty,
  });

  final PipeBuyerYellowPagesDirectoryCounts counts;
  List<Map<String, dynamic>>? customItems;
  String lastContinentCode = '';
  String lastCountryCode = '';
  String lastRegionCode = '';
  String lastCity = '';
  String lastTierFilter = '';

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
  Future<PipeBuyerYellowPagesDirectoryCounts> getDirectoryCounts() async {
    return counts;
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
    lastContinentCode = continentCode;
    lastCountryCode = countryCode;
    lastRegionCode = regionCode;
    lastCity = city;
    lastTierFilter = tierFilter;
    if (customItems != null) {
      final filtered = tierFilter == 'verified_only'
          ? customItems!.where((e) => e['verified'] == true).toList()
          : customItems!;
      return PipeBuyerYellowPagesPage<Map<String, dynamic>>(
        items: filtered,
        totalMatched: filtered.length,
      );
    }
    final sample = List<Map<String, dynamic>>.generate(
      12,
      (i) => <String, dynamic>{
        'companyId': 'comp-$i',
        'companyName':
            i == 0 ? 'Apex Permian Hydrovac' : 'Northern Rig Service ${i + 1}',
        'effectiveTier': i == 0
            ? 'featured_platinum'
            : (i == 1
                ? 'paid_verified'
                : (i == 2 ? 'free_verified' : 'free_basic')),
        'verified': i <= 2,
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
    expect(PipeBuyerYellowPagesTaxonomy.categories.length, 30);
    final trainingCat =
        PipeBuyerYellowPagesTaxonomy.byCode('oil_gas_training_courses')!;
    expect(trainingCat.label, 'Oil & Gas Training Facilities & Courses');
    expect(trainingCat.shortLabel, 'Oil & Gas Training & Courses');
    expect(trainingCat.icon, Icons.school_outlined);
    final hotelCat =
        PipeBuyerYellowPagesTaxonomy.byCode('crew_hotels_workforce_lodging')!;
    expect(
      hotelCat.label,
      'Crew Hotels, Extended-Stay & Oilfield Worker Rates',
    );
    expect(hotelCat.shortLabel, 'Crew Hotels & Worker Rates');
    expect(hotelCat.icon, Icons.hotel_outlined);
    expect(PipeBuyerYellowPagesTaxonomy.regionsForCountry('US').length, 51);
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
    expect(
      find.textContaining('12,762 service providers listed'),
      findsOneWidget,
    );

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

    // Verify staged Country -> Province/State + Submit footer on mobile (390x844) has zero overflow
    await tester.tap(find.text('WORLD REGION & COUNTRY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canada').first);
    await tester.pumpAndSettle();
    expect(find.text('Submit'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
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

  testWidgets(
      'Oilfield Directory displays live database business counts across Continents, Countries, Provinces/States, Service Sectors, and every Town',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1500, 960);
    await tester.binding.setSurfaceSize(const Size(1500, 960));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    final liveCounts = PipeBuyerYellowPagesDirectoryCounts.fromJson(const {
      'totalBusinesses': 13480,
      'byContinent': {
        'north_america': 12802,
        'europe': 291,
        'asia': 215,
        'middle_east': 111,
        'africa': 74,
        'south_america': 71,
        'oceania': 41,
      },
      'byCountry': {
        'CA': 4017,
        'US': 8737,
        'GB': 52,
        'AE': 24,
      },
      'byRegion': {
        'CA:AB': 2966,
        'CA:BC': 412,
        'CA:SK': 389,
        'CA:AB T1A0H2': 1,
        'US:TX': 3140,
      },
      'byCategory': {
        'vacuum_hydrovac_fluid': 1842,
        'pipe_octg_supply': 1295,
      },
      'towns': [
        ['Acheson', 'AB', 'CA', 43],
        ['Calgary', 'AB', 'CA', 951],
        ['Edmonton', 'AB', 'CA', 765],
        ['Fort McMurray', 'AB', 'CA', 69],
        ['Grande Prairie', 'AB', 'CA', 162],
        ['Hinton', 'AB', 'CA', 3],
        ['Midland', 'TX', 'US', 318],
      ],
    });

    expect(liveCounts.hasCounts, isTrue);
    expect(
      liveCounts
          .townsForLocation(countryCode: 'CA', regionCode: 'AB')
          .map((t) => t.city),
      containsAll(['Acheson', 'Calgary', 'Grande Prairie', 'Hinton']),
    );

    final fakeClient = _FakeYellowPagesClient(counts: liveCounts);
    await tester.pumpWidget(
      MaterialApp(
        home: PipeBuyerYellowPagesDirectoryPage(client: fakeClient),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Service picker shows total businesses and per-category counts
    await tester.tap(find.text('FILTER BY SERVICE'));
    await tester.pumpAndSettle();
    expect(find.text('13,480'), findsOneWidget);
    expect(find.text('1,842'), findsOneWidget);
    expect(find.text('1,295'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 2. World Region & Country picker shows Continent, Country, and Province/State counts
    await tester.tap(find.text('WORLD REGION & COUNTRY'));
    await tester.pumpAndSettle();
    expect(find.text('12,802'), findsOneWidget);
    await tester.tap(find.text('North America'));
    await tester.pumpAndSettle();
    expect(find.text('4,017'), findsWidgets);
    expect(find.text('8,737'), findsWidgets);

    // Select Canada -> modal stays open so user can pick a Province/State before clicking Submit
    await tester.tap(find.text('Canada').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Filter by World Region, Country & State/Province'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Canada Selected — Choose Province / State / Region (Then Click Submit)',
      ),
      findsOneWidget,
    );
    expect(find.text('All Canada'), findsOneWidget);
    expect(find.text('2,966'), findsOneWidget);
    expect(find.textContaining('T1A0H2'), findsNothing);
    expect(fakeClient.lastCountryCode, isEmpty);

    // Stage Alberta (AB) -> modal remains open until Submit is clicked
    await tester.tap(find.text('Alberta (AB)'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: Alberta (AB), Canada'), findsOneWidget);
    expect(fakeClient.lastRegionCode, isEmpty);

    // Click Submit -> applies Country + Province filter in a single step
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(fakeClient.lastCountryCode, 'CA');
    expect(fakeClient.lastRegionCode, 'AB');

    // 3. Town / City picker shows all database towns for Alberta (including Acheson) with exact business counts
    await tester.tap(find.text('FILTER BY TOWN / CITY'));
    await tester.pumpAndSettle();
    expect(
      find.text('Alberta (AB): 6 towns • 2,966 businesses listed'),
      findsOneWidget,
    );
    expect(find.text('Acheson'), findsOneWidget);
    expect(find.text('43 businesses'), findsOneWidget);
    expect(find.text('Calgary'), findsOneWidget);
    expect(find.text('951 businesses'), findsOneWidget);
    expect(find.text('Grande Prairie'), findsOneWidget);
    expect(find.text('162 businesses'), findsOneWidget);
    expect(find.text('Hinton'), findsOneWidget);
    expect(find.text('3 businesses'), findsOneWidget);

    // Toggle to 'Most Listed' sort order and select Grande Prairie
    await tester.tap(find.text('Most Listed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grande Prairie'));
    await tester.pumpAndSettle();

    expect(fakeClient.lastCity, 'Grande Prairie');
    expect(fakeClient.lastCountryCode, 'CA');
    expect(fakeClient.lastRegionCode, 'AB');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Unverified directory businesses show zero grey VERIFIED badges while verified businesses show green checkmark badge',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1500, 960);
    await tester.binding.setSurfaceSize(const Size(1500, 960));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.binding.setSurfaceSize(null);
    });

    final fakeClient = _FakeYellowPagesClient()
      ..customItems = <Map<String, dynamic>>[
        <String, dynamic>{
          'companyId': 'unver-1',
          'companyName': 'Unverified Standard Trucking Ltd.',
          'effectiveTier': 'free_basic',
          'verified': false,
          'city': 'Red Deer',
          'regionCode': 'AB',
          'countryCode': 'CA',
          'publicPhone': '(403) 555-0191',
          'categories': const ['Trucking, Towing, Winch & Heavy Haul'],
          'services': const ['Winch Truck'],
          'basins': const ['WCSB'],
          'emergency24x7': false,
        },
        <String, dynamic>{
          'companyId': 'unver-2',
          'companyName': 'Second Unverified Welding Inc.',
          'effectiveTier': 'free_basic',
          'verified': false,
          'city': 'Odessa',
          'regionCode': 'TX',
          'countryCode': 'US',
          'publicPhone': '(432) 555-0192',
          'categories': const ['Welding, Machining & Custom Fabrication'],
          'services': const ['Rig Welding'],
          'basins': const ['Permian Basin'],
          'emergency24x7': false,
        },
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: PipeBuyerYellowPagesDirectoryPage(client: fakeClient),
      ),
    );
    await tester.pumpAndSettle();

    // 1. With 100% unverified records: zero VERIFIED badges or green checkmarks appear in Grid View
    expect(find.text('Unverified Standard Trucking Ltd.'), findsOneWidget);
    expect(find.byType(PipeBuyerVerifiedCheckBadge), findsNothing);
    expect(find.text('VERIFIED'), findsNothing);

    // Tap unverified company -> detail sheet shows STANDARD DIRECTORY LISTING (not VERIFIED DIRECTORY)
    await tester.tap(find.text('Unverified Standard Trucking Ltd.'));
    await tester.pumpAndSettle();
    expect(find.text('STANDARD DIRECTORY LISTING'), findsOneWidget);
    expect(find.text('VERIFIED DIRECTORY'), findsNothing);
    expect(find.byType(PipeBuyerVerifiedCheckBadge), findsNothing);
    Navigator.of(tester.element(find.text('STANDARD DIRECTORY LISTING'))).pop();
    await tester.pumpAndSettle();

    // 2. Switch to Lines View -> zero VERIFIED badges appear on unverified rows
    await tester.tap(find.text('Lines View'));
    await tester.pumpAndSettle();
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.byType(PipeBuyerVerifiedCheckBadge), findsNothing);
    expect(find.text('VERIFIED'), findsNothing);

    // 3. Add a genuinely verified business -> green checkmark PipeBuyerVerifiedCheckBadge appears!
    fakeClient.customItems = <Map<String, dynamic>>[
      ...fakeClient.customItems!,
      <String, dynamic>{
        'companyId': 'ver-1',
        'companyName': 'Green Check Verified Wireline Ltd.',
        'effectiveTier': 'free_verified',
        'verified': true,
        'city': 'Leduc',
        'regionCode': 'AB',
        'countryCode': 'CA',
        'publicPhone': '(780) 555-0188',
        'categories': const ['Completions, Frac, Coiled Tubing & Wireline'],
        'services': const ['Wireline'],
        'basins': const ['WCSB'],
        'emergency24x7': false,
      },
    ];

    // Switch back to Grid View and filter to Verified Only (Green Checkmark)
    await tester.tap(find.text('Grid View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BASIN & OPTIONS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Listed Providers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verified Only (Green Checkmark)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply Options'));
    await tester.pumpAndSettle();

    expect(fakeClient.lastTierFilter, 'verified_only');
    expect(find.text('Green Check Verified Wireline Ltd.'), findsOneWidget);
    expect(find.text('Unverified Standard Trucking Ltd.'), findsNothing);
    expect(find.byType(PipeBuyerVerifiedCheckBadge), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
