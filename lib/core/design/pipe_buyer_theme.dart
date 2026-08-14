import 'package:flutter/material.dart';

/// Core Pipe Buyer brand colors shared across web, tablet, and mobile.
abstract final class PipeBuyerColors {
  static const orange = Color(0xFFFF6A00);
  static const orangePressed = Color(0xFFE85F00);
  static const orangeSoft = Color(0xFFFFF1E8);

  static const ink = Color(0xFF0D1117);
  static const charcoal = Color(0xFF151A20);
  static const graphite = Color(0xFF1E2938);
  static const slate = Color(0xFF475569);
  static const muted = Color(0xFF64748B);

  static const canvas = Color(0xFFF6F7F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F4F7);
  static const field = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);

  static const darkCanvas = Color(0xFF080B0F);
  static const darkSurface = Color(0xFF10151B);
  static const darkSurfaceMuted = Color(0xFF171D25);
  static const darkField = Color(0xFF151B22);
  static const darkLine = Color(0xFF29323D);
  static const darkText = Color(0xFFF7F9FC);
  static const darkMuted = Color(0xFF9AA7B6);

  static const industrialBlue = Color(0xFF0F52BA);
  static const success = Color(0xFF148A45);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFD92D20);
}

/// Premium marketplace theme applied before the accessibility layer.
///
/// The visual theme is deliberately independent of marketplace state and
/// Firebase so UI changes cannot alter transaction behavior.
abstract final class PipeBuyerTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final canvas = dark ? PipeBuyerColors.darkCanvas : PipeBuyerColors.canvas;
    final surface = dark ? PipeBuyerColors.darkSurface : PipeBuyerColors.surface;
    final surfaceMuted = dark
        ? PipeBuyerColors.darkSurfaceMuted
        : PipeBuyerColors.surfaceMuted;
    final field = dark ? PipeBuyerColors.darkField : PipeBuyerColors.field;
    final line = dark ? PipeBuyerColors.darkLine : PipeBuyerColors.line;
    final text = dark ? PipeBuyerColors.darkText : PipeBuyerColors.ink;
    final muted = dark ? PipeBuyerColors.darkMuted : PipeBuyerColors.muted;

    final scheme = ColorScheme.fromSeed(
      seedColor: PipeBuyerColors.orange,
      brightness: brightness,
    ).copyWith(
      primary: PipeBuyerColors.orange,
      onPrimary: Colors.white,
      secondary: PipeBuyerColors.industrialBlue,
      onSecondary: Colors.white,
      error: PipeBuyerColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      outline: line,
    );

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: false,
      colorScheme: scheme,
      primaryColor: PipeBuyerColors.orange,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      cardColor: surface,
      dividerColor: line,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = base.textTheme
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
          ),
          displayMedium: base.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.42),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        )
        .apply(bodyColor: text, displayColor: text);

    final cardRadius = BorderRadius.circular(14);
    final controlRadius = BorderRadius.circular(12);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: text, size: 22),
      appBarTheme: AppBarThemeData(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
            dark ? PipeBuyerColors.darkCanvas : PipeBuyerColors.ink,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: line),
        ),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: muted),
        helperStyle: TextStyle(color: muted, height: 1.3),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide:
              const BorderSide(color: PipeBuyerColors.orange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: PipeBuyerColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: const BorderSide(color: PipeBuyerColors.danger, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PipeBuyerColors.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PipeBuyerColors.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(64, 50),
          side: BorderSide(color: line, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PipeBuyerColors.orange,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        selectedColor: PipeBuyerColors.orangeSoft,
        disabledColor: surfaceMuted,
        labelStyle: TextStyle(color: text, fontWeight: FontWeight.w700),
        secondaryLabelStyle:
            const TextStyle(color: PipeBuyerColors.orangePressed),
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return PipeBuyerColors.orange;
            }
            return surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return text;
          }),
          side: WidgetStateProperty.resolveWith((states) => BorderSide(
                color: states.contains(WidgetState.selected)
                    ? PipeBuyerColors.orange
                    : line,
                width: states.contains(WidgetState.selected) ? 1.4 : 1,
              )),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          iconColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? Colors.white : muted),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: PipeBuyerColors.orange,
        unselectedLabelColor: muted,
        indicatorColor: PipeBuyerColors.orange,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: surface,
        indicatorColor: PipeBuyerColors.orangeSoft,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? PipeBuyerColors.orange
                  : muted,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? PipeBuyerColors.orangePressed
                  : muted,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w700,
              fontSize: 12,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: surface,
        indicatorColor: PipeBuyerColors.orangeSoft,
        selectedIconTheme:
            const IconThemeData(color: PipeBuyerColors.orange, size: 24),
        unselectedIconTheme: IconThemeData(color: muted, size: 23),
        selectedLabelTextStyle: const TextStyle(
          color: PipeBuyerColors.orangePressed,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle:
            TextStyle(color: muted, fontWeight: FontWeight.w700),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: text,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: muted.withValues(alpha: .38),
        dragHandleSize: const Size(40, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shadowColor: Colors.black.withValues(alpha: .16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -.25,
        ),
        contentTextStyle: TextStyle(color: text, height: 1.42),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: .14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(color: text, fontWeight: FontWeight.w700),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: PipeBuyerColors.orange,
        textColor: Colors.white,
        textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
        padding: EdgeInsets.symmetric(horizontal: 6),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: muted.withValues(alpha: .65), width: 1.4),
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? PipeBuyerColors.orange
                : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(Colors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : muted.withValues(alpha: .85)),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? PipeBuyerColors.orange
                : line),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? PipeBuyerColors.orangePressed
                : muted.withValues(alpha: .32)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: PipeBuyerColors.orange,
        linearTrackColor: line,
        circularTrackColor: line,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? PipeBuyerColors.darkText : PipeBuyerColors.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: dark ? PipeBuyerColors.ink : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        waitDuration: const Duration(milliseconds: 450),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? PipeBuyerColors.darkSurface : PipeBuyerColors.ink,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        actionTextColor: PipeBuyerColors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
