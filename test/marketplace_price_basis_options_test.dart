import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/oil_gas_marketplace.dart';

void main() {
  test('sale and Timed Buying selectors expose only settleable price bases',
      () {
    expect(
      marketplacePriceBasisOptionsFor(
        category: 'Pipe, Tubing & Materials',
        productType: 'Drill Pipe',
        wanted: false,
      ),
      const ['Per piece', 'Per joint', 'Total for all'],
    );
    expect(
      marketplacePriceBasisOptionsFor(
        category: 'Heavy Equipment',
        productType: 'Excavator',
        wanted: false,
      ),
      const ['Total asking price', 'Price per machine'],
    );
    expect(
      marketplacePriceBasisOptionsFor(
        category: 'Site & Property',
        productType: 'Industrial Real Estate',
        wanted: false,
      ),
      const ['Total asking price'],
    );
    expect(
      marketplacePriceBasisOptionsFor(
        category: 'Tanks & Containers',
        productType: 'Storage Tank',
        wanted: false,
      ),
      const ['Total asking price', 'Per item'],
    );

    const unsafeForLaunch = {
      'Per foot',
      'Per metre',
      'Per acre',
      'Per hectare',
      'Per bundle',
      'Monthly lease',
      'Annual lease',
      'Call for price',
    };
    for (final category in const [
      'Pipe, Tubing & Materials',
      'Heavy Equipment',
      'Site & Property',
      'Tanks & Containers',
    ]) {
      final options = marketplacePriceBasisOptionsFor(
        category: category,
        productType: null,
        wanted: false,
      );
      expect(options.toSet().intersection(unsafeForLaunch), isEmpty);
    }
  });

  test('Wanted Ads retain broader discovery price labels', () {
    final pipeOptions = marketplacePriceBasisOptionsFor(
      category: 'Pipe, Tubing & Materials',
      productType: 'Casing',
      wanted: true,
    );
    expect(pipeOptions, containsAll(['Per foot', 'Per metre', 'Per bundle']));
    expect(pipeOptions, contains('Call for price'));

    final propertyOptions = marketplacePriceBasisOptionsFor(
      category: 'Site & Property',
      productType: 'Industrial Real Estate',
      wanted: true,
    );
    expect(
      propertyOptions,
      containsAll(['Per acre', 'Per hectare', 'Monthly lease', 'Annual lease']),
    );
  });

  test('publication uses the displayed launch-safe fallback basis', () {
    final source =
        File('lib/marketplace/oil_gas_marketplace.dart').readAsStringSync();

    expect(source, contains("'priceBasis': effectivePriceBasis"));
    expect(
      source,
      contains('supportedPriceBases.contains(_priceBasis)'),
    );
  });
}
