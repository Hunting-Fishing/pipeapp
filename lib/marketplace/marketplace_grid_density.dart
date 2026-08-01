import 'package:flutter/material.dart';

class MarketplaceGridDensityBar extends StatelessWidget {
  const MarketplaceGridDensityBar({
    super.key,
    required this.selectedColumns,
    required this.onChanged,
  });

  /// 0 = Auto responsive (4 cols on wide desktop, 3 on desktop, 2 on tablet, 1 on phone)
  /// 1 = Forced 1 per row (List view)
  /// 2 = Forced 2 per row
  /// 3 = Forced 3 per row
  /// 4 = Forced 4 per row
  final int selectedColumns;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(0, Icons.auto_awesome_rounded, 'Auto'),
          _buildOption(1, Icons.view_headline_rounded, '1'),
          _buildOption(2, Icons.grid_view_rounded, '2'),
          _buildOption(3, Icons.grid_on_rounded, '3'),
          _buildOption(4, Icons.apps_rounded, '4'),
        ],
      ),
    );
  }

  Widget _buildOption(int cols, IconData icon, String label) {
    final isSelected = selectedColumns == cols;
    return InkWell(
      onTap: () => onChanged(cols),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0878E8) : Colors.transparent,
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
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calculates effective columns given total screen width and selected user preference.
  static int resolveColumns(double screenWidth, int preference) {
    if (preference > 0) {
      final maxPossible = (screenWidth / 180).floor().clamp(1, 4);
      return preference.clamp(1, maxPossible);
    }
    // Standard default resolution (4 columns on standard screens):
    if (screenWidth >= 750) return 4;
    if (screenWidth >= 480) return 2;
    return 1;
  }
}
