import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/flutter_flow/nav/nav.dart';
import 'package:pipe_app/marketplace/marketplace_deep_links.dart';
import 'package:pipe_app/marketplace/marketplace_grouped_navigation.dart';
import 'package:pipe_app/marketplace/marketplace_home_welcome.dart';
import 'package:pipe_app/marketplace/pipebuyer_insurance_admin_page.dart';
import 'package:pipe_app/marketplace/pipebuyer_insurance_client.dart';
import 'package:pipe_app/marketplace/pipebuyer_insurance_hub_page.dart';
import 'package:pipe_app/marketplace/pipebuyer_insurance_provider_apply_page.dart';
import 'package:pipe_app/marketplace/pipebuyer_insurance_taxonomy.dart';

class _FakeInsuranceClient extends PipeBuyerInsuranceClient {
  _FakeInsuranceClient({
    this.signedIn = false,
    this.isAdmin = false,
    List<InsuranceProviderListing>? providers,
  }) : _providers = List<InsuranceProviderListing>.from(
         providers ??
             const <InsuranceProviderListing>[
               InsuranceProviderListing(
                 providerId: 'prov_permian_mga',
                 companyName: 'Lone Star Basin Risk MGA',
                 providerType: 'mga',
                 publicEmail: 'quotes@lonestarrisk.example.com',
                 publicPhone: '(432) 555-0177',
                 countryCode: 'US',
                 regionCode: 'TX',
                 headquartersCity: 'Midland',
                 licensedCountries: <String>['US'],
                 licensedRegions: <String>['TX', 'NM', 'OK', 'ND'],
                 operatingBasins: <String>['Permian Basin', 'Anadarko / SCOOP-STACK'],
                 coverageLines: <String>[
                   'commercial_auto_fleet',
                   'oilfield_general_liability',
                   'motor_truck_cargo_hazmat',
                   'umbrella_excess_liability',
                 ],
                 licenseSummary: 'Texas TDI MGA #884120',
                 amBestRating: 'A+ (Superior)',
                 maxLimitUsd: 25000000,
                 minimumPremiumUsd: 7500,
                 fastCoi24x7: true,
                 msaCompliant: true,
                 featured: true,
                 summary:
                     'ISNetworld & Veriforce ready oilfield fleet, cargo, and MSA excess programs.',
               ),
               InsuranceProviderListing(
                 providerId: 'prov_wcsb_broker',
                 companyName: 'Prairie Foothills Energy Insurance',
                 providerType: 'specialty_broker',
                 publicEmail: 'desk@prairieenergy.example.ca',
                 publicPhone: '(403) 555-0133',
                 countryCode: 'CA',
                 regionCode: 'AB',
                 headquartersCity: 'Calgary',
                 licensedCountries: <String>['CA'],
                 licensedRegions: <String>['AB', 'SK', 'BC'],
                 operatingBasins: <String>['WCSB (Alberta / BC / SK)'],
                 coverageLines: <String>[
                   'rig_equipment_inland_marine',
                   'pollution_environmental',
                 ],
                 licenseSummary: 'Alberta AIC #55219',
                 amBestRating: 'A (Excellent)',
                 maxLimitUsd: 15000000,
                 minimumPremiumUsd: 5000,
                 fastCoi24x7: false,
                 msaCompliant: true,
                 featured: false,
                 summary:
                     'Canadian rig equipment, inland marine, and environmental liability desk.',
               ),
             ],
       );

  final bool signedIn;
  final bool isAdmin;
  final List<InsuranceProviderListing> _providers;

  final List<Map<String, Object?>> submittedRatePayloads =
      <Map<String, Object?>>[];
  final List<Map<String, Object?>> submittedProviderPayloads =
      <Map<String, Object?>>[];
  final List<Map<String, Object?>> reviewedProviderDecisions =
      <Map<String, Object?>>[];
  final List<Map<String, Object?>> rateStatusUpdates = <Map<String, Object?>>[];
  final List<Map<String, Object?>> upsertedProviders = <Map<String, Object?>>[];

  final List<InsuranceRateApplicationSummary> myRateApps =
      <InsuranceRateApplicationSummary>[];

