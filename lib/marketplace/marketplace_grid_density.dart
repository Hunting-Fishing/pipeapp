import 'package:flutter/material.dart';

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

  static const double compactBreakpoint = 600;
  static const double mediumBreakpoint = 900;
  static const double expandedBreakpoint = 1200;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      padding: const EdgeInsets.all(3),
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
    );
  }

  Widget _buildOption(
    BuildContext context,
    int columns,
    IconData icon,
    String label,
  ) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = selectedColumns == columns;
    final semanticLabel = columns == 0
        ? 'Automatic grid density'
        : '$columns ${columns == 1 ? 'column' : 'columns'}';

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: InkWell(
          onTap: () => onChanged(columns),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Color(0x29000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
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
                  color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color:
                        isSelected ? colors.onPrimary : colors.onSurfaceVariant,
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
  ///
  /// These breakpoints intentionally add a three-column desktop state instead
  /// of jumping directly from two to four columns. This keeps listing cards
  /// readable when a navigation rail or filter panel reduces the content area.
  static int maxColumnsForWidth(double availableWidth) {
    if (!availableWidth.isFinite || availableWidth <= 0) return 1;
    if (availableWidth >= expandedBreakpoint) return 4;
    if (availableWidth >= mediumBreakpoint) return 3;
    if (availableWidth >= compactBreakpoint) return 2;
    return 1;
  }

  /// Resolves the effective grid density for an automatic or explicit user
  /// preference. Explicit preferences are preserved only when the available
  /// width can display them without producing cramped cards.
  static int resolveColumns(double availableWidth, int preference) {
    final maxColumns = maxColumnsForWidth(availableWidth);
    if (preference <= 0) return maxColumns;
    return preference.clamp(1, maxColumns).toInt();
  }
}
