import 'package:flutter/material.dart';

import 'pipe_buyer_theme.dart';

enum PipeBuyerStatusTone { neutral, info, success, warning, danger, premium }

Color pipeBuyerToneColor(PipeBuyerStatusTone tone) => switch (tone) {
      PipeBuyerStatusTone.neutral => PipeBuyerColors.slate,
      PipeBuyerStatusTone.info => PipeBuyerColors.industrialBlue,
      PipeBuyerStatusTone.success => PipeBuyerColors.success,
      PipeBuyerStatusTone.warning => PipeBuyerColors.warning,
      PipeBuyerStatusTone.danger => PipeBuyerColors.danger,
      PipeBuyerStatusTone.premium => PipeBuyerColors.orange,
    };

class PipeBuyerPageHeader extends StatelessWidget {
  const PipeBuyerPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.icon,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleBlock = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: PipeBuyerColors.orangeSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: PipeBuyerColors.orange, size: 25),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null && eyebrow!.trim().isNotEmpty) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: PipeBuyerColors.orangePressed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .68),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 720 && actions.isNotEmpty;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: 18),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        );
      },
    );
  }
}

class PipeBuyerStatusBadge extends StatelessWidget {
  const PipeBuyerStatusBadge({
    super.key,
    required this.label,
    this.tone = PipeBuyerStatusTone.neutral,
    this.icon,
  });

  final String label;
  final PipeBuyerStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = pipeBuyerToneColor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class PipeBuyerSectionCard extends StatelessWidget {
  const PipeBuyerSectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHeader = title != null || subtitle != null || leading != null;
    return Card(
      margin: margin,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHeader) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: .64),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class PipeBuyerMetricCard extends StatelessWidget {
  const PipeBuyerMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.tone = PipeBuyerStatusTone.neutral,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final PipeBuyerStatusTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = pipeBuyerToneColor(tone);
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: .38),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: .70),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: .54),
              ),
            ),
          ],
        ],
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class PipeBuyerMetricGrid extends StatelessWidget {
  const PipeBuyerMetricGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 700
                ? 2
                : 1;
        const gap = 12.0;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class PipeBuyerActionTile extends StatelessWidget {
  const PipeBuyerActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.tone = PipeBuyerStatusTone.neutral,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final VoidCallback onTap;
  final PipeBuyerStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = pipeBuyerToneColor(tone);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: .60),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 10),
                badge!,
              ],
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: .44),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PipeBuyerAccountHealthCard extends StatelessWidget {
  const PipeBuyerAccountHealthCard({
    super.key,
    required this.completion,
    required this.score,
    required this.verified,
    this.onOpenScore,
    this.onCompleteProfile,
  });

  final int completion;
  final int score;
  final bool verified;
  final VoidCallback? onOpenScore;
  final VoidCallback? onCompleteProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeCompletion = completion.clamp(0, 100);
    final safeScore = score.clamp(0, 100);
    return PipeBuyerSectionCard(
      title: 'Account health',
      subtitle:
          'Complete your identity and profile to unlock stronger marketplace trust.',
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: PipeBuyerColors.orangeSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.health_and_safety_outlined,
          color: PipeBuyerColors.orange,
        ),
      ),
      trailing: PipeBuyerStatusBadge(
        label: verified ? 'VERIFIED' : 'ACTION NEEDED',
        tone: verified
            ? PipeBuyerStatusTone.success
            : PipeBuyerStatusTone.warning,
        icon: verified ? Icons.verified_rounded : Icons.pending_actions_rounded,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _HealthValue(
                  label: 'Profile completion',
                  value: '$safeCompletion%',
                ),
              ),
              Container(width: 1, height: 42, color: theme.dividerColor),
              Expanded(
                child: _HealthValue(
                  label: 'Marketplace score',
                  value: '$safeScore',
                  onTap: onOpenScore,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: safeCompletion / 100,
              backgroundColor: theme.dividerColor,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(PipeBuyerColors.orange),
            ),
          ),
          if (safeCompletion < 100 && onCompleteProfile != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onCompleteProfile,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Complete your marketplace profile'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthValue extends StatelessWidget {
  const _HealthValue({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: .58),
          ),
        ),
      ],
    );
    if (onTap == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }
}
