import 'package:cloud_firestore/cloud_firestore.dart';

enum MarketplaceOfferBand { green, yellow, orange, red }

enum MarketplaceOfferTruckingFilter {
  all,
  buyerArranged,
  dispatchRequested,
  dispatchConfirmed,
  sellerArranged,
}

class MarketplaceOfferRankingInput {
  const MarketplaceOfferRankingInput({
    required this.offerId,
    required this.data,
    this.dispatchStatus = '',
  });

  final String offerId;
  final Map<String, dynamic> data;
  final String dispatchStatus;
}

class MarketplaceBuyerListingOfferSummary {
  const MarketplaceBuyerListingOfferSummary({
    required this.listingId,
    required this.sellerUid,
    required this.history,
    required this.submittedByBuyer,
  });

  final String listingId;
  final String sellerUid;
  final List<MarketplaceOfferRankingInput> history;
  final List<MarketplaceOfferRankingInput> submittedByBuyer;

  MarketplaceOfferRankingInput get latestUpdate => history.first;
  MarketplaceOfferRankingInput get latestSubmitted => submittedByBuyer.first;
  int get submittedCount => submittedByBuyer.length;
  DateTime? get lastSubmittedAt => marketplaceOfferRankingDate(
        latestSubmitted.data['createdAt'],
      );
}

List<MarketplaceBuyerListingOfferSummary> summarizeMarketplaceBuyerOffers({
  required List<MarketplaceOfferRankingInput> offers,
  required String buyerUid,
}) {
  final grouped = <String, List<MarketplaceOfferRankingInput>>{};
  for (final offer in offers) {
    final data = offer.data;
    final listingId = '${data['listingId'] ?? ''}'.trim();
    if (listingId.isEmpty || '${data['buyerUid'] ?? ''}' != buyerUid) continue;
    grouped.putIfAbsent(listingId, () => []).add(offer);
  }

  final summaries = <MarketplaceBuyerListingOfferSummary>[];
  for (final entry in grouped.entries) {
    final history = entry.value.toList()
      ..sort((left, right) =>
          _createdAtMillis(right.data).compareTo(_createdAtMillis(left.data)));
    final submitted = history
        .where((offer) => '${offer.data['proposedByUid'] ?? ''}' == buyerUid)
        .toList();
    if (submitted.isEmpty) continue;
    summaries.add(MarketplaceBuyerListingOfferSummary(
      listingId: entry.key,
      sellerUid: '${history.first.data['sellerUid'] ?? ''}',
      history: history,
      submittedByBuyer: submitted,
    ));
  }
  summaries.sort((left, right) =>
      (right.lastSubmittedAt?.millisecondsSinceEpoch ?? 0)
          .compareTo(left.lastSubmittedAt?.millisecondsSinceEpoch ?? 0));
  return summaries;
}

class MarketplaceOfferRank {
  const MarketplaceOfferRank({
    required this.input,
    required this.rank,
    required this.score,
    required this.band,
    required this.offeredUnitPrice,
    required this.offeredTotal,
    required this.percentOffAsking,
    required this.pickupDays,
    required this.paymentDays,
    required this.bestOverall,
    required this.bestPrice,
    required this.soonestPickup,
    required this.soonestPayment,
    required this.dispatchConfirmed,
  });

  final MarketplaceOfferRankingInput input;
  final int rank;
  final double score;
  final MarketplaceOfferBand band;
  final double offeredUnitPrice;
  final double offeredTotal;
  final double? percentOffAsking;
  final int? pickupDays;
  final int? paymentDays;
  final bool bestOverall;
  final bool bestPrice;
  final bool soonestPickup;
  final bool soonestPayment;
  final bool dispatchConfirmed;

  MarketplaceOfferRank copyWith({int? rank, bool? bestOverall}) =>
      MarketplaceOfferRank(
        input: input,
        rank: rank ?? this.rank,
        score: score,
        band: band,
        offeredUnitPrice: offeredUnitPrice,
        offeredTotal: offeredTotal,
        percentOffAsking: percentOffAsking,
        pickupDays: pickupDays,
        paymentDays: paymentDays,
        bestOverall: bestOverall ?? this.bestOverall,
        bestPrice: bestPrice,
        soonestPickup: soonestPickup,
        soonestPayment: soonestPayment,
        dispatchConfirmed: dispatchConfirmed,
      );
}

