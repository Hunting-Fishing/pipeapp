import 'package:flutter/material.dart';

import 'pipe_buyer_theme.dart';

class PipeBuyerDispatchHero extends StatelessWidget {
  const PipeBuyerDispatchHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PipeBuyerColors.orange.withValues(alpha: .24)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TRUCKING & DISPATCH',
                  style: TextStyle(
                    color: PipeBuyerColors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.05,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 26 : 34,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.55,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
                if (primaryLabel != null || secondaryLabel != null) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (primaryLabel != null)
                        FilledButton.icon(
                          onPressed: onPrimary,
                          icon: const Icon(Icons.add_road_outlined),
                          label: Text(primaryLabel!),
                        ),
                      if (secondaryLabel != null)
                        OutlinedButton.icon(
                          onPressed: onSecondary,
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: Text(secondaryLabel!),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            );

            if (compact || trailing == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  if (trailing != null) ...[
                    const SizedBox(height: 18),
                    trailing!,
                  ],
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 7, child: content),
                const SizedBox(width: 20),
                Expanded(flex: 3, child: trailing!),
              ],
            );
          },
        ),
      );
}

class PipeBuyerDispatchMetricData {
  const PipeBuyerDispatchMetricData({
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;
}

class PipeBuyerDispatchMetrics extends StatelessWidget {
  const PipeBuyerDispatchMetrics({super.key, required this.items});

  final List<PipeBuyerDispatchMetricData> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 4
              : constraints.maxWidth >= 620
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
                    child: _DispatchMetricCard(item: item),
                  ),
                )
                .toList(growable: false),
          );
        },
      );
}

class _DispatchMetricCard extends StatelessWidget {
  const _DispatchMetricCard({required this.item});

  final PipeBuyerDispatchMetricData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: PipeBuyerColors.orangeSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: PipeBuyerColors.orangePressed),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    item.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: .58),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (item.caption != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.caption!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: .48),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PipeBuyerDispatchWorkspace extends StatelessWidget {
  const PipeBuyerDispatchWorkspace({
    super.key,
    required this.loads,
    this.map,
    this.sidebar,
    this.filters,
  });

  final Widget loads;
  final Widget? map;
  final Widget? sidebar;
  final Widget? filters;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1120;
          final medium = constraints.maxWidth >= 760;

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (filters != null) ...[
                        filters!,
                        const SizedBox(height: 14),
                      ],
                      loads,
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (map != null) map!,
                      if (map != null && sidebar != null) const SizedBox(height: 14),
                      if (sidebar != null) sidebar!,
                    ],
                  ),
                ),
              ],
            );
          }

          if (medium) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (filters != null) ...[filters!, const SizedBox(height: 14)],
                if (map != null) ...[map!, const SizedBox(height: 14)],
                loads,
                if (sidebar != null) ...[const SizedBox(height: 14), sidebar!],
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (filters != null) ...[filters!, const SizedBox(height: 12)],
              loads,
              if (map != null) ...[const SizedBox(height: 12), map!],
              if (sidebar != null) ...[const SizedBox(height: 12), sidebar!],
            ],
          );
        },
      );
}

class PipeBuyerLoadRow extends StatelessWidget {
  const PipeBuyerLoadRow({
    super.key,
    required this.payout,
    required this.commodity,
    required this.origin,
    required this.destination,
    required this.trailer,
    this.loadSize,
    this.pickup,
    this.listed,
    this.onView,
  });

  final String payout;
  final String commodity;
  final String origin;
  final String destination;
  final String trailer;
  final String? loadSize;
  final String? pickup;
  final String? listed;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            payout,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: PipeBuyerColors.orangePressed,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        if (onView != null)
                          OutlinedButton(onPressed: onView, child: const Text('View')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      commodity,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 10),
                    _RouteLine(origin: origin, destination: destination),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _LoadChip(icon: Icons.local_shipping_outlined, label: trailer),
                        if (loadSize != null)
                          _LoadChip(icon: Icons.scale_outlined, label: loadSize!),
                        if (pickup != null)
                          _LoadChip(icon: Icons.event_outlined, label: pickup!),
                        if (listed != null)
                          _LoadChip(icon: Icons.schedule_outlined, label: listed!),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          final theme = Theme.of(context);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    payout,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: PipeBuyerColors.orangePressed,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _LoadCell(primary: commodity, secondary: loadSize)),
                Expanded(child: _LoadCell(primary: origin, secondary: pickup)),
                Expanded(child: _LoadCell(primary: destination, secondary: null)),
                Expanded(child: _LoadCell(primary: trailer, secondary: listed)),
                if (onView != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: onView, child: const Text('View Details')),
                ],
              ],
            ),
          );
        },
      );
}

class _LoadCell extends StatelessWidget {
  const _LoadCell({required this.primary, required this.secondary});

  final String primary;
  final String? secondary;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              primary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (secondary != null) ...[
              const SizedBox(height: 2),
              Text(
                secondary!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .54),
                    ),
              ),
            ],
          ],
        ),
      );
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.origin, required this.destination});

  final String origin;
  final String destination;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.trip_origin_rounded, size: 17, color: PipeBuyerColors.success),
          const SizedBox(width: 6),
          Expanded(child: Text(origin, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 7),
            child: Icon(Icons.arrow_forward_rounded, size: 17),
          ),
          Expanded(child: Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      );
}

class _LoadChip extends StatelessWidget {
  const _LoadChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
