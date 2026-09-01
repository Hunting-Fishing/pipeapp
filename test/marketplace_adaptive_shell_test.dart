import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_adaptive_shell.dart';

void main() {
  const compactDestinations = <MarketplaceShellDestination>[
    MarketplaceShellDestination(
      pageIndex: 0,
      label: 'Home',
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
    ),
    MarketplaceShellDestination(
      pageIndex: 1,
      label: 'Browse',
      icon: Icon(Icons.search),
    ),
    MarketplaceShellDestination(
      pageIndex: 2,
      label: 'Sell',
      icon: Icon(Icons.add_box_outlined),
    ),
    MarketplaceShellDestination(
      pageIndex: 4,
      label: 'Messages',
      icon: Icon(Icons.forum_outlined),
    ),
    MarketplaceShellDestination(
      pageIndex: 5,
      label: 'Account',
      icon: Icon(Icons.person_outline),
    ),
  ];

  const railDestinations = <MarketplaceShellDestination>[
    ...compactDestinations,
    MarketplaceShellDestination(
      pageIndex: 6,
      label: 'Auctions',
      icon: Icon(Icons.gavel_outlined),
    ),
    MarketplaceShellDestination(
      pageIndex: 7,
      label: 'Dispatch',
      icon: Icon(Icons.local_shipping_outlined),
    ),
  ];

  Future<void> pumpShell(
    WidgetTester tester, {
    required double width,
    int selectedPageIndex = 0,
    ValueChanged<int>? onDestinationSelected,
    Widget? railFooter,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MarketplaceAdaptiveShell(
          scaffoldKey: GlobalKey<ScaffoldState>(),
          selectedPageIndex: selectedPageIndex,
          title: 'Pipe Buyer',
          body: const ColoredBox(
            key: Key('marketplace-body'),
            color: Colors.white,
          ),
          drawer: const Drawer(child: Text('Marketplace navigation')),
          compactDestinations: compactDestinations,
          railDestinations: railDestinations,
          railFooter: railFooter,
          onDestinationSelected: onDestinationSelected ?? (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('preserves drawer and bottom navigation on phone widths', (
    tester,
  ) async {
    await pumpShell(tester, width: 390);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byTooltip('Open navigation'), findsOneWidget);
  });

  testWidgets('uses a collapsed rail at expanded widths', (tester) async {
    await pumpShell(tester, width: 1000, selectedPageIndex: 5);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Open navigation'), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.selectedIndex, 4);
  });

  testWidgets('extends the rail only at wide widths', (tester) async {
    await pumpShell(tester, width: 1300);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('maps compact destinations back to marketplace page indexes', (
    tester,
  ) async {
    int? selectedPage;
    await pumpShell(
      tester,
      width: 390,
      onDestinationSelected: (value) => selectedPage = value,
    );

    await tester.tap(find.text('Messages'));
    await tester.pump();

    expect(selectedPage, 4);
  });

  testWidgets('maps rail destinations back to marketplace page indexes', (
    tester,
  ) async {
    int? selectedPage;
    await pumpShell(
      tester,
      width: 1000,
      onDestinationSelected: (value) => selectedPage = value,
    );

    await tester.tap(find.text('Dispatch'));
    await tester.pump();

    expect(selectedPage, 7);
  });

  testWidgets('shows List Now on Marketplace browse and opens the list page', (
    tester,
  ) async {
    int? selectedPage;
    await pumpShell(
      tester,
      width: 1000,
      selectedPageIndex: 1,
      onDestinationSelected: (value) => selectedPage = value,
    );

    final listNow = find.byKey(const Key('marketplace-list-now'));
    expect(listNow, findsOneWidget);
    expect(find.text('List Now'), findsOneWidget);

    await tester.tap(listNow);
    await tester.pump();

    expect(selectedPage, 2);
  });

  testWidgets('keeps List Now off non-Marketplace pages', (tester) async {
    await pumpShell(tester, width: 1000, selectedPageIndex: 0);

    expect(find.byKey(const Key('marketplace-list-now')), findsNothing);
  });

  testWidgets(
    'keeps List Now visible without overlaying compact page content',
    (tester) async {
      await pumpShell(tester, width: 390, selectedPageIndex: 1);

      expect(find.byKey(const Key('marketplace-list-now')), findsOneWidget);
      expect(find.byKey(const Key('marketplace-body')), findsOneWidget);
    },
  );

  testWidgets('pins the rail footer below desktop destinations', (
    tester,
  ) async {
    await pumpShell(
      tester,
      width: 1300,
      railFooter: const Text('Sign out', key: Key('rail-auth-footer')),
    );

    expect(find.byKey(const Key('rail-auth-footer')), findsOneWidget);
    final dispatchBottom = tester.getBottomLeft(find.text('Dispatch')).dy;
    final footerTop = tester
        .getTopLeft(find.byKey(const Key('rail-auth-footer')))
        .dy;
    expect(footerTop, greaterThan(dispatchBottom));
  });

  testWidgets('caps wide marketplace content at the shared maximum', (
    tester,
  ) async {
    await pumpShell(tester, width: 1800);

    final bodySize = tester.getSize(find.byKey(const Key('marketplace-body')));
    expect(bodySize.width, 1440);
  });
}
