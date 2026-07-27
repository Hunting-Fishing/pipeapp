import 'package:flutter/material.dart';

import 'pipe_status_feedback.dart';

/// Release-wide interaction defaults for touch, keyboard, and assistive tech.
abstract final class PipeAccessibilityTheme {
  static const double minimumTouchTarget = 48;
  static const Color lightFocusIndicator = Color(0xFF111827);
  static const Color darkFocusIndicator = Color(0xFFFFFFFF);

  static WidgetStateProperty<BorderSide?> _focusSide(
    Color color, {
    BorderSide normal = BorderSide.none,
  }) =>
      WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.focused)
              ? BorderSide(color: color, width: 3)
              : normal);

  static WidgetStateProperty<Color?> _focusOverlay(Color color) =>
      WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.focused)
              ? color.withValues(alpha: 0.14)
              : null);

  static ThemeData apply(ThemeData base) {
    const squareMinimum = WidgetStatePropertyAll(
      Size.square(minimumTouchTarget),
    );
    const buttonMinimum = WidgetStatePropertyAll(
      Size(64, minimumTouchTarget),
    );
    const padded = MaterialTapTargetSize.padded;
    final focusIndicator = base.brightness == Brightness.dark
        ? darkFocusIndicator
        : lightFocusIndicator;
    final outlineBorder = base.inputDecorationTheme.border;
    final focusedInputBorder = outlineBorder is OutlineInputBorder
        ? outlineBorder.copyWith(
            borderSide: BorderSide(color: focusIndicator, width: 3),
          )
        : base.inputDecorationTheme.focusedBorder;
    final semanticColors = base.brightness == Brightness.dark
        ? const PipeStatusColors.dark()
        : const PipeStatusColors.light();
    return base.copyWith(
      extensions: [
        ...base.extensions.values.where((item) => item is! PipeStatusColors),
        semanticColors,
      ],
      focusColor: focusIndicator.withValues(alpha: 0.14),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: squareMinimum,
          tapTargetSize: padded,
          side: _focusSide(focusIndicator),
          overlayColor: _focusOverlay(focusIndicator),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMinimum,
          tapTargetSize: padded,
          side: _focusSide(focusIndicator),
          overlayColor: _focusOverlay(focusIndicator),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMinimum,
          tapTargetSize: padded,
          side: _focusSide(
            focusIndicator,
            normal: BorderSide(color: base.colorScheme.outline),
          ),
          overlayColor: _focusOverlay(focusIndicator),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMinimum,
          tapTargetSize: padded,
          side: _focusSide(focusIndicator),
          overlayColor: _focusOverlay(focusIndicator),
        ),
      ),
      checkboxTheme: const CheckboxThemeData(materialTapTargetSize: padded),
      radioTheme: const RadioThemeData(materialTapTargetSize: padded),
      switchTheme: const SwitchThemeData(materialTapTargetSize: padded),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        focusedBorder: focusedInputBorder,
      ),
      tooltipTheme: base.tooltipTheme.copyWith(
        waitDuration: const Duration(milliseconds: 400),
        showDuration: const Duration(seconds: 4),
        preferBelow: true,
      ),
    );
  }
}

/// Establishes predictable reading-order keyboard traversal around the app's
/// Navigator while allowing dialogs and routes to keep their own focus scopes.
class PipeAccessibilityRoot extends StatelessWidget {
  const PipeAccessibilityRoot({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: child,
      );
}

/// An icon-only action with an explicit, testable screen-reader label.
class PipeAccessibleIconButton extends StatelessWidget {
  const PipeAccessibleIconButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.onTapHint,
    super.key,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final String? onTapHint;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onPressed != null,
        label: label,
        onTapHint: onTapHint,
        child: ExcludeSemantics(
          child: IconButton(
            tooltip: label,
            onPressed: onPressed,
            icon: icon,
          ),
        ),
      );
}
