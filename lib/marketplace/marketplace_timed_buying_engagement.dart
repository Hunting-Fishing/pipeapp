import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_timed_buying_presentation.dart';

String timedBuyingDisplayTitle(Object? raw) {
  var value = '${raw ?? 'Timed Buying listing'}'.trim();
  if (value.isEmpty) return 'Timed Buying listing';
  value = value.replaceFirst(
    RegExp(r'^Timed\s+Auction\s*[—–-]\s*', caseSensitive: false),
    'Timed Buying — ',
  );
  value = value.replaceFirst(
    RegExp(r'^Upcoming\s+Auction\s*[—–-]\s*', caseSensitive: false),
    'Timed Buying — Upcoming — ',
  );
  value = value.replaceFirst(
    RegExp(r'^Ended\s+Auction\s*[—–-]\s*', caseSensitive: false),
    'Timed Buying — Closed — ',
  );
  value = value.replaceAll(
    RegExp(r'\bTimed\s+Auction\b', caseSensitive: false),
    'Timed Buying',
  );
  value = value.replaceAll(
    RegExp(r'\bAuction\b', caseSensitive: false),
    'Timed Buying',
  );
  return value;
}

bool timedBuyingAttentionAnimates(TimedBuyingUrgency urgency) =>
    urgency == TimedBuyingUrgency.hours ||
    urgency == TimedBuyingUrgency.finalHour;

double timedBuyingAttentionStroke(TimedBuyingUrgency urgency) => switch (urgency) {
      TimedBuyingUrgency.monthPlus => 1.3,
      TimedBuyingUrgency.weeks => 1.5,
      TimedBuyingUrgency.week => 1.8,
      TimedBuyingUrgency.day => 2.2,
      TimedBuyingUrgency.hours => 3.2,
      TimedBuyingUrgency.finalHour => 4.2,
      _ => 1.4,
    };

