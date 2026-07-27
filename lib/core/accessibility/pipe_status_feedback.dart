import 'package:flutter/material.dart';

enum PipeStatusTone { info, success, warning, error }

@immutable
class PipeStatusColors extends ThemeExtension<PipeStatusColors> {
  const PipeStatusColors({
    required this.info,
    required this.success,
    required this.warning,
    required this.error,
  });

  const PipeStatusColors.light()
      : info = const PipeStatusColorSet(
          foreground: Color(0xFF0B4F8A),
          background: Color(0xFFEAF4FD),
          border: Color(0xFF1769AA),
        ),
        success = const PipeStatusColorSet(
          foreground: Color(0xFF0B5D3B),
          background: Color(0xFFEAF7F1),
          border: Color(0xFF2E7D5A),
        ),
        warning = const PipeStatusColorSet(
          foreground: Color(0xFF6D3B00),
          background: Color(0xFFFFF4E5),
          border: Color(0xFFB85C00),
        ),
        error = const PipeStatusColorSet(
          foreground: Color(0xFF8A1538),
          background: Color(0xFFFFEBEF),
          border: Color(0xFFC6284B),
        );

  const PipeStatusColors.dark()
      : info = const PipeStatusColorSet(
          foreground: Color(0xFFA9D5FF),
          background: Color(0xFF12314A),
          border: Color(0xFF5BA9E6),
        ),
        success = const PipeStatusColorSet(
          foreground: Color(0xFF9AE6C2),
          background: Color(0xFF123629),
          border: Color(0xFF56B987),
        ),
        warning = const PipeStatusColorSet(
          foreground: Color(0xFFFFD08A),
          background: Color(0xFF402A0E),
          border: Color(0xFFF0A23A),
        ),
        error = const PipeStatusColorSet(
          foreground: Color(0xFFFFB4C2),
          background: Color(0xFF441824),
          border: Color(0xFFEF6B83),
        );

  final PipeStatusColorSet info;
  final PipeStatusColorSet success;
  final PipeStatusColorSet warning;
  final PipeStatusColorSet error;

  static PipeStatusColors of(BuildContext context) =>
      Theme.of(context).extension<PipeStatusColors>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? const PipeStatusColors.dark()
          : const PipeStatusColors.light());

  PipeStatusColorSet forTone(PipeStatusTone tone) => switch (tone) {
        PipeStatusTone.info => info,
        PipeStatusTone.success => success,
        PipeStatusTone.warning => warning,
        PipeStatusTone.error => error,
      };

  @override
  PipeStatusColors copyWith({
    PipeStatusColorSet? info,
    PipeStatusColorSet? success,
    PipeStatusColorSet? warning,
    PipeStatusColorSet? error,
  }) =>
      PipeStatusColors(
        info: info ?? this.info,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        error: error ?? this.error,
      );

  @override
  PipeStatusColors lerp(covariant PipeStatusColors? other, double t) {
    if (other == null) return this;
    return PipeStatusColors(
      info: info.lerp(other.info, t),
      success: success.lerp(other.success, t),
      warning: warning.lerp(other.warning, t),
      error: error.lerp(other.error, t),
    );
  }
}

@immutable
class PipeStatusColorSet {
  const PipeStatusColorSet({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;

  PipeStatusColorSet lerp(PipeStatusColorSet other, double t) =>
      PipeStatusColorSet(
        foreground: Color.lerp(foreground, other.foreground, t)!,
        background: Color.lerp(background, other.background, t)!,
        border: Color.lerp(border, other.border, t)!,
      );
}

class PipeStatusSurface extends StatelessWidget {
  const PipeStatusSurface({
    required this.tone,
    required this.message,
    this.title,
    this.icon,
    this.liveRegion = false,
    this.action,
    super.key,
  });

  final PipeStatusTone tone;
  final String message;
  final String? title;
  final IconData? icon;
  final bool liveRegion;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = PipeStatusColors.of(context).forTone(tone);
    final resolvedIcon = icon ?? _iconForTone(tone);
    final semanticLabel = [
      _labelForTone(tone),
      if (title != null) title!,
      message,
    ].join('. ');
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(resolvedIcon, color: colors.foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null) ...[
                        Text(
                          title!,
                          style: TextStyle(
                            color: colors.foreground,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(message, style: TextStyle(color: colors.foreground)),
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 8),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class PipeFeedback {
  static void show(
    BuildContext context, {
    required String message,
    PipeStatusTone tone = PipeStatusTone.info,
    IconData? icon,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final colors = PipeStatusColors.of(context).forTone(tone);
    final label = _labelForTone(tone);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.background,
        showCloseIcon: true,
        closeIconColor: colors.foreground,
        content: Semantics(
          container: true,
          liveRegion: true,
          label: '$label. $message',
          child: ExcludeSemantics(
            child: Row(children: [
              Icon(icon ?? _iconForTone(tone), color: colors.foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: colors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ));
  }
}

String _labelForTone(PipeStatusTone tone) => switch (tone) {
      PipeStatusTone.info => 'Information',
      PipeStatusTone.success => 'Success',
      PipeStatusTone.warning => 'Warning',
      PipeStatusTone.error => 'Error',
    };

IconData _iconForTone(PipeStatusTone tone) => switch (tone) {
      PipeStatusTone.info => Icons.info_outline,
      PipeStatusTone.success => Icons.check_circle_outline,
      PipeStatusTone.warning => Icons.warning_amber_outlined,
      PipeStatusTone.error => Icons.error_outline,
    };
