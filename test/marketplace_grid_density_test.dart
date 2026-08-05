import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_grid_density.dart';

void main() {
  group('MarketplaceGridDensityBar', () {
    test('resolves compact, medium, expanded, and wide automatic layouts', () {
      expect(MarketplaceGridDensityBar.resolveColumns(1400, 0), 4);
      expect(MarketplaceGridDensityBar.resolveColumns(1200, 0), 4);
      expect(MarketplaceGridDensityBar.resolveColumns(1199, 0), 3);
      expect(MarketplaceGridDensityBar.resolveColumns(900, 0), 3);
      expect(MarketplaceGridDensityBar.resolveColumns(899, 0), 2);
      expect(MarketplaceGridDensityBar.resolveColumns(600, 0), 2);
      expect(MarketplaceGridDensityBar.resolveColumns(599, 0), 1);
      expect(MarketplaceGridDensityBar.resolveColumns(390, 0), 1);
    });

    test('clamps explicit preferences to readable card widths', () {
      expect(MarketplaceGridDensityBar.resolveColumns(1400, 1), 1);
      expect(MarketplaceGridDensityBar.resolveColumns(1400, 2), 2);
      expect(MarketplaceGridDensityBar.resolveColumns(1400, 3), 3);
      expect(MarketplaceGridDensityBar.resolveColumns(1400, 4), 4);
      expect(MarketplaceGridDensityBar.resolveColumns(1000, 4), 3);
      expect(MarketplaceGridDensityBar.resolveColumns(700, 4), 2);
      expect(MarketplaceGridDensityBar.resolveColumns(390, 4), 1);
    });

    test('fails safely for invalid available widths', () {
      expect(MarketplaceGridDensityBar.resolveColumns(0, 4), 1);
      expect(MarketplaceGridDensityBar.resolveColumns(-100, 4), 1);
      expect(MarketplaceGridDensityBar.resolveColumns(double.nan, 4), 1);
      expect(MarketplaceGridDensityBar.resolveColumns(double.infinity, 4), 1);
    });

    testWidgets('exposes accessible density labels and selection state',
        (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MarketplaceGridDensityBar(
                selectedColumns: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Automatic grid density'), findsOneWidget);
      expect(find.bySemanticsLabel('1 column'), findsOneWidget);
      expect(find.bySemanticsLabel('2 columns'), findsOneWidget);
      expect(find.bySemanticsLabel('3 columns'), findsOneWidget);
      expect(find.bySemanticsLabel('4 columns'), findsOneWidget);

      await tester.tap(find.byTooltip('3 columns'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('3 columns')),
        matchesSemantics(
          label: '3 columns',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
    });
  });
}
