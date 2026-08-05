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
/// the future adaptive navigation shell from drifting onto incompatible
/// breakpoints. Invalid dimensions always fail safely to the compact layout.
abstract final class MarketplaceAdaptiveLayout {
  static const double compactBreakpoint = 600;
  static const double mediumBreakpoint = 900;
  static const double expandedBreakpoint = 1200;
  static const double maxContentWidth = 1440;

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

  static double constrainedContentWidth(double availableWidth) {
    if (!availableWidth.isFinite || availableWidth <= 0) return 0;
    return math.min(availableWidth, maxContentWidth);
  }
}
