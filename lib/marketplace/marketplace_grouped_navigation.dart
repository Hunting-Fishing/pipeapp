import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

class MarketplaceGroupedNavigation extends StatelessWidget {
  const MarketplaceGroupedNavigation({
    super.key,
    required this.selectedPageIndex,
    required this.marketplaceEnabled,
    required this.auctionsEnabled,
    required this.dispatchEnabled,
    required this.onDestinationSelected,
    required this.onWanted,
  });

  final int selectedPageIndex;
  final bool marketplaceEnabled;
  final bool auctionsEnabled;
  final bool dispatchEnabled;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onWanted;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
            selected: selectedPageIndex == 0,
            onTap: () => onDestinationSelected(0),
          ),
          if (marketplaceEnabled) ...[
            const _SectionLabel('MARKETPLACE'),
            _NavItem(
              icon: Icons.storefront_outlined,
              selectedIcon: Icons.storefront_rounded,
              label: 'Browse Marketplace',
              selected: selectedPageIndex == 1,
              onTap: () => onDestinationSelected(1),
            ),
            _NavItem(
              icon: Icons.add_box_outlined,
              selectedIcon: Icons.add_box_rounded,
              label: 'Create Listing',
              selected: selectedPageIndex == 2,
              onTap: () => onDestinationSelected(2),
            ),
            _NavItem(
              icon: Icons.campaign_outlined,
              selectedIcon: Icons.campaign_rounded,
              label: 'Wanted Ads & RFQs',
              selected: false,
              onTap: onWanted,
            ),
            _NavItem(
              icon: Icons.bookmark_border_rounded,
              selectedIcon: Icons.bookmark_rounded,
              label: 'Saved Listings',
              selected: selectedPageIndex == 3,
              onTap: () => onDestinationSelected(3),
            ),
          ],
          const _SectionLabel('DEALS'),
          _NavItem(
            icon: Icons.forum_outlined,
            selectedIcon: Icons.forum_rounded,
            label: 'Messages & Offers',
            selected: selectedPageIndex == 4,
            onTap: () => onDestinationSelected(4),
          ),
          if (auctionsEnabled)
            _NavItem(
              icon: Icons.timer_outlined,
              selectedIcon: Icons.timer_rounded,
              label: 'Timed Buying',
              selected: selectedPageIndex == 6,
              onTap: () => onDestinationSelected(6),
            ),
          if (dispatchEnabled) ...[
            const _SectionLabel('LOGISTICS'),
            _NavItem(
              icon: Icons.local_shipping_outlined,
              selectedIcon: Icons.local_shipping_rounded,
              label: 'Dispatch',
              selected: selectedPageIndex == 7,
              onTap: () => onDestinationSelected(7),
            ),
          ],
        ],
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
        child: Text(
          label,
          style: const TextStyle(
            color: PipeBuyerColors.muted,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.15,
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected ? PipeBuyerColors.orangeSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: selected
                    ? Border.all(
                        color: PipeBuyerColors.orange.withValues(alpha: .20),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: selected
                          ? PipeBuyerColors.orange.withValues(alpha: .12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      selected ? selectedIcon : icon,
                      size: 20,
                      color: selected
                          ? PipeBuyerColors.orangePressed
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .58),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w900 : FontWeight.w700,
                        color: selected
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: .68),
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: PipeBuyerColors.orangePressed,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}