  final List<Map<String, dynamic>> adminProviderApps = <Map<String, dynamic>>[
    <String, dynamic>{
      'applicationId': 'papp_101',
      'companyName': 'Gulf Coast Specialty Underwriters',
      'providerType': 'carrier',
      'contactName': 'Morgan Vance',
      'email': 'underwriting@gulfcoastcarrier.example.com',
      'phone': '(713) 555-0190',
      'licenseSummary': 'NAIC #44109 • TX / LA Admitted',
      'amBestRating': 'A+ (Superior)',
      'coverageLines': <String>[
        'oilfield_general_liability',
        'umbrella_excess_liability',
      ],
      'status': 'pending_review',
      'summary': 'Direct upstream & midstream casualty carrier.',
    },
  ];

  final List<InsuranceRateApplicationSummary> adminRateApps =
      <InsuranceRateApplicationSummary>[
        const InsuranceRateApplicationSummary(
          applicationId: 'rapp_201',
          companyName: 'Redwater Tubular & Hotshot LLC',
          contactName: 'Casey Miller',
          email: 'safety@redwaterhotshot.example.com',
          phone: '(432) 555-0148',
          countryCode: 'US',
          regionCode: 'TX',
          city: 'Odessa',
          coverageLines: <String>[
            'commercial_auto_fleet',
            'motor_truck_cargo_hazmat',
          ],
          fleetVehicleCount: 14,
          equipmentValueUsd: 950000,
          annualRevenueBand: '2m_10m',
          status: 'new',
        ),
      ];

  @override
  bool get isSignedIn => signedIn;

  @override
  String get currentUserEmail =>
      signedIn ? 'ops@redwaterhotshot.example.com' : '';

  @override
  String get currentUserDisplayName => signedIn ? 'Casey Miller' : '';

  @override
  Future<bool> checkAdministratorAccess({bool forceRefresh = true}) async =>
      isAdmin;

  @override
  Future<PipeBuyerInsuranceProvidersResult> listProviders({
    String query = '',
    String coverageLine = '',
    String countryCode = '',
    String regionCode = '',
    String providerType = '',
    bool msaOnly = false,
    bool fastCoiOnly = false,
    int pageSize = 60,
  }) async {
    final matched = _providers
        .where(
          (item) => item.matchesFilters(
            query: query,
            coverageLine: coverageLine,
            countryFilter: countryCode,
            regionFilter: regionCode,
            providerTypeFilter: providerType,
            msaOnly: msaOnly,
            fastCoiOnly: fastCoiOnly,
          ),
        )
        .toList(growable: false);
    return PipeBuyerInsuranceProvidersResult(
      providers: matched,
      totalMatched: matched.length,
    );
  }

  @override
  Future<PipeBuyerInsuranceRateSubmissionResult> submitRateApplication({
    required String companyName,
    required String contactName,
    required String email,
    required String phone,
    required String countryCode,
    required String regionCode,
    required String city,
    List<String> operatingBasins = const <String>[],
    required List<String> coverageLines,
    List<String> msaRequirements = const <String>[],
    int fleetVehicleCount = 0,
    double equipmentValueUsd = 0,
    String annualRevenueBand = '500k_2m',
    String dotOrMcNumber = '',
    String desiredEffectiveDate = '',
    String claimsSummary = '',
    String? targetProviderId,
    String targetProviderName = '',
    String notes = '',
  }) async {
    submittedRatePayloads.add(<String, Object?>{
      'companyName': companyName,
      'contactName': contactName,
      'email': email,
      'phone': phone,
      'countryCode': countryCode,
      'regionCode': regionCode,
      'city': city,
      'coverageLines': coverageLines,
      'msaRequirements': msaRequirements,
      'fleetVehicleCount': fleetVehicleCount,
      'equipmentValueUsd': equipmentValueUsd,
      'annualRevenueBand': annualRevenueBand,
      'targetProviderId': targetProviderId,
      'targetProviderName': targetProviderName,
    });

    final mode = (targetProviderId != null && targetProviderId.isNotEmpty)
        ? 'targeted'
        : 'multi_carrier';
    final appId = 'rapp_${1000 + submittedRatePayloads.length}';
    myRateApps.insert(
      0,
      InsuranceRateApplicationSummary(
        applicationId: appId,
        companyName: companyName,
        contactName: contactName,
        email: email,
        phone: phone,
        countryCode: countryCode,
        regionCode: regionCode,
        city: city,
        coverageLines: coverageLines,
        targetProviderId: targetProviderId,
        targetProviderName: targetProviderName,
        distributionMode: mode,
        status: 'new',
      ),
    );

    return PipeBuyerInsuranceRateSubmissionResult(
      applicationId: appId,
      status: 'new',
      distributionMode: mode,
      coverageLines: coverageLines,
      targetProviderId: targetProviderId,
      targetProviderName: targetProviderName,
    );
  }

