import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

const marketplaceWeightDisclaimer =
    'Approximate planning weight only. Not a certified scale weight and not for legal axle, permit, route, or load-limit compliance. Confirm actual loaded and axle weights using appropriate certified scales and the rules for every jurisdiction and route used.';

String marketplaceWeightKeyPart(Object? value) => '${value ?? ''}'
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

List<String> marketplaceWeightCatalogIds({
  required String category,
  required String productType,
  String manufacturer = '',
  String model = '',
  int? modelYear,
  String pipeSize = '',
}) {
  final ids = <String>[];
  final makeKey = marketplaceWeightKeyPart(manufacturer);
  final modelKey = marketplaceWeightKeyPart(model);
  final productKey = marketplaceWeightKeyPart(productType);
  final pipeKey = marketplaceWeightKeyPart(pipeSize);
  if (makeKey.isNotEmpty && modelKey.isNotEmpty) {
    if (modelYear != null) {
      ids.add('equipment_${makeKey}_${modelKey}_$modelYear');
    }
    ids.add('equipment_${makeKey}_$modelKey');
  }
  if (productKey.isNotEmpty && pipeKey.isNotEmpty) {
    ids.add('pipe_${productKey}_$pipeKey');
  }
  final categoryKey = marketplaceWeightKeyPart(category);
  if (categoryKey.isNotEmpty && productKey.isNotEmpty) {
    ids.add('product_${categoryKey}_$productKey');
  }
  return ids.toSet().toList(growable: false);
}

@immutable
class MarketplaceWeightEstimate {
  const MarketplaceWeightEstimate({
    this.kg,
    this.minimumKg,
    this.maximumKg,
    required this.status,
    required this.source,
    required this.confidence,
    this.catalogId,
    this.sourceName,
    this.sourceUrl,
    this.sourceReference,
    this.revision,
    this.method,
  });

  final double? kg;
  final double? minimumKg;
  final double? maximumKg;
  final String status;
  final String source;
  final String confidence;
  final String? catalogId;
  final String? sourceName;
  final String? sourceUrl;
  final String? sourceReference;
  final int? revision;
  final String? method;

  bool get hasWeight => kg != null && kg! > 0;
  bool get isRange => minimumKg != null && maximumKg != null;

  factory MarketplaceWeightEstimate.fromListing(Map<String, dynamic> listing) {
    final snapshot = listing['weightSnapshot'];
    if (snapshot is Map) {
      final data = Map<String, dynamic>.from(snapshot);
      return MarketplaceWeightEstimate(
        kg: _positive(data['estimatedWeightKg']),
        minimumKg: _positive(data['estimatedWeightMinKg']),
        maximumKg: _positive(data['estimatedWeightMaxKg']),
        status: '${data['status'] ?? listing['weightStatus'] ?? 'estimated'}',
        source: '${data['sourceLabel'] ?? data['source'] ?? listing['weightSource'] ?? 'Listing weight snapshot'}',
        confidence: '${data['confidence'] ?? listing['weightConfidence'] ?? 'listing snapshot'}',
        catalogId: data['catalogId']?.toString(),
        sourceName: data['sourceName']?.toString(),
        sourceUrl: data['sourceUrl']?.toString(),
        sourceReference: data['sourceReference']?.toString(),
        revision: (data['catalogRevision'] as num?)?.toInt(),
        method: data['method']?.toString(),
      );
    }
    for (final entry in <({String field, String source})>[
      (field: 'shippingWeightKg', source: 'Seller shipping weight'),
      (field: 'operatingWeightKg', source: 'Listed operating weight'),
      (field: 'weightKg', source: 'Listed weight'),
      (field: 'catalogWeightKg', source: 'Catalog weight'),
    ]) {
      final value = _positive(listing[entry.field]);
      if (value != null) {
        return MarketplaceWeightEstimate(
          kg: value,
          status: 'estimated',
          source: entry.source,
          confidence: 'legacy listing value',
        );
      }
    }
    if ('${listing['weightStatus'] ?? ''}' == 'unknown') {
      return const MarketplaceWeightEstimate(
        status: 'unknown',
        source: 'Seller does not know the load weight',
        confidence: 'unknown',
      );
    }
    return const MarketplaceWeightEstimate(
      status: 'unavailable',
      source: 'No listing weight snapshot',
      confidence: 'unknown',
    );
  }

  static double? _positive(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number > 0 ? number : null;
  }
}

