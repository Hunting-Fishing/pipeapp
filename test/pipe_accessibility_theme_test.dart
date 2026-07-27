import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  test('release theme exposes high-contrast keyboard focus indicators', () {
    final light = PipeAccessibilityTheme.apply(ThemeData.light());
    final dark = PipeAccessibilityTheme.apply(ThemeData.dark());
    const focused = {WidgetState.focused};

    expect(light.focusColor.a, greaterThan(0));
    expect(
      light.filledButtonTheme.style?.side?.resolve(focused),
      const BorderSide(
        color: PipeAccessibilityTheme.lightFocusIndicator,
        width: 3,
      ),
    );
    expect(
      dark.iconButtonTheme.style?.side?.resolve(focused),
      const BorderSide(
        color: PipeAccessibilityTheme.darkFocusIndicator,
        width: 3,
      ),
    );
    expect(
      light.outlinedButtonTheme.style?.side?.resolve(const {}),
      isNot(BorderSide.none),
    );
    expect(
      _contrastRatio(
        PipeAccessibilityTheme.lightFocusIndicator,
        light.colorScheme.surface,
      ),
      greaterThanOrEqualTo(3),
    );
    expect(
      _contrastRatio(
        PipeAccessibilityTheme.darkFocusIndicator,
        dark.colorScheme.surface,
      ),
      greaterThanOrEqualTo(3),
    );
  });

  test('outlined form themes receive a visible focused border', () {
    final theme = PipeAccessibilityTheme.apply(
      ThemeData.light().copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
    final border = theme.inputDecorationTheme.focusedBorder;

    expect(border, isA<OutlineInputBorder>());
    expect(
      (border! as OutlineInputBorder).borderSide,
      const BorderSide(
        color: PipeAccessibilityTheme.lightFocusIndicator,
        width: 3,
      ),
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

  testWidgets('keyboard traversal follows visual reading order',
      (tester) async {
    final first = FocusNode(debugLabel: 'first');
    final second = FocusNode(debugLabel: 'second');
    final third = FocusNode(debugLabel: 'third');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(third.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: PipeAccessibilityTheme.apply(ThemeData.light()),
      home: PipeAccessibilityRoot(
        child: Scaffold(
          body: Column(children: [
            TextField(focusNode: first),
            FilledButton(
              focusNode: second,
              onPressed: () {},
              child: const Text('Continue'),
            ),
            TextButton(
              focusNode: third,
              onPressed: () {},
              child: const Text('Help'),
            ),
          ]),
        ),
      ),
    ));

    first.requestFocus();
    await tester.pump();
    expect(first.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(second.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(third.hasFocus, isTrue);
  });
}

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
