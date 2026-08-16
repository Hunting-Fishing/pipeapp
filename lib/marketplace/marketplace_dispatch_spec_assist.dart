import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_weight_catalog.dart';

/// Extracts a plausible model year from free-form equipment details.
///
/// This is intentionally conservative. It does not claim to identify the
/// machine; it only captures an explicit four-digit year that the user typed.
int? dispatchSpecAssistYearFromText(String value) {
  final match = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(value);
  if (match == null) return null;
  final year = int.tryParse(match.group(1) ?? '');
  if (year == null || year < 1950 || year > 2099) return null;
  return year;
}

double? _positive(Object? value) {
  if (value is num) return value > 0 ? value.toDouble() : null;
  final parsed = double.tryParse(
    '${value ?? ''}'.trim().replaceAll(RegExp(r'[^0-9.]'), ''),
  );
  return parsed != null && parsed > 0 ? parsed : null;
}

double? _meters(
  Map<String, dynamic> data, {
  required List<String> meterKeys,
  required List<String> footKeys,
  required List<String> inchKeys,
}) {
  for (final key in meterKeys) {
    final value = _positive(data[key]);
    if (value != null) return value;
  }
  for (final key in footKeys) {
    final value = _positive(data[key]);
    if (value != null) return value * 0.3048;
  }
  for (final key in inchKeys) {
    final value = _positive(data[key]);
    if (value != null) return value * 0.0254;
  }
  return null;
}

