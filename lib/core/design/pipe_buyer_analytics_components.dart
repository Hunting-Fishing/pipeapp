import 'package:flutter/material.dart';

import 'pipe_buyer_theme.dart';

class PipeBuyerAnalyticsMetricData {
  const PipeBuyerAnalyticsMetricData({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final bool emphasis;
}

class PipeBuyerAnalyticsMetricGrid extends StatelessWidget {
  const PipeBuyerAnalyticsMetricGrid({
    super.key,
    required this.items,
    this.compactBreakpoint = 620,
  });

  final List<PipeBuyerAnalyticsMetricData> items;
  final double compactBreakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 920
              ? 4
              : constraints.maxWidth >= compactBreakpoint
                  ? 2
                  : 1;
          const gap = 10.0;
          final width = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: items
                .map(
                  (item) => SizedBox(
                    width: width,
                    child: _PipeBuyerAnalyticsMetricCard(item: item),
                  ),
                )
                .toList(growable: false),
          );
        },
      );
}

class _PipeBuyerAnalyticsMetricCard extends StatelessWidget {
  const _PipeBuyerAnalyticsMetricCard({required this.item});

  final PipeBuyerAnalyticsMetricData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = item.emphasis
        ? PipeBuyerColors.orangePressed
        : PipeBuyerColors.industrialBlue;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.emphasis
            ? PipeBuyerColors.orangeSoft
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.emphasis
              ? PipeBuyerColors.orange.withValues(alpha: .24)
              : theme.colorScheme.outline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.icon, size: 20, color: accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .60),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.detail != null && item.detail!.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: .54),
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PipeBuyerAnalyticsFunnelStepData {
  const PipeBuyerAnalyticsFunnelStepData({
    required this.label,
    required this.value,
    this.rateLabel,
  });

  final String label;
  final int value;
  final String? rateLabel;
}

class PipeBuyerAnalyticsFunnel extends StatelessWidget {
  const PipeBuyerAnalyticsFunnel({
    super.key,
    required this.steps,
    this.title = 'Buyer engagement funnel',
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<PipeBuyerAnalyticsFunnelStepData> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = steps.fold<int>(
      0,
      (current, step) => step.value > current ? step.value : current,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: .58),
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final ratio = maxValue <= 0 ? 0.0 : step.value / maxValue;
            return Padding(
              padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${step.value}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (step.rateLabel != null &&
                          step.rateLabel!.trim().isNotEmpty) ...[
                        const SizedBox(width: 7),
                        Text(
                          step.rateLabel!,
                          style: const TextStyle(
                            color: PipeBuyerColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: PipeBuyerColors.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        index == steps.length - 1
                            ? PipeBuyerColors.orangePressed
                            : PipeBuyerColors.industrialBlue,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class PipeBuyerAnalyticsSignalBand extends StatelessWidget {
  const PipeBuyerAnalyticsSignalBand({
    super.key,
    required this.label,
    required this.message,
    this.icon = Icons.insights_rounded,
    this.strong = false,
  });

  final String label;
  final String message;
  final IconData icon;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final accent = strong ? PipeBuyerColors.success : PipeBuyerColors.orangePressed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: .20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
