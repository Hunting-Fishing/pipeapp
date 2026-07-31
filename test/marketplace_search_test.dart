import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_search.dart';

void main() {
  test('search queries use the same bounded industrial prefix shape', () {
    expect(
      normalizeMarketplaceSearchQuery('  CAT-320 Hydraulic Excavator extra '),
      'cat 320 hydraulic',
    );
    expect(normalizeMarketplaceSearchQuery('x'), isEmpty);
    expect(normalizeMarketplaceSearchQuery('Drill Pipe'), 'drill pipe');
    expect(
        normalizeMarketplaceSearchQuery('Montréal, Québec'), 'montreal quebec');
    expect(normalizeMarketplaceSearchQuery('México'), 'mexico');
  });

  test('server search reloads only when the normalized token changes', () {
    expect(marketplaceSearchNeedsServerReload('drill-pipe', 'Drill pipe'),
        isFalse);
    expect(marketplaceSearchNeedsServerReload('drill', 'drill pipe'), isTrue);
  });
}
