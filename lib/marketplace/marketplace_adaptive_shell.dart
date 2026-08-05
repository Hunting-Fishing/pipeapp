import 'package:flutter/material.dart';

import 'marketplace_adaptive_layout.dart';

@immutable
class MarketplaceShellDestination {
  const MarketplaceShellDestination({
    required this.pageIndex,
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final int pageIndex;
  final String label;
  final Widget icon;
  final Widget? selectedIcon;
}

/// Responsive application shell for marketplace navigation surfaces.
///
/// Compact and medium windows preserve the phone-first drawer and bottom
/// navigation pattern. Expanded and wide windows replace both with a
/// persistent navigation rail while constraining the active page to the
/// shared marketplace content width.
class MarketplaceAdaptiveShell extends StatelessWidget {
  const MarketplaceAdaptiveShell({
    super.key,
    required this.scaffoldKey,
    required this.selectedPageIndex,
    required this.title,
    required this.body,
    required this.onDestinationSelected,
    required this.compactDestinations,
    required this.railDestinations,
    this.drawer,
    this.actions = const <Widget>[],
    this.railLeading,
    this.railTrailing,
    this.backgroundColor,
    this.navigationBackgroundColor,
    this.indicatorColor,
  })  : assert(compactDestinations.length >= 2),
        assert(railDestinations.length >= 2);

  final GlobalKey<ScaffoldState> scaffoldKey;
  final int selectedPageIndex;
  final String title;
  final Widget body;
  final ValueChanged<int> onDestinationSelected;
  final List<MarketplaceShellDestination> compactDestinations;
  final List<MarketplaceShellDestination> railDestinations;
  final Widget? drawer;
  final List<Widget> actions;
  final Widget? railLeading;
  final Widget? railTrailing;
  final Color? backgroundColor;
  final Color? navigationBackgroundColor;
  final Color? indicatorColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final useRail =
            MarketplaceAdaptiveLayout.useNavigationRail(availableWidth);
        final extendRail =
            MarketplaceAdaptiveLayout.extendNavigationRail(availableWidth);

        if (useRail) {
          return Scaffold(
            key: scaffoldKey,
            backgroundColor: backgroundColor,
            appBar: _buildAppBar(context, showMenuButton: false),
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedDestinationIndex(
                      railDestinations,
                    ),
                    onDestinationSelected: (index) => onDestinationSelected(
                      railDestinations[index].pageIndex,
                    ),
                    extended: extendRail,
                    scrollable: true,
                    groupAlignment: -1,
                    backgroundColor: navigationBackgroundColor,
                    indicatorColor: indicatorColor,
                    leading: railLeading,
                    trailing: railTrailing,
                    destinations: railDestinations
                        .map(
                          (destination) => NavigationRailDestination(
                            icon: destination.icon,
                            selectedIcon:
                                destination.selectedIcon ?? destination.icon,
                            label: Text(destination.label),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _ConstrainedMarketplaceBody(
                      availableWidth: _contentWidthAfterRail(
                        availableWidth,
                        extendRail,
                      ),
                      child: body,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          key: scaffoldKey,
          backgroundColor: backgroundColor,
          appBar: _buildAppBar(context, showMenuButton: drawer != null),
          drawer: drawer,
          body: SafeArea(
            child: _ConstrainedMarketplaceBody(
              availableWidth: availableWidth,
              child: body,
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: NavigationBar(
              backgroundColor: navigationBackgroundColor,
              indicatorColor: indicatorColor,
              selectedIndex: _selectedDestinationIndex(
                    compactDestinations,
                  ) ??
                  0,
              onDestinationSelected: (index) => onDestinationSelected(
                compactDestinations[index].pageIndex,
              ),
              destinations: compactDestinations
                  .map(
                    (destination) => NavigationDestination(
                      icon: destination.icon,
                      selectedIcon:
                          destination.selectedIcon ?? destination.icon,
                      label: destination.label,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(
    BuildContext context, {
    required bool showMenuButton,
  }) {
    return AppBar(
      backgroundColor: navigationBackgroundColor,
      surfaceTintColor: navigationBackgroundColor,
      elevation: 0,
      leading: showMenuButton
          ? IconButton(
              tooltip: 'Open navigation',
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            )
          : null,
      automaticallyImplyLeading: false,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      actions: actions,
    );
  }

  int? _selectedDestinationIndex(
    List<MarketplaceShellDestination> destinations,
  ) {
    final index = destinations.indexWhere(
      (destination) => destination.pageIndex == selectedPageIndex,
    );
    return index < 0 ? null : index;
  }

  double _contentWidthAfterRail(double availableWidth, bool extended) {
    const collapsedRailWidth = 80.0;
    const extendedRailWidth = 256.0;
    final width = availableWidth -
        (extended ? extendedRailWidth : collapsedRailWidth) -
        1;
    return width <= 0 ? availableWidth : width;
  }
}

class _ConstrainedMarketplaceBody extends StatelessWidget {
  const _ConstrainedMarketplaceBody({
    required this.availableWidth,
    required this.child,
  });

  final double availableWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final contentWidth =
        MarketplaceAdaptiveLayout.constrainedContentWidth(availableWidth);
    if (contentWidth <= 0) return child;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
