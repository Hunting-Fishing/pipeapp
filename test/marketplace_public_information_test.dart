import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/config/public_release_config.dart';
import 'package:pipe_app/marketplace/marketplace_public_information.dart';

void main() {
  const releaseConfiguration = PublicReleaseConfiguration(
    environment: 'staging',
    supportEmail: 'support@pipebuyer.com',
  );

  test('public information kinds map to reviewed policy identifiers', () {
    expect(
      MarketplacePublicInformationKind.privacy.policyId,
      'privacy_notice',
    );
    expect(
      MarketplacePublicInformationKind.terms.policyId,
      'terms_of_service',
    );
    expect(MarketplacePublicInformationKind.support.policyId, isNull);
    expect(MarketplacePublicInformationKind.accountDeletion.policyId, isNull);
  });

  testWidgets('public support explains both authenticated and access help',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MarketplacePublicInformationPage(
          kind: MarketplacePublicInformationKind.support,
          releaseConfiguration: releaseConfiguration,
        ),
      ),
    );

    expect(find.text('Help and support'), findsOneWidget);
    expect(find.text('Signed-in support'), findsOneWidget);
    expect(find.text('Cannot access your account?'), findsOneWidget);
    expect(find.text('Email support'), findsOneWidget);
    expect(find.textContaining('support@pipebuyer.com'), findsOneWidget);
    expect(find.textContaining('not an emergency service'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public deletion page explains the controlled lifecycle',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MarketplacePublicInformationPage(
          kind: MarketplacePublicInformationKind.accountDeletion,
          releaseConfiguration: releaseConfiguration,
        ),
      ),
    );

    expect(find.text('Delete your account'), findsOneWidget);
    expect(find.text('Request deletion in Pipe Buyer'), findsOneWidget);
    expect(find.text('Fourteen-day cancellation period'), findsOneWidget);
    expect(find.text('Records that must be retained'), findsOneWidget);
    expect(find.textContaining('active listings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
