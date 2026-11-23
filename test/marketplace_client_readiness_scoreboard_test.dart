import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_client_readiness_scoreboard.dart';

void main() {
  test('client scoreboard exposes dated headline estimates', () {
    expect(MarketplaceClientReadinessScoreboard.auditDate, 'August 21, 2026');
    expect(MarketplaceClientReadinessScoreboard.overallCompletion, 81);
    expect(MarketplaceClientReadinessScoreboard.foundationCompletion, 95);
    expect(MarketplaceClientReadinessScoreboard.softLaunchReadiness, 80);
  });

  testWidgets('client scoreboard renders progress and parallel-work warning',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarketplaceClientReadinessScoreboard(),
        ),
      ),
    );

    expect(find.text('Pipe Buyer Launch Readiness'), findsOneWidget);
    expect(find.text('81%'), findsWidgets);
    expect(find.textContaining('Parallel work rule:'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Stripe / Payments / Tax'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Stripe / Payments / Tax'), findsOneWidget);
    expect(find.text('ACTIVE SEPARATE BRANCH'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Messaging / Deal Room'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Messaging / Deal Room'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