class MarketplaceWeightCatalogRepository {
  MarketplaceWeightCatalogRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<MarketplaceWeightEstimate> resolve({
    required String category,
    required String productType,
    String manufacturer = '',
    String model = '',
    int? modelYear,
    String pipeSize = '',
    int quantity = 1,
    double? lengthM,
  }) async {
    final ids = marketplaceWeightCatalogIds(
      category: category,
      productType: productType,
      manufacturer: manufacturer,
      model: model,
      modelYear: modelYear,
      pipeSize: pipeSize,
    );
    for (final id in ids) {
      final snapshot = await _firestore.collection('weight_catalog').doc(id).get();
      if (!snapshot.exists) continue;
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['active'] == false) continue;
      final yearFrom = (data['modelYearFrom'] as num?)?.toInt();
      final yearTo = (data['modelYearTo'] as num?)?.toInt();
      if (modelYear != null &&
          ((yearFrom != null && modelYear < yearFrom) ||
              (yearTo != null && modelYear > yearTo))) {
        continue;
      }
      return _estimateFromCatalog(id, data, quantity: quantity, lengthM: lengthM);
    }
    return const MarketplaceWeightEstimate(
      status: 'unavailable',
      source: 'No approved catalog match',
      confidence: 'unknown',
    );
  }

  MarketplaceWeightEstimate _estimateFromCatalog(
    String id,
    Map<String, dynamic> data, {
    required int quantity,
    required double? lengthM,
  }) {
    final safeQuantity = quantity <= 0 ? 1 : quantity;
    double? total;
    String method = 'catalog';
    final shipping = _positive(data['shippingWeightKg']);
    final operating = _positive(data['operatingWeightKg']);
    final unit = _positive(data['unitWeightKg']);
    final kgPerM = _positive(data['kgPerM']);
    final lbFt = _positive(data['nominalWeightLbFt']);
    if (shipping != null) {
      total = shipping * safeQuantity;
      method = 'catalog shipping weight × quantity';
    } else if (operating != null) {
      total = operating * safeQuantity;
      method = 'manufacturer operating weight × quantity';
    } else if (unit != null) {
      total = unit * safeQuantity;
      method = 'catalog unit weight × quantity';
    } else if (kgPerM != null && lengthM != null && lengthM > 0) {
      total = kgPerM * lengthM * safeQuantity;
      method = 'catalog kg/m × length × quantity';
    } else if (lbFt != null && lengthM != null && lengthM > 0) {
      total = lbFt * (lengthM / 0.3048) * safeQuantity * 0.45359237;
      method = 'catalog lb/ft × length × quantity';
    }

    final minEach = _positive(data['operatingWeightMinKg']) ??
        _positive(data['shippingWeightMinKg']);
    final maxEach = _positive(data['operatingWeightMaxKg']) ??
        _positive(data['shippingWeightMaxKg']);
    final minimum = minEach == null ? null : minEach * safeQuantity;
    final maximum = maxEach == null ? null : maxEach * safeQuantity;
    if (total == null && maximum != null) {
      // A conservative planning value is preferable to silently understating
      // a configuration-dependent machine. The UI still shows the range and
      // requires legal confirmation.
      total = maximum;
      method = 'catalog range — conservative upper planning value';
    }

    return MarketplaceWeightEstimate(
      kg: total,
      minimumKg: minimum,
      maximumKg: maximum,
      status: total == null ? 'reference_only' : 'estimated',
      source: '${data['sourceLabel'] ?? data['sourceName'] ?? 'Approved weight catalog'}',
      confidence: '${data['verificationStatus'] ?? 'admin reviewed'}',
      catalogId: id,
      sourceName: data['sourceName']?.toString(),
      sourceUrl: data['sourceUrl']?.toString(),
      sourceReference: data['sourceReference']?.toString(),
      revision: (data['revision'] as num?)?.toInt(),
      method: method,
    );
  }

  static double? _positive(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number > 0 ? number : null;
  }
}

enum MarketplaceListingWeightMode { catalogEstimate, sellerEstimate, unknown }

class MarketplaceListingWeightInputState extends State<MarketplaceListingWeightInput> {
  final _repository = MarketplaceWeightCatalogRepository();
  final _manual = TextEditingController();
  MarketplaceListingWeightMode _mode = MarketplaceListingWeightMode.catalogEstimate;
  MarketplaceWeightEstimate? _estimate;
  bool _loading = false;
  String _manualUnit = 'kg';
  int _requestVersion = 0;

