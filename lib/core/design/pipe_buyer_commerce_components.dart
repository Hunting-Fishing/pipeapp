import 'package:flutter/material.dart';

import 'pipe_buyer_theme.dart';

/// Reusable high-level commerce components for the Pipe Buyer home, browse,
/// listing and Dispatch surfaces.
///
/// These widgets intentionally contain presentation only. Callers own all
/// Firebase queries, navigation, permissions, commands and marketplace state.
class PipeBuyerHeroPanel extends StatelessWidget {
  const PipeBuyerHeroPanel({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.backgroundImage,
    this.trailing,
    this.minHeight = 330,
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final ImageProvider<Object>? backgroundImage;
  final Widget? trailing;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final content = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 620 : 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow != null && eyebrow!.trim().isNotEmpty) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: PipeBuyerColors.orange,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                title,
                style: (compact
                        ? theme.textTheme.headlineLarge
                        : theme.textTheme.displaySmall)
                    ?.copyWith(
                  color: Colors.white,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: compact ? -.65 : -1.0,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: .82),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (primaryActionLabel != null ||
                  secondaryActionLabel != null) ...[
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (primaryActionLabel != null)
                      FilledButton.icon(
                        onPressed: onPrimaryAction,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text(primaryActionLabel!),
                      ),
                    if (secondaryActionLabel != null)
                      OutlinedButton.icon(
                        onPressed: onSecondaryAction,
                        icon: const Icon(Icons.add_business_outlined, size: 18),
                        label: Text(secondaryActionLabel!),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: .52),
                          ),
                          backgroundColor:
                              Colors.black.withValues(alpha: .12),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (backgroundImage != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: backgroundImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          PipeBuyerColors.ink,
                          PipeBuyerColors.graphite,
                        ],
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        PipeBuyerColors.ink.withValues(alpha: .96),
                        PipeBuyerColors.ink.withValues(alpha: .78),
                        PipeBuyerColors.ink.withValues(
                          alpha: compact ? .62 : .22,
                        ),
                      ],
                      stops: const [0, .48, 1],
                    ),
                    border: Border.all(
                      color: PipeBuyerColors.orange.withValues(alpha: .18),
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(compact ? 24 : 38),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            content,
                            if (trailing != null) ...[
                              const SizedBox(height: 20),
                              trailing!,
                            ],
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(flex: 7, child: content),
                            if (trailing != null) ...[
                              const SizedBox(width: 28),
                              Expanded(flex: 3, child: trailing!),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PipeBuyerCommerceSearchBar extends StatelessWidget {
  const PipeBuyerCommerceSearchBar({
    super.key,
    required this.fields,
    required this.onSearch,
    this.searchLabel = 'Search',
    this.padding = const EdgeInsets.all(14),
  });

  final List<Widget> fields;
  final VoidCallback? onSearch;
  final String searchLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 820;
            final button = FilledButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded, size: 19),
              label: Text(searchLabel),
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < fields.length; index++) ...[
                    fields[index],
                    if (index != fields.length - 1)
                      const SizedBox(height: 10),
                  ],
                  if (fields.isNotEmpty) const SizedBox(height: 12),
                  SizedBox(height: 52, child: button),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var index = 0; index < fields.length; index++) ...[
                  Expanded(child: fields[index]),
                  const SizedBox(width: 10),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 150),
                  child: SizedBox(height: 52, child: button),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PipeBuyerTrustItemData {
  const PipeBuyerTrustItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class PipeBuyerTrustBand extends StatelessWidget {
  const PipeBuyerTrustBand({
    super.key,
    required this.items,
    this.dark = true,
  });

  final List<PipeBuyerTrustItemData> items;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = dark ? PipeBuyerColors.ink : theme.colorScheme.surface;
    final foreground = dark ? Colors.white : theme.colorScheme.onSurface;
    final secondary = dark
        ? Colors.white.withValues(alpha: .66)
        : theme.colorScheme.onSurface.withValues(alpha: .60);
    final border = dark
        ? Colors.white.withValues(alpha: .08)
        : theme.colorScheme.outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desired = constraints.maxWidth >= 1080
              ? items.length.clamp(1, 4).toInt()
              : constraints.maxWidth >= 620
                  ? 2
                  : 1;
          const gap = 12.0;
          final width = desired == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - gap * (desired - 1)) / desired;
          return Wrap(
            spacing: gap,
            runSpacing: 12,
            children: items
                .map(
                  (item) => SizedBox(
                    width: width,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: PipeBuyerColors.orange.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.icon,
                            color: PipeBuyerColors.orange,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: secondary,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class PipeBuyerSectionHeading extends StatelessWidget {
  const PipeBuyerSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.35,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .62),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 14),
          trailing!,
        ],
      ],
    );
  }
}

class PipeBuyerCategoryTile extends StatelessWidget {
  const PipeBuyerCategoryTile({
    super.key,
    required this.title,
    required this.visual,
    required this.onTap,
    this.subtitle,
    this.selected = false,
  });

  final String title;
  final Widget visual;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? PipeBuyerColors.orange : theme.colorScheme.outline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 46, height: 46, child: Center(child: visual)),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .56),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