String _firstText(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = '${data[key] ?? ''}'.trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

@immutable
class DispatchSpecAssistResult {
  const DispatchSpecAssistResult({
    required this.status,
    required this.source,
    required this.confidence,
    this.make = '',
    this.model = '',
    this.year,
    this.weightKg,
    this.lengthM,
    this.widthM,
    this.heightM,
    this.catalogId,
  });

  final String status;
  final String source;
  final String confidence;
  final String make;
  final String model;
  final int? year;
  final double? weightKg;
  final double? lengthM;
  final double? widthM;
  final double? heightM;
  final String? catalogId;

  bool get hasPlanningSpecs =>
      weightKg != null || lengthM != null || widthM != null || heightM != null;

  bool get isApprovedReference =>
      status == 'catalog_match' || status == 'listing_specs';
}

@immutable
class DispatchSpecAssistSnapshot {
  const DispatchSpecAssistSnapshot({
    this.make = '',
    this.model = '',
    this.year,
    this.description = '',
    this.lengthM,
    this.widthM,
    this.heightM,
    this.source = '',
    this.confidence = '',
  });

  final String make;
  final String model;
  final int? year;
  final String description;
  final double? lengthM;
  final double? widthM;
  final double? heightM;
  final String source;
  final String confidence;

  String get equipmentSummary {
    final identity = [make.trim(), model.trim()]
        .where((value) => value.isNotEmpty)
        .join(' ')
        .trim();
    if (identity.isEmpty && year == null) return '';
    if (identity.isEmpty) return '$year';
    return year == null ? identity : '$year $identity';
  }

  String get dimensionsSummary {
    final values = <String>[];
    if (lengthM != null) values.add('L ${lengthM!.toStringAsFixed(2)} m');
    if (widthM != null) values.add('W ${widthM!.toStringAsFixed(2)} m');
    if (heightM != null) values.add('H ${heightM!.toStringAsFixed(2)} m');
    return values.join(' × ');
  }

  String appendToNotes(
    String baseNotes, {
    required bool weightUnknown,
  }) {
    final lines = <String>[];
    final base = baseNotes.trim();
    if (base.isNotEmpty) lines.add(base);
    if (equipmentSummary.isNotEmpty) {
      lines.add('Equipment: $equipmentSummary');
    }
    if (dimensionsSummary.isNotEmpty) {
      lines.add('Approx. transport dimensions: $dimensionsSummary');
    }
    final details = description.trim();
    if (details.isNotEmpty) {
      lines.add('Spec-assist details: $details');
    }
    final sourceText = source.trim();
    if (sourceText.isNotEmpty) {
      final confidenceText = confidence.trim();
      lines.add(
        confidenceText.isEmpty
            ? 'Planning spec source: $sourceText'
            : 'Planning spec source: $sourceText • $confidenceText',
      );
    }
    if (weightUnknown) {
      lines.add('Shipping weight: TO CONFIRM before final transport planning.');
    }
    return lines.join('\n');
  }
}

DispatchSpecAssistSnapshot dispatchSpecAssistSnapshotFromListing(
  Map<String, dynamic> listing,
) {
  final year = (listing['modelYear'] as num?)?.toInt() ??
      (listing['year'] as num?)?.toInt();
  return DispatchSpecAssistSnapshot(
    make: _firstText(listing, ['brand', 'make', 'manufacturer']),
    model: _firstText(listing, ['model']),
    year: year,
    lengthM: _meters(
      listing,
      meterKeys: const [
        'transportLengthM',
        'shippingLengthM',
        'overallLengthM',
        'lengthM',
      ],
      footKeys: const [
        'transportLengthFt',
        'shippingLengthFt',
        'overallLengthFt',
        'lengthFt',
      ],
      inchKeys: const ['transportLengthIn', 'overallLengthIn'],
    ),
    widthM: _meters(
      listing,
      meterKeys: const [
        'transportWidthM',
        'shippingWidthM',
        'overallWidthM',
        'widthM',
      ],
      footKeys: const [
        'transportWidthFt',
        'shippingWidthFt',
        'overallWidthFt',
        'widthFt',
      ],
      inchKeys: const ['transportWidthIn', 'overallWidthIn'],
    ),
    heightM: _meters(
      listing,
      meterKeys: const [
        'transportHeightM',
        'shippingHeightM',
        'overallHeightM',
        'heightM',
      ],
      footKeys: const [
        'transportHeightFt',
        'shippingHeightFt',
        'overallHeightFt',
        'heightFt',
      ],
      inchKeys: const ['transportHeightIn', 'overallHeightIn'],
    ),
    source: 'Listing specifications',
    confidence: 'seller/listing data',
  );
}

/// Stable data-access seam for Dispatch equipment spec assistance.
///
/// Today this uses Pipe Buyer's approved Firestore reference catalog and the
/// listing itself. A future AI enrichment service can be added behind this
/// interface without changing the carrier-request form or its saved payload.
class DispatchSpecAssistRepository {
  DispatchSpecAssistRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _weightCatalog = MarketplaceWeightCatalogRepository(
          firestore: firestore ?? FirebaseFirestore.instance,
        );

  final FirebaseFirestore _firestore;
  final MarketplaceWeightCatalogRepository _weightCatalog;

  Future<DispatchSpecAssistResult> resolve({
    required Map<String, dynamic> listing,
    required String make,
    required String model,
    int? year,
    String description = '',
  }) async {
    final effectiveYear = year ??
        dispatchSpecAssistYearFromText('$make $model $description');
    final effectiveMake = make.trim().isNotEmpty
        ? make.trim()
        : _firstText(listing, ['brand', 'make', 'manufacturer']);
    final effectiveModel = model.trim().isNotEmpty
        ? model.trim()
        : _firstText(listing, ['model']);
    final category = '${listing['category'] ?? ''}'.trim();
    final productType = '${listing['productType'] ?? ''}'.trim();
    final pipeSize = '${listing['pipeSize'] ?? ''}'.trim();
    final quantity = (listing['quantity'] as num?)?.toInt() ?? 1;
    final lengthM = _positive(listing['jointLengthM']) ??
        ((_positive(listing['jointLengthFt']) ?? 0) * 0.3048);

    final weight = await _weightCatalog.resolve(
      category: category,
      productType: productType,
      manufacturer: effectiveMake,
      model: effectiveModel,
      modelYear: effectiveYear,
      pipeSize: pipeSize,
      quantity: quantity,
      lengthM: lengthM > 0 ? lengthM : null,
    );

    final ids = marketplaceWeightCatalogIds(
      category: category,
      productType: productType,
      manufacturer: effectiveMake,
      model: effectiveModel,
      modelYear: effectiveYear,
      pipeSize: pipeSize,
    );

    for (final id in ids) {
      final snapshot = await _firestore.collection('weight_catalog').doc(id).get();
      if (!snapshot.exists) continue;
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['active'] == false) continue;
      final yearFrom = (data['modelYearFrom'] as num?)?.toInt();
      final yearTo = (data['modelYearTo'] as num?)?.toInt();
      if (effectiveYear != null &&
          ((yearFrom != null && effectiveYear < yearFrom) ||
              (yearTo != null && effectiveYear > yearTo))) {
        continue;
      }

      return DispatchSpecAssistResult(
        status: 'catalog_match',
        source:
            '${data['sourceLabel'] ?? data['sourceName'] ?? 'Pipe Buyer approved catalog'}',
        confidence: '${data['verificationStatus'] ?? 'admin reviewed'}',
        make: effectiveMake.isNotEmpty
            ? effectiveMake
            : '${data['manufacturer'] ?? ''}'.trim(),
        model: effectiveModel.isNotEmpty
            ? effectiveModel
            : '${data['model'] ?? ''}'.trim(),
        year: effectiveYear,
        weightKg: weight.kg,
        lengthM: _meters(
          data,
          meterKeys: const [
            'transportLengthM',
            'shippingLengthM',
            'overallLengthM',
            'lengthM',
          ],
          footKeys: const [
            'transportLengthFt',
            'shippingLengthFt',
            'overallLengthFt',
            'lengthFt',
          ],
          inchKeys: const ['transportLengthIn', 'overallLengthIn'],
        ),
        widthM: _meters(
          data,
          meterKeys: const [
            'transportWidthM',
            'shippingWidthM',
            'overallWidthM',
            'widthM',
          ],
          footKeys: const [
            'transportWidthFt',
            'shippingWidthFt',
            'overallWidthFt',
            'widthFt',
          ],
          inchKeys: const ['transportWidthIn', 'overallWidthIn'],
        ),
        heightM: _meters(
          data,
          meterKeys: const [
            'transportHeightM',
            'shippingHeightM',
            'overallHeightM',
            'heightM',
          ],
          footKeys: const [
            'transportHeightFt',
            'shippingHeightFt',
            'overallHeightFt',
            'heightFt',
          ],
          inchKeys: const ['transportHeightIn', 'overallHeightIn'],
        ),
        catalogId: id,
      );
    }

    final listingSnapshot = dispatchSpecAssistSnapshotFromListing(listing);
    final listedWeight = MarketplaceWeightEstimate.fromListing(listing);
    if (listingSnapshot.lengthM != null ||
        listingSnapshot.widthM != null ||
        listingSnapshot.heightM != null ||
        listedWeight.hasWeight) {
      return DispatchSpecAssistResult(
        status: 'listing_specs',
        source: 'Listing specifications',
        confidence: 'seller/listing data',
        make: effectiveMake,
        model: effectiveModel,
        year: effectiveYear,
        weightKg: listedWeight.kg,
        lengthM: listingSnapshot.lengthM,
        widthM: listingSnapshot.widthM,
        heightM: listingSnapshot.heightM,
      );
    }

    if (weight.hasWeight) {
      return DispatchSpecAssistResult(
        status: 'catalog_match',
        source: weight.source,
        confidence: weight.confidence,
        make: effectiveMake,
        model: effectiveModel,
        year: effectiveYear,
        weightKg: weight.kg,
        catalogId: weight.catalogId,
      );
    }

    return DispatchSpecAssistResult(
      status: 'no_match',
      source: 'No approved catalog match yet',
      confidence: 'manual confirmation required',
      make: effectiveMake,
      model: effectiveModel,
      year: effectiveYear,
    );
  }
}

