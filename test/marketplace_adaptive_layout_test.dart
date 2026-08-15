import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_adaptive_layout.dart';

void main() {
  group('MarketplaceAdaptiveLayout', () {
    test('classifies compact, medium, expanded, and wide boundaries', () {
      expect(
        MarketplaceAdaptiveLayout.windowClassFor(390),
        MarketplaceWindowClass.compact,
      );
      expect(
        MarketplaceAdaptiveLayout.windowClassFor(599),
        MarketplaceWindowClass.compact,
      );
      expect(
        MarketplaceAdaptiveLayout.windowClassFor(600),
        MarketplaceWindowClass.medium,
      );
      expect(
        MarketplaceAdaptiveLayout.windowClassFor(899),
        MarketplaceWindowClass.medium,
      );
      expect(
        MarketplaceAdaptiveLayout.windowClassFor(900),
        MarketplaceWindowClass.expanded,
      );
      expect(
        MarketplaceAdaptiveLayout.windowClassFor(1199),
        MarketplaceWindowClass.expanded,
      );
      expect(
        MarketplaceAdaptiveLayout.windowClassFor(1200),
        MarketplaceWindowClass.wide,
      );
    });

    test('fails invalid dimensions safely to compact behavior', () {
      for (final width in [0.0, -20.0, double.nan, double.infinity]) {
        expect(
          MarketplaceAdaptiveLayout.windowClassFor(width),
          MarketplaceWindowClass.compact,
        );
        expect(MarketplaceAdaptiveLayout.maxGridColumns(width), 1);
        expect(MarketplaceAdaptiveLayout.useNavigationRail(width), isFalse);
      }
      expect(MarketplaceAdaptiveLayout.constrainedContentWidth(-1), 0);
      expect(MarketplaceAdaptiveLayout.constrainedContentWidth(double.nan), 0);
      expect(MarketplaceAdaptiveLayout.listingCardWidth(-1), 0);
    });

    test('uses a rail only when the content area is genuinely expanded', () {
      expect(MarketplaceAdaptiveLayout.useNavigationRail(899), isFalse);
      expect(MarketplaceAdaptiveLayout.useNavigationRail(900), isTrue);
      expect(MarketplaceAdaptiveLayout.extendNavigationRail(1199), isFalse);
      expect(MarketplaceAdaptiveLayout.extendNavigationRail(1200), isTrue);
    });

    test('keeps grid and action densities readable', () {
      expect(MarketplaceAdaptiveLayout.maxGridColumns(390), 1);
      expect(MarketplaceAdaptiveLayout.maxGridColumns(700), 2);
      expect(MarketplaceAdaptiveLayout.maxGridColumns(1000), 3);
      expect(MarketplaceAdaptiveLayout.maxGridColumns(1400), 4);

      expect(MarketplaceAdaptiveLayout.homeActionColumns(390, 4), 1);
      expect(MarketplaceAdaptiveLayout.homeActionColumns(700, 4), 2);
      expect(MarketplaceAdaptiveLayout.homeActionColumns(1000, 4), 3);
      expect(MarketplaceAdaptiveLayout.homeActionColumns(1400, 4), 4);
      expect(MarketplaceAdaptiveLayout.homeActionColumns(1400, 2), 2);
      expect(MarketplaceAdaptiveLayout.homeActionColumns(1400, 0), 0);
    });

    test('caps desktop content and increases page padding deliberately', () {
      expect(MarketplaceAdaptiveLayout.constrainedContentWidth(900), 900);
      expect(MarketplaceAdaptiveLayout.constrainedContentWidth(1800), 1440);

      expect(MarketplaceAdaptiveLayout.pagePadding(390).left, 16);
      expect(MarketplaceAdaptiveLayout.pagePadding(700).left, 24);
      expect(MarketplaceAdaptiveLayout.pagePadding(1000).left, 32);
      expect(MarketplaceAdaptiveLayout.pagePadding(1400).left, 40);
    });

    test('supports image-led hero and detail layouts', () {
      expect(MarketplaceAdaptiveLayout.heroHeight(390), 230);
      expect(MarketplaceAdaptiveLayout.heroHeight(700), 250);
      expect(MarketplaceAdaptiveLayout.heroHeight(1000), 270);
      expect(MarketplaceAdaptiveLayout.heroHeight(1400), 290);

      expect(MarketplaceAdaptiveLayout.useDetailSidebar(900), isFalse);
      expect(MarketplaceAdaptiveLayout.useDetailSidebar(1040), isTrue);
      expect(MarketplaceAdaptiveLayout.detailSidebarWidth(900), 0);
      expect(MarketplaceAdaptiveLayout.detailSidebarWidth(1200), 340);
    });

    test('calculates readable listing card widths', () {
      expect(MarketplaceAdaptiveLayout.listingCardWidth(390), 390);
      expect(MarketplaceAdaptiveLayout.listingCardWidth(700), 343);
      expect(
        MarketplaceAdaptiveLayout.listingCardWidth(1000),
        closeTo(322.666, .01),
      );
      expect(MarketplaceAdaptiveLayout.listingCardWidth(1400), 336.5);
      expect(
        MarketplaceAdaptiveLayout.listingCardWidth(600, columns: 4),
        MarketplaceAdaptiveLayout.minimumListingCardWidth,
      );
    });
  });
}
