import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/design/pipe_buyer_theme.dart';
import 'package:pipe_app/marketplace/marketplace_deep_links.dart';
import 'package:pipe_app/marketplace/marketplace_grouped_navigation.dart';
import 'package:pipe_app/marketplace/marketplace_home_welcome.dart';
import 'package:pipe_app/marketplace/pipebuyer_shop_admin_page.dart';
import 'package:pipe_app/marketplace/pipebuyer_shop_client.dart';
import 'package:pipe_app/marketplace/pipebuyer_shop_contextual_widgets.dart';
import 'package:pipe_app/marketplace/pipebuyer_shop_csv_helper.dart';
import 'package:pipe_app/marketplace/pipebuyer_shop_store_page.dart';
import 'package:pipe_app/marketplace/pipebuyer_shop_taxonomy.dart';
import 'package:pipe_app/marketplace/pipebuyer_shop_vendor_apply_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAdminShopClient extends PipeBuyerShopClient {
  _FakeAdminShopClient({super.urlLauncher, this.remotePreviewResponder});

  final Future<PipeBuyerParsedAffiliateSubmission?> Function(String rawInput)?
      remotePreviewResponder;
  Map<String, dynamic>? lastVendorSubmission;
  Map<String, dynamic>? lastReviewedApplication;
  final List<Map<String, dynamic>> _applications = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'app_1',
      'companyName': 'Midwest Milwaukee & Rigging Supply',
      'contactName': 'Alex Cole',
      'contactTitle': 'National Accounts Director',
      'email': 'alex@midwestrigging.example.com',
      'phone': '+1-403-555-0144',
      'headquartersLocation': 'Calgary, AB & Houston, TX',
      'websiteUrl': 'https://www.midwestrigging.example.com',
      'sampleCatalogUrl': 'https://www.midwestrigging.example.com/catalog',
      'partnershipTrack': 'oem_heavy_equipment_dealer',
      'authorizationLevel': 'authorized_dealer',
      'requestedPlacements': <String>[
        'shop_storefront',
        'heavy_equipment_listings',
      ],
      'brandsCarried': <String>['Brandt Tractor', 'Caterpillar', 'Milwaukee'],
      'categories': <String>['heavy_equipment_oem', 'power_hand_tools'],
      'fulfillmentRegions': <String>['US', 'CA'],
      'catalogIntegrationMethod': 'api_xml_feed',
      'estimatedSkuCount': '250–1,000 SKUs',
      'notificationSummary': <String, dynamic>{
        'inAppNotifiedCount': 2,
        'adminEmailSentCount': 2,
      },
      'status': 'pending',
    },
  ];
  final List<Map<String, Object?>> upsertedPayloads = <Map<String, Object?>>[];
  final List<String> deletedIds = <String>[];
  final List<PipeBuyerShopProduct> _customProducts = <PipeBuyerShopProduct>[];
  final Set<String> _hiddenStarterIds = <String>{};
  final List<PipeBuyerProductSuggestion> submittedSuggestions =
      <PipeBuyerProductSuggestion>[];

  PipeBuyerShopSettings get _currentSettings => PipeBuyerShopSettings(
        amazonAssociateTagUs: 'pipebuyer-20',
        amazonAssociateTagCa: 'pipebuyer0c-20',
        hiddenStarterIds: _hiddenStarterIds.toList(growable: false),
      );

  @override
  Future<PipeBuyerShopCatalogSnapshot> loadStoreCatalog() async {
    return PipeBuyerShopCatalogSnapshot(
      settings: _currentSettings,
      products: PipeBuyerShopClient.mergeWithStarterCatalog(
        _customProducts,
        suppressedIds: _hiddenStarterIds,
      ),
      vendors: const <Map<String, dynamic>>[],
      fromLiveBackend: true,
    );
  }

  @override
  Future<Map<String, dynamic>> upsertProduct(
    Map<String, Object?> payload,
  ) async {
    upsertedPayloads.add(payload);
    final id = (payload['id']?.toString().trim().isNotEmpty ?? false)
        ? payload['id'].toString().trim()
        : 'custom_${upsertedPayloads.length}';
    final created = PipeBuyerShopProduct.fromJson(<String, dynamic>{
      ...payload,
      'id': id,
    });
    _customProducts.removeWhere((p) => p.id == id);
    _customProducts.insert(0, created);
    _hiddenStarterIds.remove(id);
    return <String, dynamic>{
      'productId': id,
      'product': created.toUpsertPayload(),
    };
  }

  @override
  Future<Map<String, dynamic>> bulkUpsertProducts(
    List<Map<String, Object?>> items, {
    void Function(int completed, int total)? onProgress,
  }) async {
    for (var i = 0; i < items.length; i++) {
      await upsertProduct(items[i]);
      onProgress?.call(i + 1, items.length);
    }
    return <String, dynamic>{
      'importedCount': items.length,
      'skippedBlankCount': 0,
      'failedCount': 0,
      'errors': const <Object>[],
    };
  }

  @override
  Future<Map<String, dynamic>> deleteProduct({
    required String productId,
    String title = '',
    bool hideStarterFallback = true,
  }) async {
    deletedIds.add(productId);
    _customProducts.removeWhere((p) => p.id == productId);
    if (hideStarterFallback) {
      _hiddenStarterIds.add(productId);
    }
    return <String, dynamic>{
      'deleted': true,
      'productId': productId,
      'hiddenStarterIds': _hiddenStarterIds.toList(growable: false),
    };
  }

  @override
  Future<Map<String, dynamic>> hideStarterProducts(
    List<String> productIds,
  ) async {
    _hiddenStarterIds.addAll(
      productIds.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
    );
    return <String, dynamic>{
      'hiddenStarterIds': _hiddenStarterIds.toList(growable: false),
    };
  }

  @override
  Future<Map<String, dynamic>> restoreStarterProducts({
    String? productId,
  }) async {
    if (productId != null && productId.trim().isNotEmpty) {
      _hiddenStarterIds.remove(productId.trim().toLowerCase());
    } else {
      _hiddenStarterIds.clear();
    }
    return <String, dynamic>{
      'hiddenStarterIds': _hiddenStarterIds.toList(growable: false),
    };
  }

  @override
  Future<PipeBuyerParsedAffiliateSubmission?> fetchRemoteAffiliatePreview(
    String rawInput,
  ) async {
    if (remotePreviewResponder != null) {
      return remotePreviewResponder!(rawInput);
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> submitVendorApplication({
    required String companyName,
    required String contactName,
    String contactTitle = '',
    required String email,
    required String phone,
    String headquartersLocation = '',
    required String websiteUrl,
    String sampleCatalogUrl = '',
    required String partnershipTrack,
    String authorizationLevel = 'authorized_dealer',
    List<String> requestedPlacements = const <String>['shop_storefront'],
    required List<String> categories,
    required List<String> brandsCarried,
    required List<String> fulfillmentRegions,
    String catalogIntegrationMethod = 'direct_dealer_link',
    required String estimatedSkuCount,
    String affiliateProgramDetails = '',
    String catalogNotes = '',
  }) async {
    lastVendorSubmission = <String, dynamic>{
      'companyName': companyName,
      'contactName': contactName,
      'contactTitle': contactTitle,
      'email': email,
      'phone': phone,
      'headquartersLocation': headquartersLocation,
      'websiteUrl': websiteUrl,
      'sampleCatalogUrl': sampleCatalogUrl,
      'partnershipTrack': partnershipTrack,
      'authorizationLevel': authorizationLevel,
      'requestedPlacements': requestedPlacements,
      'categories': categories,
      'brandsCarried': brandsCarried,
      'fulfillmentRegions': fulfillmentRegions,
      'catalogIntegrationMethod': catalogIntegrationMethod,
      'estimatedSkuCount': estimatedSkuCount,
      'affiliateProgramDetails': affiliateProgramDetails,
      'catalogNotes': catalogNotes,
    };
    return <String, dynamic>{
      'applicationId': 'app_test_101',
      'status': 'pending',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> listMyVendorApplications() async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, dynamic>> reviewVendorApplication({
    required String applicationId,
    required String status,
    String reviewNotes = '',
    bool notifyApplicant = true,
  }) async {
    lastReviewedApplication = <String, dynamic>{
      'applicationId': applicationId,
      'status': status,
      'reviewNotes': reviewNotes,
      'notifyApplicant': notifyApplicant,
    };
    final idx = _applications.indexWhere((a) => a['id'] == applicationId);
    if (idx != -1) {
      _applications[idx] = <String, dynamic>{
        ..._applications[idx],
        'status': status,
        'reviewNotes': reviewNotes,
      };
    }
    return <String, dynamic>{'applicationId': applicationId, 'status': status};
  }

  @override
  Future<PipeBuyerShopAdminSnapshot> getAdminDashboard() async {
    final pendingCount =
        _applications.where((a) => a['status'] == 'pending').length;
    final openCount = _applications
        .where((a) => a['status'] == 'pending' || a['status'] == 'under_review')
        .length;
    return PipeBuyerShopAdminSnapshot(
      settings: _currentSettings,
      products: List<PipeBuyerShopProduct>.from(_customProducts),
      applications: List<Map<String, dynamic>>.from(_applications),
      vendors: const <Map<String, dynamic>>[],
      analytics: <String, dynamic>{
        'totalRecordedClicks': 48,
        'activeProductCount': 3,
        'pendingApplicationCount': pendingCount,
        'openApplicationCount': openCount,
        'approvedVendorCount': 0,
        'clicksBySource': const <String, int>{'amazon_affiliate': 48},
        'clicksByPlacement': const <String, int>{
          'store_grid': 36,
          'home_showcase': 12,
        },
      },
    );
  }

  @override
  Future<String> submitProductSuggestion({
    required String productName,
    String productUrl = '',
    String categoryCode = 'power_hand_tools',
    String notes = '',
    String submitterName = '',
    String contactEmail = '',
  }) async {
    final id = 'sugg_${submittedSuggestions.length + 1}';
    submittedSuggestions.insert(
      0,
      PipeBuyerProductSuggestion(
        id: id,
        productName: productName.trim(),
        productUrl: productUrl.trim(),
        categoryCode: categoryCode,
        notes: notes.trim(),
        submitterName: submitterName.trim(),
        contactEmail: contactEmail.trim(),
        status: 'pending',
        createdAtIso: '2026-11-07T19:00:00Z',
      ),
    );
    return id;
  }

  @override
  Future<List<PipeBuyerProductSuggestion>> listProductSuggestions() async {
    return List<PipeBuyerProductSuggestion>.from(submittedSuggestions);
  }

  @override
  Future<void> updateProductSuggestionStatus({
    required String suggestionId,
    required String status,
    String reviewNotes = '',
  }) async {
    final idx = submittedSuggestions.indexWhere((s) => s.id == suggestionId);
    if (idx < 0) return;
    final prev = submittedSuggestions[idx];
    submittedSuggestions[idx] = PipeBuyerProductSuggestion(
      id: prev.id,
      productName: prev.productName,
      productUrl: prev.productUrl,
      categoryCode: prev.categoryCode,
      notes: prev.notes,
      submitterName: prev.submitterName,
      contactEmail: prev.contactEmail,
      status: status,
      createdAtIso: prev.createdAtIso,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'Amazon ASIN extraction and US/CA Associate tag monetization work cleanly',
    () {
      expect(
        PipeBuyerShopUrlBuilder.extractAmazonAsin(
          'https://www.amazon.com/Milwaukee-2767-20/dp/B077H7JP1D/ref=sr_1_1',
        ),
        'B077H7JP1D',
      );
      expect(
        PipeBuyerShopUrlBuilder.extractAmazonAsin('b0000224j8'),
        'B0000224J8',
      );

      const settings = PipeBuyerShopSettings(
        amazonAssociateTagUs: 'pipebuyer-20',
        amazonAssociateTagCa: 'pipebuyerca-20',
      );

      const product = PipeBuyerShopProduct(
        id: 'm18-impact',
        title: 'Milwaukee M18 FUEL 1/2 Impact',
        brand: 'Milwaukee',
        vendorName: 'Amazon',
        sourceType: PipeBuyerShopSourceType.amazonAffiliate,
        categoryCode: 'power_hand_tools',
        asin: 'B077H7JP1D',
        destinationUrl: 'https://www.amazon.com/dp/B077H7JP1D',
      );

      final usUri = Uri.parse(
        PipeBuyerShopUrlBuilder.buildMonetizedUrl(
          product,
          settings,
          regionCode: 'US',
        ),
      );
      expect(usUri.host, 'www.amazon.com');
      expect(usUri.queryParameters['tag'], 'pipebuyer-20');

      final caUri = Uri.parse(
        PipeBuyerShopUrlBuilder.buildMonetizedUrl(
          product,
          settings,
          regionCode: 'CA',
        ),
      );
      expect(caUri.host, 'www.amazon.ca');
      expect(caUri.queryParameters['tag'], 'pipebuyerca-20');

      // Partner distributor / brand link appends UTM params without losing existing params
      const partnerProduct = PipeBuyerShopProduct(
        id: 'milwaukee-direct',
        title: 'Milwaukee MX FUEL Pipe Threading Machine',
        brand: 'Milwaukee',
        vendorName: 'Milwaukee Authorized Partner',
        sourceType: PipeBuyerShopSourceType.brandPartner,
        categoryCode: 'pipe_welding_fab',
        destinationUrl:
            'https://www.milwaukeetool.com/Products/MXF314?irclickid=xyz',
      );
      final partnerUri = Uri.parse(
        PipeBuyerShopUrlBuilder.buildMonetizedUrl(partnerProduct, settings),
      );
      expect(partnerUri.queryParameters['irclickid'], 'xyz');
      expect(partnerUri.queryParameters['utm_source'], 'pipebuyer');
      expect(partnerUri.queryParameters['utm_medium'], 'affiliate_store');
      expect(partnerUri.queryParameters['utm_campaign'], 'pipe_welding_fab');

      // Amazon Associates link.amazon short links stay intact and validate cleanly
      final shortSubmission = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
        'https://link.amazon/B0iZoQG46',
        settings,
      );
      expect(shortSubmission, isNotNull);
      expect(shortSubmission!.isAmazonLink, isTrue);
      expect(shortSubmission.isShortLink, isTrue);
      expect(
        shortSubmission.monetizedPreviewUs,
        'https://link.amazon/B0iZoQG46',
      );

      // Unsafe URLs rejected
      expect(
        PipeBuyerShopUrlBuilder.isSafeHttpsUrl(
          'http://www.amazon.com/dp/B077H7JP1D',
        ),
        isFalse,
      );
      expect(
        PipeBuyerShopUrlBuilder.isSafeHttpsUrl('https://localhost/test'),
        isFalse,
      );
    },
  );

  test(
    'Shop taxonomy maps Marketplace categories and defines deep-link paths',
    () {
      expect(PipeBuyerShopTaxonomy.categories.length, 8);
      expect(
        PipeBuyerShopTaxonomy.starterCatalog.length,
        greaterThanOrEqualTo(18),
      );
      expect(MarketplaceDeepLinks.shopStorePath, '/shop');
      expect(MarketplaceDeepLinks.shopVendorApplyPath, '/shop/apply');
      expect(MarketplaceDeepLinks.shopAdminPath, '/admin/shop');

      final pipeItems = PipeBuyerShopTaxonomy.contextualProductsForMarketplace(
        'Pipe',
      );
      expect(pipeItems, isNotEmpty);
      expect(pipeItems.first.categoryCode, 'pipe_welding_fab');

      final haulingItems =
          PipeBuyerShopTaxonomy.contextualProductsForMarketplace(
        'Transport & Hauling',
      );
      expect(haulingItems.first.categoryCode, 'rigging_hauling_cargo');
    },
  );

  testWidgets(
    'Grouped navigation and Home Intent Actions expose Shopping & Store',
    (tester) async {
      var shopTapped = 0;
      var vendorTapped = 0;
      var adminTapped = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 900,
              child: MarketplaceGroupedNavigation(
                selectedPageIndex: 0,
                marketplaceEnabled: true,
                auctionsEnabled: true,
                dispatchEnabled: true,
                isAdmin: true,
                onDestinationSelected: (_) {},
                onWanted: () {},
                onShopStore: () => shopTapped++,
                onShopVendorApply: () => vendorTapped++,
                onShopAdmin: () => adminTapped++,
              ),
            ),
          ),
        ),
      );

      expect(find.text('SHOPPING & STORE'), findsOneWidget);
      expect(find.text('Shop Tools & Gear'), findsOneWidget);
      expect(find.text('Vendor & Brand Portal'), findsOneWidget);
      expect(find.text('Store & Affiliate Admin'), findsOneWidget);

      await tester.tap(find.text('Shop Tools & Gear'));
      await tester.tap(find.text('Vendor & Brand Portal'));
      await tester.tap(find.text('Store & Affiliate Admin'));
      expect(shopTapped, 1);
      expect(vendorTapped, 1);
      expect(adminTapped, 1);

      var homeShopTapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketplaceHomeIntentActions(
                onShopStore: () => homeShopTapped++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Shop tools & gear'), findsOneWidget);
      await tester.ensureVisible(find.text('Shop tools & gear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shop tools & gear'));
      expect(homeShopTapped, 1);
    },
  );

  testWidgets(
    'PipeBuyerShopStorePage filters items, toggles CA region, and opens tagged Amazon link',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final launchedUris = <Uri>[];
      final client = _FakeAdminShopClient(
        urlLauncher: (uri) async {
          launchedUris.add(uri);
          return true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopStorePage(client: client),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pipe Buyer Store'), findsOneWidget);
      expect(find.textContaining('As an Amazon Associate'), findsOneWidget);
      expect(find.text('Milwaukee Tool Selection'), findsOneWidget);

      // Switch to Canada storefront and click first Buy button
      await tester.tap(find.text('Canada (.ca)'));
      await tester.pumpAndSettle();

      final buyButton = find.text('Amazon.ca').first;
      await tester.scrollUntilVisible(
        buyButton,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(buyButton);
      await tester.pumpAndSettle();

      expect(launchedUris, hasLength(1));
      expect(launchedUris.first.host, 'www.amazon.ca');
      expect(launchedUris.first.queryParameters['tag'], 'pipebuyer0c-20');
    },
  );

  testWidgets(
    'PipeBuyerShopVendorApplyPage submits distributor/brand application',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = _FakeAdminShopClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopVendorApplyPage(
            client: client,
            skipAuthGateForTest: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Company, Distributor, or Brand Name *',
        ),
        'Northern Milwaukee & Oilfield Tool Supply',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Primary Contact Name *'),
        'Morgan Vance',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Direct Phone *'),
        '+1 780 555 0188',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business Email *'),
        'morgan@northern-tools.example.com',
      );

      final submitBtn = find.text('Submit Store Partner Application');
      await tester.scrollUntilVisible(
        submitBtn,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Store Partner Application Submitted'), findsOneWidget);
      expect(
        client.lastVendorSubmission?['companyName'],
        'Northern Milwaukee & Oilfield Tool Supply',
      );
    },
  );

  testWidgets(
    'Contextual shop card and Admin authorization guard work cleanly',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PipeBuyerContextualShopCard(
                marketplaceCategory: 'Transport & Hauling',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recommended Rigging & Hauling Gear'), findsOneWidget);

      // Unauthorized admin blocked
      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopAdminPage(adminAccessOverride: () async => false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Administrator Access Required'), findsOneWidget);

      // Authorized admin loads 4-tab control center
      final fakeClient = _FakeAdminShopClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopAdminPage(
            client: fakeClient,
            adminAccessOverride: () async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Store & Affiliate Revenue Control'), findsOneWidget);
      expect(find.text('Outbound Affiliate Clicks'), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
    },
  );

  testWidgets(
    'Storefront and Home Shop Showcase render cleanly on 360px mobile with 1.25x text scale',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = _FakeAdminShopClient();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.25),
          ),
          child: MaterialApp(
            theme: PipeBuyerTheme.light(),
            home: PipeBuyerShopStorePage(client: client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.25),
          ),
          child: MaterialApp(
            theme: PipeBuyerTheme.light(),
            home: PipeBuyerShopStorePage(
              client: client,
              sessionOverride: () async =>
                  const PipeBuyerShopRoleSession.authorizedAdmin(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.25),
          ),
          child: MaterialApp(
            theme: PipeBuyerTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: PipeBuyerHomeShopShowcase(client: client),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Shop Tools, Welding, Rigging & Jobsite Gear'),
        findsOneWidget,
      );
    },
  );

  test(
      'parseAffiliateSubmission handles SiteStripe short/full links, mobile share text, HTML snippets, and ASINs',
      () {
    const settings = PipeBuyerShopSettings(
      amazonAssociateTagUs: 'pipebuyer-20',
      amazonAssociateTagCa: 'pipebuyer0c-20',
    );

    // 1. SiteStripe Full Text Link
    final full = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
      'https://www.amazon.com/RIDGID-31020-Heavy-Duty-Straight-Wrench/dp/B0000224J8?linkCode=ll1&tag=pipebuyer-20&linkId=abc123',
      settings,
    );
    expect(full, isNotNull);
    expect(full!.asin, 'B0000224J8');
    expect(full.suggestedBrand, 'RIDGID');
    expect(full.suggestedCategoryCode, 'pipe_welding_fab');
    expect(full.effectiveAssociateTag, 'pipebuyer-20');
    expect(
      Uri.parse(full.monetizedPreviewUs).queryParameters['linkCode'],
      'll1',
    );
    expect(
      Uri.parse(full.monetizedPreviewUs).queryParameters['linkId'],
      'abc123',
    );

    // 2. Amazon Mobile App Associate Share Text + SiteStripe Short Link
    final mobileShare = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
      'Check this out on Amazon: Crosby 3/4" Carbon Screw Pin Anchor Shackle https://amzn.to/3XyZ99A #ad',
      settings,
    );
    expect(mobileShare, isNotNull);
    expect(mobileShare!.isShortLink, isTrue);
    expect(mobileShare.destinationUrl, 'https://amzn.to/3XyZ99A');
    expect(mobileShare.suggestedBrand, 'Crosby');
    expect(mobileShare.suggestedCategoryCode, 'rigging_hauling_cargo');
    expect(mobileShare.suggestedTitle, contains('Crosby'));

    // 3. Associates Central HTML Snippet (decodes &amp;, strips 1x1 pixel, extracts image)
    final htmlSnippet = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
      '<a target="_blank" href="https://www.amazon.com/Lincoln-Electric-K3068-1-Welding-Helmet/dp/B0032TF88Q?linkCode=li2&amp;tag=pipebuyer-20">'
      '<img border="0" src="https://m.media-amazon.com/images/I/71weld._SL250_.jpg" ></a>'
      '<img src="https://ir-na.amazon-adsystem.com/e/ir?t=pipebuyer-20&l=li2&o=1&a=B0032TF88Q" width="1" height="1" border="0" alt="" />',
      settings,
    );
    expect(htmlSnippet, isNotNull);
    expect(htmlSnippet!.asin, 'B0032TF88Q');
    expect(
      htmlSnippet.imageUrl,
      'https://m.media-amazon.com/images/I/71weld._SL250_.jpg',
    );
    expect(htmlSnippet.suggestedBrand, 'Lincoln Electric');
    expect(htmlSnippet.suggestedCategoryCode, 'pipe_welding_fab');

    // 4. Bare 10-character ASIN
    final bareAsin = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
      'B077H7JP1D',
      settings,
    );
    expect(bareAsin, isNotNull);
    expect(bareAsin!.asin, 'B077H7JP1D');
    expect(bareAsin.destinationUrl, 'https://www.amazon.com/dp/B077H7JP1D');
  });

  testWidgets(
    'Admin & Catalog Editor roles can Quick-Paste add and remove affiliate links, and MFA guard prompts cleanly',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // MFA-required admin sees actionable prompt
      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopAdminPage(
            sessionOverride: () async => const PipeBuyerShopRoleSession(
              authorized: false,
              reason: 'mfa_required',
              role: 'administrator',
              isAdmin: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Administrator Sign-In Requires MFA'), findsOneWidget);
      expect(find.text('Open Account Security (MFA)'), findsOneWidget);

      // Authorized Admin loads 5-tab control center and adds + removes affiliate links
      final fakeClient = _FakeAdminShopClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopAdminPage(
            client: fakeClient,
            sessionOverride: () async =>
                const PipeBuyerShopRoleSession.authorizedAdmin(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Roles & Access'), findsOneWidget);

      // Switch to Affiliate Links tab
      await tester.tap(find.textContaining('Affiliate Links ('));
      await tester.pumpAndSettle();

      // Open Quick-Paste Add Affiliate Link dialog
      await tester.tap(find.text('Add Affiliate Link').first);
      await tester.pumpAndSettle();
      expect(
        find.text('1. Choose Platform & Paste Affiliate Link'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Paste Affiliate Link, Shortlink, Share Text, or ASIN',
        ),
        'https://www.amazon.com/RIDGID-31020-Heavy-Duty-Straight-Wrench/dp/B09XYZW123?linkCode=ll1&tag=pipebuyer-20',
      );
      await tester.pumpAndSettle();

      expect(find.text('ASIN: B09XYZW123'), findsOneWidget);

      await tester.tap(find.text('Publish Affiliate Link'));
      await tester.pumpAndSettle();

      expect(fakeClient.upsertedPayloads, hasLength(1));
      expect(fakeClient.upsertedPayloads.first['asin'], 'B09XYZW123');
      expect(fakeClient.upsertedPayloads.first['brand'], 'RIDGID');

      // Filter to the newly added affiliate link by ASIN and remove it
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Search affiliate links by title, brand, subcategory, ASIN...',
        ),
        'B09XYZW123',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove Affiliate Link').first);
      await tester.pumpAndSettle();
      expect(find.text('Remove Affiliate Link?'), findsOneWidget);
      await tester.tap(find.text('Remove Link'));
      await tester.pumpAndSettle();

      expect(fakeClient.deletedIds, contains('custom_1'));
    },
  );

  test(
      '1,000-item Master CSV & 48 Subcategories parse cleanly and skip pending blank rows',
      () {
    expect(PipeBuyerShopTaxonomy.categories, hasLength(8));
    final allSubs = PipeBuyerShopTaxonomy.subcategoriesForCategory(null);
    expect(allSubs, hasLength(48));
    expect(allSubs.toSet(), hasLength(48));

    final masterCsv = File(
      'docs/shop_catalog/pipebuyer_store_1000_items_master.csv',
    ).readAsStringSync();
    const settings = PipeBuyerShopSettings(
      amazonAssociateTagUs: 'pipebuyer-20',
    );
    final blankScan = PipeBuyerShopCsvHelper.parseSpreadsheetText(
      masterCsv,
      settings,
    );
    expect(blankScan.totalDataRows, 1000);
    expect(
      blankScan.readyPayloads.length + blankScan.pendingBlankLinkRows,
      1000,
    );
    expect(blankScan.readyPayloads.length, greaterThanOrEqualTo(8));
    expect(blankScan.invalidRows, isEmpty);

    const partialCsv =
        'item_id,category_code,subcategory,title,brand,amazon_search_helper_url,amazon_affiliate_link\n'
        'pb-test-1,pipe_welding_fab,"Pipe Wrenches, Chain Tongs & Vises",RIDGID 824 24-Inch Aluminum Pipe Wrench,RIDGID,https://www.amazon.com/s?k=ridgid,https://amzn.to/3Pipe24\n'
        'pb-test-2,power_hand_tools,Cordless Impact Wrenches & Socket Sets,Milwaukee M18 Impact,Milwaukee,https://www.amazon.com/s?k=milwaukee,\n';
    final partialScan = PipeBuyerShopCsvHelper.parseSpreadsheetText(
      partialCsv,
      settings,
    );
    expect(partialScan.totalDataRows, 2);
    expect(partialScan.readyPayloads, hasLength(1));
    expect(partialScan.pendingBlankLinkRows, 1);
    expect(partialScan.readyPayloads.first['id'], 'pb-test-1');
    expect(
      partialScan.readyPayloads.first['subcategory'],
      'Pipe Wrenches, Chain Tongs & Vises',
    );
  });

  testWidgets(
    'PipeBuyerShopAdminPage imports ready CSV rows via Bulk Spreadsheet dialog',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeClient = _FakeAdminShopClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopAdminPage(
            client: fakeClient,
            sessionOverride: () async =>
                const PipeBuyerShopRoleSession.authorizedAdmin(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import Spreadsheet (.CSV)').first);
      await tester.pumpAndSettle();

      const csvBatch =
          'item_id,category_code,subcategory,title,brand,amazon_search_helper_url,amazon_affiliate_link\n'
          'pb-bulk-1,rigging_hauling_cargo,"Shackles, Hooks, Swivels & Hardware",Crosby G-209 1-Inch Shackle,Crosby,https://www.amazon.com/s?k=crosby,https://www.amazon.com/dp/B001CROSBY\n'
          'pb-bulk-2,ppe_fr_safety,"H2S / 4-Gas Monitors & Respiratory",Honeywell BW Solo H2S,Honeywell,https://www.amazon.com/s?k=bw,\n';
      await tester.enterText(
        find.byKey(const Key('bulk_spreadsheet_input_field')),
        csvBatch,
      );
      await tester.pumpAndSettle();

      expect(find.text('Ready w/ Links: 1'), findsOneWidget);
      expect(find.text('Pending Blank Links (Skipped): 1'), findsOneWidget);

      await tester.tap(find.text('Publish 1 Ready Item'));
      await tester.pumpAndSettle();

      expect(fakeClient.upsertedPayloads, hasLength(1));
      expect(fakeClient.upsertedPayloads.first['id'], 'pb-bulk-1');
    },
  );

  testWidgets(
    'PipeBuyerShopStorePage renders Shopee-style public storefront with zero developer/admin UI and end-to-end product suggestions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeClient = _FakeAdminShopClient();

      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopStorePage(
            client: fakeClient,
            sessionOverride: () async =>
                const PipeBuyerShopRoleSession.authorizedAdmin(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero developer, admin, or inline product-input controls leak onto /shop
      expect(find.text('Quick-Add Amazon / Affiliate Link'), findsNothing);
      expect(find.text('Add Affiliate Link'), findsNothing);
      expect(find.text('Store Admin'), findsNothing);
      expect(find.text('Remove Link'), findsNothing);
      expect(
        find.text('BRANDS, AFFILIATES & PARTNER STOREFRONTS'),
        findsNothing,
      );

      // Shopee-style e-commerce storefront elements render cleanly
      expect(find.text('CATEGORIES'), findsOneWidget);
      expect(find.text('Sort by'), findsOneWidget);
      expect(find.text('Top Picks'), findsOneWidget);
      expect(find.text('Price: Low to High'), findsOneWidget);
      expect(
        find.text('Know a helpful product not listed? Let us know!'),
        findsWidgets,
      );

      // Public shopper submits a helpful product suggestion
      await tester.tap(
        find.byKey(const Key('shop_suggest_product_top_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suggest a Helpful Product'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('suggest_product_name_field')),
        'RIDGID 31110',
      );
      await tester.enterText(
        find.byKey(const Key('suggest_product_notes_field')),
        'Essential 36-inch aluminum pipe wrench for rig crews.',
      );
      await tester.tap(find.byKey(const Key('suggest_product_submit_button')));
      await tester.pumpAndSettle();

      expect(fakeClient.submittedSuggestions, hasLength(1));
      expect(
        fakeClient.submittedSuggestions.single.productName,
        'RIDGID 31110',
      );
      expect(fakeClient.submittedSuggestions.single.status, 'pending');

      // Admin / Store Manager reviews the suggestion inside /admin/shop and publishes it in 1 click
      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopAdminPage(
            client: fakeClient,
            sessionOverride: () async =>
                const PipeBuyerShopRoleSession.authorizedAdmin(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suggestions (1)'), findsOneWidget);
      await tester.tap(find.text('Suggestions (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Shopper Product Suggestions'), findsOneWidget);
      expect(find.text('RIDGID 31110'), findsOneWidget);

      await tester.tap(find.byKey(const Key('suggestion_add_sugg_1')));
      await tester.pumpAndSettle();

      // SiteStripe Product Finder automatically searched Amazon for "RIDGID 31110"
      expect(find.text('Select SKU'), findsWidgets);
      await tester.tap(find.text('Select SKU').first);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.text('ASIN: B0000224JH'), findsOneWidget);
      await tester.tap(find.text('Publish Affiliate Link'));
      await tester.pumpAndSettle();

      expect(fakeClient.upsertedPayloads, hasLength(1));
      expect(fakeClient.upsertedPayloads.single['asin'], 'B0000224JH');
      expect(fakeClient.submittedSuggestions.single.status, 'added');
      expect(find.text('Suggestions (0)'), findsOneWidget);
    },
  );

  testWidgets(
    'PipeBuyerShopStorePage smart country geo-filtering hides PH-only Lazada/Shopee links for US shoppers and shows them for PH or ALL',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeClient = _FakeAdminShopClient();
      await fakeClient.hideStarterProducts(
        PipeBuyerShopTaxonomy.starterCatalog.map((e) => e.id).toList(),
      );
      await fakeClient.upsertProduct(<String, Object?>{
        'id': 'lazada-ph-welder',
        'title': 'INGCO Inverter Stick Welder 200A (Lazada PH)',
        'brand': 'INGCO',
        'vendorName': 'Lazada',
        'sourceType': 'lazada_affiliate',
        'categoryCode': 'pipe_welding_fab',
        'destinationUrl':
            'https://www.lazada.com.ph/products/ingco-welder-i12345.html',
        'eligibleCountries': <String>['PH'],
        'featured': true,
      });
      await fakeClient.upsertProduct(<String, Object?>{
        'id': 'ali-global-clamp',
        'title': 'Heavy Duty Pipe Alignment Clamp (AliExpress Global)',
        'brand': 'VEVOR',
        'vendorName': 'AliExpress',
        'sourceType': 'aliexpress_affiliate',
        'categoryCode': 'pipe_welding_fab',
        'destinationUrl': 'https://s.click.aliexpress.com/e/_dPipeClamp',
        'eligibleCountries': <String>['GLOBAL'],
        'featured': true,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopStorePage(client: fakeClient),
        ),
      );
      await tester.pumpAndSettle();

      // Default US shopper sees the Worldwide AliExpress item, NOT the PH-only Lazada item
      expect(
        find.text('Heavy Duty Pipe Alignment Clamp (AliExpress Global)'),
        findsOneWidget,
      );
      expect(
        find.text('INGCO Inverter Stick Welder 200A (Lazada PH)'),
        findsNothing,
      );
      expect(
        find.textContaining('1 regional item hidden for US'),
        findsOneWidget,
      );

      // Switch shopper delivery country to Philippines via country picker
      await tester.tap(find.byKey(const Key('shop_country_picker_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Philippines').last);
      await tester.pumpAndSettle();

      expect(
        find.text('INGCO Inverter Stick Welder 200A (Lazada PH)'),
        findsOneWidget,
      );
      expect(
        find.text('Heavy Duty Pipe Alignment Clamp (AliExpress Global)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'PipeBuyerShopAdminPage hides demo templates in 1 click, opens Test Buy Link, and auto-fills photo + country on paste',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final launched = <Uri>[];
      final fakeClient = _FakeAdminShopClient(
        urlLauncher: (uri) async {
          launched.add(uri);
          return true;
        },
        remotePreviewResponder: (raw) async {
          return const PipeBuyerParsedAffiliateSubmission(
            sourceType: PipeBuyerShopSourceType.shopeeAffiliate,
            platformName: 'Shopee',
            asin: '',
            destinationUrl: 'https://shope.ee/9pShopeeDrill',
            monetizedPreviewUs: 'https://shope.ee/9pShopeeDrill',
            monetizedPreviewCa: 'https://shope.ee/9pShopeeDrill',
            embeddedAssociateTag: '',
            effectiveAssociateTag: 'Shopee Shortlink (Embedded Attribution)',
            isAmazonLink: false,
            isShortLink: true,
            imageUrl: 'https://cf.shopee.ph/file/drill-photo-500.jpg',
            suggestedTitle: 'Makita 18V Brushless Hammer Drill Kit',
            suggestedBrand: 'Makita',
            suggestedVendorName: 'Shopee',
            suggestedCategoryCode: 'power_hand_tools',
            suggestedPriceDisplay: 'PHP 6,490',
            eligibleCountries: <String>['PH'],
            resolvedUrl:
                'https://shopee.ph/Makita-18V-Brushless-Drill-i.100.200',
            metadataFetched: true,
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopAdminPage(
            client: fakeClient,
            sessionOverride: () async => const PipeBuyerShopRoleSession(
              authorized: true,
              reason: 'authorized',
              uid: 'joan-uid',
              role: 'store_manager',
              allowedPlatforms: <String>['all'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1-click Hide All Demo Templates clears all 28 built-in starter placeholders
      final hideBtn = find.textContaining('Hide All Demo Templates (');
      expect(hideBtn, findsOneWidget);
      await tester.tap(hideBtn);
      await tester.pumpAndSettle();
      expect(find.text('Affiliate Links (0)'), findsOneWidget);

      // Open Add Affiliate Link dialog and paste a Shopee PH shortlink
      await tester.tap(find.text('Add Affiliate Link').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('affiliate_quick_paste_field')),
        'https://shope.ee/9pShopeeDrill',
      );
      // Advance debounce timer (380ms) and settle
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      // Photo URL, title, price, and PH regional store warning auto-populate
      expect(
        find.text('Makita 18V Brushless Hammer Drill Kit'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Regional Store Detected (PH)'),
        findsOneWidget,
      );

      await tester.tap(find.text('Publish Affiliate Link'));
      await tester.pumpAndSettle();

      expect(fakeClient.upsertedPayloads, hasLength(1));
      expect(
        fakeClient.upsertedPayloads.first['imageUrl'],
        'https://cf.shopee.ph/file/drill-photo-500.jpg',
      );
      expect(fakeClient.upsertedPayloads.first['eligibleCountries'], <String>[
        'PH',
      ]);

      // Switch to Affiliate Links tab (now 1 live item) and click Test Buy Link
      await tester.tap(find.text('Affiliate Links (1)'));
      await tester.pumpAndSettle();

      expect(find.text('YOUR LIVE LINK'), findsOneWidget);
      await tester.tap(find.text('Test Buy Link'));
      await tester.pumpAndSettle();

      expect(launched, hasLength(1));
      expect(launched.first.toString(), 'https://shope.ee/9pShopeeDrill');
    },
  );

  test(
      'All 30 starterCatalog SKUs carry verified direct /dp/ links, high-res photos, and OneLink CA support',
      () {
    expect(PipeBuyerShopTaxonomy.starterCatalog, hasLength(30));
    for (final item in PipeBuyerShopTaxonomy.starterCatalog) {
      expect(
        RegExp(r'^[A-Z0-9]{10}$').hasMatch(item.asin),
        isTrue,
        reason: 'Missing 10-char ASIN on ${item.id}',
      );
      expect(
        item.destinationUrl,
        'https://www.amazon.com/dp/${item.asin}?linkCode=ll1',
      );
      expect(item.destinationUrl.contains('/s?k='), isFalse);
      expect(
        item.imageUrl.startsWith('https://m.media-amazon.com/images/I/'),
        isTrue,
        reason: 'Missing Amazon CDN photo on ${item.id}',
      );
      expect(item.priceDisplay.startsWith(r'$'), isTrue);
      expect(item.subcategory, isNotEmpty);
    }

    // Explicit blank CA tag preserves OneLink routing via amazon.com + US Store ID
    final oneLinkSettings = PipeBuyerShopSettings.fromJson(
      const <String, dynamic>{
        'amazonAssociateTagUs': '366industri09-20',
        'amazonAssociateTagCa': '',
        'forceOverrideAmazonTag': true,
      },
    );
    expect(oneLinkSettings.amazonAssociateTagUs, '366industri09-20');
    expect(oneLinkSettings.amazonAssociateTagCa, '');

    final ridgid36 = PipeBuyerShopTaxonomy.starterCatalog.firstWhere(
      (item) => item.id == 'ridgid-36-aluminum-pipe-wrench',
    );
    final caOneLink = Uri.parse(
      PipeBuyerShopUrlBuilder.buildMonetizedUrl(
        ridgid36,
        oneLinkSettings,
        regionCode: 'CA',
      ),
    );
    expect(caOneLink.host, 'www.amazon.com');
    expect(caOneLink.path, '/dp/B0000224JH');
    expect(caOneLink.queryParameters['tag'], '366industri09-20');
    expect(caOneLink.queryParameters['linkCode'], 'll1');
  });

  testWidgets(
    'SiteStripe Product Finder searches Amazon SKUs and auto-populates direct /dp/ link, photo, category, and subcategory',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeClient = _FakeAdminShopClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopAdminPage(
            client: fakeClient,
            sessionOverride: () async =>
                const PipeBuyerShopRoleSession.authorizedAdmin(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Affiliate Product'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('amazon_product_finder_field')),
        'RIDGID 31110',
      );
      await tester.tap(find.byKey(const Key('amazon_product_finder_button')));
      await tester.pumpAndSettle();

      expect(find.text('Select SKU'), findsWidgets);
      await tester.tap(find.text('Select SKU').first);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();

      expect(find.text('ASIN: B0000224JH'), findsOneWidget);

      await tester.tap(find.text('Publish Affiliate Link'));
      await tester.pumpAndSettle();

      expect(fakeClient.upsertedPayloads, hasLength(1));
      final saved = fakeClient.upsertedPayloads.first;
      expect(saved['asin'], 'B0000224JH');
      expect(
        saved['destinationUrl'].toString(),
        contains('https://www.amazon.com/dp/B0000224JH'),
      );
      expect(
        saved['imageUrl'].toString(),
        startsWith('https://m.media-amazon.com/images/I/'),
      );
      expect(saved['categoryCode'], 'pipe_welding_fab');
      expect(saved['subcategory'], 'Pipe Wrenches, Chain Tongs & Vises');
    },
  );

  testWidgets(
    'Public B2B OEM/Dealer representative submits Caterpillar & Brandt Tractor Request-to-List without consumer auth blocker',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = _FakeAdminShopClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopVendorApplyPage(
            client: client,
            // Explicitly verify public B2B corporate access (no consumer login wall)
            skipAuthGateForTest: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Request to List Your Equipment, Tools & Brand Catalog on Pipe Buyer',
        ),
        findsOneWidget,
      );

      // Select Heavy Equipment OEM / Dealer track
      await tester.tap(find.text('Heavy Equipment OEM / Dealer'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Company, Distributor, or Brand Name *',
        ),
        'Brandt Tractor Ltd. — Pipeline & Earthmoving Division',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Primary Contact Name *'),
        'Jordan Reid',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Role / Job Title'),
        'VP Fleet & OEM Partnerships',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Direct Phone *'),
        '+1 306 555 0199',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Business Email *'),
        'jordan.reid@brandt.example.com',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Headquarters or Authorized Dealer Territory',
        ),
        'Regina, SK • Western Canada & US North',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Sample Product / Dealer Inventory URL',
        ),
        'https://www.brandt.ca/equipment/pipelayers',
      );

      // Quick-add Caterpillar & Brandt Tractor brand chips
      final catChip = find.byKey(const Key('brand_chip_caterpillar'));
      await tester.scrollUntilVisible(
        catChip,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(catChip);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('brand_chip_brandt_tractor')));
      await tester.pumpAndSettle();

      final submitBtn = find.text('Submit Store Partner Application');
      await tester.scrollUntilVisible(
        submitBtn,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Store Partner Application Submitted'), findsOneWidget);
      expect(
        find.text('Pipe Buyer Administrators & Store Managers Notified'),
        findsOneWidget,
      );
      expect(find.textContaining('app_test_101'), findsOneWidget);

      expect(
        client.lastVendorSubmission?['companyName'],
        'Brandt Tractor Ltd. — Pipeline & Earthmoving Division',
      );
      expect(
        client.lastVendorSubmission?['partnershipTrack'],
        'oem_heavy_equipment_dealer',
      );
      expect(
        client.lastVendorSubmission?['contactTitle'],
        'VP Fleet & OEM Partnerships',
      );
      expect(
        client.lastVendorSubmission?['sampleCatalogUrl'],
        'https://www.brandt.ca/equipment/pipelayers',
      );
      expect(
        client.lastVendorSubmission?['brandsCarried'],
        containsAll(<String>['Caterpillar', 'Brandt Tractor']),
      );
    },
  );

  testWidgets(
    'PipeBuyerShopAdminPage deep-links via initialSection=applications and reviews + notifies partner',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeClient = _FakeAdminShopClient();
      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: PipeBuyerShopAdminPage(
            client: fakeClient,
            initialSection: 'applications',
            sessionOverride: () async =>
                const PipeBuyerShopRoleSession.authorizedAdmin(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deep-linked straight into the Vendor Applications review console
      expect(
        find.text('OEM, Brand & Distributor Listing Requests'),
        findsOneWidget,
      );
      expect(find.text('Midwest Milwaukee & Rigging Supply'), findsOneWidget);
      expect(
        find.textContaining('Brands: Brandt Tractor, Caterpillar, Milwaukee'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Admin Alerts Dispatched: 2 in-app/push'),
        findsOneWidget,
      );

      // Open Review & Message dialog and approve with onboarding instructions
      await tester.tap(find.byKey(const Key('vendor_dialog_app_1')));
      await tester.pumpAndSettle();

      expect(
        find.text('Review Midwest Milwaukee & Rigging Supply'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Message / Onboarding Notes to Partner'),
        'Approved for Pipe Buyer Storefront & Heavy Equipment showcase.',
      );
      await tester.tap(find.text('Save Decision'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastReviewedApplication?['applicationId'], 'app_1');
      expect(fakeClient.lastReviewedApplication?['status'], 'approved');
      expect(fakeClient.lastReviewedApplication?['notifyApplicant'], isTrue);
      expect(
        fakeClient.lastReviewedApplication?['reviewNotes'],
        'Approved for Pipe Buyer Storefront & Heavy Equipment showcase.',
      );
      expect(find.text('APPROVED'), findsOneWidget);
    },
  );
}
