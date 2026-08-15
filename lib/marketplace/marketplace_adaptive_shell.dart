import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
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
    this.railFooter,
    this.expandedRailNavigation,
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
  final Widget? railFooter;
  final Widget? expandedRailNavigation;
  final Color? backgroundColor;
  final Color? navigationBackgroundColor;
  final Color? indicatorColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackground =
        backgroundColor ?? theme.scaffoldBackgroundColor;
    final effectiveNavigation =
        navigationBackgroundColor ?? theme.colorScheme.surface;
    final effectiveIndicator = indicatorColor ?? PipeBuyerColors.orangeSoft;
    final navigationBorder = theme.dividerColor;

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
            backgroundColor: effectiveBackground,
            appBar: _buildAppBar(context, showMenuButton: false),
            body: SafeArea(
              child: Row(
                children: [
                  Container(
                    width: extendRail ? 268 : 82,
                    decoration: BoxDecoration(
                      color: effectiveNavigation,
                      border: Border(
                        right: BorderSide(color: navigationBorder),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 18,
                          offset: Offset(7, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: extendRail && expandedRailNavigation != null
                              ? expandedRailNavigation!
                              : NavigationRailTheme(
                                  data: NavigationRailThemeData(
                                    backgroundColor: Colors.transparent,
                                    indicatorColor: effectiveIndicator,
                                    selectedIconTheme: const IconThemeData(
                                      color: PipeBuyerColors.orangePressed,
                                      size: 24,
                                    ),
                                    unselectedIconTheme: IconThemeData(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: .58),
                                      size: 22,
                                    ),
                                    selectedLabelTextStyle:
                                        theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    unselectedLabelTextStyle:
                                        theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: .60),
                                    ),
                                  ),
                                  child: NavigationRail(
                                    selectedIndex: _selectedDestinationIndex(
                                      railDestinations,
                                    ),
                                    onDestinationSelected: (index) =>
                                        onDestinationSelected(
                                      railDestinations[index].pageIndex,
                                    ),
                                    extended: extendRail,
                                    scrollable: true,
                                    groupAlignment: -1,
                                    minWidth: 82,
                                    minExtendedWidth: 268,
                                    backgroundColor: Colors.transparent,
                                    indicatorColor: effectiveIndicator,
                                    leading: railLeading ??
                                        _RailBrand(extended: extendRail),
                                    trailing: railTrailing,
                                    destinations: railDestinations
                                        .map(
                                          (destination) =>
                                              NavigationRailDestination(
                                            icon: destination.icon,
                                            selectedIcon:
                                                destination.selectedIcon ??
                                                    destination.icon,
                                            label: Text(destination.label),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                ),
                        ),
                        if (railFooter != null)
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                              child: SizedBox(
                                width: double.infinity,
                                child: railFooter,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _MarketplaceCanvas(
                      backgroundColor: effectiveBackground,
                      child: _ConstrainedMarketplaceBody(
                        availableWidth: _contentWidthAfterRail(
                          availableWidth,
                          extendRail,
                        ),
                        child: body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          key: scaffoldKey,
          backgroundColor: effectiveBackground,
          appBar: _buildAppBar(context, showMenuButton: drawer != null),
          drawer: drawer,
          body: SafeArea(
            child: _MarketplaceCanvas(
              backgroundColor: effectiveBackground,
              child: _ConstrainedMarketplaceBody(
                availableWidth: availableWidth,
                child: body,
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: effectiveNavigation,
                border: Border(
                  top: BorderSide(color: navigationBorder),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x16000000),
                    blurRadius: 18,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: 70,
                  backgroundColor: effectiveNavigation,
                  indicatorColor: effectiveIndicator,
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const IconThemeData(
                        color: PipeBuyerColors.orangePressed,
                        size: 24,
                      );
                    }
                    return IconThemeData(
                      color: theme.colorScheme.onSurface.withValues(alpha: .58),
                      size: 22,
                    );
                  }),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      color: selected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: .58),
                    );
                  }),
                ),
                child: NavigationBar(
                  backgroundColor: effectiveNavigation,
                  indicatorColor: effectiveIndicator,
                  elevation: 0,
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
    final theme = Theme.of(context);
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: theme.appBarTheme.backgroundColor ?? PipeBuyerColors.ink,
      foregroundColor: theme.appBarTheme.foregroundColor ?? Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const Border(
        bottom: BorderSide(color: PipeBuyerColors.orange, width: 2),
      ),
      leading: showMenuButton
          ? IconButton(
              tooltip: 'Open navigation',
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            )
          : null,
      automaticallyImplyLeading: false,
      titleSpacing: showMenuButton ? 4 : 18,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 28,
            decoration: BoxDecoration(
              color: PipeBuyerColors.orange,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.appBarTheme.titleTextStyle ??
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.1,
                  ),
            ),
          ),
        ],
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
    const collapsedRailWidth = 82.0;
    const extendedRailWidth = 268.0;
    final width = availableWidth -
        (extended ? extendedRailWidth : collapsedRailWidth) -
        1;
    return width <= 0 ? availableWidth : width;
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          extended ? 14 : 10,
          10,
          extended ? 14 : 10,
          18,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: extended ? 12 : 8,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: PipeBuyerColors.ink,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: PipeBuyerColors.orange.withValues(alpha: .30),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PipeBuyerColors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'PB',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .2,
                  ),
                ),
              ),
              if (extended) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PIPE BUYER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'INDUSTRIAL MARKETPLACE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _MarketplaceCanvas extends StatelessWidget {
  const _MarketplaceCanvas({
    required this.backgroundColor,
    required this.child,
  });

  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backgroundColor,
              Color.alphaBlend(
                PipeBuyerColors.orange.withValues(alpha: .012),
                backgroundColor,
              ),
            ],
          ),
        ),
        child: child,
      );
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
