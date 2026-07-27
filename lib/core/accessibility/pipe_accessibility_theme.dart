import 'package:flutter/material.dart';

/// Release-wide interaction defaults for touch, keyboard, and assistive tech.
abstract final class PipeAccessibilityTheme {
  static const double minimumTouchTarget = 48;

  static ThemeData apply(ThemeData base) {
    const squareMinimum = WidgetStatePropertyAll(
      Size.square(minimumTouchTarget),
    );
    const buttonMinimum = WidgetStatePropertyAll(
      Size(64, minimumTouchTarget),
    );
    const padded = MaterialTapTargetSize.padded;
    return base.copyWith(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: squareMinimum,
          tapTargetSize: padded,
        ),
      ),
      filledButtonTheme: const FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMinimum,
          tapTargetSize: padded,
        ),
      ),
      outlinedButtonTheme: const OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMinimum,
          tapTargetSize: padded,
        ),
      ),
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMinimum,
          tapTargetSize: padded,
        ),
      ),
      checkboxTheme: const CheckboxThemeData(materialTapTargetSize: padded),
      radioTheme: const RadioThemeData(materialTapTargetSize: padded),
      switchTheme: const SwitchThemeData(materialTapTargetSize: padded),
      tooltipTheme: base.tooltipTheme.copyWith(
        waitDuration: const Duration(milliseconds: 400),
        showDuration: const Duration(seconds: 4),
        preferBelow: true,
      ),
    );
  }
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
