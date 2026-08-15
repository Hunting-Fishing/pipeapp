import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

enum TimedBuyingUrgency {
  unknown,
  upcoming,
  monthPlus,
  weeks,
  week,
  day,
  hours,
  finalHour,
  closed,
}

@immutable
class TimedBuyingUrgencyState {
  const TimedBuyingUrgencyState({
    required this.urgency,
    required this.label,
    required this.detail,
    required this.color,
    this.animated = false,
  });

  final TimedBuyingUrgency urgency;
  final String label;
  final String detail;
  final Color color;
  final bool animated;
}

TimedBuyingUrgencyState timedBuyingUrgencyState({
  required DateTime? start,
  required DateTime? end,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  if (start == null || end == null) {
    return const TimedBuyingUrgencyState(
      urgency: TimedBuyingUrgency.unknown,
      label: 'Schedule',
      detail: 'Closing time unavailable',
      color: PipeBuyerColors.slate,
    );
  }
  if (clock.isBefore(start)) {
    return TimedBuyingUrgencyState(
      urgency: TimedBuyingUrgency.upcoming,
      label: 'Upcoming',
      detail: 'Starts in ${timedBuyingDuration(start.difference(clock))}',
      color: PipeBuyerColors.industrialBlue,
    );
  }
  if (!clock.isBefore(end)) {
    return const TimedBuyingUrgencyState(
      urgency: TimedBuyingUrgency.closed,
      label: 'Closed',
      detail: 'Timed Buying closed',
      color: PipeBuyerColors.slate,
    );
  }

  final remaining = end.difference(clock);
  if (remaining > const Duration(days: 30)) {
    return TimedBuyingUrgencyState(
      urgency: TimedBuyingUrgency.monthPlus,
      label: 'Month+',
      detail: 'Closes in ${timedBuyingDuration(remaining)}',
      color: PipeBuyerColors.slate,
    );
  }
  if (remaining > const Duration(days: 14)) {
    return TimedBuyingUrgencyState(
      urgency: TimedBuyingUrgency.weeks,
      label: 'Weeks',
      detail: 'Closes in ${timedBuyingDuration(remaining)}',
      color: PipeBuyerColors.industrialBlue,
    );
  }
  if (remaining > const Duration(days: 7)) {
    return TimedBuyingUrgencyState(
      urgency: TimedBuyingUrgency.week,
      label: 'Final weeks',
      detail: 'Closes in ${timedBuyingDuration(remaining)}',
      color: PipeBuyerColors.success,
    );
  }
  if (remaining > const Duration(days: 1)) {
    return TimedBuyingUrgencyState(
      urgency: TimedBuyingUrgency.day,
      label: 'Final week',
      detail: 'Closes in ${timedBuyingDuration(remaining)}',
      color: PipeBuyerColors.warning,
    );
  }
  if (remaining > const Duration(hours: 1)) {
    return TimedBuyingUrgencyState(
      urgency: TimedBuyingUrgency.hours,
      label: 'Final day',
      detail: 'Closes in ${timedBuyingDuration(remaining)}',
      color: PipeBuyerColors.orangePressed,
    );
  }
  return TimedBuyingUrgencyState(
    urgency: TimedBuyingUrgency.finalHour,
    label: 'Final hour',
    detail: 'Closes in ${timedBuyingDuration(remaining)}',
    color: PipeBuyerColors.danger,
    animated: true,
  );
}

String timedBuyingTimeLabel({
  required DateTime? start,
  required DateTime? end,
  DateTime? now,
}) =>
    timedBuyingUrgencyState(start: start, end: end, now: now).detail;

String timedBuyingDuration(Duration value) {
  final safe = value.isNegative ? Duration.zero : value;
  final days = safe.inDays;
  final hours = safe.inHours.remainder(24);
  final minutes = safe.inMinutes.remainder(60);
  final seconds = safe.inSeconds.remainder(60);
  if (days >= 30) {
    final months = days ~/ 30;
    final remainingDays = days.remainder(30);
    return remainingDays == 0 ? '${months}mo' : '${months}mo ${remainingDays}d';
  }
  if (days > 0) return '${days}d ${hours}h ${minutes}m';
  if (safe.inHours > 0) return '${safe.inHours}h ${minutes}m ${seconds}s';
  return '${safe.inMinutes}m ${seconds}s';
}

String timedBuyingPublicMessage(String value) {
  var output = value.trim();
  if (output.isEmpty) return output;
  final replacements = <(RegExp, String)>[
    (RegExp(r'winning bidder', caseSensitive: false), 'successful buyer'),
    (RegExp(r'high bidder', caseSensitive: false), 'leading buyer'),
    (RegExp(r'bidders', caseSensitive: false), 'buyers'),
    (RegExp(r'bidder', caseSensitive: false), 'buyer'),
    (RegExp(r'bidding', caseSensitive: false), 'timed offers'),
    (RegExp(r'bids', caseSensitive: false), 'timed offers'),
    (RegExp(r'bid', caseSensitive: false), 'timed offer'),
    (RegExp(r'auctions', caseSensitive: false), 'Timed Buying listings'),
    (RegExp(r'auction', caseSensitive: false), 'Timed Buying listing'),
  ];
  for (final replacement in replacements) {
    output = output.replaceAll(replacement.$1, replacement.$2);
  }
  return output;
}

class TimedBuyingUrgencyFrame extends StatefulWidget {
  const TimedBuyingUrgencyFrame({
    super.key,
    required this.start,
    required this.end,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.radius = 18,
  });

  final DateTime? start;
  final DateTime? end;
  final Widget child;
  final EdgeInsetsGeometry margin;
  final double radius;

  @override
  State<TimedBuyingUrgencyFrame> createState() =>
      _TimedBuyingUrgencyFrameState();
}

class _TimedBuyingUrgencyFrameState extends State<TimedBuyingUrgencyFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgency = timedBuyingUrgencyState(
      start: widget.start,
      end: widget.end,
    );
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animate = urgency.animated && !reduceMotion;
    final stroke = urgency.urgency == TimedBuyingUrgency.finalHour ? 3.0 : 2.0;
    return Padding(
      padding: widget.margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius + 2),
          boxShadow: urgency.urgency == TimedBuyingUrgency.hours ||
                  urgency.urgency == TimedBuyingUrgency.finalHour
              ? [
                  BoxShadow(
                    color: urgency.color.withValues(
                      alpha: urgency.urgency == TimedBuyingUrgency.finalHour
                          ? .28
                          : .16,
                    ),
                    blurRadius: urgency.urgency == TimedBuyingUrgency.finalHour
                        ? 16
                        : 10,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => CustomPaint(
            foregroundPainter: _TimedBuyingBorderPainter(
              color: urgency.color,
              radius: widget.radius + 2,
              strokeWidth: stroke,
              progress: animate ? _controller.value : 0,
              sparkle: animate,
            ),
            child: child,
          ),
          child: Padding(
            padding: EdgeInsets.all(stroke + 1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimedBuyingBorderPainter extends CustomPainter {
  const _TimedBuyingBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.progress,
    required this.sparkle,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double progress;
  final bool sparkle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    if (sparkle) {
      paint.shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: [
          color.withValues(alpha: .35),
          color,
          Colors.white,
          color,
          color.withValues(alpha: .35),
        ],
      ).createShader(rect);
    } else {
      paint.color = color.withValues(alpha: .78);
    }
    canvas.drawRRect(rrect, paint);

    if (!sparkle) return;
    final sparklePaint = Paint()..color = Colors.white.withValues(alpha: .92);
    final center = rect.center;
    final rx = math.max(0.0, size.width / 2 - 7).toDouble();
    final ry = math.max(0.0, size.height / 2 - 7).toDouble();
    for (var index = 0; index < 3; index++) {
      final angle = progress * math.pi * 2 + index * (math.pi * 2 / 3);
      final point = Offset(
        center.dx + math.cos(angle) * rx,
        center.dy + math.sin(angle) * ry,
      );
      canvas.drawCircle(point, index == 0 ? 2.4 : 1.7, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimedBuyingBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.sparkle != sparkle ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}

class TimedBuyingUrgencyBadge extends StatelessWidget {
  const TimedBuyingUrgencyBadge({
    super.key,
    required this.start,
    required this.end,
    this.compact = false,
  });

  final DateTime? start;
  final DateTime? end;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = timedBuyingUrgencyState(start: start, end: end);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: state.color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: state.color.withValues(alpha: .38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: compact ? 13 : 15, color: state.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              state.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: state.color,
                fontSize: compact ? 10.5 : 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showTimedBuyingLegend(BuildContext context) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: PipeBuyerColors.orangePressed),
            SizedBox(width: 9),
            Text('Timed Buying time signals'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Listing borders become more urgent as the closing time approaches. The final hour uses a subtle moving highlight unless reduced-motion settings are enabled.',
                ),
                SizedBox(height: 14),
                _TimedBuyingLegendRow(
                  color: PipeBuyerColors.slate,
                  label: 'Month+',
                  detail: 'More than 30 days remaining',
                ),
                _TimedBuyingLegendRow(
                  color: PipeBuyerColors.industrialBlue,
                  label: 'Weeks',
                  detail: '15–30 days remaining',
                ),
                _TimedBuyingLegendRow(
                  color: PipeBuyerColors.success,
                  label: 'Final weeks',
                  detail: '8–14 days remaining',
                ),
                _TimedBuyingLegendRow(
                  color: PipeBuyerColors.warning,
                  label: 'Final week',
                  detail: '1–7 days remaining',
                ),
                _TimedBuyingLegendRow(
                  color: PipeBuyerColors.orangePressed,
                  label: 'Final day',
                  detail: '1–24 hours remaining',
                ),
                _TimedBuyingLegendRow(
                  color: PipeBuyerColors.danger,
                  label: 'Final hour',
                  detail: 'Less than 60 minutes remaining',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );

class _TimedBuyingLegendRow extends StatelessWidget {
  const _TimedBuyingLegendRow({
    required this.color,
    required this.label,
    required this.detail,
  });

  final Color color;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: color, width: 2),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: PipeBuyerColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