  @override
  Future<List<InsuranceRateApplicationSummary>> listMyRateApplications() async {
    return List<InsuranceRateApplicationSummary>.from(myRateApps);
  }

  @override
  Future<PipeBuyerInsuranceProviderApplicationResult>
      submitProviderApplication({
    required String companyName,
    required String providerType,
    required String contactName,
    String contactTitle = '',
    required String email,
    required String phone,
    String website = '',
    required String licenseSummary,
    String countryCode = 'US',
    String regionCode = '',
    String headquartersCity = '',
    List<String> licensedCountries = const <String>['US'],
    List<String> licensedRegions = const <String>[],
    List<String> operatingBasins = const <String>[],
    required List<String> coverageLines,
    String amBestRating = '',
    double maxLimitUsd = 0,
    bool fastCoi24x7 = false,
    bool msaCompliant = false,
    double minimumPremiumUsd = 0,
    String summary = '',
  }) async {
    submittedProviderPayloads.add(<String, Object?>{
      'companyName': companyName,
      'providerType': providerType,
      'contactName': contactName,
      'email': email,
      'phone': phone,
      'licenseSummary': licenseSummary,
      'licensedCountries': licensedCountries,
      'coverageLines': coverageLines,
      'msaCompliant': msaCompliant,
      'fastCoi24x7': fastCoi24x7,
    });
    return PipeBuyerInsuranceProviderApplicationResult(
      applicationId: 'papp_${500 + submittedProviderPayloads.length}',
      status: 'pending_review',
    );
  }

  @override
  Future<PipeBuyerInsuranceAdminDashboardData> listAdminDashboard() async {
    return PipeBuyerInsuranceAdminDashboardData(
      providerApplications: List<Map<String, dynamic>>.from(adminProviderApps),
      rateApplications: List<InsuranceRateApplicationSummary>.from(
        adminRateApps,
      ),
      providers: _providers
          .map(
            (p) => <String, dynamic>{
              'providerId': p.providerId,
              'companyName': p.companyName,
              'providerType': p.providerType,
              'headquartersCity': p.headquartersCity,
              'regionCode': p.regionCode,
              'countryCode': p.countryCode,
              'licenseSummary': p.licenseSummary,
              'coverageLines': p.coverageLines,
              'active': p.active,
              'featured': p.featured,
            },
          )
          .toList(growable: false),
      counts: <String, int>{
        'pendingProviderApps': adminProviderApps
            .where((a) => a['status'] == 'pending_review')
            .length,
        'newRateApps':
            adminRateApps.where((a) => a.status == 'new').length,
        'totalRateApps': adminRateApps.length,
        'activeProviders': _providers.where((p) => p.active).length,
      },
    );
  }

  @override
  Future<Map<String, dynamic>> reviewProviderApplication({
    required String applicationId,
    required String decision,
    bool featured = false,
    String reviewNote = '',
  }) async {
    reviewedProviderDecisions.add(<String, Object?>{
      'applicationId': applicationId,
      'decision': decision,
      'featured': featured,
      'reviewNote': reviewNote,
    });
    for (final app in adminProviderApps) {
      if (app['applicationId'] == applicationId) {
        app['status'] = decision;
      }
    }
    return <String, dynamic>{
      'applicationId': applicationId,
      'status': decision,
    };
  }

