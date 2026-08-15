import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/design/pipe_buyer_analytics_components.dart';
import 'package:pipe_app/core/design/pipe_buyer_theme.dart';

Widget _host({required double width, required Widget child}) => MaterialApp(
      theme: PipeBuyerTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

void main() {
  testWidgets('analytics metric grid renders all KPI labels on mobile',
      (tester) async {
    await tester.pumpWidget(
      _host(
        width: 390,
        child: const PipeBuyerAnalyticsMetricGrid(
          items: [
            PipeBuyerAnalyticsMetricData(
              label: 'Comparable median',
              value: r'$73',
              icon: Icons.price_check_outlined,
            ),
            PipeBuyerAnalyticsMetricData(
              label: 'Listing vs median',
              value: '+8%',
              icon: Icons.balance_rounded,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Comparable median'), findsOneWidget);
    expect(find.text('Listing vs median'), findsOneWidget);
    expect(find.text(r'$73'), findsOneWidget);
  });

  testWidgets('analytics funnel exposes values and conversion rate labels',
      (tester) async {
    await tester.pumpWidget(
      _host(
        width: 760,
        child: const PipeBuyerAnalyticsFunnel(
          steps: [
            PipeBuyerAnalyticsFunnelStepData(
              label: 'Views',
              value: 200,
              rateLabel: 'baseline',
            ),
            PipeBuyerAnalyticsFunnelStepData(
              label: 'Offers',
              value: 5,
              rateLabel: '2.5% of views',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Buyer engagement funnel'), findsOneWidget);
    expect(find.text('Views'), findsOneWidget);
    expect(find.text('Offers'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
    expect(find.text('2.5% of views'), findsOneWidget);
  });

  testWidgets('strong signal band remains presentation-only and readable',
      (tester) async {
    await tester.pumpWidget(
      _host(
        width: 390,
        child: const PipeBuyerAnalyticsSignalBand(
          label: 'Strong buyer signal',
          message: 'Buyer actions are accumulating on this listing.',
          strong: true,
        ),
      ),
    );

    expect(find.text('Strong buyer signal'), findsOneWidget);
    expect(
      find.text('Buyer actions are accumulating on this listing.'),
      findsOneWidget,
    );
  });
}
