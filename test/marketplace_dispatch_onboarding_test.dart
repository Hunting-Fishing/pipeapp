import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_onboarding.dart';

void main() {
  testWidgets('Dispatch onboarding explains network and wires primary actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var postCount = 0;
    var browseCount = 0;
    var signupCount = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarketplaceDispatchOnboarding(
          onPostLoad: () => postCount += 1,
          onBrowseJobs: () => browseCount += 1,
          onJoinCarrier: () => signupCount += 1,
        ),
      ),
    ));

    expect(find.text('Pipe Buyer Dispatch Network'), findsOneWidget);
    expect(find.text('Request trucking service'), findsOneWidget);
    expect(find.text('Offer trucking services'), findsOneWidget);
    expect(find.text(r'$25 per year'), findsOneWidget);
    expect(find.text(r'$10 per awarded job'), findsOneWidget);
    expect(find.text('Dispatch notifications'), findsOneWidget);
    expect(
      find.textContaining('Billing and fee collection are not active'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Post a load request'));
    await tester.pump();
    expect(postCount, 1);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Join the Dispatch network'),
    );
    await tester.pump();
    expect(signupCount, 1);

    await tester.ensureVisible(find.text('View open jobs'));
    await tester.tap(find.text('View open jobs'));
    await tester.pump();
    expect(browseCount, 1);
  });
}
