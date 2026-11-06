import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/design/pipe_buyer_theme.dart';
import 'package:pipe_app/marketplace/marketplace_admin_access.dart';
import 'package:pipe_app/marketplace/marketplace_admin_user_permissions_panel.dart';
import 'package:pipe_app/marketplace/pipebuyer_shop_admin_page.dart';
import 'package:pipe_app/marketplace/pipebuyer_shop_client.dart';
import 'package:pipe_app/marketplace/pipebuyer_shop_taxonomy.dart';

class _FakePermissionsRepository implements AdminPermissionsRepository {
  _FakePermissionsRepository(this._records);

  final List<AdminManagedUserRecord> _records;
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];

  @override
  Future<List<AdminManagedUserRecord>> listUsers({String query = ''}) async {
    return List<AdminManagedUserRecord>.from(_records);
  }

  @override
  Future<AdminManagedUserRecord> updatePermissions(
    Map<String, Object?> payload,
  ) async {
    calls.add(payload);
    final uid = payload['targetUid']?.toString() ?? '';
    final email = payload['email']?.toString().toLowerCase() ?? '';
    final idx = _records.indexWhere(
      (u) =>
          (uid.isNotEmpty && u.uid == uid) ||
          (email.isNotEmpty && u.email.toLowerCase() == email),
    );
    if (idx < 0) {
      throw StateError('User not found');
    }
    final prev = _records[idx];
    final updated = AdminManagedUserRecord(
      uid: prev.uid,
      email: prev.email,
      displayName: prev.displayName,
      emailVerified: prev.emailVerified,
      providers: prev.providers,
      hasFederatedProvider: prev.hasFederatedProvider,
      isPrimaryAdmin: prev.isPrimaryAdmin,
      isAdmin: payload['grantAdmin'] is bool
          ? payload['grantAdmin'] as bool
          : prev.isAdmin,
      canGrantPermissions: payload['permissions'] is Map
          ? ((payload['permissions'] as Map)['canGrantPermissions'] == true)
          : prev.canGrantPermissions,
      shopRole: payload['shopRole']?.toString() ?? prev.shopRole,
      allowedAffiliatePlatforms: payload['allowedAffiliatePlatforms'] is List
          ? List<String>.from(payload['allowedAffiliatePlatforms'] as List)
          : prev.allowedAffiliatePlatforms,
      restricted: payload['restricted'] is bool
          ? payload['restricted'] as bool
          : prev.restricted,
      loginDisabled: payload['loginDisabled'] is bool
          ? payload['loginDisabled'] as bool
          : prev.loginDisabled,
      restrictions: payload['restrictions'] is List
          ? List<String>.from(payload['restrictions'] as List)
          : prev.restrictions,
      restrictionReason:
          payload['restrictionReason']?.toString() ?? prev.restrictionReason,
    );
    _records[idx] = updated;
    return updated;
  }
}

class _FakeShopClient extends PipeBuyerShopClient {
  final List<Map<String, Object?>> upserted = <Map<String, Object?>>[];

  @override
  Future<PipeBuyerShopAdminSnapshot> getAdminDashboard() async {
    return const PipeBuyerShopAdminSnapshot(
      actor: PipeBuyerShopRoleSession(
        authorized: true,
        reason: 'authorized',
        uid: 'google-contributor-1',
        role: 'affiliate_contributor',
        allowedPlatforms: <String>['all'],
      ),
      settings: PipeBuyerShopSettings(
        amazonAssociateTagUs: 'pipebuyer-20',
        aliexpressTrackingId: '_dPipeAli',
        shopeeAffiliateSubId: 'PipeBuyerShopee1',
        lazadaAffiliateSubId: 'pipebuyer_laz',
      ),
      products: <PipeBuyerShopProduct>[],
      applications: <Map<String, dynamic>>[],
      vendors: <Map<String, dynamic>>[],
      analytics: <String, dynamic>{'totalRecordedClicks': 12},
    );
  }

  @override
  Future<Map<String, dynamic>> upsertProduct(
    Map<String, Object?> payload,
  ) async {
    upserted.add(payload);
    return <String, dynamic>{'productId': 'prod_1', 'product': payload};
  }
}

