import 'package:flutter/material.dart';

abstract final class TycoonPalette {
  static const ink = Color(0xFF152D38);
  static const muted = Color(0xFF718087);
  static const canvas = Color(0xFFF4F1E9);
  static const surface = Color(0xFFFFFDFA);
  static const line = Color(0xFFE3E3D8);
  static const orange = Color(0xFFE87536);
  static const teal = Color(0xFF16796F);
  static const paleTeal = Color(0xFFE4F0EA);
  static const paleOrange = Color(0xFFFFEADA);
  static const gold = Color(0xFFDAAA50);
  static const red = Color(0xFFB64036);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          primary: teal,
          secondary: orange,
          surface: surface,
          error: red,
        ),
        fontFamily: 'TycoonSans',
        textTheme: const TextTheme(
          displaySmall: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: ink),
          headlineMedium: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
              color: ink),
          headlineSmall: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
              color: ink),
          titleLarge: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
              color: ink),
          titleMedium:
              TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
          titleSmall:
              TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink),
          bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: ink),
          bodyMedium: TextStyle(fontSize: 13, height: 1.45, color: ink),
          bodySmall: TextStyle(fontSize: 12, height: 1.35, color: muted),
          labelLarge: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .1),
          labelMedium: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .5),
          labelSmall: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .8),
        ),
        appBarTheme: const AppBarTheme(
            backgroundColor: canvas,
            foregroundColor: ink,
            elevation: 0,
            centerTitle: false),
        dividerTheme:
            const DividerThemeData(color: line, space: 24, thickness: 1),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
          minimumSize: const Size(48, 46),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(
              fontFamily: 'TycoonSans',
              fontSize: 13,
              fontWeight: FontWeight.w700),
        )),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 44),
          side: const BorderSide(color: line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
              fontFamily: 'TycoonSans',
              fontSize: 13,
              fontWeight: FontWeight.w700),
        )),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        )),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: line)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          elevation: 0,
          indicatorColor: paleTeal,
          height: 76,
          labelTextStyle: WidgetStateProperty.all(const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: ink)),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: ink,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          contentTextStyle:
              const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: teal, linearTrackColor: line),
        tooltipTheme: const TooltipThemeData(preferBelow: true),
      );
}

String tycoonMoney(num value, {bool compact = false}) {
  final sign = value < 0 ? '−' : '';
  final absolute = value.abs();
  if (compact && absolute >= 1000000) {
    return '$sign\$${(absolute / 1000000).toStringAsFixed(absolute >= 10000000 ? 1 : 2)}m';
  }
  if (compact && absolute >= 10000) {
    return '$sign\$${(absolute / 1000).toStringAsFixed(absolute >= 100000 ? 0 : 1)}k';
  }
  final whole = absolute
      .round()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$sign\$$whole';
}

String tycoonNumber(num value) => value
    .round()
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class TycoonPanel extends StatelessWidget {
  const TycoonPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18),
      this.color,
      this.borderColor});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  @override
  Widget build(BuildContext context) => Material(
        color: color ?? TycoonPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor ?? TycoonPalette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      );
}

class TycoonTag extends StatelessWidget {
  const TycoonTag(this.text,
      {super.key, this.color = TycoonPalette.teal, this.icon});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4)
          ],
          Flexible(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: .3))),
        ]),
      );
}

class TycoonSectionTitle extends StatelessWidget {
  const TycoonSectionTitle(this.title,
      {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(subtitle!,
                          style: Theme.of(context).textTheme.bodySmall)),
              ])),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
      );
}
