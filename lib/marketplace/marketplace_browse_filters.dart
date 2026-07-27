enum MarketplaceBrowseSort {
  newest,
  priceLowToHigh,
  priceHighToLow,
}

class MarketplaceBrowseFilters {
  const MarketplaceBrowseFilters({
    this.transactionType,
    this.condition,
    this.minimumPrice,
    this.maximumPrice,
    this.sort = MarketplaceBrowseSort.newest,
  });

  final String? transactionType;
  final String? condition;
  final double? minimumPrice;
  final double? maximumPrice;
  final MarketplaceBrowseSort sort;

  bool get hasPriceRange => minimumPrice != null || maximumPrice != null;

  MarketplaceBrowseSort get effectiveSort =>
      hasPriceRange && sort == MarketplaceBrowseSort.newest
          ? MarketplaceBrowseSort.priceLowToHigh
          : sort;

  int get activeCount => <bool>[
        transactionType != null,
        condition != null,
        minimumPrice != null,
        maximumPrice != null,
        sort != MarketplaceBrowseSort.newest,
      ].where((active) => active).length;

  String? get validationMessage {
    if (minimumPrice != null && minimumPrice! < 0) {
      return 'Minimum price cannot be negative.';
    }
    if (maximumPrice != null && maximumPrice! < 0) {
      return 'Maximum price cannot be negative.';
    }
    if (minimumPrice != null &&
        maximumPrice != null &&
        minimumPrice! > maximumPrice!) {
      return 'Minimum price cannot be greater than maximum price.';
    }
    return null;
  }

  MarketplaceBrowseFilters copyWith({
    String? transactionType,
    bool clearTransactionType = false,
    String? condition,
    bool clearCondition = false,
    double? minimumPrice,
    bool clearMinimumPrice = false,
    double? maximumPrice,
    bool clearMaximumPrice = false,
    MarketplaceBrowseSort? sort,
  }) =>
      MarketplaceBrowseFilters(
        transactionType: clearTransactionType
            ? null
            : transactionType ?? this.transactionType,
        condition: clearCondition ? null : condition ?? this.condition,
        minimumPrice:
            clearMinimumPrice ? null : minimumPrice ?? this.minimumPrice,
        maximumPrice:
            clearMaximumPrice ? null : maximumPrice ?? this.maximumPrice,
        sort: sort ?? this.sort,
      );
}

String marketplaceBrowseSortLabel(MarketplaceBrowseSort value) =>
    switch (value) {
      MarketplaceBrowseSort.newest => 'Newest first',
      MarketplaceBrowseSort.priceLowToHigh => 'Price: low to high',
      MarketplaceBrowseSort.priceHighToLow => 'Price: high to low',
    };
