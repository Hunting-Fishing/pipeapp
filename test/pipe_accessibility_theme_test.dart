import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/accessibility/pipe_accessibility_theme.dart';

void main() {
  test('release theme enforces 48 logical pixel interaction targets', () {
    final theme = PipeAccessibilityTheme.apply(ThemeData.light());
    expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    expect(
      theme.iconButtonTheme.style?.minimumSize?.resolve({}),
      const Size.square(PipeAccessibilityTheme.minimumTouchTarget),
    );
    expect(
      theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height,
      greaterThanOrEqualTo(PipeAccessibilityTheme.minimumTouchTarget),
    );
    expect(
      theme.outlinedButtonTheme.style?.minimumSize?.resolve({})?.height,
      greaterThanOrEqualTo(PipeAccessibilityTheme.minimumTouchTarget),
    );
  });

  testWidgets('large text retains labelled keyboard and touch controls',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: PipeAccessibilityTheme.apply(ThemeData.light()),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Row(children: [
          PipeAccessibleIconButton(
            label: 'Search Marketplace',
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
          FilledButton(
            onPressed: () {},
            child: const Text('Continue'),
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(IconButton)).width,
        greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byType(IconButton)).height,
        greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(find.byType(PipeAccessibleIconButton)).label,
      contains('Search Marketplace'),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
