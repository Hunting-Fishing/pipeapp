import 'package:flutter/material.dart';

import 'pipe_status_feedback.dart';

/// Release-wide interaction defaults for touch, keyboard, and assistive tech.
abstract final class PipeAccessibilityTheme {
  static const double minimumTouchTarget = 48;
  static const Color lightFocusIndicator = Color(0xFF111827);
  static const Color darkFocusIndicator = Color(0xFFFFFFFF);

  static WidgetStateProperty<BorderSide?> _focusSide(
    Color color, {
    WidgetStateProperty<BorderSide?>? base,
    BorderSide normal = BorderSide.none,
  }) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: color, width: 3);
        }
        return base?.resolve(states) ?? normal;
      });

  static WidgetStateProperty<Color?> _focusOverlay(
    Color color, {
    WidgetStateProperty<Color?>? base,
  }) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return color.withValues(alpha: 0.14);
        }
        return base?.resolve(states);
      });

  static WidgetStateProperty<Size?> _minimumSize(
    WidgetStateProperty<Size?>? base,
    Size minimum,
  ) =>
      WidgetStateProperty.resolveWith((states) {
        final current = base?.resolve(states);
        if (current == null) return minimum;
        return Size(
          current.width < minimum.width ? minimum.width : current.width,
          current.height < minimum.height ? minimum.height : current.height,
        );
      });

  static ButtonStyle _accessibleButtonStyle(
    ButtonStyle? baseStyle, {
    required Color focusIndicator,
    required Size minimumSize,
    BorderSide fallbackSide = BorderSide.none,
  }) {
    final style = baseStyle ?? const ButtonStyle();
    return style.copyWith(
      minimumSize: _minimumSize(style.minimumSize, minimumSize),
      tapTargetSize: const WidgetStatePropertyAll(MaterialTapTargetSize.padded),
      side: _focusSide(
        focusIndicator,
        base: style.side,
        normal: fallbackSide,
      ),
      overlayColor: _focusOverlay(
        focusIndicator,
        base: style.overlayColor,
      ),
    );
  }

  static ThemeData apply(ThemeData base) {
    const squareMinimum = Size.square(minimumTouchTarget);
    const buttonMinimum = Size(64, minimumTouchTarget);
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
      materialTapTargetSize: padded,
      visualDensity: VisualDensity.standard,
      iconButtonTheme: IconButtonThemeData(
        style: _accessibleButtonStyle(
          base.iconButtonTheme.style,
          focusIndicator: focusIndicator,
          minimumSize: squareMinimum,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _accessibleButtonStyle(
          base.filledButtonTheme.style,
          focusIndicator: focusIndicator,
          minimumSize: buttonMinimum,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _accessibleButtonStyle(
          base.elevatedButtonTheme.style,
          focusIndicator: focusIndicator,
          minimumSize: buttonMinimum,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _accessibleButtonStyle(
          base.outlinedButtonTheme.style,
          focusIndicator: focusIndicator,
          minimumSize: buttonMinimum,
          fallbackSide: BorderSide(color: base.colorScheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _accessibleButtonStyle(
          base.textButtonTheme.style,
          focusIndicator: focusIndicator,
          minimumSize: buttonMinimum,
        ),
      ),
      checkboxTheme:
          base.checkboxTheme.copyWith(materialTapTargetSize: padded),
      radioTheme: base.radioTheme.copyWith(materialTapTargetSize: padded),
      switchTheme: base.switchTheme.copyWith(materialTapTargetSize: padded),
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
