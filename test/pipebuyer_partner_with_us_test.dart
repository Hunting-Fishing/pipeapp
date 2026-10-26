import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_deep_links.dart';
import 'package:pipe_app/marketplace/pipebuyer_business_logo_uploader.dart';
import 'package:pipe_app/marketplace/pipebuyer_partner_admin_page.dart';
import 'package:pipe_app/marketplace/pipebuyer_partner_client.dart';
import 'package:pipe_app/marketplace/pipebuyer_partner_taxonomy.dart';
import 'package:pipe_app/marketplace/pipebuyer_partner_with_us_page.dart';
import 'package:pipe_app/marketplace/pipebuyer_site_footer.dart';

class _FakePartnerClient extends PipeBuyerPartnerClient {
  Map<String, Object?>? lastSubmittedInquiry;
  Map<String, Object?>? lastDealInterest;
  Map<String, Object?>? lastReviewedInquiry;

  @override
  String? get currentUserEmail => null;

  @override
  String? get currentUserDisplayName => null;

  @override
  bool get isSignedIn => false;

  @override
  Future<List<PartnerShowcaseDeal>> listShowcaseDeals({
    String brandCategory = '',
    String programType = '',
    String region = '',
    String query = '',
    bool featuredOnly = false,
  }) async {
    return const <PartnerShowcaseDeal>[
      PartnerShowcaseDeal(
        showcaseId: 'ford-fleet-showcase',
        partnerName: 'Ford Pro Commercial Fleet',
        brandCategory: 'oem_fleet_crew_trucks',
        programTypes: <String>[
          'promote_brand',
          'showcase_sell_products',
          'oilfield_deals_discounts',
        ],
        headline: '2026 Super Duty F-350 & F-550 Oilfield Crew Trucks',
        summary:
            'Factory commercial crew truck allocations and crane/service body upfit rebates for oil & gas fleets.',
        offerBadge: 'OEM Fleet Rebate',
        discountDetails: 'Up to \$3,500 Commercial Upfit Allowance',
        productHighlights: <String>[
          '4x4 Diesel Crew Cab',
          'Fleet Volume Pricing'
        ],
        targetRegions: <String>['Permian Basin', 'WCSB'],
        ctaLabel: 'Request Ford Fleet Info',
        featured: true,
        priorityRank: 1,
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> submitPartnerInquiry({
    required String companyName,
    required String brandCategory,
    required List<String> programTypes,
    required String commercialModel,
    required String headline,
    required String productSummary,
    String dealOrDiscountOffer = '',
    List<String> targetRegions = const <String>['North America'],
    int? estimatedMonthlyBudgetUsd,
    required String contactName,
    String contactTitle = '',
    required String email,
    required String phone,
    String website = '',
    String logoUrl = '',
    String notes = '',
  }) async {
    lastSubmittedInquiry = <String, Object?>{
      'companyName': companyName,
      'brandCategory': brandCategory,
      'programTypes': programTypes,
      'commercialModel': commercialModel,
      'headline': headline,
      'productSummary': productSummary,
      'dealOrDiscountOffer': dealOrDiscountOffer,
      'targetRegions': targetRegions,
      'estimatedMonthlyBudgetUsd': estimatedMonthlyBudgetUsd,
      'contactName': contactName,
      'email': email,
      'phone': phone,
      'logoUrl': logoUrl,
    };
    return <String, dynamic>{
      'inquiryId': 'INQ-2026-FORD',
      'status': 'new',
      'companyName': companyName,
    };
  }

  @override
  Future<Map<String, dynamic>> submitDealInterest({
    required String showcaseId,
    required String partnerName,
    required String companyName,
    required String contactName,
    required String email,
    required String phone,
    String fleetOrQuantityNeed = '',
    String region = '',
    String message = '',
  }) async {
    lastDealInterest = <String, Object?>{
      'showcaseId': showcaseId,
      'partnerName': partnerName,
      'companyName': companyName,
    };
    return <String, dynamic>{'leadId': 'LEAD-1', 'status': 'new'};
  }

  @override
  Future<Map<String, dynamic>> listAdminDashboard() async {
    return <String, dynamic>{
      'inquiries': <Map<String, dynamic>>[
        <String, dynamic>{
          'inquiryId': 'INQ-2026-FORD',
          'companyName': 'Ford Pro Commercial Fleet',
          'brandCategory': 'oem_fleet_crew_trucks',
          'commercialModel': 'member_fleet_discount',
          'headline': 'Super Duty Crew Truck Oilfield Program',
          'dealOrDiscountOffer': '\$3,500 Upfit Allowance',
          'productSummary': 'New commercial crew trucks and chassis cabs.',
          'contactName': 'Jordan Mitchell',
          'contactTitle': 'Fleet Partnerships',
          'email': 'fleet@fordcommercial.example.com',
          'phone': '800-555-0199',
          'status': 'new',
        },
      ],
      'showcases': const <Map<String, dynamic>>[],
      'dealLeads': const <Map<String, dynamic>>[],
    };
  }

  @override
  Future<Map<String, dynamic>> reviewPartnerInquiry({
    required String inquiryId,
    required String status,
    String adminNotes = '',
    bool publishShowcase = false,
    bool featured = false,
    String offerBadge = '',
    List<String> productHighlights = const <String>[],
  }) async {
    lastReviewedInquiry = <String, Object?>{
      'inquiryId': inquiryId,
      'status': status,
      'publishShowcase': publishShowcase,
      'featured': featured,
    };
    return <String, dynamic>{
      'inquiryId': inquiryId,
      'status': status,
      'publishedShowcaseId': publishShowcase ? 'SHOW-FORD-1' : null,
    };
  }
}

void main() {
  test(
      'Partner With Us deep links and taxonomy cover OEM fleets and oilfield deals',
      () {
    expect(MarketplaceDeepLinks.partnerWithUsPath, '/partner');
    expect(MarketplaceDeepLinks.partnerApplyPath, '/partner/apply');
    expect(MarketplaceDeepLinks.partnerAdminPath, '/admin/partners');
    expect(PipeBuyerPartnerTaxonomy.brandCategories.length, 8);
    expect(PipeBuyerPartnerTaxonomy.programPillars.length, 4);
    expect(
      PipeBuyerPartnerTaxonomy.categoryByCode('oem_fleet_crew_trucks')
          ?.shortLabel,
      'Fleet & Crew Trucks',
    );
  });

  testWidgets(
      'PipeBuyerSiteFooter renders Partner With Us CTA on mobile and desktop without overflow',
      (
    tester,
  ) async {
    var tappedPartner = false;
    for (final size in const [Size(390, 900), Size(1280, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PipeBuyerSiteFooter(
                onOpenPartnerWithUs: () => tappedPartner = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pipebuyer-site-footer')), findsOneWidget);
      expect(
        find.byKey(const Key('footer-partner-with-us-cta')),
        findsOneWidget,
      );
      expect(find.text('OEM Fleet & Crew Trucks'), findsOneWidget);
      expect(find.text('Oilfield Deals & Discounts'), findsOneWidget);
      expect(
        find.byKey(const Key('footer-link-commercial-insurance')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('footer-link-insurance-carrier-apply')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.byKey(const Key('footer-partner-with-us-cta')));
    await tester.pump();
    expect(tappedPartner, isTrue);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets(
      'PipeBuyerPartnerWithUsPage showcases fleet deals and submits corporate partnership proposal',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeClient = _FakePartnerClient();
    final logoUploader = PipeBuyerBusinessLogoUploader(
      pickBytesOverride: () async => Uint8List.fromList(
        List<int>.filled(64, 0x89),
      ),
      uploadBytesOverride: ({required bytes, required purpose}) async {
        expect(purpose, 'partner_brand');
        return 'https://cdn.pipebuyer.example.com/logos/ford-pro.png';
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PipeBuyerPartnerWithUsPage(
          client: fakeClient,
          logoUploader: logoUploader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('2026 Super Duty F-350 & F-550 Oilfield Crew Trucks'),
      findsOneWidget,
    );
    expect(find.text('PROGRAM PREVIEW'), findsWidgets);
    expect(find.text('FEATURED'), findsWidgets);
    expect(
      find.textContaining('Up to \$3,500 Commercial Upfit Allowance'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('partner-company-name-input')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.enterText(
      find.byKey(const Key('partner-company-name-input')),
      'Ford Pro Commercial',
    );
    final uploadLogoBtn = find.byKey(
      const Key('partner_brand_logo_upload_button'),
    );
    await tester.ensureVisible(uploadLogoBtn);
    await tester.tap(uploadLogoBtn);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('partner-headline-input')),
      '2026 Crew Truck Oilfield Fleet Showcase',
    );
    await tester.enterText(
      find.byKey(const Key('partner-deal-offer-input')),
      '\$3,500 Upfit & Fleet Rebate',
    );
    await tester.enterText(
      find.byKey(const Key('partner-summary-input')),
      'New commercial crew trucks, chassis cabs, and oilfield fleet deals.',
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('partner-submit-inquiry-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.enterText(
      find.byKey(const Key('partner-contact-name-input')),
      'Jordan Mitchell',
    );
    await tester.enterText(
      find.byKey(const Key('partner-email-input')),
      'fleet@fordpro.example.com',
    );
    await tester.enterText(
      find.byKey(const Key('partner-phone-input')),
      '1-800-555-0199',
    );

    await tester.ensureVisible(
      find.byKey(const Key('partner-submit-inquiry-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('partner-submit-inquiry-button')));
    await tester.pumpAndSettle();

    expect(
        fakeClient.lastSubmittedInquiry?['companyName'], 'Ford Pro Commercial');
    expect(
      fakeClient.lastSubmittedInquiry?['logoUrl'],
      'https://cdn.pipebuyer.example.com/logos/ford-pro.png',
    );
    expect(
      find.byKey(const Key('partner-submission-confirmation')),
      findsOneWidget,
    );
    expect(find.textContaining('INQ-2026-FORD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'PipeBuyerPartnerAdminPage enforces authorization and approves + publishes inquiries',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeClient = _FakePartnerClient();

    await tester.pumpWidget(
      MaterialApp(
        home: PipeBuyerPartnerAdminPage(
          client: fakeClient,
          adminAccessOverride: () async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Administrator Privileges Required'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: PipeBuyerPartnerAdminPage(
          client: fakeClient,
          adminAccessOverride: () async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Ford Pro Commercial Fleet — Super Duty Crew Truck'),
      findsOneWidget,
    );
    await tester.tap(find.text('Approve & Publish Showcase'));
    await tester.pumpAndSettle();

    expect(fakeClient.lastReviewedInquiry?['status'], 'approved');
    expect(fakeClient.lastReviewedInquiry?['publishShowcase'], isTrue);
  });
}
