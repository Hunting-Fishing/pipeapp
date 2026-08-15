import 'package:flutter/material.dart';

import '../design/pipe_buyer_theme.dart';
import 'pipe_status_feedback.dart';

/// Release-wide interaction defaults for touch, keyboard, and assistive tech.
abstract final class PipeAccessibilityTheme {
  static const double minimumTouchTarget = 48;
  static const Color lightFocusIndicator = Color(0xFF111827);
  static const Color darkFocusIndicator = Color(0xFFFFFFFF);

  // Historic marketplace surfaces used these as their primary brand blue.
  // Normalizing only these exact values lets the premium design system migrate
  // older screens to PipeBuyer orange without removing blue from informational
  // or semantic UI where it is still useful.
  static const Set<int> _legacyBrandPrimaryValues = {
    0xFF0F52BA,
    0xFF0878E8,
  };

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
      tapTargetSize: MaterialTapTargetSize.padded,
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

  static ThemeData _normalizeLegacyBrandTheme(ThemeData base) {
    if (!_legacyBrandPrimaryValues.contains(base.colorScheme.primary.toARGB32())) {
      return base;
    }
    final scheme = base.colorScheme.copyWith(
      primary: PipeBuyerColors.orange,
      onPrimary: Colors.white,
      primaryContainer: PipeBuyerColors.orangeSoft,
      onPrimaryContainer: PipeBuyerColors.orangePressed,
      secondary: PipeBuyerColors.industrialBlue,
    );
    return base.copyWith(
      colorScheme: scheme,
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: PipeBuyerColors.orange,
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: PipeBuyerColors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData apply(ThemeData base) {
    final brandedBase = _normalizeLegacyBrandTheme(base);
    const squareMinimum = Size.square(minimumTouchTarget);
    const buttonMinimum = Size(64, minimumTouchTarget);
    const padded = MaterialTapTargetSize.padded;
    final focusIndicator = brandedBase.brightness == Brightness.dark
        ? darkFocusIndicator
        : lightFocusIndicator;
    final outlineBorder = brandedBase.inputDecorationTheme.border;
    final focusedInputBorder = outlineBorder is OutlineInputBorder
        ? outlineBorder.copyWith(
            borderSide: BorderSide(color: focusIndicator, width: 3),
          )
        : brandedBase.inputDecorationTheme.focusedBorder;
    final semanticColors = brandedBase.brightness == Brightness.dark
        ? const PipeStatusColors.dark()
        : const PipeStatusColors.light();

    return brandedBase.copyWith(
      extensions: [
        ...brandedBase.extensions.values
            .where((item) => item is! PipeStatusColors),
        semanticColors,
      ],
      focusColor: focusIndicator.withValues(alpha: 0.14),
      materialTapTargetSize: padded,
      visualDensity: VisualDensity.standard,
      iconButtonTheme: IconButtonThemeData(
        style: _accessibleButtonStyle(
          brandedBase.iconButtonTheme.style,
          focusIndicator: focusIndicator,
          minimumSize: squareMinimum,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _accessibleButtonStyle(
          brandedBase.filledButtonTheme.style,
          focusIndicator: focusIndicator,
          minimumSize: buttonMinimum,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _accessibleButtonStyle(
          brandedBase.elevatedButtonTheme.style,
          focusIndicator: focusIndicator,
          minimumSize: buttonMinimum,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _accessibleButtonStyle(
          brandedBase.outlinedButtonTheme.style,
          focusIndicator: focusIndicator,
          minimumSize: buttonMinimum,
          fallbackSide: BorderSide(color: brandedBase.colorScheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _accessibleButtonStyle(
          brandedBase.textButtonTheme.style,
          focusIndicator: focusIndicator,
          minimumSize: buttonMinimum,
        ),
      ),
      checkboxTheme:
          brandedBase.checkboxTheme.copyWith(materialTapTargetSize: padded),
      radioTheme:
          brandedBase.radioTheme.copyWith(materialTapTargetSize: padded),
      switchTheme:
          brandedBase.switchTheme.copyWith(materialTapTargetSize: padded),
      inputDecorationTheme: brandedBase.inputDecorationTheme.copyWith(
        focusedBorder: focusedInputBorder,
      ),
      tooltipTheme: brandedBase.tooltipTheme.copyWith(
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
