import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/design/pipe_buyer_commerce_components.dart';
import 'package:pipe_app/core/design/pipe_buyer_theme.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
        theme: PipeBuyerTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      );

  group('PipeBuyer commerce components', () {
    testWidgets('hero keeps the commercial actions visible', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(
        PipeBuyerHeroPanel(
          eyebrow: 'Industrial marketplace',
          title: 'Find the right equipment. Anywhere.',
          subtitle: 'Buy, sell and connect with verified industry professionals.',
          primaryActionLabel: 'Browse Marketplace',
          onPrimaryAction: () {},
          secondaryActionLabel: 'List Your Equipment',
          onSecondaryAction: () {},
        ),
      ));

      expect(find.text('INDUSTRIAL MARKETPLACE'), findsOneWidget);
      expect(find.text('Browse Marketplace'), findsOneWidget);
      expect(find.text('List Your Equipment'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets('hero renders safely inside the scrolling mobile home',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: PipeBuyerTheme.light(),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              PipeBuyerHeroPanel(
                eyebrow: 'Industrial marketplace',
                title: 'Find. Connect. Move.',
                subtitle: 'Industry inventory and logistics in one marketplace.',
                trailing: SizedBox(
                  height: 120,
                  child: Placeholder(),
                ),
              ),
            ],
          ),
        ),
      ));

      expect(find.text('Find. Connect. Move.'), findsOneWidget);
      expect(find.byType(Placeholder), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('search toolbar stacks on mobile', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(
        PipeBuyerCommerceSearchBar(
          fields: const [
            TextField(decoration: InputDecoration(labelText: 'Category')),
            TextField(decoration: InputDecoration(labelText: 'Location')),
          ],
          onSearch: () {},
        ),
      ));

      final first = tester.getRect(find.byType(TextField).at(0));
      final second = tester.getRect(find.byType(TextField).at(1));
      final button = tester.getRect(find.widgetWithText(FilledButton, 'Search'));

      expect(second.top, greaterThan(first.bottom));
      expect(button.top, greaterThan(second.bottom));
    });

    testWidgets('search toolbar becomes one row on desktop', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(
        PipeBuyerCommerceSearchBar(
          fields: const [
            TextField(decoration: InputDecoration(labelText: 'Category')),
            TextField(decoration: InputDecoration(labelText: 'Location')),
            TextField(decoration: InputDecoration(labelText: 'Distance')),
          ],
          onSearch: () {},
        ),
      ));

      final tops = <double>{
        tester.getRect(find.byType(TextField).at(0)).top,
        tester.getRect(find.byType(TextField).at(1)).top,
        tester.getRect(find.byType(TextField).at(2)).top,
      };
      expect(tops.length, 1);
      expect(find.widgetWithText(FilledButton, 'Search'), findsOneWidget);
    });

    testWidgets('trust band uses four columns on a wide screen', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(const PipeBuyerTrustBand(items: [
        PipeBuyerTrustItemData(
          icon: Icons.verified_outlined,
          title: 'Verified Sellers',
          subtitle: 'Quality you can trust',
        ),
        PipeBuyerTrustItemData(
          icon: Icons.lock_outline,
          title: 'Secure Payments',
          subtitle: 'Provider-backed options',
        ),
        PipeBuyerTrustItemData(
          icon: Icons.public,
          title: 'Global Network',
          subtitle: 'Buy and sell worldwide',
        ),
        PipeBuyerTrustItemData(
          icon: Icons.shield_outlined,
          title: 'Fraud Protection',
          subtitle: 'Report suspicious activity',
        ),
      ])));

      final tops = <double>{
        tester.getRect(find.text('Verified Sellers')).top,
        tester.getRect(find.text('Secure Payments')).top,
        tester.getRect(find.text('Global Network')).top,
        tester.getRect(find.text('Fraud Protection')).top,
      };
      expect(tops.length, 1);
    });

    testWidgets('category tile exposes selected visual state', (tester) async {
      await tester.pumpWidget(app(
        PipeBuyerCategoryTile(
          title: 'Pipe & Tubing',
          subtitle: 'Browse inventory',
          visual: const Icon(Icons.horizontal_rule),
          selected: true,
          onTap: () {},
        ),
      ));

      expect(find.text('Pipe & Tubing'), findsOneWidget);
      expect(find.text('Browse inventory'), findsOneWidget);
      expect(find.byType(InkWell), findsOneWidget);
    });
  });
}
