import 'package:flutter/material.dart';

import 'pipe_buyer_theme.dart';

enum PipeBuyerBrowseMode { grid, map }

class PipeBuyerBrowseToolbar extends StatelessWidget {
  const PipeBuyerBrowseToolbar({
    super.key,
    required this.resultLabel,
    required this.mode,
    required this.onModeChanged,
    this.activeFilters = const <Widget>[],
    this.sortControl,
    this.trailing,
  });

  final String resultLabel;
  final PipeBuyerBrowseMode mode;
  final ValueChanged<PipeBuyerBrowseMode> onModeChanged;
  final List<Widget> activeFilters;
  final Widget? sortControl;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resultLabel,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.25,
              ),
            ),
            if (activeFilters.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: activeFilters,
              ),
            ],
          ],
        );
        final controls = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (sortControl != null) sortControl!,
            _BrowseModeToggle(
              mode: mode,
              onChanged: onModeChanged,
            ),
            if (trailing != null) trailing!,
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              const SizedBox(height: 12),
              controls,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 18),
            controls,
          ],
        );
      },
    );
  }
}

class PipeBuyerFilterChip extends StatelessWidget {
  const PipeBuyerFilterChip({
    super.key,
    required this.label,
    this.onRemoved,
    this.icon,
  });

  final String label;
  final VoidCallback? onRemoved;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: EdgeInsets.fromLTRB(icon == null ? 11 : 9, 6, 7, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: PipeBuyerColors.orange),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (onRemoved != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemoved,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PipeBuyerFilterPanel extends StatelessWidget {
  const PipeBuyerFilterPanel({
    super.key,
    required this.children,
    this.title = 'Filters',
    this.onClear,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onClear;
  final Widget? footer;

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
                if (onClear != null)
                  TextButton(
                    onPressed: onClear,
                    child: const Text('Clear all'),
                  ),
              ],
            ),
            if (children.isNotEmpty) const SizedBox(height: 12),
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1) const SizedBox(height: 14),
            ],
            if (footer != null) ...[
              const SizedBox(height: 16),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class PipeBuyerMapPanel extends StatelessWidget {
  const PipeBuyerMapPanel({
    super.key,
    required this.child,
    this.title = 'Listings Map',
    this.subtitle = 'Browse public listing locations',
    this.searchAsMapMoves,
    this.onSearchAsMapMovesChanged,
    this.onRefresh,
    this.onExpand,
  });

  final Widget child;
  final String title;
  final String subtitle;
  final bool? searchAsMapMoves;
  final ValueChanged<bool>? onSearchAsMapMovesChanged;
  final VoidCallback? onRefresh;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final titleBlock = Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.orangeSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        color: PipeBuyerColors.orangePressed,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: .58),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final actions = Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (onRefresh != null)
                      IconButton(
                        tooltip: 'Refresh map listings',
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    if (onExpand != null)
                      IconButton(
                        tooltip: 'Expand map',
                        onPressed: onExpand,
                        icon: const Icon(Icons.open_in_full_rounded),
                      ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      titleBlock,
                      if (actions.children.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerLeft, child: actions),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: titleBlock),
                    actions,
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outline),
          Expanded(child: child),
          if (searchAsMapMoves != null &&
              onSearchAsMapMovesChanged != null) ...[
            Divider(height: 1, color: theme.colorScheme.outline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.travel_explore_outlined, size: 20),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Search as I move the map',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Switch(
                    value: searchAsMapMoves!,
                    onChanged: onSearchAsMapMovesChanged,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrowseModeToggle extends StatelessWidget {
  const _BrowseModeToggle({
    required this.mode,
    required this.onChanged,
  });

  final PipeBuyerBrowseMode mode;
  final ValueChanged<PipeBuyerBrowseMode> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<PipeBuyerBrowseMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: PipeBuyerBrowseMode.grid,
            icon: Icon(Icons.grid_view_rounded),
            label: Text('Grid'),
          ),
          ButtonSegment(
            value: PipeBuyerBrowseMode.map,
            icon: Icon(Icons.map_outlined),
            label: Text('Map'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) onChanged(selection.first);
        },
      );
}
