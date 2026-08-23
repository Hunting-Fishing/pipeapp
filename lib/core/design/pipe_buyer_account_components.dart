import 'package:flutter/material.dart';

import 'pipe_buyer_theme.dart';

class PipeBuyerCenterHeader extends StatelessWidget {
  const PipeBuyerCenterHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.actions = const <Widget>[],
    this.badges = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final List<Widget> actions;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PipeBuyerColors.orange.withValues(alpha: .20)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null && eyebrow!.trim().isNotEmpty) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: const TextStyle(
                    color: PipeBuyerColors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 26 : 31,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.45,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 7, runSpacing: 7, children: badges),
              ],
            ],
          );
          if (compact || actions.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              const SizedBox(width: 18),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        },
      ),
    );
  }
}

class PipeBuyerCenterGrid extends StatelessWidget {
  const PipeBuyerCenterGrid({
    super.key,
    required this.main,
    this.sidebar,
    this.gap = 16,
  });

  final Widget main;
  final Widget? sidebar;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1050 && sidebar != null) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: main),
                SizedBox(width: gap),
                SizedBox(width: 330, child: sidebar!),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              main,
              if (sidebar != null) ...[
                SizedBox(height: gap),
                sidebar!,
              ],
            ],
          );
        },
      );
}

class PipeBuyerCenterActionData {
  const PipeBuyerCenterActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
}

class PipeBuyerCenterActions extends StatelessWidget {
  const PipeBuyerCenterActions({
    super.key,
    required this.items,
    this.title = 'Quick Actions',
  });

  final String title;
  final List<PipeBuyerCenterActionData> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 800
                    ? 3
                    : constraints.maxWidth >= 480
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
                          child: _CenterAction(item: item),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterAction extends StatelessWidget {
  const _CenterAction({required this.item});

  final PipeBuyerCenterActionData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.orangeSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(item.icon, color: PipeBuyerColors.orangePressed, size: 20),
                  ),
                  const Spacer(),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.orange.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          color: PipeBuyerColors.orangePressed,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                item.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: .58),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PipeBuyerListingHealthCard extends StatelessWidget {
  const PipeBuyerListingHealthCard({
    super.key,
    required this.title,
    required this.completion,
    this.message,
    this.items = const <PipeBuyerHealthItemData>[],
    this.onImprove,
  });

  final String title;
  final int completion;
  final String? message;
  final List<PipeBuyerHealthItemData> items;
  final VoidCallback? onImprove;

  @override
  Widget build(BuildContext context) {
    final safe = completion.clamp(0, 100);
    final theme = Theme.of(context);
    final tone = safe >= 85
        ? PipeBuyerColors.success
        : safe >= 60
            ? PipeBuyerColors.warning
            : PipeBuyerColors.danger;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$safe%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: safe / 100,
                minHeight: 8,
                color: tone,
                backgroundColor: theme.colorScheme.outline,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 9),
              Text(
                message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: .60),
                ),
              ),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 13),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        item.complete ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        size: 18,
                        color: item.complete ? PipeBuyerColors.success : theme.colorScheme.onSurface.withValues(alpha: .40),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          item.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (onImprove != null) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: onImprove,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Improve Listing'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PipeBuyerHealthItemData {
  const PipeBuyerHealthItemData({required this.label, required this.complete});

  final String label;
  final bool complete;
}
