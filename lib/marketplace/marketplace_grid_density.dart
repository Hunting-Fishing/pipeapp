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
    return Semantics(
      container: true,
      label: 'Marketplace listing layout density',
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
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
          children: [
            _buildOption(context, 0, Icons.auto_awesome_rounded, 'Auto'),
            _buildOption(context, 1, Icons.view_headline_rounded, '1'),
            _buildOption(context, 2, Icons.grid_view_rounded, '2'),
            _buildOption(context, 3, Icons.grid_on_rounded, '3'),
            _buildOption(context, 4, Icons.apps_rounded, '4'),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    int columns,
    IconData icon,
    String label,
  ) {
    final theme = Theme.of(context);
    final isSelected = selectedColumns == columns;
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
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? PipeBuyerColors.orange : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Color(0x28F36A21),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurface.withValues(alpha: .62),
                ),
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
