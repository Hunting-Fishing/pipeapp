import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved quote planner supports listing or standalone source', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_dashboard.dart',
    ).readAsStringSync();

    expect(source, contains("'listing'"));
    expect(source, contains("'standalone'"));
    expect(source, contains("collection('public_listings')"));
    expect(source, contains("where('status', isEqualTo: 'active')"));
    expect(source, contains('selectedListingId'));
    expect(source, contains('listingTitle'));
  });

  test('saved quote planner requires mapped origin and destination', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_dashboard.dart',
    ).readAsStringSync();

    expect(source, contains('MarketplaceLocation? originLocation'));
    expect(source, contains('MarketplaceLocation? destinationLocation'));
    expect(source, contains('MarketplaceLocationPicker.show('));
    expect(source, contains('MarketplaceLocationPicker.showDelivery('));
    expect(source, contains("'originLocation'"));
    expect(source, contains("'destinationLocation'"));
  });

  test('saved quote planner supports ranged multi-unit requirements', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_dashboard.dart',
    ).readAsStringSync();

    expect(source, contains('class _DispatchUnitRequirementDraft'));
    expect(source, contains("'pilot_truck'"));
    expect(source, contains("'hauling_tractor'"));
    expect(source, contains('minQuantity'));
    expect(source, contains('maxQuantity'));
    expect(source, contains("'requestedUnits'"));
    expect(source, contains("'requirementsVersion': 1"));
  });

  test('master plan locks source and requested-unit model for Phase 5', () {
    final plan = File('docs/DISPATCH_NETWORK_MASTER_PLAN.md').readAsStringSync();

    expect(plan, contains('requestedUnits[]'));
    expect(plan, contains('Select Marketplace listing'));
    expect(plan, contains('Custom / standalone job'));
  });
}