class TimedBuyingAttentionFrame extends StatefulWidget {
  const TimedBuyingAttentionFrame({
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
  State<TimedBuyingAttentionFrame> createState() =>
      _TimedBuyingAttentionFrameState();
}

class _TimedBuyingAttentionFrameState extends State<TimedBuyingAttentionFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _clock = Timer.periodic(const Duration(seconds: 10), (_) {
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
    final state = timedBuyingUrgencyState(start: widget.start, end: widget.end);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final motion = timedBuyingAttentionAnimates(state.urgency) && !reduceMotion;
    final stroke = timedBuyingAttentionStroke(state.urgency);
    final urgent = state.urgency == TimedBuyingUrgency.day ||
        state.urgency == TimedBuyingUrgency.hours ||
        state.urgency == TimedBuyingUrgency.finalHour;
    final critical = state.urgency == TimedBuyingUrgency.finalHour;

    return Padding(
      padding: widget.margin,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = motion
              ? .5 + .5 * math.sin(_controller.value * math.pi * 2)
              : 0.0;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius + 4),
              boxShadow: urgent
                  ? [
                      BoxShadow(
                        color: state.color.withValues(
                          alpha: critical ? .34 + pulse * .16 : .20 + pulse * .10,
                        ),
                        blurRadius: critical ? 22 + pulse * 8 : 15 + pulse * 5,
                        spreadRadius: critical ? 2.2 : 1.2,
                      ),
                    ]
                  : const [],
            ),
            child: CustomPaint(
              foregroundPainter: _TimedBuyingAttentionPainter(
                color: state.color,
                radius: widget.radius + 3,
                strokeWidth: stroke,
                progress: motion ? _controller.value : 0,
                motion: motion,
                critical: critical,
              ),
              child: Padding(
                padding: EdgeInsets.all(stroke + 1.6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.radius),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _TimedBuyingAttentionPainter extends CustomPainter {
  const _TimedBuyingAttentionPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.progress,
    required this.motion,
    required this.critical,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double progress;
  final bool motion;
  final bool critical;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final baseRect = rect.deflate(strokeWidth / 2 + .4);
    final base = RRect.fromRectAndRadius(baseRect, Radius.circular(radius));
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: .92);
    canvas.drawRRect(base, basePaint);

    if (!motion) return;

    final movingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = critical ? strokeWidth + 1.4 : strokeWidth + .8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        transform: GradientRotation(progress * math.pi * 2),
        colors: [
          color.withValues(alpha: .12),
          color.withValues(alpha: .35),
          Colors.white,
          color,
          Colors.white,
          color.withValues(alpha: .18),
        ],
        stops: const [0, .23, .38, .48, .58, 1],
      ).createShader(rect);
    canvas.drawRRect(base, movingPaint);

    if (critical) {
      final inner = RRect.fromRectAndRadius(
        rect.deflate(strokeWidth + 4),
        Radius.circular(math.max(2, radius - 4)),
      );
      final innerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: .55);
      canvas.drawRRect(inner, innerPaint);
    }

    final sparklePaint = Paint()..color = Colors.white.withValues(alpha: .96);
    final center = rect.center;
    final rx = math.max(0.0, size.width / 2 - 8).toDouble();
    final ry = math.max(0.0, size.height / 2 - 8).toDouble();
    final count = critical ? 5 : 2;
    for (var index = 0; index < count; index++) {
      final angle = progress * math.pi * 2 + index * (math.pi * 2 / count);
      final point = Offset(
        center.dx + math.cos(angle) * rx,
        center.dy + math.sin(angle) * ry,
      );
      canvas.drawCircle(point, critical && index == 0 ? 2.8 : 1.8, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TimedBuyingAttentionPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.motion != motion ||
      oldDelegate.critical != critical ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.radius != radius;
}

class TimedBuyingAttentionStrip extends StatelessWidget {
  const TimedBuyingAttentionStrip({
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
    final urgent = state.urgency == TimedBuyingUrgency.day ||
        state.urgency == TimedBuyingUrgency.hours ||
        state.urgency == TimedBuyingUrgency.finalHour;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: state.color.withValues(alpha: urgent ? .12 : .07),
        border: Border(
          left: BorderSide(color: state.color, width: urgent ? 4 : 3),
          bottom: BorderSide(color: state.color.withValues(alpha: .18)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            state.urgency == TimedBuyingUrgency.finalHour
                ? Icons.notification_important_outlined
                : Icons.timer_outlined,
            color: state.color,
            size: compact ? 16 : 18,
          ),
          const SizedBox(width: 7),
          Text(
            state.label.toUpperCase(),
            style: TextStyle(
              color: state.color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .55,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              state.detail,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: state.color,
                fontSize: compact ? 10.5 : 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum TimedBuyingViewerPosition { seller, leading, outbid, participating }

class TimedBuyingViewerPositionBadge extends StatelessWidget {
  const TimedBuyingViewerPositionBadge({
    super.key,
    required this.position,
    this.compact = true,
  });

  final TimedBuyingViewerPosition position;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (position) {
      TimedBuyingViewerPosition.seller =>
        ('YOUR LISTING', Icons.storefront_outlined, PipeBuyerColors.industrialBlue),
      TimedBuyingViewerPosition.leading =>
        ('YOU’RE LEADING', Icons.emoji_events_outlined, PipeBuyerColors.success),
      TimedBuyingViewerPosition.outbid =>
        ('YOU’VE BEEN SURPASSED', Icons.trending_up_outlined, PipeBuyerColors.danger),
      TimedBuyingViewerPosition.participating =>
        ('YOUR TIMED OFFER', Icons.schedule_send_outlined, PipeBuyerColors.orangePressed),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xF20B1118),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1.25),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .22),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .35,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showTimedBuyingAttentionLegend(BuildContext context) =>
    showDialog<void>(
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
          constraints: const BoxConstraints(maxWidth: 540),
          child: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Borders intensify as closing approaches. The final day uses a moving highlight; the final hour adds a stronger glow, moving highlight and spark points unless reduced-motion settings are enabled.',
                ),
                SizedBox(height: 14),
                _AttentionLegendRow(
                    color: PipeBuyerColors.slate,
                    label: 'Month+',
                    detail: 'More than 30 days remaining'),
                _AttentionLegendRow(
                    color: PipeBuyerColors.industrialBlue,
                    label: 'Weeks',
                    detail: '15–30 days remaining'),
                _AttentionLegendRow(
                    color: PipeBuyerColors.success,
                    label: 'Final weeks',
                    detail: '8–14 days remaining'),
                _AttentionLegendRow(
                    color: PipeBuyerColors.warning,
                    label: 'Final week',
                    detail: '1–7 days remaining'),
                _AttentionLegendRow(
                    color: PipeBuyerColors.orangePressed,
                    label: 'Final day',
                    detail: '1–24 hours • moving orange highlight'),
                _AttentionLegendRow(
                    color: PipeBuyerColors.danger,
                    label: 'Final hour',
                    detail: 'Under 60 minutes • critical moving border + spark points'),
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

class _AttentionLegendRow extends StatelessWidget {
  const _AttentionLegendRow({
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
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: .20), blurRadius: 6),
                ],
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
