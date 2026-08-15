import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MarketplaceWindowClass {
  compact,
  medium,
  expanded,
  wide,
}

/// Shared responsive policy for Pipe Buyer marketplace surfaces.
///
/// Keeping these decisions in one place prevents Browse, Auctions, Home and
/// the adaptive navigation shell from drifting onto incompatible breakpoints.
/// Invalid dimensions always fail safely to the compact layout.
abstract final class MarketplaceAdaptiveLayout {
  static const double compactBreakpoint = 600;
  static const double mediumBreakpoint = 900;
  static const double expandedBreakpoint = 1200;
  static const double maxContentWidth = 1440;

  /// Target width for image-led Marketplace cards. The existing 1/2/3/4
  /// density policy is retained, while new surfaces can use this value when
  /// calculating flexible Wrap/Grid layouts.
  static const double preferredListingCardWidth = 310;
  static const double minimumListingCardWidth = 268;
  static const double preferredSidebarWidth = 340;

  static MarketplaceWindowClass windowClassFor(double availableWidth) {
    if (!availableWidth.isFinite || availableWidth <= 0) {
      return MarketplaceWindowClass.compact;
    }
    if (availableWidth >= expandedBreakpoint) {
      return MarketplaceWindowClass.wide;
    }
    if (availableWidth >= mediumBreakpoint) {
      return MarketplaceWindowClass.expanded;
    }
    if (availableWidth >= compactBreakpoint) {
      return MarketplaceWindowClass.medium;
    }
    return MarketplaceWindowClass.compact;
  }

  static bool useNavigationRail(double availableWidth) =>
      windowClassFor(availableWidth).index >=
      MarketplaceWindowClass.expanded.index;

  static bool extendNavigationRail(double availableWidth) =>
      windowClassFor(availableWidth) == MarketplaceWindowClass.wide;

  static int maxGridColumns(double availableWidth) =>
      switch (windowClassFor(availableWidth)) {
        MarketplaceWindowClass.compact => 1,
        MarketplaceWindowClass.medium => 2,
        MarketplaceWindowClass.expanded => 3,
        MarketplaceWindowClass.wide => 4,
      };

  static int homeActionColumns(double availableWidth, int actionCount) {
    if (actionCount <= 0) return 0;
    final maximum = switch (windowClassFor(availableWidth)) {
      MarketplaceWindowClass.compact => 1,
      MarketplaceWindowClass.medium => 2,
      MarketplaceWindowClass.expanded => 3,
      MarketplaceWindowClass.wide => 4,
    };
    return actionCount.clamp(1, maximum).toInt();
  }

  static EdgeInsets pagePadding(double availableWidth) =>
      switch (windowClassFor(availableWidth)) {
        MarketplaceWindowClass.compact =>
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        MarketplaceWindowClass.medium =>
          const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        MarketplaceWindowClass.expanded =>
          const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        MarketplaceWindowClass.wide =>
          const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      };

  /// Gap between image-led cards and layout regions.
  static double contentGap(double availableWidth) =>
      switch (windowClassFor(availableWidth)) {
        MarketplaceWindowClass.compact => 12,
        MarketplaceWindowClass.medium => 14,
        MarketplaceWindowClass.expanded => 16,
        MarketplaceWindowClass.wide => 18,
      };

  /// Suggested hero height for industrial image/artwork-led page headers.
  static double heroHeight(double availableWidth) =>
      switch (windowClassFor(availableWidth)) {
        MarketplaceWindowClass.compact => 230,
        MarketplaceWindowClass.medium => 250,
        MarketplaceWindowClass.expanded => 270,
        MarketplaceWindowClass.wide => 290,
      };

  /// True when a detail surface has room for primary content and a persistent
  /// transaction/trust sidebar without squeezing either region.
  static bool useDetailSidebar(double availableWidth) =>
      availableWidth.isFinite && availableWidth >= 1040;

  /// Width of a desktop detail sidebar, capped so the main listing imagery and
  /// technical specifications remain the visual focus.
  static double detailSidebarWidth(double availableWidth) {
    if (!useDetailSidebar(availableWidth)) return 0;
    return math.min(preferredSidebarWidth, availableWidth * .30);
  }

  /// Calculates a readable card width using the established density policy.
  /// New grids can use this instead of hard-coded ratios so photos remain large
  /// enough to identify industrial equipment and tubular inventory.
  static double listingCardWidth(
    double availableWidth, {
    int? columns,
    double? gap,
  }) {
    if (!availableWidth.isFinite || availableWidth <= 0) return 0;
    final resolvedColumns =
        (columns ?? maxGridColumns(availableWidth)).clamp(1, 4).toInt();
    final resolvedGap = gap ?? contentGap(availableWidth);
    final width =
        (availableWidth - resolvedGap * (resolvedColumns - 1)) / resolvedColumns;
    return math.max(minimumListingCardWidth, width);
  }

  static double constrainedContentWidth(double availableWidth) {
    if (!availableWidth.isFinite || availableWidth <= 0) return 0;
    return math.min(availableWidth, maxContentWidth);
  }
}
