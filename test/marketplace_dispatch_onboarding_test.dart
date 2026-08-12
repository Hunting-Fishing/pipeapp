import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_dispatch_onboarding.dart';

Widget _subject({
  required VoidCallback onPostLoad,
  required VoidCallback onBrowseJobs,
  required VoidCallback onJoinCarrier,
}) =>
    MaterialApp(
      home: Scaffold(
        body: MarketplaceDispatchOnboarding(
          onPostLoad: onPostLoad,
          onBrowseJobs: onBrowseJobs,
          onJoinCarrier: onJoinCarrier,
        ),
      ),
    );

void main() {
  testWidgets('Dispatch onboarding wires customer and provider actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var postCount = 0;
    var browseCount = 0;
    var signupCount = 0;

    await tester.pumpWidget(_subject(
      onPostLoad: () => postCount += 1,
      onBrowseJobs: () => browseCount += 1,
      onJoinCarrier: () => signupCount += 1,
    ));

    expect(find.text('Pipe Buyer Dispatch Network'), findsOneWidget);
    expect(find.text('Request trucking service'), findsOneWidget);
    expect(find.text('Offer trucking services'), findsOneWidget);

    await tester.tap(find.text('Post a load request'));
    await tester.pump();
    expect(postCount, 1);

    await tester.tap(find.text('Join the Dispatch network'));
    await tester.pump();
    expect(signupCount, 1);

    await tester.tap(find.text('Browse jobs'));
    await tester.pump();
    expect(browseCount, 1);
  });

  testWidgets('Dispatch onboarding discloses membership and signup requirements',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_subject(
      onPostLoad: () {},
      onBrowseJobs: () {},
      onJoinCarrier: () {},
    ));

    await tester.scrollUntilVisible(
      find.text(r'CAD $25 per month'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dispatch membership pricing'), findsOneWidget);
    expect(find.text(r'CAD $25 per month'), findsOneWidget);
    expect(find.text(r'CAD $300 per year'), findsOneWidget);
    expect(find.text('Monthly carrier bidding membership'), findsOneWidget);
    expect(find.text('Yearly carrier bidding membership'), findsOneWidget);
    expect(
      find.textContaining('Joining Dispatch is free'),
      findsOneWidget,
    );
    expect(
      find.textContaining('membership is required only before a carrier submits a bid'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Dispatch notifications'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dispatch notifications'), findsOneWidget);
    expect(find.textContaining('matching opportunities'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('View open jobs'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dispatch signup requirements'), findsOneWidget);
    expect(find.textContaining('at least 70%'), findsOneWidget);
    expect(find.textContaining('either their email or mobile number'), findsOneWidget);
    expect(find.text('Join Dispatch'), findsOneWidget);
    expect(find.text('View open jobs'), findsOneWidget);
  });
}
