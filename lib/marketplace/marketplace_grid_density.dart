import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_adaptive_layout.dart';

class MarketplaceGridDensityBar extends StatelessWidget {
  const MarketplaceGridDensityBar({
    super.key,
    required this.selectedColumns,
    required this.onChanged,
  });

  /// 0 = automatic responsive density.
  /// 1-4 = explicit user preference, clamped to a readable width.
  final int selectedColumns;
  final ValueChanged<int> onChanged;

  static const double compactBreakpoint =
      MarketplaceAdaptiveLayout.compactBreakpoint;
  static const double mediumBreakpoint =
      MarketplaceAdaptiveLayout.mediumBreakpoint;
  static const double expandedBreakpoint =
      MarketplaceAdaptiveLayout.expandedBreakpoint;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < compactBreakpoint;
    final options = compact
        ? const <({int columns, IconData icon, String label})>[
            (columns: 0, icon: Icons.auto_awesome_rounded, label: 'Auto'),
            (columns: 1, icon: Icons.view_headline_rounded, label: '1'),
            (columns: 2, icon: Icons.grid_view_rounded, label: '2'),
          ]
        : const <({int columns, IconData icon, String label})>[
            (columns: 0, icon: Icons.auto_awesome_rounded, label: 'Auto'),
            (columns: 1, icon: Icons.view_headline_rounded, label: '1'),
            (columns: 2, icon: Icons.grid_view_rounded, label: '2'),
            (columns: 3, icon: Icons.grid_on_rounded, label: '3'),
            (columns: 4, icon: Icons.apps_rounded, label: '4'),
          ];

    return Semantics(
      container: true,
      label: 'Marketplace listing layout density',
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (option) => _buildOption(
                  context,
                  option.columns,
                  option.icon,
                  option.label,
                  iconOnly: compact && option.columns != 0,
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    int columns,
    IconData icon,
    String label, {
    bool iconOnly = false,
  }) {
    final theme = Theme.of(context);
    final maxColumns = maxColumnsForWidth(MediaQuery.sizeOf(context).width);
    final effectiveSelection = selectedColumns <= 0
        ? 0
        : selectedColumns.clamp(1, maxColumns).toInt();
    final isSelected = effectiveSelection == columns;
    final semanticLabel = columns == 0
        ? 'Automatic responsive grid density'
        : '$columns ${columns == 1 ? 'column' : 'columns'}';

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: InkWell(
          onTap: () => onChanged(columns),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 34),
            padding: EdgeInsets.symmetric(
              horizontal: iconOnly ? 8 : 9,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: isSelected ? PipeBuyerColors.orange : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Color(0x28FF6A00),
                        blurRadius: 9,
                        offset: Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurface.withValues(alpha: .62),
                ),
                if (!iconOnly) ...[
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurface.withValues(alpha: .68),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Maximum readable density for the available content width.
  static int maxColumnsForWidth(double availableWidth) =>
      MarketplaceAdaptiveLayout.maxGridColumns(availableWidth);

  /// Resolves the effective grid density for an automatic or explicit user
  /// preference. Explicit preferences are preserved only when the available
  /// width can display them without producing cramped cards.
  static int resolveColumns(double availableWidth, int preference) {
    final maxColumns = maxColumnsForWidth(availableWidth);
    if (preference <= 0) return maxColumns;
    return preference.clamp(1, maxColumns).toInt();
  }
}