  @override
  Future<void> updateRateApplicationStatus({
    required String applicationId,
    required String status,
    List<String>? matchedProviderIds,
    List<String>? matchedProviderNames,
    String? brokerResponseNotes,
  }) async {
    rateStatusUpdates.add(<String, Object?>{
      'applicationId': applicationId,
      'status': status,
      'matchedProviderNames': matchedProviderNames,
      'brokerResponseNotes': brokerResponseNotes,
    });
    final index = adminRateApps.indexWhere(
      (item) => item.applicationId == applicationId,
    );
    if (index != -1) {
      final current = adminRateApps[index];
      adminRateApps[index] = InsuranceRateApplicationSummary(
        applicationId: current.applicationId,
        companyName: current.companyName,
        contactName: current.contactName,
        email: current.email,
        phone: current.phone,
        countryCode: current.countryCode,
        regionCode: current.regionCode,
        city: current.city,
        coverageLines: current.coverageLines,
        status: status,
        matchedProviderNames:
            matchedProviderNames ?? current.matchedProviderNames,
        brokerResponseNotes:
            brokerResponseNotes ?? current.brokerResponseNotes,
      );
    }
  }

  @override
  Future<String> upsertProvider({
    String? providerId,
    required Map<String, Object?> provider,
  }) async {
    final resolvedId = providerId ?? 'prov_added_${upsertedProviders.length + 1}';
    upsertedProviders.add(<String, Object?>{
      'providerId': resolvedId,
      ...provider,
    });
    _providers.add(
      InsuranceProviderListing.fromJson(<String, dynamic>{
        'providerId': resolvedId,
        ...provider,
      }),
    );
    return resolvedId;
  }
}

