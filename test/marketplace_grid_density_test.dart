import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_grid_density.dart';

void main() {
  group('MarketplaceGridDensityBar Unit Tests', () {
    test('resolves auto columns based on screen width', () {
      expect(MarketplaceGridDensityBar.resolveColumns(1400, 0), 4);
      expect(MarketplaceGridDensityBar.resolveColumns(900, 0), 3);
      expect(MarketplaceGridDensityBar.resolveColumns(600, 0), 2);
      expect(MarketplaceGridDensityBar.resolveColumns(400, 0), 1);
    });

    test('respects explicit forced preferences clamped safely to screen width', () {
      expect(MarketplaceGridDensityBar.resolveColumns(1400, 1), 1);
      expect(MarketplaceGridDensityBar.resolveColumns(1400, 2), 2);
      expect(MarketplaceGridDensityBar.resolveColumns(1400, 3), 3);
      expect(MarketplaceGridDensityBar.resolveColumns(1400, 4), 4);
      expect(MarketplaceGridDensityBar.resolveColumns(300, 4), 1); // safe fallback on narrow mobile
    });
  });
}
