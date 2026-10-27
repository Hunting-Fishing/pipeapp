import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_account_hub.dart';
import 'package:pipe_app/marketplace/marketplace_auth_action_page.dart';
import 'package:pipe_app/marketplace/marketplace_deep_links.dart';
import 'package:pipe_app/marketplace/marketplace_home_welcome.dart';

void main() {
  group('Auth action URL & ActionCodeSettings helpers', () {
    test('marketplaceEmailActionCodeSettings builds Pipe Buyer return URL', () {
      final prodSettings = marketplaceEmailActionCodeSettings(
        currentUri: Uri.parse('https://pipebuyer.com/auth'),
      );
      expect(prodSettings.url, 'https://pipebuyer.com/?emailVerified=1');
      expect(prodSettings.handleCodeInApp, isFalse);

      final stagingSettings = marketplaceEmailActionCodeSettings(
        returnPath: '/?emailVerified=1',
        currentUri: Uri.parse('https://pipebuyer-5c77f.web.app/'),
      );
      expect(
        stagingSettings.url,
        'https://pipebuyer-5c77f.web.app/?emailVerified=1',
      );

      final fallbackSettings = marketplaceEmailActionCodeSettings(
        currentUri: Uri.parse('https://untrusted.example.com/phish'),
      );
      expect(fallbackSettings.url, 'https://pipebuyer.com/?emailVerified=1');
    });

    test('isFirebaseAuthActionMode recognizes standard Firebase email modes',
        () {
      expect(isFirebaseAuthActionMode('verifyEmail'), isTrue);
      expect(isFirebaseAuthActionMode('verifyAndChangeEmail'), isTrue);
      expect(isFirebaseAuthActionMode('resetPassword'), isTrue);
      expect(isFirebaseAuthActionMode('recoverEmail'), isTrue);
      expect(isFirebaseAuthActionMode(''), isFalse);
      expect(isFirebaseAuthActionMode('signIn'), isFalse);
      expect(isFirebaseAuthActionMode(null), isFalse);
    });

    test('resolveSafeContinueRoute blocks open redirects and self-loops', () {
      expect(resolveSafeContinueRoute(null), '/');
      expect(resolveSafeContinueRoute(''), '/');
      expect(
        resolveSafeContinueRoute('https://pipebuyer.com/?emailVerified=1'),
        '/?emailVerified=1',
      );
      expect(
        resolveSafeContinueRoute('https://www.pipebuyer.com/listing/abc'),
        '/listing/abc',
      );
      expect(
        resolveSafeContinueRoute('https://attacker.example.com/steal'),
        '/',
      );
      expect(
        resolveSafeContinueRoute(
            'https://pipebuyer.com/auth/action?oobCode=123'),
        '/',
      );
      expect(
        resolveSafeContinueRoute(
            'https://flutter-flow-pipe.firebaseapp.com/__/auth/action'),
        '/',
      );
    });
  });

  group('MarketplaceAuthActionPage widget behavior', () {
    testWidgets(
      'auto-verifies email action code and redirects automatically into Pipe Buyer',
      (tester) async {
        String? appliedCode;
        String? navigatedTo;

        await tester.pumpWidget(
          MaterialApp(
            home: MarketplaceAuthActionPage(
              mode: 'verifyEmail',
              oobCode: 'oob-verify-123',
              continueUrl: 'https://pipebuyer.com/?emailVerified=1',
              autoRedirectDelay: const Duration(milliseconds: 300),
              applyActionCodeOverride: (code) async {
                appliedCode = code;
              },
              onNavigateRoute: (target) {
                navigatedTo = target;
              },
            ),
          ),
        );

        await tester.pump();
        expect(appliedCode, 'oob-verify-123');
        expect(find.text('Email verified'), findsOneWidget);
        expect(find.text('Open Pipe Buyer'), findsOneWidget);
        expect(navigatedTo, isNull);

        await tester.pump(const Duration(milliseconds: 350));
        expect(navigatedTo, '/?emailVerified=1');
      },
    );

    testWidgets(
      'handles password reset link inside Pipe Buyer and redirects after saving',
      (tester) async {
        String? resetCode;
        String? savedPassword;
        String? navigatedTo;

        await tester.pumpWidget(
          MaterialApp(
            home: MarketplaceAuthActionPage(
              mode: 'resetPassword',
              oobCode: 'oob-reset-456',
              autoRedirectDelay: const Duration(milliseconds: 250),
              verifyPasswordResetCodeOverride: (code) async {
                expect(code, 'oob-reset-456');
                return 'rsanford@1stdefenceindustries.com';
              },
              confirmPasswordResetOverride: (code, password) async {
                resetCode = code;
                savedPassword = password;
              },
              onNavigateRoute: (target) {
                navigatedTo = target;
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Choose a new password'), findsOneWidget);
        expect(
          find.textContaining('rsanford@1stdefenceindustries.com'),
          findsOneWidget,
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'New password'),
          'NewSecurePass!99',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm new password'),
          'NewSecurePass!99',
        );
        await tester.tap(find.text('Save new password'));
        await tester.pump();

        expect(resetCode, 'oob-reset-456');
        expect(savedPassword, 'NewSecurePass!99');
        expect(find.text('Password updated'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 300));
        expect(navigatedTo, '/');
      },
    );

    testWidgets(
      'incomplete or expired link shows Open Pipe Buyer escape hatch',
      (tester) async {
        String? navigatedTo;

        await tester.pumpWidget(
          MaterialApp(
            home: MarketplaceAuthActionPage(
              mode: 'verifyEmail',
              oobCode: '',
              onNavigateRoute: (target) {
                navigatedTo = target;
              },
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Link already used or expired'), findsOneWidget);
        await tester.tap(find.text('Open Pipe Buyer'));
        await tester.pump();
        expect(navigatedTo, '/');
      },
    );
  });

  group('MarketplaceEmailVerificationReminderBanner', () {
    testWidgets('renders non-blocking reminder with resend, tab shortcut, and dismiss',
        (tester) async {
      var resent = false;
      var openedTab = false;
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketplaceEmailVerificationReminderBanner(
              email: 'rsanford@1stdefenceindustries.com',
              onResend: () => resent = true,
              onOpenVerification: () => openedTab = true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('Confirm your email when convenient'), findsOneWidget);
      expect(
        find.textContaining('rsanford@1stdefenceindustries.com'),
        findsOneWidget,
      );

      await tester.tap(find.text('Resend email'));
      expect(resent, isTrue);

      await tester.tap(find.text('Verification & Security'));
      expect(openedTab, isTrue);

      await tester.tap(find.byTooltip('Dismiss reminder'));
      expect(dismissed, isTrue);
    });
  });

  group('Account hub & non-blocking onboarding architecture contracts', () {
    test('Verification & Security lives in Account hub tab index 2', () {
      expect(MarketplaceAccountHub.overviewTabIndex, 0);
      expect(MarketplaceAccountHub.profileTabIndex, 1);
      expect(MarketplaceAccountHub.verificationTabIndex, 2);
      expect(MarketplaceAccountHub.listingsTabIndex, 3);
      expect(MarketplaceAccountHub.messagesTabIndex, 4);
      expect(MarketplaceAccountHub.notificationsTabIndex, 5);
      expect(MarketplaceAccountHub.settingsTabIndex, 6);
      expect(MarketplaceAccountHub.adminPortalTabIndex, 7);

      final hubSource = File(
        'lib/marketplace/marketplace_account_hub.dart',
      ).readAsStringSync();
      expect(hubSource, contains("text: 'Verification & Security'"));
      expect(
        hubSource,
        contains('const MarketplaceAccountSecurityPage(embedded: true)'),
      );
    });

    test('Security page removes legacy LOCKED gate copy and router wires /auth/action',
        () {
      final securitySource = File(
        'lib/marketplace/marketplace_account_security_page.dart',
      ).readAsStringSync();
      expect(securitySource, isNot(contains('Marketplace access: LOCKED')));
      expect(
        securitySource,
        isNot(contains('Verify either your email or mobile number to enter Pipe Buyer')),
      );
      expect(securitySource, isNot(contains('administrator access')));
      expect(
        securitySource,
        isNot(contains('Configure Banking & Payout Vault')),
      );

      expect(MarketplaceDeepLinks.authActionRouteName, 'marketplace-auth-action');
      expect(MarketplaceDeepLinks.authActionPath, '/auth/action');

      final navSource = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
      expect(navSource, contains('MarketplaceDeepLinks.authActionRouteName'));
      expect(navSource, contains('MarketplaceDeepLinks.authActionPath'));
      expect(navSource, contains("state.uri.path == '/__/auth/action'"));
      expect(navSource, contains('MarketplaceAuthActionPage('));
    });
  });
}
