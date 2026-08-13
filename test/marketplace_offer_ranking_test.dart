import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_offer_ranking.dart';

void main() {
  final now = DateTime(2026, 8, 13);

  MarketplaceOfferRankingInput offer(
    String id, {
    required num price,
    num quantity = 1,
    DateTime? pickup,
    DateTime? payment,
    String truckingPlan = 'buyer_arranged',
    String dispatchStatus = '',
  }) =>
      MarketplaceOfferRankingInput(
        offerId: id,
        dispatchStatus: dispatchStatus,
        data: {
          'offeredUnitPrice': price,
          'requestedQuantity': quantity,
          'offeredTotal': price * quantity,
          'truckingPlan': truckingPlan,
          if (pickup != null) 'truckingDate': pickup,
          if (payment != null) 'moneyTransferDate': payment,
        },
      );

  test('smart ranking balances price, pickup, payment, and trucking', () {
    final ranked = rankMarketplaceOffers(
      askingUnitPrice: 100,
      now: now,
      offers: [
        offer(
          'complete',
          price: 100,
          pickup: now.add(const Duration(days: 7)),
          payment: now.add(const Duration(days: 5)),
        ),
        offer(
          'fast-lower',
          price: 90,
          pickup: now.add(const Duration(days: 2)),
          payment: now.add(const Duration(days: 2)),
          truckingPlan: 'request_dispatch',
          dispatchStatus: 'accepted',
        ),
        offer('price-only', price: 110),
      ],
    );

    expect(ranked.map((item) => item.input.offerId),
        ['complete', 'fast-lower', 'price-only']);
    expect(ranked.first.bestOverall, isTrue);
    expect(ranked.last.bestPrice, isTrue);
    expect(ranked[1].soonestPickup, isTrue);
    expect(ranked[1].soonestPayment, isTrue);
    expect(ranked[1].dispatchConfirmed, isTrue);
    expect(ranked.first.band, MarketplaceOfferBand.green);
  });

  test('percent-off and pickup filters exclude offers outside the range', () {
    final ranked = rankMarketplaceOffers(
      askingUnitPrice: 100,
      now: now,
      offers: [
        offer('five',
            price: 95,
            pickup: now.add(const Duration(days: 7)),
            payment: now.add(const Duration(days: 3))),
        offer('twenty',
            price: 80,
            pickup: now.add(const Duration(days: 30)),
            payment: now.add(const Duration(days: 3))),
      ],
    );
    final filters = MarketplaceOfferRankingFilters(
      minimumPercentOff: 0,
      maximumPercentOff: 10,
      pickupFrom: now,
      pickupTo: now.add(const Duration(days: 14)),
    );

    expect(
      ranked.where(filters.matches).map((item) => item.input.offerId),
      ['five'],
    );
  });

  test('trucking filters distinguish requested from carrier-confirmed', () {
    final ranked = rankMarketplaceOffers(
      askingUnitPrice: 100,
      now: now,
      offers: [
        offer('arranged', price: 100),
        offer('requested',
            price: 100,
            truckingPlan: 'request_dispatch',
            dispatchStatus: 'open'),
        offer('awarded',
            price: 100,
            truckingPlan: 'request_dispatch',
            dispatchStatus: 'awarded'),
        offer('confirmed',
            price: 100,
            truckingPlan: 'request_dispatch',
            dispatchStatus: 'accepted'),
      ],
    );
    const requested = MarketplaceOfferRankingFilters(
      trucking: MarketplaceOfferTruckingFilter.dispatchRequested,
    );
    const confirmed = MarketplaceOfferRankingFilters(
      trucking: MarketplaceOfferTruckingFilter.dispatchConfirmed,
    );

    expect(ranked.where(requested.matches), hasLength(3));
    expect(ranked.where(confirmed.matches).single.input.offerId, 'confirmed');
    expect(marketplaceDispatchIsConfirmed('awarded'), isFalse);
    expect(marketplaceDispatchIsConfirmed('scheduled'), isTrue);
  });

  test('colour bands communicate strong through incomplete offers', () {
    final ranked = rankMarketplaceOffers(
      askingUnitPrice: 100,
      now: now,
      offers: [
        offer('green',
            price: 100,
            pickup: now.add(const Duration(days: 2)),
            payment: now.add(const Duration(days: 2))),
        offer('yellow',
            price: 80,
            pickup: now.add(const Duration(days: 30)),
            payment: now.add(const Duration(days: 30))),
        offer('orange', price: 100),
        offer('red',
            price: 30,
            truckingPlan: 'request_dispatch',
            dispatchStatus: 'open'),
      ],
    );
    final byId = {for (final item in ranked) item.input.offerId: item.band};
    expect(byId['green'], MarketplaceOfferBand.green);
    expect(byId['yellow'], MarketplaceOfferBand.yellow);
    expect(byId['orange'], MarketplaceOfferBand.orange);
    expect(byId['red'], MarketplaceOfferBand.red);
  });
}
