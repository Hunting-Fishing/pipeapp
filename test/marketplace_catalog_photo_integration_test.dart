import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const sourcePath = 'lib/marketplace/oil_gas_marketplace.dart';

  test('Marketplace photographic resolver is wired into catalog UI', () {
    final source = File(sourcePath).readAsStringSync();

    expect(
      source,
      contains("import 'marketplace_catalog_photo_assets.dart';"),
    );

    expect(
      source,
      matches(
        RegExp(
          r'MarketplaceCatalogPhotoAssets\.forProductType\(\s*'
          r'fallbackLabel,\s*label\)',
        ),
      ),
      reason:
          'CatalogIcon must resolve product photos using category + product type.',
    );

    expect(
      source,
      matches(
        RegExp(
          r'MarketplaceCatalogPhotoAssets\.forCategory\(\s*label\s*\)',
        ),
      ),
      reason: 'Catalog category selectors must use photographic artwork.',
    );

    expect(
      source,
      matches(
        RegExp(
          r'CatalogIcon\(\s*'
          r'label:\s*item,\s*'
          r'fallbackLabel:\s*_category,\s*'
          r'size:\s*20',
        ),
      ),
      reason:
          'Browse product choices must pass category context to CatalogIcon.',
    );
  });

  test('listing fallbacks use exact category and product type', () {
    final source = File(sourcePath).readAsStringSync();

    final matches = RegExp(
      r'MarketplaceCatalogPhotoAssets\.forProductType\(\s*'
      r'listing\.category,\s*listing\.productType\)',
    ).allMatches(source);

    expect(
      matches.length,
      greaterThanOrEqualTo(2),
      reason:
          'Both listing cards and listing details must use exact product photos.',
    );

    expect(
      source,
      contains('IndustrialIconAssets.wantedEquipment'),
      reason: 'Wanted listings must retain dedicated Wanted artwork.',
    );
  });

  test('Marketplace workflow navigation artwork stays separate', () {
    final source = File(sourcePath).readAsStringSync();

    for (final workflow in const [
      'Browse',
      'Sell',
      'Auctions',
      'Dispatch',
    ]) {
      expect(
        source,
        contains("IndustrialIconAssets.forLabel('$workflow')"),
        reason:
            '$workflow workflow artwork must remain outside the catalog-photo resolver.',
      );
    }
  });
}
