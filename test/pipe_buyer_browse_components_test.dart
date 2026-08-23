import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/design/pipe_buyer_browse_components.dart';
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

  group('PipeBuyer browse components', () {
    testWidgets('browse toolbar stacks controls on mobile', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(PipeBuyerBrowseToolbar(
        resultLabel: '128 Results for oilfield pipe',
        mode: PipeBuyerBrowseMode.grid,
        onModeChanged: (_) {},
        activeFilters: const [
          PipeBuyerFilterChip(label: 'Used'),
          PipeBuyerFilterChip(label: 'Alberta, Canada'),
        ],
      )));

      final heading = tester.getRect(find.text('128 Results for oilfield pipe'));
      final grid = tester.getRect(find.text('Grid'));
      expect(grid.top, greaterThan(heading.bottom));
      expect(find.text('Used'), findsOneWidget);
      expect(find.text('Alberta, Canada'), findsOneWidget);
    });

    testWidgets('browse mode toggle reports map selection', (tester) async {
      var selected = PipeBuyerBrowseMode.grid;
      await tester.pumpWidget(app(PipeBuyerBrowseToolbar(
        resultLabel: 'Listings',
        mode: selected,
        onModeChanged: (value) => selected = value,
      )));

      await tester.tap(find.text('Map'));
      await tester.pump();
      expect(selected, PipeBuyerBrowseMode.map);
    });

    testWidgets('filter chip exposes removable action', (tester) async {
      var removed = false;
      await tester.pumpWidget(app(Center(
        child: PipeBuyerFilterChip(
          label: '250 km',
          icon: Icons.route_outlined,
          onRemoved: () => removed = true,
        ),
      )));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(removed, isTrue);
    });

    testWidgets('map panel shows public-map controls', (tester) async {
      var searchAsMoves = false;
      await tester.pumpWidget(app(SizedBox(
        height: 620,
        child: PipeBuyerMapPanel(
          title: 'Listings Map',
          subtitle: 'Public approximate locations only',
          searchAsMapMoves: searchAsMoves,
          onSearchAsMapMovesChanged: (value) => searchAsMoves = value,
          onRefresh: () {},
          onExpand: () {},
          child: const ColoredBox(
            color: Color(0xFFEFF3F7),
            child: Center(child: Text('Map surface')),
          ),
        ),
      )));

      expect(find.text('Listings Map'), findsOneWidget);
      expect(find.text('Map surface'), findsOneWidget);
      expect(find.text('Search as I move the map'), findsOneWidget);
      expect(find.byTooltip('Refresh map listings'), findsOneWidget);
      expect(find.byTooltip('Expand map'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(searchAsMoves, isTrue);
    });
  });
}
