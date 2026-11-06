import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_account_menu.dart';
import 'package:pipe_app/marketplace/marketplace_admin_access.dart';

void main() {
  tearDown(() => setMarketplaceAdminViewAsUserMode(false));

  group('administrator access state', () {
    test('requires both administrator claims', () {
      expect(
        marketplaceAdministratorClaimsState(const {'admin': true}),
        MarketplaceAdministratorState.roleMissing,
      );
      expect(
        marketplaceAdministratorClaimsState(
          const {'role': 'administrator'},
        ),
        MarketplaceAdministratorState.roleMissing,
      );
    });

    test('reports MFA requirement for a provisioned administrator role', () {
      expect(
        marketplaceAdministratorClaimsState(
          const {'admin': true, 'role': 'administrator'},
        ),
        MarketplaceAdministratorState.mfaRequired,
      );
    });

    test('authorizes only a role with second-factor evidence', () {
      const claims = {
        'admin': true,
        'role': 'administrator',
        'firebase': {'sign_in_second_factor': 'phone'},
      };
      expect(
        marketplaceAdministratorClaimsState(claims),
        MarketplaceAdministratorState.authorized,
      );
      expect(marketplaceAdministratorClaims(claims), isTrue);
    });

    test('email and public profile fields cannot grant administrator UI', () {
      expect(
        marketplaceAdministratorClaims({
          'email': 'administrator@example.com',
          'email_verified': true,
          'isAdmin': true,
        }),
        isFalse,
      );
    });
  });

  group('admin view vs. view what everyone else sees mode', () {
    testWidgets('regular non-admin user never sees admin badges or menu items',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                child: MarketplaceAccountMenuButton(
                  extended: true,
                  signedInOverride: true,
                  displayNameOverride: 'Field Buyer',
                  emailOverride: 'buyer@example.com',
                  adminAccessOverride: ({forceRefresh = false}) async => false,
                  onAccount: () {},
                  onTrust: () {},
                  onMemberships: () {},
                  onSupport: () {},
                  onAdminSettings: () {},
                  onSignOut: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account & membership'), findsOneWidget);
      expect(find.text('Administrator • Full access'), findsNothing);

      await tester.tap(find.text('Field Buyer'));
      await tester.pumpAndSettle();

      expect(find.text('ADMIN'), findsNothing);
      expect(find.text('Admin settings'), findsNothing);
      expect(find.text('View what everyone else sees'), findsNothing);
      expect(find.text('Switch back to Admin view'), findsNothing);
    });

    testWidgets(
        'authorized admin can switch into View what everyone else sees mode and back to Admin view',
        (tester) async {
      var openedAdminSettings = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                child: MarketplaceAccountMenuButton(
                  extended: true,
                  signedInOverride: true,
                  displayNameOverride: 'Platform Operator',
                  emailOverride: 'operator@example.com',
                  adminAccessOverride: ({forceRefresh = false}) async => true,
                  onAccount: () {},
                  onTrust: () {},
                  onMemberships: () {},
                  onSupport: () {},
                  onAdminSettings: () => openedAdminSettings += 1,
                  onSignOut: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In Admin Mode: shows Administrator • Full access, ADMIN badge, Admin settings & preview toggle
      expect(find.text('Administrator • Full access'), findsOneWidget);
      expect(find.text('Account & membership'), findsNothing);

      await tester.tap(find.text('Platform Operator'));
      await tester.pumpAndSettle();

      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('Admin settings'), findsOneWidget);
      expect(find.text('View what everyone else sees'), findsOneWidget);

      // Switch to "View what everyone else sees" mode
      await tester.tap(find.text('View what everyone else sees'));
      await tester.pumpAndSettle();

      expect(marketplaceAdminViewAsUserMode.value, isTrue);
      // Footer card now matches regular customer UI identically
      expect(find.text('Administrator • Full access'), findsNothing);
      expect(find.text('Account & membership'), findsOneWidget);

      // Open account menu while in regular-user preview: no ADMIN pill or Admin settings,
      // but provides 1-click "Switch back to Admin view"
      await tester.tap(find.text('Platform Operator'));
      await tester.pumpAndSettle();

      expect(find.text('ADMIN'), findsNothing);
      expect(find.text('Admin settings'), findsNothing);
      expect(find.text('Switch back to Admin view'), findsOneWidget);

      // Switch back to Admin view
      await tester.tap(find.text('Switch back to Admin view'));
      await tester.pumpAndSettle();

      expect(marketplaceAdminViewAsUserMode.value, isFalse);
      expect(find.text('Administrator • Full access'), findsOneWidget);

      // Opening Admin settings works cleanly
      await tester.tap(find.text('Platform Operator'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Admin settings'));
      await tester.pumpAndSettle();
      expect(openedAdminSettings, 1);
    });
  });
}