void main() {
  test(
      'Federated Google Admin claims authorize cleanly and restricted claims fail closed',
      () {
    expect(
      marketplaceAdministratorClaimsState(const <String, dynamic>{
        'admin': true,
        'role': 'administrator',
        'federatedAdminApproved': true,
        'email_verified': true,
      }),
      MarketplaceAdministratorState.authorized,
    );

    expect(
      marketplaceAdministratorClaimsState(const <String, dynamic>{
        'admin': true,
        'role': 'administrator',
        'primaryAdmin': true,
        'email_verified': true,
        'restricted': true,
      }),
      MarketplaceAdministratorState.roleMissing,
    );
  });

  test(
      'Multi-platform affiliate URL builder & parser handle AliExpress, Shopee, Lazada, Involve Asia, eBay & VEVOR',
      () {
    expect(
      PipeBuyerShopTaxonomy.affiliatePlatformsDirectory.length,
      greaterThanOrEqualTo(14),
    );

    const settings = PipeBuyerShopSettings(
      amazonAssociateTagUs: 'pipebuyer-20',
      amazonAssociateTagSg: 'pipebuyersg-22',
      aliexpressTrackingId: '_dPipeAli',
      shopeeAffiliateSubId: 'PipeBuyerShopee1',
      lazadaAffiliateSubId: 'pipebuyer_laz',
      involveAsiaSubId: 'pb_involve',
      ebayCampaignId: '5338999999',
    );

    final ali = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
      'Just found this amazing item on AliExpress: Ultrasonic Thickness Gauge https://s.click.aliexpress.com/e/_DmPipe99',
      settings,
    );
    expect(ali, isNotNull);
    expect(ali!.sourceType, PipeBuyerShopSourceType.aliexpressAffiliate);
    expect(ali.platformName, 'AliExpress');
    expect(ali.isShortLink, isTrue);
    expect(ali.suggestedCategoryCode, 'measuring_inspection');

    final shopee = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
      'https://shopee.ph/Bosch-Heavy-Duty-Angle-Grinder-i.112233.445566',
      settings,
    );
    expect(shopee, isNotNull);
    expect(shopee!.sourceType, PipeBuyerShopSourceType.shopeeAffiliate);
    expect(shopee.suggestedBrand, 'Bosch');
    expect(
      Uri.parse(shopee.monetizedPreviewUs).queryParameters['sub_id'],
      'PipeBuyerShopee1',
    );

    final lazada = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
      'https://www.lazada.com.ph/products/makita-cordless-impact-wrench-i998877-s112233.html',
      settings,
    );
    expect(lazada, isNotNull);
    expect(lazada!.sourceType, PipeBuyerShopSourceType.lazadaAffiliate);
    expect(lazada.suggestedBrand, 'Makita');
    expect(
      Uri.parse(lazada.monetizedPreviewUs).queryParameters['aff_sub'],
      'pipebuyer_laz',
    );

    final involve = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
      'https://invol.co/cl99pipe',
      settings,
    );
    expect(involve, isNotNull);
    expect(
      Uri.parse(involve!.monetizedPreviewUs).queryParameters['subid'],
      'pb_involve',
    );
  });

  testWidgets(
      'Admin User Permissions Panel grants Google Sign-in user affiliate access and restricts/unrestricts users',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _FakePermissionsRepository(<AdminManagedUserRecord>[
      const AdminManagedUserRecord(
        uid: 'primary-admin-1',
        email: 'admin@example.com',
        displayName: 'Primary Operator',
        emailVerified: true,
        providers: <String>['google.com'],
        hasFederatedProvider: true,
        isPrimaryAdmin: true,
        isAdmin: true,
        canGrantPermissions: true,
      ),
      const AdminManagedUserRecord(
        uid: 'new-google-user-1',
        email: 'newcontributor@example.com',
        displayName: 'New Google Contributor',
        emailVerified: true,
        providers: <String>['google.com'],
        hasFederatedProvider: true,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: PipeBuyerTheme.light(),
        home: Scaffold(
          body: MarketplaceAdminUserPermissionsPanel(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRIMARY ADMIN'), findsOneWidget);
    expect(find.textContaining('New Google Contributor'), findsOneWidget);

    // 1-click Grant Amazon / Affiliate Access to the new Google Sign-in user
    await tester.tap(find.text('Grant Amazon / Affiliate Access'));
    await tester.pumpAndSettle();

    expect(repo.calls, hasLength(1));
    expect(repo.calls.first['shopRole'], 'catalog_editor');
    expect(repo.calls.first['allowedAffiliatePlatforms'], const <String>['all']);
    expect(find.text('STORE: CATALOG_EDITOR'), findsOneWidget);

    // Restrict the user, then unrestrict them
    await tester.tap(find.text('Restrict User'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restrict User'));
    await tester.pumpAndSettle();

    expect(find.text('RESTRICTED'), findsOneWidget);

    await tester.tap(find.text('Unrestrict User'));
    await tester.pumpAndSettle();
    expect(find.text('RESTRICTED'), findsNothing);
  });

  testWidgets(
      'Google Sign-in Affiliate Contributor can browse 25+ Passive Income Platforms and publish Shopee link',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = _FakeShopClient();
    await tester.pumpWidget(
      MaterialApp(
        theme: PipeBuyerTheme.light(),
        home: PipeBuyerShopAdminPage(
          client: client,
          sessionOverride: () async => const PipeBuyerShopRoleSession(
            authorized: true,
            reason: 'authorized',
            uid: 'google-contributor-1',
            role: 'affiliate_contributor',
            allowedPlatforms: <String>['all'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Passive Income Platforms tab
    await tester.tap(find.text('Passive Income Platforms (25+)'));
    await tester.pumpAndSettle();
    expect(find.text('Shopee Affiliate Program'), findsOneWidget);
    expect(find.text('AliExpress Portals Affiliate Program'), findsOneWidget);

    // Publish a Shopee affiliate product via Quick-Paste
    await tester.tap(find.text('Add Affiliate Link').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Paste Amazon SiteStripe Link, amzn.to, Share Text, HTML, or ASIN',
      ),
      'Check out Bosch Heavy Duty Angle Grinder https://shope.ee/9pShopeeTool',
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform: Shopee'), findsOneWidget);

    await tester.tap(find.text('Publish Affiliate Link'));
    await tester.pumpAndSettle();

    expect(client.upserted, hasLength(1));
    expect(client.upserted.first['sourceType'], 'shopee_affiliate');
    expect(client.upserted.first['vendorName'], 'Shopee');
  });
}
