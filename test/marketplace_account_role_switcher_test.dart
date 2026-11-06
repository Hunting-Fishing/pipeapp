import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/design/pipe_buyer_theme.dart';
import 'package:pipe_app/marketplace/marketplace_account_role_switcher.dart';

void main() {
  test(
    'resolveWebsiteRolesFromClaims surfaces Admin & Store roles when MFA is pending vs live',
    () {
      // Admin claims assigned, 2-step SMS not yet enrolled/completed
      final pendingMfaRoles = resolveWebsiteRolesFromClaims(
        const <String, dynamic>{
          'accountType': 'personal',
          'personal': true,
          'business': false,
          'admin': true,
          'role': 'administrator',
          'email_verified': true,
        },
      );
      expect(pendingMfaRoles.length, 2);
      expect(pendingMfaRoles[0].title, 'Administrator Portal');
      expect(pendingMfaRoles[0].authorized, isFalse);
      expect(pendingMfaRoles[0].mfaRequired, isTrue);
      expect(pendingMfaRoles[0].badgeLabel, '2-STEP SMS NEEDED');
      expect(pendingMfaRoles[1].title, 'Store & Affiliate Admin');
      expect(pendingMfaRoles[1].authorized, isFalse);
      expect(pendingMfaRoles[1].mfaRequired, isTrue);

      // Admin claims assigned + 2-step SMS completed
      final liveAdminRoles = resolveWebsiteRolesFromClaims(
        const <String, dynamic>{
          'admin': true,
          'role': 'administrator',
          'email_verified': true,
          'yellowPagesRole': 'manager',
          'firebase': <String, dynamic>{
            'sign_in_second_factor': 'phone',
          },
        },
      );
      expect(liveAdminRoles.length, 3);
      expect(liveAdminRoles[0].authorized, isTrue);
      expect(liveAdminRoles[0].badgeLabel, 'ROLE LIVE');
      expect(liveAdminRoles[1].target, MarketplaceWebsiteRoleTarget.shopAdmin);
      expect(liveAdminRoles[1].authorized, isTrue);
      expect(
        liveAdminRoles[2].target,
        MarketplaceWebsiteRoleTarget.directoryAdmin,
      );
      expect(liveAdminRoles[2].authorized, isTrue);
    },
  );

  testWidgets(
    'Change account popup lists Personal, multiple Businesses, new Business creator & Website Roles cleanly on mobile',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      MarketplaceAccountSwitcherSelection? result;
      final roles = resolveWebsiteRolesFromClaims(
        const <String, dynamic>{
          'admin': true,
          'role': 'administrator',
          'email_verified': true,
        },
      );
      const businesses = <MarketplaceBusinessProfileEntry>[
        MarketplaceBusinessProfileEntry(
          id: 'primary',
          publicName: 'Pipe Buyer Admin Business Account',
          serviceAreaLabel: 'Alberta, Canada',
        ),
        MarketplaceBusinessProfileEntry(
          id: 'biz_2',
          publicName: 'Prairie Pipe & Rigging Ltd.',
          serviceAreaLabel: 'Saskatchewan, Canada',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: PipeBuyerTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await MarketplaceAccountRoleSwitcherDialog.show(
                      context,
                      activeAccountType: 'personal',
                      activeBusinessProfileId: 'primary',
                      accountEmail: 'operator@example.com',
                      personalDisplayName: 'Jordi B.',
                      personalCommunity: 'Grande Prairie, AB',
                      businessProfiles: businesses,
                      websiteRoles: roles,
                    );
                  },
                  child: const Text('Change'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open switcher dialog and verify all accounts & roles appear
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();

      expect(find.text('Switch account, business or role'), findsOneWidget);
      expect(find.text('Jordi B.'), findsOneWidget);
      expect(find.text('Pipe Buyer Admin Business Account'), findsOneWidget);
      expect(find.text('Prairie Pipe & Rigging Ltd.'), findsOneWidget);
      expect(find.text('Administrator Portal'), findsOneWidget);
      expect(find.text('Store & Affiliate Admin'), findsOneWidget);
      expect(find.text('2-STEP SMS NEEDED'), findsNWidgets(2));

      // Switch to second business
      await tester.tap(find.byKey(const Key('switcher-business-biz_2')));
      await tester.pumpAndSettle();
      expect(
        result?.kind,
        MarketplaceAccountSwitcherActionKind.switchBusiness,
      );
      expect(result?.businessProfileId, 'biz_2');

      // Re-open and create a 3rd business account
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('switcher-add-business-button')),
      );
      await tester.tap(find.byKey(const Key('switcher-add-business-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('switcher-new-business-input')),
      );
      await tester.enterText(
        find.byKey(const Key('switcher-new-business-input')),
        'Northern Welding Supply Inc.',
      );
      await tester.ensureVisible(
        find.byKey(const Key('switcher-create-business-submit')),
      );
      await tester.tap(
        find.byKey(const Key('switcher-create-business-submit')),
      );
      await tester.pumpAndSettle();
      expect(
        result?.kind,
        MarketplaceAccountSwitcherActionKind.createBusiness,
      );
      expect(result?.newBusinessName, 'Northern Welding Supply Inc.');

      // Re-open and tap Store & Affiliate Admin role
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('switcher-role_shop_admin')),
      );
      await tester.tap(find.byKey(const Key('switcher-role_shop_admin')));
      await tester.pumpAndSettle();
      expect(result?.kind, MarketplaceAccountSwitcherActionKind.openRole);
      expect(result?.role?.target, MarketplaceWebsiteRoleTarget.shopAdmin);
    },
  );
}
