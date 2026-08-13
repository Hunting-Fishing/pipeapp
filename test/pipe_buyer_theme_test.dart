import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/core/accessibility/pipe_accessibility_theme.dart';
import 'package:pipe_app/core/design/pipe_buyer_theme.dart';

void main() {
  group('PipeBuyer premium theme', () {
    test('light theme uses the industrial brand palette', () {
      final theme = PipeAccessibilityTheme.apply(PipeBuyerTheme.light());

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, PipeBuyerColors.orange);
      expect(theme.colorScheme.secondary, PipeBuyerColors.industrialBlue);
      expect(theme.scaffoldBackgroundColor, PipeBuyerColors.canvas);
      expect(theme.appBarTheme.backgroundColor, PipeBuyerColors.ink);
      expect(theme.cardColor, PipeBuyerColors.surface);
    });

    test('dark theme keeps PipeBuyer orange as the action color', () {
      final theme = PipeAccessibilityTheme.apply(PipeBuyerTheme.dark());

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, PipeBuyerColors.orange);
      expect(theme.scaffoldBackgroundColor, PipeBuyerColors.darkCanvas);
      expect(theme.cardColor, PipeBuyerColors.darkSurface);
    });

    test('premium button styling survives accessibility enforcement', () {
      final theme = PipeAccessibilityTheme.apply(PipeBuyerTheme.light());
      final style = theme.filledButtonTheme.style!;
      final normalStates = <WidgetState>{};
      final focusedStates = <WidgetState>{WidgetState.focused};

      expect(
        style.backgroundColor?.resolve(normalStates),
        PipeBuyerColors.orange,
      );
      final minimum = style.minimumSize?.resolve(normalStates);
      expect(minimum, isNotNull);
      expect(minimum!.height, greaterThanOrEqualTo(48));
      expect(minimum.width, greaterThanOrEqualTo(64));

      final focusedSide = style.side?.resolve(focusedStates);
      expect(focusedSide, isNotNull);
      expect(focusedSide!.width, 3);
    });
  });
}