class MarketplaceDispatchSpecAssistPanel extends StatefulWidget {
  const MarketplaceDispatchSpecAssistPanel({
    super.key,
    required this.listing,
    this.onChanged,
    this.onWeightSuggested,
  });

  final Map<String, dynamic> listing;
  final ValueChanged<DispatchSpecAssistSnapshot>? onChanged;
  final void Function(double kg, String source, String confidence)?
      onWeightSuggested;

  @override
  State<MarketplaceDispatchSpecAssistPanel> createState() =>
      _MarketplaceDispatchSpecAssistPanelState();
}

class _MarketplaceDispatchSpecAssistPanelState
    extends State<MarketplaceDispatchSpecAssistPanel> {
  final _repository = DispatchSpecAssistRepository();
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _details;
  late final TextEditingController _length;
  late final TextEditingController _width;
  late final TextEditingController _height;

  bool _busy = false;
  String _source = '';
  String _confidence = '';
  String? _status;
  bool _statusIsWarning = false;
  double? _suggestedWeightKg;

  @override
  void initState() {
    super.initState();
    final initial = dispatchSpecAssistSnapshotFromListing(widget.listing);
    _make = TextEditingController(text: initial.make);
    _model = TextEditingController(text: initial.model);
    _year = TextEditingController(text: initial.year?.toString() ?? '');
    _details = TextEditingController();
    _length = TextEditingController(
      text: initial.lengthM?.toStringAsFixed(2) ?? '',
    );
    _width = TextEditingController(
      text: initial.widthM?.toStringAsFixed(2) ?? '',
    );
    _height = TextEditingController(
      text: initial.heightM?.toStringAsFixed(2) ?? '',
    );
    _source = initial.source;
    _confidence = initial.confidence;
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _details.dispose();
    _length.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  DispatchSpecAssistSnapshot get _snapshot => DispatchSpecAssistSnapshot(
        make: _make.text.trim(),
        model: _model.text.trim(),
        year: int.tryParse(_year.text.trim()) ??
            dispatchSpecAssistYearFromText(_details.text),
        description: _details.text.trim(),
        lengthM: _positive(_length.text),
        widthM: _positive(_width.text),
        heightM: _positive(_height.text),
        source: _source,
        confidence: _confidence,
      );

  void _notify() => widget.onChanged?.call(_snapshot);

  Future<void> _findSpecs() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final result = await _repository.resolve(
        listing: widget.listing,
        make: _make.text,
        model: _model.text,
        year: int.tryParse(_year.text.trim()),
        description: _details.text,
      );
      if (!mounted) return;
      if (_make.text.trim().isEmpty && result.make.isNotEmpty) {
        _make.text = result.make;
      }
      if (_model.text.trim().isEmpty && result.model.isNotEmpty) {
        _model.text = result.model;
      }
      if (_year.text.trim().isEmpty && result.year != null) {
        _year.text = '${result.year}';
      }
      if (result.lengthM != null) {
        _length.text = result.lengthM!.toStringAsFixed(2);
      }
      if (result.widthM != null) {
        _width.text = result.widthM!.toStringAsFixed(2);
      }
      if (result.heightM != null) {
        _height.text = result.heightM!.toStringAsFixed(2);
      }
      _source = result.source;
      _confidence = result.confidence;
      _suggestedWeightKg = result.weightKg;
      _statusIsWarning = !result.hasPlanningSpecs;
      _status = result.hasPlanningSpecs
          ? 'Approximate planning specs found. Review every value before publishing the carrier request.'
          : 'No approved spec match yet. Keep the details you know, enter dimensions manually if available, or skip weight for later.';
      if (result.weightKg != null) {
        widget.onWeightSuggested?.call(
          result.weightKg!,
          result.source,
          result.confidence,
        );
      }
      _notify();
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusIsWarning = true;
        _status =
            'Spec Assist could not reach the reference catalog. You can still complete the request and add weight later.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PipeBuyerSectionCard(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: PipeBuyerColors.orangeSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.auto_awesome_outlined,
          color: PipeBuyerColors.orangePressed,
        ),
      ),
      trailing: const PipeBuyerStatusBadge(
        label: 'AI-READY',
        tone: PipeBuyerStatusTone.premium,
        icon: Icons.auto_awesome,
      ),
      title: 'Pipe Buyer Spec Assist',
      subtitle:
          'Enter what you know about the equipment. Approved catalog data works now; AI enrichment can feed this same form as it comes online.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              final make = TextFormField(
                controller: _make,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _notify(),
                decoration: const InputDecoration(
                  labelText: 'Make / manufacturer',
                  hintText: 'Example: Caterpillar',
                  prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                ),
              );
              final model = TextFormField(
                controller: _model,
                onChanged: (_) => _notify(),
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'Example: D6',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              );
              final year = TextFormField(
                controller: _year,
                keyboardType: TextInputType.number,
                onChanged: (_) => _notify(),
                decoration: const InputDecoration(
                  labelText: 'Year',
                  hintText: '2021',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
              );
              if (!wide) {
                return Column(
                  children: [
                    make,
                    const SizedBox(height: 10),
                    model,
                    const SizedBox(height: 10),
                    year,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: make),
                  const SizedBox(width: 10),
                  Expanded(flex: 3, child: model),
                  const SizedBox(width: 10),
                  SizedBox(width: 140, child: year),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _details,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => _notify(),
            decoration: const InputDecoration(
              labelText: 'Equipment details for Spec Assist',
              hintText:
                  'Example: CAT D6 LGP, cab, PAT blade, ripper; serial prefix if known.',
              helperText:
                  'Add configuration clues, serial prefix, attachments, or anything that could change transport size or weight.',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.manage_search_outlined),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy ? null : _findSpecs,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(_busy ? 'Checking specs…' : 'Find approximate specs'),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusIsWarning
                    ? const Color(0xFFFFF7E8)
                    : const Color(0xFFEAF8F1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _statusIsWarning
                      ? const Color(0xFFF5C978)
                      : const Color(0xFFB9E3CA),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _statusIsWarning
                        ? Icons.info_outline
                        : Icons.verified_outlined,
                    color: _statusIsWarning
                        ? PipeBuyerColors.warning
                        : PipeBuyerColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _status!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        if (_source.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Source: $_source${_confidence.trim().isEmpty ? '' : ' • $_confidence'}',
                            style: const TextStyle(
                              color: PipeBuyerColors.muted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                        if (_suggestedWeightKg != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Planning weight: ${_suggestedWeightKg!.toStringAsFixed(0)} kg / ${(_suggestedWeightKg! * 2.2046226218).toStringAsFixed(0)} lb',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Approximate transport dimensions',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Review or enter dimensions manually. These are planning values, not permit dimensions.',
            style: TextStyle(fontSize: 11, color: PipeBuyerColors.muted),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              Widget field(
                TextEditingController controller,
                String label,
                IconData icon,
              ) => TextFormField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _notify(),
                    decoration: InputDecoration(
                      labelText: label,
                      suffixText: 'm',
                      prefixIcon: Icon(icon),
                    ),
                  );
              final length = field(
                _length,
                'Length',
                Icons.straighten_outlined,
              );
              final width = field(
                _width,
                'Width',
                Icons.swap_horiz_outlined,
              );
              final height = field(
                _height,
                'Height',
                Icons.height_outlined,
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  children: [
                    length,
                    const SizedBox(height: 8),
                    width,
                    const SizedBox(height: 8),
                    height,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: length),
                  const SizedBox(width: 8),
                  Expanded(child: width),
                  const SizedBox(width: 8),
                  Expanded(child: height),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          const Text(
            marketplaceWeightDisclaimer,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.35,
              color: PipeBuyerColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