class MarketplaceOfferRankingFilters {
  const MarketplaceOfferRankingFilters({
    this.minimumPercentOff = 0,
    this.maximumPercentOff = 100,
    this.pickupFrom,
    this.pickupTo,
    this.trucking = MarketplaceOfferTruckingFilter.all,
  });

  final double minimumPercentOff;
  final double maximumPercentOff;
  final DateTime? pickupFrom;
  final DateTime? pickupTo;
  final MarketplaceOfferTruckingFilter trucking;

  bool get hasPriceFilter => minimumPercentOff > 0 || maximumPercentOff < 100;

  bool get hasPickupFilter => pickupFrom != null || pickupTo != null;

  bool get hasActiveFilters =>
      hasPriceFilter ||
      hasPickupFilter ||
      trucking != MarketplaceOfferTruckingFilter.all;

  bool matches(MarketplaceOfferRank offer) {
    final percentOff = offer.percentOffAsking;
    if (hasPriceFilter &&
        (percentOff == null ||
            percentOff < minimumPercentOff ||
            percentOff > maximumPercentOff)) {
      return false;
    }
    final pickupDate = marketplaceOfferRankingDate(
      offer.input.data['truckingDate'],
    );
    if (hasPickupFilter && pickupDate == null) return false;
    if (pickupFrom != null &&
        _dateOnly(pickupDate!).isBefore(_dateOnly(pickupFrom!))) {
      return false;
    }
    if (pickupTo != null &&
        _dateOnly(pickupDate!).isAfter(_dateOnly(pickupTo!))) {
      return false;
    }
    final plan = '${offer.input.data['truckingPlan'] ?? ''}';
    return switch (trucking) {
      MarketplaceOfferTruckingFilter.all => true,
      MarketplaceOfferTruckingFilter.buyerArranged => plan == 'buyer_arranged',
      MarketplaceOfferTruckingFilter.dispatchRequested =>
        plan == 'request_dispatch',
      MarketplaceOfferTruckingFilter.dispatchConfirmed =>
        plan == 'request_dispatch' && offer.dispatchConfirmed,
      MarketplaceOfferTruckingFilter.sellerArranged => plan == 'seller_pickup',
    };
  }
}

DateTime? marketplaceOfferRankingDate(dynamic value) => switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime date => date,
      int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),
      _ => null,
    };

bool marketplaceDispatchIsConfirmed(String status) => const {
      'accepted',
      'scheduled',
      'in_transit',
      'delivered',
      'completed',
      'closed',
    }.contains(status.trim().toLowerCase());