  Map<String, dynamic> get listingFields {
    final raw = double.tryParse(_manual.text.trim().replaceAll(',', ''));
    final manualKg = raw == null || raw <= 0
        ? null
        : _manualUnit == 'lb'
            ? raw * 0.45359237
            : raw;
    return {
      'weightInputMode': switch (_mode) {
        MarketplaceListingWeightMode.catalogEstimate => 'catalog_estimate',
        MarketplaceListingWeightMode.sellerEstimate => 'seller_estimate',
        MarketplaceListingWeightMode.unknown => 'unknown',
      },
      if (_mode == MarketplaceListingWeightMode.sellerEstimate && manualKg != null)
        'sellerEstimatedWeightKg': manualKg,
      if (_mode == MarketplaceListingWeightMode.sellerEstimate)
        'sellerWeightSource': 'seller_estimate',
    };
  }

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant MarketplaceListingWeightInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lookupSignature != widget.lookupSignature) _resolve();
  }

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final version = ++_requestVersion;
    if (widget.productType.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final estimate = await _repository.resolve(
        category: widget.category,
        productType: widget.productType,
        manufacturer: widget.manufacturer,
        model: widget.model,
        modelYear: widget.modelYear,
        pipeSize: widget.pipeSize,
        quantity: widget.quantity,
        lengthM: widget.lengthM,
      );
      if (!mounted || version != _requestVersion) return;
      setState(() => _estimate = estimate);
    } finally {
      if (mounted && version == _requestVersion) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _estimate;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PipeBuyerColors.canvas,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFDDE3EA)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.scale_outlined, color: PipeBuyerColors.orangePressed),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Shipping weight', style: TextStyle(fontWeight: FontWeight.w900)),
              Text('Stored with this listing for Dispatch planning.',
                  style: TextStyle(fontSize: 11, color: PipeBuyerColors.muted)),
            ]),
          ),
          if (_loading)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ]),
        const SizedBox(height: 10),
        SegmentedButton<MarketplaceListingWeightMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: MarketplaceListingWeightMode.catalogEstimate,
              icon: Icon(Icons.auto_awesome_outlined),
              label: Text('Use approximate'),
            ),
            ButtonSegment(
              value: MarketplaceListingWeightMode.sellerEstimate,
              icon: Icon(Icons.edit_outlined),
              label: Text('Enter estimate'),
            ),
            ButtonSegment(
              value: MarketplaceListingWeightMode.unknown,
              icon: Icon(Icons.help_outline),
              label: Text("I don't know"),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (value) => setState(() => _mode = value.first),
        ),
        const SizedBox(height: 10),
        if (_mode == MarketplaceListingWeightMode.catalogEstimate)
          _WeightEstimateCard(estimate: estimate)
        else if (_mode == MarketplaceListingWeightMode.sellerEstimate)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _manual,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Approximate total shipping weight',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _manualUnit,
              items: const [
                DropdownMenuItem(value: 'kg', child: Text('kg')),
                DropdownMenuItem(value: 'lb', child: Text('lb')),
              ],
              onChanged: (value) => setState(() => _manualUnit = value ?? 'kg'),
            ),
          ])
        else
          const _UnknownWeightCard(),
        const SizedBox(height: 10),
        const Text(
          marketplaceWeightDisclaimer,
          style: TextStyle(fontSize: 10.5, height: 1.3, color: PipeBuyerColors.muted),
        ),
      ]),
    );
  }
}

class MarketplaceListingWeightInput extends StatefulWidget {
  const MarketplaceListingWeightInput({
    super.key,
    required this.category,
    required this.productType,
    this.manufacturer = '',
    this.model = '',
    this.modelYear,
    this.pipeSize = '',
    this.quantity = 1,
    this.lengthM,
  });

  final String category;
  final String productType;
  final String manufacturer;
  final String model;
  final int? modelYear;
  final String pipeSize;
  final int quantity;
  final double? lengthM;

  String get lookupSignature =>
      '$category|$productType|$manufacturer|$model|$modelYear|$pipeSize|$quantity|$lengthM';

  @override
  State<MarketplaceListingWeightInput> createState() => MarketplaceListingWeightInputState();
}

class _WeightEstimateCard extends StatelessWidget {
  const _WeightEstimateCard({required this.estimate});
  final MarketplaceWeightEstimate? estimate;

  @override
  Widget build(BuildContext context) {
    if (estimate == null || !estimate!.hasWeight) {
      return const _UnknownWeightCard(
        message: 'No approved catalog match yet. Enter your best approximate total weight or choose “I don’t know”.',
      );
    }
    final value = estimate!.kg!;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: PipeBuyerColors.success.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PipeBuyerColors.success.withValues(alpha: .22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.check_circle_outline, size: 18, color: PipeBuyerColors.success),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Approx. ${value.toStringAsFixed(0)} kg • ${(value * 2.2046226218).toStringAsFixed(0)} lb',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ]),
        if (estimate!.isRange) ...[
          const SizedBox(height: 4),
          Text(
            'Catalog range: ${estimate!.minimumKg!.toStringAsFixed(0)}–${estimate!.maximumKg!.toStringAsFixed(0)} kg. Planning uses the upper value until the exact configuration is confirmed.',
            style: const TextStyle(fontSize: 10.5, color: PipeBuyerColors.muted),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          '${estimate!.source} • ${estimate!.confidence}${estimate!.method == null ? '' : ' • ${estimate!.method}'}',
          style: const TextStyle(fontSize: 10.5, color: PipeBuyerColors.muted),
        ),
      ]),
    );
  }
}

class _UnknownWeightCard extends StatelessWidget {
  const _UnknownWeightCard({
    this.message = 'Weight will be marked “to confirm” for carriers. Providers can quote subject to verified weight and configuration.',
  });
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: PipeBuyerColors.warning.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PipeBuyerColors.warning.withValues(alpha: .24)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.help_outline, size: 18, color: PipeBuyerColors.warning),
          const SizedBox(width: 7),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 11))),
        ]),
      );
}
