import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_vip_access.dart';

void main() {
  final viewports = <Size>[
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 1000),
  ];

  for (final viewport in viewports) {
    testWidgets(
      'membership plans show one expanded selection at ${viewport.width.toInt()}px',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MarketplaceSubscriptionPlansDialog(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SvgPicture), findsNWidgets(3));
        expect(find.text('VIP Membership'), findsOneWidget);
        expect(find.text('Dispatch Monthly'), findsOneWidget);
        expect(find.text('Dispatch Yearly'), findsOneWidget);
        expect(find.text('SELECTED PLAN'), findsOneWidget);

        final vipArtwork = find.byKey(
          const ValueKey<String>('membership-artwork-VIP Membership-false'),
        );
        final monthlyArtwork = find.byKey(
          const ValueKey<String>('membership-artwork-Dispatch Monthly-true'),
        );
        final yearlyArtwork = find.byKey(
          const ValueKey<String>('membership-artwork-Dispatch Yearly-false'),
        );
        expect(vipArtwork, findsOneWidget);
        expect(monthlyArtwork, findsOneWidget);
        expect(yearlyArtwork, findsOneWidget);

        final vipSize = tester.getSize(vipArtwork);
        final monthlySize = tester.getSize(monthlyArtwork);
        final yearlySize = tester.getSize(yearlyArtwork);
        expect(vipSize.height, inInclusiveRange(170, 210));
        expect(yearlySize.height, inInclusiveRange(170, 210));
        expect(monthlySize.height, inInclusiveRange(220, 280));
        expect(monthlySize.height, greaterThan(vipSize.height));
        expect(monthlySize.height, greaterThan(yearlySize.height));

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('selecting VIP expands VIP and collapses Dispatch Monthly',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarketplaceSubscriptionPlansDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final monthlyBefore = tester.getSize(
      find.byKey(
        const ValueKey<String>('membership-artwork-Dispatch Monthly-true'),
      ),
    );
    final vipBefore = tester.getSize(
      find.byKey(
        const ValueKey<String>('membership-artwork-VIP Membership-false'),
      ),
    );

    await tester.tap(find.text('VIP Membership'));
    await tester.pumpAndSettle();

    final vipSelected = find.byKey(
      const ValueKey<String>('membership-artwork-VIP Membership-true'),
    );
    final monthlyCollapsed = find.byKey(
      const ValueKey<String>('membership-artwork-Dispatch Monthly-false'),
    );
    expect(vipSelected, findsOneWidget);
    expect(monthlyCollapsed, findsOneWidget);
    expect(find.text('SELECTED PLAN'), findsOneWidget);

    final vipAfter = tester.getSize(vipSelected);
    final monthlyAfter = tester.getSize(monthlyCollapsed);
    expect(vipAfter.height, greaterThan(vipBefore.height));
    expect(monthlyAfter.height, lessThan(monthlyBefore.height));
    expect(vipAfter.height, greaterThan(monthlyAfter.height));
    expect(tester.takeException(), isNull);
  });
}