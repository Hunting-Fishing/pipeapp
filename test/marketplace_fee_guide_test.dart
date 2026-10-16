import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_fee_guide.dart';

void main() {
  test('public fee catalog parses the sale-only USD schedule', () {
    final catalog = MarketplaceFeeCatalog.fromMap({
      'scheduleRevision': marketplaceFeeScheduleRevision,
      'feePayer': 'seller',
      'collectionTiming': 'sale_payment',
      'listingFeeByCurrency': {
        'USD': {'minor': 0, 'amount': 0},
      },
      'pipe': {
        'unitFeeByCurrency': {
          'USD': {'minor': 100, 'amount': 1},
        },
        'percentageCap': 3,
        'maximumFeeByCurrency': {
          'USD': {'minor': 225000, 'amount': 2250},
        },
      },
      'equipment': {
        'minimumFeeByCurrency': {
          'USD': {'minor': 100, 'amount': 1},
        },
        'maximumFeeByCurrency': {
          'USD': {'minor': 250000, 'amount': 2500},
        },
        'brackets': [
          {'upToExclusive': 5000, 'feePercent': 3},
          {'upToExclusive': 25000, 'feePercent': 2.5},
          {'upToExclusive': 100000, 'feePercent': 2},
          {'upToExclusive': 250000, 'feePercent': 1.5},
          {'upToExclusive': null, 'feePercent': 1},
        ],
      },
    });

    expect(catalog.revision, marketplaceFeeScheduleRevision);
    expect(catalog.listingFee, 0);
    expect(catalog.pipeUnitFee, 1);
    expect(catalog.pipePercentageCap, 3);
    expect(catalog.pipeMaximumFee, 2250);
    expect(catalog.equipmentMinimumFee, 1);
    expect(catalog.equipmentMaximumFee, 2500);
    expect(
      catalog.brackets.map((bracket) => bracket.percentage),
      [3, 2.5, 2, 1.5, 1],
    );
  });

  test('equipment examples are calculated from the parsed marginal schedule',
      () {
    final catalog = MarketplaceFeeCatalog.fallback;

    expect(catalog.equipmentFeeFor(5000), 150);
    expect(catalog.equipmentFeeFor(25000), 650);
    expect(catalog.equipmentFeeFor(100000), 2150);
    expect(catalog.equipmentFeeFor(250000), 2500);
    expect(catalog.equipmentFeeFor(.5), .5);
    expect(catalog.equipmentFeeFor(0), 0);
  });

  test('fallback fee guide is clearly marked as locally cached', () {
    expect(MarketplaceFeeCatalog.fallback.verified, isFalse);
    expect(
      MarketplaceFeeCatalog.fallback.revision,
      marketplaceFeeScheduleRevision,
    );
  });
}
