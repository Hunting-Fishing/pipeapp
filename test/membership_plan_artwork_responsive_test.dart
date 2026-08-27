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
      'membership plan artwork is readable at ${viewport.width.toInt()}px',
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

        for (final title in const [
          'VIP Membership',
          'Dispatch Monthly',
          'Dispatch Yearly',
        ]) {
          final artwork =
              find.byKey(ValueKey<String>('membership-artwork-$title'));
          expect(artwork, findsOneWidget);

          final size = tester.getSize(artwork);
          expect(size.height, greaterThanOrEqualTo(220));
          expect(size.height, lessThanOrEqualTo(280));
        }

        expect(tester.takeException(), isNull);
      },
    );
  }
}