void main() {
  test(
    'Commercial & Oilfield Insurance taxonomy covers all 8 coverage lines, 6 MSA endorsements, and filter matching',
    () {
      expect(PipeBuyerInsuranceTaxonomy.coverageLines.length, 8);
      expect(
        PipeBuyerInsuranceTaxonomy.coverageLines.map((c) => c.code),
        containsAll(const <String>[
          'commercial_auto_fleet',
          'oilfield_general_liability',
          'rig_equipment_inland_marine',
          'motor_truck_cargo_hazmat',
          'pollution_environmental',
          'umbrella_excess_liability',
          'workers_comp_crew',
          'commercial_property_yards',
        ]),
      );
      expect(PipeBuyerInsuranceTaxonomy.msaEndorsements.length, 6);
      expect(
        PipeBuyerInsuranceTaxonomy.msaEndorsements.map((m) => m.code),
        containsAll(const <String>[
          'waiver_of_subrogation',
          'additional_insured',
          'primary_non_contributory',
          'thirty_day_cancellation_notice',
          'hired_non_owned_auto',
          'sudden_accidental_pollution',
        ]),
      );

      final showcase = PipeBuyerInsuranceTaxonomy.showcaseProviders;
      expect(showcase.length, greaterThanOrEqualTo(4));
      expect(showcase.every((p) => p.isSampleShowcase), isTrue);

      final canadianMatches = showcase.where(
        (p) => p.matchesFilters(countryFilter: 'CA'),
      );
      expect(canadianMatches, isNotEmpty);

      final fastCoiRigMatches = showcase.where(
        (p) => p.matchesFilters(
          coverageLine: 'rig_equipment_inland_marine',
          fastCoiOnly: true,
        ),
      );
      expect(fastCoiRigMatches.length, 1);
      expect(
        fastCoiRigMatches.single.companyName,
        'Foothills WCSB Energy Risk Partners',
      );
    },
  );

  test('router registers Commercial Insurance deep link destinations', () {
    expect(MarketplaceDeepLinks.insuranceHubPath, '/insurance');
    expect(
      MarketplaceDeepLinks.insuranceProviderApplyPath,
      '/insurance/list-provider',
    );
    expect(MarketplaceDeepLinks.insuranceAdminPath, '/admin/insurance');

    final router = createRouter(AppStateNotifier.instance);
    addTearDown(router.dispose);
    final paths = router.configuration.routes
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toSet();
    expect(
      paths,
      containsAll(const <String>{
        '/insurance',
        '/insurance/list-provider',
        '/admin/insurance',
      }),
    );
  });

  testWidgets(
    'Home intent actions and grouped navigation expose Commercial Insurance entry points and gate admin access',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var insuranceTapped = 0;
      var listProviderTapped = 0;
      var adminTapped = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 260,
                  child: MarketplaceGroupedNavigation(
                    selectedPageIndex: 0,
                    marketplaceEnabled: true,
                    auctionsEnabled: true,
                    dispatchEnabled: true,
                    isAdmin: false,
                    onDestinationSelected: (_) {},
                    onWanted: () {},
                    onInsuranceHub: () => insuranceTapped += 1,
                    onInsuranceProviderApply: () => listProviderTapped += 1,
                    onInsuranceAdmin: () => adminTapped += 1,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: MarketplaceHomeIntentActions(
                      onBrowse: () {},
                      onSell: () {},
                      onDispatch: () {},
                      onWanted: () {},
                      onCommercialInsurance: () => insuranceTapped += 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Commercial Insurance'), findsOneWidget);
      expect(find.text('List Insurance Company'), findsOneWidget);
      expect(find.text('Insurance Admin'), findsNothing);
      expect(find.text('Commercial insurance'), findsOneWidget);

      await tester.tap(find.text('Commercial Insurance'));
      await tester.tap(find.text('List Insurance Company'));
      await tester.tap(find.text('Commercial insurance'));
      await tester.pump();

      expect(insuranceTapped, 2);
      expect(listProviderTapped, 1);
      expect(adminTapped, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Insurance Hub renders responsively on mobile and desktop, filters providers, and submits targeted rate application',
    (tester) async {
      final client = _FakeInsuranceClient(signedIn: true);

      // First verify mobile 390x844 has zero overflow
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PipeBuyerInsuranceHubPage(client: client),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Lone Star Basin Risk MGA'), findsOneWidget);
      expect(find.text('Prairie Foothills Energy Insurance'), findsOneWidget);

      // Switch to desktop 1280x900 and test filtering + targeted rate application
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Filter by Rig & Heavy Equipment coverage ChoiceChip
      final rigFilter = find.byKey(
        const Key('coverage_filter_rig_equipment_inland_marine'),
      );
      await tester.ensureVisible(rigFilter);
      await tester.tap(rigFilter);
      await tester.pumpAndSettle();

      expect(find.text('Prairie Foothills Energy Insurance'), findsOneWidget);
      expect(find.text('Lone Star Basin Risk MGA'), findsNothing);

      // Click "Apply for Rates" on Prairie Foothills Energy Insurance
      final applyBtn = find.byKey(const Key('apply_rates_prov_wcsb_broker'));
      await tester.ensureVisible(applyBtn);
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Targeted Provider Quote: Prairie Foothills Energy Insurance',
        ),
        findsOneWidget,
      );

      // Fill company & phone (email & contactName prefilled from signedIn client)
      await tester.enterText(
        find.byKey(const Key('rate_apply_company_name')),
        'Redwater Tubular & Hauling LLC',
      );
      await tester.enterText(
        find.byKey(const Key('rate_apply_phone')),
        '(432) 555-0194',
      );
      await tester.enterText(
        find.byKey(const Key('rate_apply_city')),
        'Midland',
      );

      final submitBtn = find.byKey(const Key('rate_apply_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(client.submittedRatePayloads.length, 1);
      expect(
        client.submittedRatePayloads.single['companyName'],
        'Redwater Tubular & Hauling LLC',
      );
      expect(
        client.submittedRatePayloads.single['targetProviderId'],
        'prov_wcsb_broker',
      );
      expect(
        find.byKey(const Key('rate_application_receipt_card')),
        findsOneWidget,
      );
      expect(
        find.text('Commercial Insurance Rate Application Submitted'),
        findsOneWidget,
      );

      // Navigate to My Applications tab via receipt button
      await tester.tap(find.text('View My Rate Applications'));
      await tester.pumpAndSettle();
      expect(find.text('Redwater Tubular & Hauling LLC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Insurance Provider Apply page validates credentials and submits carrier onboarding application',
    (tester) async {
      final client = _FakeInsuranceClient();

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: PipeBuyerInsuranceProviderApplyPage(client: client),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Attempt empty submit -> triggers validation without calling backend
      final submitBtn = find.byKey(const Key('provider_apply_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      expect(client.submittedProviderPayloads, isEmpty);
      expect(find.text('Enter your company name.'), findsOneWidget);

      // Fill required carrier credentials
      await tester.enterText(
        find.byKey(const Key('provider_apply_company_name')),
        'Brazos Oilfield Risk MGA LLC',
      );
      await tester.enterText(
        find.byKey(const Key('provider_apply_contact_name')),
        'Taylor Brooks',
      );
      await tester.enterText(
        find.byKey(const Key('provider_apply_email')),
        'submissions@brazosrisk.example.com',
      );
      await tester.enterText(
        find.byKey(const Key('provider_apply_phone')),
        '(713) 555-0126',
      );
      await tester.enterText(
        find.byKey(const Key('provider_apply_license_summary')),
        'Texas TDI MGA #512904 • OK & NM Surplus Lines',
      );

      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(client.submittedProviderPayloads.length, 1);
      expect(
        client.submittedProviderPayloads.single['companyName'],
        'Brazos Oilfield Risk MGA LLC',
      );
      expect(
        find.text('Provider Onboarding Application Received'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Insurance admin source adheres to unauthorized administrator security contract',
    () {
      final source = File(
        'lib/marketplace/pipebuyer_insurance_admin_page.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('jordilwbailey@gmail.com')));
      expect(source, isNot(contains('goldcity4u@icloud.com')));
      expect(source, isNot(contains('Only master administrator')));
      expect(source, contains('approved administrator account'));
      expect(source, contains('checkAdministratorAccess'));
    },
  );

  testWidgets(
    'Insurance Admin blocks non-admin accounts and enables MFA-verified admins to approve carriers and update rate requests',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 1. Unauthorized state
      final unauthClient = _FakeInsuranceClient(isAdmin: false);
      await tester.pumpWidget(
        MaterialApp(
          home: PipeBuyerInsuranceAdminPage(client: unauthClient),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Administrator Privileges Required'), findsOneWidget);
      expect(
        find.textContaining('approved administrator account'),
        findsOneWidget,
      );

      // 2. Authorized MFA admin state
      final adminClient = _FakeInsuranceClient(signedIn: true, isAdmin: true);
      await tester.pumpWidget(
        MaterialApp(
          home: PipeBuyerInsuranceAdminPage(client: adminClient),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Gulf Coast Specialty Underwriters'),
        findsOneWidget,
      );

      // Toggle Featured + Approve & Publish
      await tester.tap(find.byKey(const Key('feature_toggle_papp_101')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('approve_provider_app_papp_101')));
      await tester.pumpAndSettle();

      expect(adminClient.reviewedProviderDecisions.length, 1);
      expect(
        adminClient.reviewedProviderDecisions.single['decision'],
        'approved',
      );
      expect(adminClient.reviewedProviderDecisions.single['featured'], isTrue);

      // Switch to Company Rate Requests tab and update status to quoted
      await tester.tap(find.byKey(const Key('admin_tab_rate_apps')));
      await tester.pumpAndSettle();
      expect(find.text('Redwater Tubular & Hotshot LLC'), findsOneWidget);

      await tester.tap(find.byKey(const Key('update_rate_app_rapp_201')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin_rate_status_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QUOTED').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('admin_rate_matched_carriers_field')),
        'Lone Star Basin Risk MGA',
      );
      await tester.enterText(
        find.byKey(const Key('admin_rate_response_notes_field')),
        'Indicative fleet & cargo quote released at \$18,400/yr.',
      );
      await tester.tap(find.byKey(const Key('admin_rate_status_save_button')));
      await tester.pumpAndSettle();

      expect(adminClient.rateStatusUpdates.length, 1);
      expect(adminClient.rateStatusUpdates.single['status'], 'quoted');
      expect(find.text('RATES QUOTED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