List<MarketplaceOfferRank> rankMarketplaceOffers({
  required List<MarketplaceOfferRankingInput> offers,
  required DateTime now,
  num? askingUnitPrice,
}) {
  if (offers.isEmpty) return const [];
  final asking = (askingUnitPrice ?? 0).toDouble();
  final prices = offers.map(_unitPrice).toList();
  final maximumPrice =
      prices.reduce((left, right) => left > right ? left : right);
  final pickupDates = offers
      .map((offer) => marketplaceOfferRankingDate(offer.data['truckingDate']))
      .whereType<DateTime>()
      .toList();
  final paymentDates = offers
      .map((offer) =>
          marketplaceOfferRankingDate(offer.data['moneyTransferDate']))
      .whereType<DateTime>()
      .toList();
  final earliestPickup = pickupDates.isEmpty
      ? null
      : pickupDates
          .reduce((left, right) => left.isBefore(right) ? left : right);
  final earliestPayment = paymentDates.isEmpty
      ? null
      : paymentDates
          .reduce((left, right) => left.isBefore(right) ? left : right);

  final ranked = <MarketplaceOfferRank>[];
  for (final offer in offers) {
    final price = _unitPrice(offer);
    final total = _total(offer);
    final pickup = marketplaceOfferRankingDate(offer.data['truckingDate']);
    final payment =
        marketplaceOfferRankingDate(offer.data['moneyTransferDate']);
    final pickupDays = _daysFrom(now, pickup);
    final paymentDays = _daysFrom(now, payment);
    final confirmed = marketplaceDispatchIsConfirmed(offer.dispatchStatus);
    final priceRatio = asking > 0
        ? price / asking
        : maximumPrice <= 0
            ? 0.0
            : price / maximumPrice;
    final priceScore = priceRatio.clamp(0.0, 1.0) * 50;
    final score = priceScore +
        _dateScore(paymentDays) +
        _dateScore(pickupDays) +
        _truckingScore(
          '${offer.data['truckingPlan'] ?? ''}',
          confirmed: confirmed,
        );
    ranked.add(MarketplaceOfferRank(
      input: offer,
      rank: 0,
      score: score,
      band: _bandFor(score),
      offeredUnitPrice: price,
      offeredTotal: total,
      percentOffAsking:
          asking <= 0 ? null : ((asking - price) / asking * 100).clamp(0, 100),
      pickupDays: pickupDays,
      paymentDays: paymentDays,
      bestOverall: false,
      bestPrice: price == maximumPrice,
      soonestPickup: pickup != null &&
          earliestPickup != null &&
          _dateOnly(pickup) == _dateOnly(earliestPickup),
      soonestPayment: payment != null &&
          earliestPayment != null &&
          _dateOnly(payment) == _dateOnly(earliestPayment),
      dispatchConfirmed: confirmed,
    ));
  }
  ranked.sort((left, right) {
    var comparison = right.score.compareTo(left.score);
    if (comparison != 0) return comparison;
    comparison = right.offeredUnitPrice.compareTo(left.offeredUnitPrice);
    if (comparison != 0) return comparison;
    comparison = _nullableDays(left.paymentDays, right.paymentDays);
    if (comparison != 0) return comparison;
    comparison = _nullableDays(left.pickupDays, right.pickupDays);
    if (comparison != 0) return comparison;
    return _createdAtMillis(left.input.data)
        .compareTo(_createdAtMillis(right.input.data));
  });
  return [
    for (var index = 0; index < ranked.length; index++)
      ranked[index].copyWith(rank: index + 1, bestOverall: index == 0),
  ];
}

double _unitPrice(MarketplaceOfferRankingInput offer) =>
    (offer.data['offeredUnitPrice'] as num? ?? 0).toDouble();

double _total(MarketplaceOfferRankingInput offer) {
  final price = _unitPrice(offer);
  final quantity = (offer.data['requestedQuantity'] as num? ?? 0).toDouble();
  return (offer.data['offeredTotal'] as num? ?? price * quantity).toDouble();
}

int? _daysFrom(DateTime now, DateTime? value) {
  if (value == null) return null;
  final difference = _dateOnly(value).difference(_dateOnly(now)).inDays;
  return difference < 0 ? 0 : difference;
}

double _dateScore(int? days) {
  if (days == null) return 0;
  if (days <= 3) return 20;
  if (days <= 7) return 18;
  if (days <= 14) return 15;
  if (days <= 30) return 11;
  if (days <= 60) return 6;
  return 3;
}

double _truckingScore(String plan, {required bool confirmed}) => switch (plan) {
      'buyer_arranged' => 10,
      'request_dispatch' when confirmed => 9,
      'seller_pickup' => 6,
      'request_dispatch' => 4,
      _ => 0,
    };

MarketplaceOfferBand _bandFor(double score) {
  if (score >= 80) return MarketplaceOfferBand.green;
  if (score >= 65) return MarketplaceOfferBand.yellow;
  if (score >= 45) return MarketplaceOfferBand.orange;
  return MarketplaceOfferBand.red;
}

int _nullableDays(int? left, int? right) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return left.compareTo(right);
}

int _createdAtMillis(Map<String, dynamic> data) =>
    marketplaceOfferRankingDate(data['createdAt'])?.millisecondsSinceEpoch ?? 0;

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
