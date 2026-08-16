import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import 'industrial_icon_assets.dart';
import 'marketplace_command_client.dart';
import 'marketplace_dispatch_repository.dart';
import 'marketplace_location.dart';
import 'marketplace_trucking_plan.dart';

class FreightWeightEstimate {
  const FreightWeightEstimate(
      {required this.kg, required this.source, required this.confidence});

  final double? kg;
  final String source;
  final String confidence;

  static FreightWeightEstimate fromListing(Map<String, dynamic> data) {
    for (final key in [
      'shippingWeightKg',
      'operatingWeightKg',
      'weightKg',
      'catalogWeightKg'
    ]) {
      final value = data[key] as num?;
      if (value != null && value > 0) {
        return FreightWeightEstimate(
            kg: value.toDouble(),
            source: key == 'shippingWeightKg'
                ? 'Seller shipping weight'
                : 'Listing specification',
            confidence:
                key == 'shippingWeightKg' ? 'seller adjusted' : 'listed');
      }
    }

    final nominalLbFt =
        _number(data['nominalWeightLbFt'] ?? data['pipeWeightLbFt']);
    final lengthFt =
        _number(data['lengthFt'] ?? data['jointLengthFt'] ?? data['length']);
    final pipeQuantity = _number(data['quantity']) ?? 1;
    if (nominalLbFt != null && lengthFt != null) {
      return FreightWeightEstimate(
          kg: nominalLbFt * lengthFt * pipeQuantity * 0.45359237,
          source: 'Nominal pipe mass × joint length × quantity',
          confidence: 'engineering estimate');
    }

    // Carbon-steel pipe estimate: cross-sectional steel area × length × density.
    final odMm = _number(data['outsideDiameterMm'] ?? data['pipeOdMm']);
    final wallMm = _number(data['wallThicknessMm']);
    final lengthM = _number(data['lengthM'] ?? data['jointLengthM']);
    final quantity = _number(data['quantity']) ?? 1;
    if (odMm != null &&
        wallMm != null &&
        lengthM != null &&
        odMm > wallMm * 2) {
      final outer = odMm / 1000;
      final inner = (odMm - wallMm * 2) / 1000;
      final area = math.pi / 4 * (outer * outer - inner * inner);
      return FreightWeightEstimate(
          kg: area * lengthM * 7850 * quantity,
          source: 'Calculated carbon-steel pipe geometry',
          confidence: 'engineering estimate');
    }
    return const FreightWeightEstimate(
        kg: null,
        source: 'Weight not yet available',
        confidence: 'manual weight required');
  }

  static Future<FreightWeightEstimate> resolve(
      Map<String, dynamic> data) async {
    final listed = fromListing(data);
    if (listed.kg != null) return listed;
    final make = '${data['brand'] ?? data['make'] ?? ''}'.trim();
    final model = '${data['model'] ?? ''}'.trim();
    if (make.isEmpty || model.isEmpty) return listed;
    final key = _catalogKey(make, model);
    final catalog = await FirebaseFirestore.instance
        .collection('weight_catalog')
        .doc(key)
        .get();
    final value = catalog.data()?['operatingWeightKg'] as num? ??
        catalog.data()?['shippingWeightKg'] as num?;
    if (value == null || value <= 0) return listed;
    return FreightWeightEstimate(
        kg: value.toDouble(),
        source:
            '${catalog.data()?['manufacturer'] ?? make} verified catalog • $make $model',
        confidence: '${catalog.data()?['verificationStatus'] ?? 'catalog'}');
  }

  static String _catalogKey(String make, String model) =>
      '${make}_$model'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}'.replaceAll(RegExp(r'[^0-9.]'), ''));
  }
}

class MarketplaceFreightQuote {
  static Future<bool> show(BuildContext context,
      {required String listingId,
      required Map<String, dynamic> listing,
      bool auction = false}) async {
    if (FirebaseAuth.instance.currentUser == null) {
      PipeFeedback.show(
        context,
        message: 'Sign in to request carrier quotes.',
        tone: PipeStatusTone.warning,
      );
      return false;
    }
    final estimate = await FreightWeightEstimate.resolve(listing);
    if (!context.mounted) return false;
    final draft = await showDialog<_FreightQuoteDraft>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _FreightQuoteDialog(
            listingId: listingId,
            listing: listing,
            estimate: estimate,
            auction: auction));
    if (draft == null || !context.mounted) return false;

    final confirmed = await _reviewRequest(context,
        draft: draft,
        listingTitle: '${listing['title'] ?? 'Selected listing'}');
    if (!confirmed || !context.mounted) return false;

    try {
      await MarketplaceDispatchRepository().createJob(
          title: '${listing['title'] ?? 'Listing freight'}',
          pickup: draft.pickup,
          delivery: draft.delivery.publicName.trim(),
          deliveryLocation: draft.delivery,
          truckingDate: draft.truckingDate,
          loadDetails: draft.details,
          listingId: listingId,
          sourceType: auction ? 'auction' : 'marketplace',
          estimatedWeightKg: draft.weightKg,
          catalogWeightKg: draft.catalogWeightKg,
          weightSource: draft.weightSource,
          pickupGeoPoint: listing['publicGeoPoint'] is GeoPoint
              ? listing['publicGeoPoint'] as GeoPoint
              : null);
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message: 'Carrier request published. Dispatch providers can now bid.',
          tone: PipeStatusTone.success,
        );
      }
      return true;
    } catch (error) {
      if (context.mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'Carrier request was not published. Nothing was changed.',
          ),
          tone: PipeStatusTone.error,
        );
      }
      return false;
    }
  }

  static Future<bool> _reviewRequest(
    BuildContext context, {
    required _FreightQuoteDraft draft,
    required String listingTitle,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          clipBehavior: Clip.antiAlias,
          backgroundColor: const Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
          actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          title: Container(
            color: const Color(0xFF0D1117),
            padding: const EdgeInsets.fromLTRB(22, 20, 14, 19),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6A00).withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFF6A00).withValues(alpha: .42),
                    ),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    color: Color(0xFFFF6A00),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PIPE BUYER DISPATCH',
                        style: TextStyle(
                          color: Color(0xFFFF6A00),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Publish carrier request?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Confirm the route, load information and requested date.',
                        style: TextStyle(
                          color: Color(0xFFB7C0CC),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(dialogContext, false),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ReviewSummaryCard(
                    listingTitle: listingTitle,
                    draft: draft,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF8F1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFB9E3CA)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: Color(0xFF148A45),
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Publishing opens this load to eligible Dispatch providers. Carrier quotes stay separate from the item purchase, and you choose whether to award one.',
                            style: TextStyle(fontSize: 11, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Go back'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.publish_outlined),
              label: const Text('Publish carrier request'),
            ),
          ],
        ),
      ) ??
      false;

  static Future<void> suggestWeightCorrection(BuildContext context,
      {required String listingId,
      required Map<String, dynamic> listing}) async {
    final weight = TextEditingController();
    final source = TextEditingController();
    final reason = TextEditingController();
    final submit = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                    title: const Text('Suggest a weight correction'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: weight,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Suggested weight', suffixText: 'kg')),
                      TextField(
                          controller: source,
                          decoration: const InputDecoration(
                              labelText:
                                  'Source (manual, scale ticket, manufacturer)')),
                      TextField(
                          controller: reason,
                          maxLines: 3,
                          decoration:
                              const InputDecoration(labelText: 'Explanation'))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Send for review'))
                    ])) ??
        false;
    final value = num.tryParse(weight.text);
    final user = FirebaseAuth.instance.currentUser;
    if (!submit || value == null || value <= 0 || user == null) return;
    await FirebaseFirestore.instance.collection('weight_suggestions').add({
      'listingId': listingId,
      'listingTitle': listing['title'],
      'make': listing['brand'] ?? listing['make'],
      'model': listing['model'],
      'productType': listing['productType'],
      'suggestedWeightKg': value,
      'evidenceSource': source.text.trim(),
      'reason': reason.text.trim(),
      'requestedByUid': user.uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp()
    });
  }
}

class _FreightQuoteDraft {
  const _FreightQuoteDraft({
    required this.pickup,
    required this.delivery,
    required this.weightKg,
    required this.catalogWeightKg,
    required this.weightSource,
    required this.weightUnknown,
    required this.details,
    required this.truckingDate,
  });

  final String pickup;
  final MarketplaceLocation delivery;
  final double? weightKg;
  final double? catalogWeightKg;
  final String weightSource;
  final bool weightUnknown;
  final String details;
  final DateTime truckingDate;
}

class _FreightQuoteDialog extends StatefulWidget {
  const _FreightQuoteDialog({
    required this.listingId,
    required this.listing,
    required this.estimate,
    required this.auction,
  });

  final String listingId;
  final Map<String, dynamic> listing;
  final FreightWeightEstimate estimate;
  final bool auction;

  @override
  State<_FreightQuoteDialog> createState() => _FreightQuoteDialogState();
}

enum _FreightWeightChoice { suggested, manual, unknown }

class _FreightQuoteDialogState extends State<_FreightQuoteDialog> {
  static const _orange = Color(0xFFFF6A00);
  static const _orangePressed = Color(0xFFE85F00);
  static const _ink = Color(0xFF0D1117);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _canvas = Color(0xFFF6F7F9);
  static const _success = Color(0xFF148A45);
  static const _warning = Color(0xFFF59E0B);

  final _form = GlobalKey<FormState>();
  late final TextEditingController _weight;
  late final TextEditingController _details;
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _specDetails;
  late final TextEditingController _lengthM;
  late final TextEditingController _widthM;
  late final TextEditingController _heightM;
  late final String _pickup;

  MarketplaceLocation? _delivery;
  late DateTime _date;
  bool _usePounds = false;
  late _FreightWeightChoice _weightChoice;

  double? _suggestedWeightKg;
  double? _catalogWeightKg;
  String _suggestedWeightSource = 'No reviewed planning weight found yet';
  String _suggestedWeightConfidence = 'manual confirmation required';

  bool _specBusy = false;
  String? _specStatus;
  bool _specStatusWarning = false;
  String _specSource = '';
  String _specConfidence = '';

  @override
  void initState() {
    super.initState();
    final listing = widget.listing;
    _pickup = [
      listing['publicLocationName'],
      listing['nearestTown'],
      listing['location']
    ]
        .map((value) => '${value ?? ''}'.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    _suggestedWeightKg = widget.estimate.kg;
    _catalogWeightKg = widget.estimate.kg;
    if (widget.estimate.kg != null) {
      _suggestedWeightSource = widget.estimate.source;
      _suggestedWeightConfidence = widget.estimate.confidence;
    }
    _weightChoice = widget.estimate.kg == null
        ? _FreightWeightChoice.manual
        : _FreightWeightChoice.suggested;
    _weight = TextEditingController(
      text: widget.estimate.kg == null
          ? ''
          : widget.estimate.kg!.toStringAsFixed(0),
    );

    _details = TextEditingController(
      text: '${listing['title'] ?? 'Marketplace load'}',
    );
    _make = TextEditingController(
      text: _firstListingText(listing, ['brand', 'make', 'manufacturer']),
    );
    _model = TextEditingController(
      text: _firstListingText(listing, ['model']),
    );
    final listingYear =
        (listing['modelYear'] as num?)?.toInt() ?? (listing['year'] as num?)?.toInt();
    _year = TextEditingController(text: listingYear?.toString() ?? '');
    _specDetails = TextEditingController();
    _lengthM = TextEditingController(
      text: _listingMeters(
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
              )?.toStringAsFixed(2) ??
          '',
    );
    _widthM = TextEditingController(
      text: _listingMeters(
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
              )?.toStringAsFixed(2) ??
          '',
    );
    _heightM = TextEditingController(
      text: _listingMeters(
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
              )?.toStringAsFixed(2) ??
          '',
    );
    _date = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _weight.dispose();
    _details.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _specDetails.dispose();
    _lengthM.dispose();
    _widthM.dispose();
    _heightM.dispose();
    super.dispose();
  }

  bool get _weightUnknown => _weightChoice == _FreightWeightChoice.unknown;

  double? get _manualWeightKg {
    final value = double.tryParse(_weight.text.trim().replaceAll(',', ''));
    if (value == null || value <= 0) return null;
    return _usePounds ? value * 0.45359237 : value;
  }

  double? get _effectiveWeightKg => switch (_weightChoice) {
        _FreightWeightChoice.suggested => _suggestedWeightKg,
        _FreightWeightChoice.manual => _manualWeightKg,
        _FreightWeightChoice.unknown => null,
      };

  void _changeUnit(bool pounds) {
    final kg = _manualWeightKg;
    setState(() {
      _usePounds = pounds;
      if (kg != null) {
        _weight.text = (pounds ? kg * 2.2046226218 : kg).toStringAsFixed(0);
        _weight.selection =
            TextSelection.collapsed(offset: _weight.text.length);
      }
    });
  }

  void _setWeightChoice(_FreightWeightChoice choice) {
    setState(() {
      _weightChoice = choice;
      if (choice == _FreightWeightChoice.manual) {
        if (_weight.text.trim().isEmpty && _suggestedWeightKg != null) {
          final value = _usePounds
              ? _suggestedWeightKg! * 2.2046226218
              : _suggestedWeightKg!;
          _weight.text = value.toStringAsFixed(0);
        }
      } else if (choice == _FreightWeightChoice.suggested) {
      }
    });
  }

  Future<void> _findApproximateSpecs() async {
    if (_specBusy) return;
    final make = _make.text.trim();
    final model = _model.text.trim();
    final year = int.tryParse(_year.text.trim());

    if (make.isEmpty || model.isEmpty) {
      setState(() {
        _specStatusWarning = true;
        _specStatus =
            'Enter at least the equipment make and model. Add the year or configuration details when known.';
      });
      return;
    }

    setState(() {
      _specBusy = true;
      _specStatus = null;
    });

    try {
      // AI integration seam:
      // A protected server-side equipment intelligence service can be called
      // here later. The form already accepts the same make/model/year,
      // dimensions, source, confidence, and planning-weight result.
      final makeKey = _catalogKeyPart(make);
      final modelKey = _catalogKeyPart(model);
      final ids = <String>[
        if (year != null) 'equipment_${makeKey}_${modelKey}_$year',
        'equipment_${makeKey}_$modelKey',
        '${makeKey}_$modelKey',
      ];

      Map<String, dynamic>? matched;
      String? matchedId;
      for (final id in ids.toSet()) {
        final snapshot = await FirebaseFirestore.instance
            .collection('weight_catalog')
            .doc(id)
            .get();
        if (!snapshot.exists) continue;
        final data = snapshot.data() ?? const <String, dynamic>{};
        if (data['active'] == false) continue;
        final yearFrom = (data['modelYearFrom'] as num?)?.toInt();
        final yearTo = (data['modelYearTo'] as num?)?.toInt();
        if (year != null &&
            ((yearFrom != null && year < yearFrom) ||
                (yearTo != null && year > yearTo))) {
          continue;
        }
        matched = data;
        matchedId = id;
        break;
      }

      if (!mounted) return;
      if (matched == null) {
        setState(() {
          _specStatusWarning = true;
          _specStatus =
              'No reviewed Pipe Buyer reference matches this equipment yet. Keep the details you know, enter dimensions manually if available, or choose "I don\'t know - add later" for weight.';
          _specSource = '';
          _specConfidence = '';
        });
        return;
      }

      final shippingWeight = _positive(matched['shippingWeightKg']);
      final operatingWeight = _positive(matched['operatingWeightKg']);
      final maximumWeight = _positive(matched['operatingWeightMaxKg']) ??
          _positive(matched['shippingWeightMaxKg']);
      final resolvedWeight =
          shippingWeight ?? operatingWeight ?? maximumWeight;

      final length = _listingMeters(
        matched,
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
      );
      final width = _listingMeters(
        matched,
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
      );
      final height = _listingMeters(
        matched,
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
      );

      final source =
          '${matched['sourceLabel'] ?? matched['sourceName'] ?? 'Pipe Buyer reviewed reference'}';
      final confidence =
          '${matched['verificationStatus'] ?? 'admin reviewed'}';

      setState(() {
        if (resolvedWeight != null) {
          _suggestedWeightKg = resolvedWeight;
          _catalogWeightKg = resolvedWeight;
          _suggestedWeightSource = source;
          _suggestedWeightConfidence = confidence;
          _weightChoice = _FreightWeightChoice.suggested;
        }
        if (length != null) _lengthM.text = length.toStringAsFixed(2);
        if (width != null) _widthM.text = width.toStringAsFixed(2);
        if (height != null) _heightM.text = height.toStringAsFixed(2);
        _specSource = source;
        _specConfidence = confidence;
        _specStatusWarning = false;
        _specStatus =
            'Approximate planning specs found from $source. Review the configuration before publishing. Reference: ${matchedId ?? 'catalog'}.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _specStatusWarning = true;
        _specStatus =
            'Spec Assist could not reach the reviewed reference catalog. You can still request carrier quotes and add the weight later.';
      });
    } finally {
      if (mounted) setState(() => _specBusy = false);
    }
  }

  String _buildLoadDetails() {
    final lines = <String>[];
    final base = _details.text.trim();
    if (base.isNotEmpty) lines.add(base);

    final identity = [
      if (_year.text.trim().isNotEmpty) _year.text.trim(),
      _make.text.trim(),
      _model.text.trim(),
    ].where((value) => value.isNotEmpty).join(' ');
    if (identity.isNotEmpty) lines.add('Equipment: $identity');

    final dimensions = <String>[];
    final length = _positive(_lengthM.text);
    final width = _positive(_widthM.text);
    final height = _positive(_heightM.text);
    if (length != null) dimensions.add('L ${length.toStringAsFixed(2)} m');
    if (width != null) dimensions.add('W ${width.toStringAsFixed(2)} m');
    if (height != null) dimensions.add('H ${height.toStringAsFixed(2)} m');
    if (dimensions.isNotEmpty) {
      lines.add('Approx. transport dimensions: ${dimensions.join(' x ')}');
    }

    final specDetails = _specDetails.text.trim();
    if (specDetails.isNotEmpty) {
      lines.add('Equipment/spec details: $specDetails');
    }
    if (_specSource.trim().isNotEmpty) {
      final confidence = _specConfidence.trim();
      lines.add(
        confidence.isEmpty
            ? 'Planning spec source: $_specSource'
            : 'Planning spec source: $_specSource - $confidence',
      );
    }
    if (_weightUnknown) {
      lines.add('Shipping weight: TO CONFIRM before final transport planning.');
    }
    return lines.join('\n');
  }

  void _continue() {
    if (!_form.currentState!.validate()) return;
    if (_pickup.isEmpty || _delivery == null) {
      setState(() {});
      return;
    }
    if (_weightChoice == _FreightWeightChoice.suggested &&
        _suggestedWeightKg == null) {
      PipeFeedback.show(
        context,
        message:
            'No suggested weight is available yet. Enter an estimate or choose "I don\'t know - add later".',
        tone: PipeStatusTone.warning,
      );
      return;
    }

    Navigator.pop(
      context,
      _FreightQuoteDraft(
        pickup: _pickup,
        delivery: _delivery!,
        weightKg: _effectiveWeightKg,
        catalogWeightKg:
            _weightUnknown ? null : (_catalogWeightKg ?? widget.estimate.kg),
        weightSource: _weightUnknown
            ? 'shipper_unknown'
            : _weightChoice == _FreightWeightChoice.manual
                ? 'shipper_adjusted'
                : _suggestedWeightSource,
        weightUnknown: _weightUnknown,
        details: _buildLoadDetails(),
        truckingDate: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listingTitle = '${widget.listing['title'] ?? 'Selected listing'}';
    final daysAway =
        _date.difference(DateUtils.dateOnly(DateTime.now())).inDays;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      title: Container(
        color: _ink,
        padding: const EdgeInsets.fromLTRB(22, 20, 14, 19),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1C12),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFF7A3C12)),
              ),
              child: const IndustrialAssetIcon(
                label: 'Trucking quote',
                assetPath: IndustrialIconAssets.truckingQuote,
                size: 38,
                borderRadius: 9,
                fallback:
                    Icon(Icons.local_shipping_outlined, color: _orange),
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PIPE BUYER DISPATCH',
                    style: TextStyle(
                      color: _orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Request carrier quotes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.35,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Build a professional load brief carriers can price confidently.',
                    style: TextStyle(
                      color: Color(0xFFB7C0CC),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ListingLoadSummary(
                  title: listingTitle,
                  pickup: _pickup,
                  auction: widget.auction,
                ),
                const SizedBox(height: 14),
                _specAssistPanel(),
                const SizedBox(height: 14),
                _premiumSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeading(
                        Icons.route_outlined,
                        'Route',
                        'Pickup comes from the listing. Choose the delivery destination for carrier pricing.',
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: _canvas,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: _line),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.trip_origin, color: _orangePressed),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PICKUP',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    _pickup.isEmpty
                                        ? 'Pickup area not supplied'
                                        : _pickup,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: _muted,
                            ),
                          ],
                        ),
                      ),
                      if (_pickup.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(left: 4, top: 6),
                          child: Text(
                            'The seller must add a pickup area before carrier quotes can be requested.',
                            style: TextStyle(
                              color: Color(0xFFD92D20),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      MarketplaceDeliveryLocationSelector(
                        value: _delivery,
                        onChanged: (value) =>
                            setState(() => _delivery = value),
                      ),
                      if (_delivery == null)
                        const Padding(
                          padding: EdgeInsets.only(left: 4, top: 6),
                          child: Text(
                            'A mapped delivery destination is required.',
                            style: TextStyle(
                              color: Color(0xFFD92D20),
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _premiumSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeading(
                        Icons.scale_outlined,
                        'Load weight',
                        'Use a reviewed planning estimate, enter your own estimate, or defer the weight until later.',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            selected:
                                _weightChoice == _FreightWeightChoice.suggested,
                            avatar: const Icon(
                              Icons.auto_awesome_outlined,
                              size: 18,
                            ),
                            label: const Text('Use suggested weight'),
                            onSelected: (_) =>
                                _setWeightChoice(_FreightWeightChoice.suggested),
                          ),
                          ChoiceChip(
                            selected:
                                _weightChoice == _FreightWeightChoice.manual,
                            avatar:
                                const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Enter / adjust weight'),
                            onSelected: (_) =>
                                _setWeightChoice(_FreightWeightChoice.manual),
                          ),
                          ChoiceChip(
                            selected:
                                _weightChoice == _FreightWeightChoice.unknown,
                            avatar:
                                const Icon(Icons.help_outline, size: 18),
                            label: const Text("I don't know - add later"),
                            onSelected: (_) =>
                                _setWeightChoice(_FreightWeightChoice.unknown),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_weightChoice == _FreightWeightChoice.suggested)
                        _suggestedWeightCard()
                      else if (_weightChoice == _FreightWeightChoice.manual)
                        _manualWeightEditor()
                      else
                        _unknownWeightCard(),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              MarketplaceFreightQuote.suggestWeightCorrection(
                            context,
                            listingId: widget.listingId,
                            listing: widget.listing,
                          ),
                          icon:
                              const Icon(Icons.edit_note_outlined, size: 18),
                          label:
                              const Text('Suggest a catalog weight correction'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _premiumSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeading(
                        Icons.inventory_2_outlined,
                        'Load details',
                        'Give carriers the loading, configuration and access details that affect equipment and price.',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _details,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Load configuration and notes *',
                          hintText:
                              'Example: forklift loading available, gravel yard, call before arrival, attachments ship separately.',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Describe the load and loading requirements'
                                : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _premiumSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeading(
                        Icons.calendar_month_outlined,
                        'Timing',
                        'Select when you would like the load collected.',
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _pickDate,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'REQUESTED TRUCKING DATE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    MaterialLocalizations.of(context)
                                        .formatMediumDate(_date),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              daysAway == 0
                                  ? 'Today'
                                  : '$daysAway day${daysAway == 1 ? '' : 's'} away',
                              style: const TextStyle(
                                color: _muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E8),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xFFF5C978)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: _warning),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'All dimensions and weights in this form are planning values only. Confirm the actual loaded configuration, certified weights, axle limits, permits and route requirements before transport.',
                          style: TextStyle(fontSize: 11, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _continue,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Review carrier request'),
        ),
      ],
    );
  }

  Widget _specAssistPanel() => _premiumSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E8),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_outlined,
                    color: _orangePressed,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pipe Buyer Spec Assist',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Enter what you know. Reviewed reference data works now, and the same fields are ready for protected AI enrichment as that service comes online.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E8),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFFFC9A5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: _orangePressed),
                      SizedBox(width: 4),
                      Text(
                        'AI-READY',
                        style: TextStyle(
                          color: _orangePressed,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 600;
                final make = TextFormField(
                  controller: _make,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Make / manufacturer',
                    hintText: 'Example: Caterpillar',
                    prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                  ),
                );
                final model = TextFormField(
                  controller: _model,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    hintText: 'Example: 320 or D6',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                );
                final year = TextFormField(
                  controller: _year,
                  keyboardType: TextInputType.number,
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
                    SizedBox(width: 150, child: year),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _specDetails,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Equipment / configuration details',
                hintText:
                    'Example: LGP undercarriage, PAT blade, ripper, hydraulic thumb, serial prefix if known.',
                helperText:
                    'Configuration clues matter because attachments and options can change transport dimensions and weight.',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.manage_search_outlined),
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  _dimensionField(_lengthM, 'Length', 'm'),
                  _dimensionField(_widthM, 'Width', 'm'),
                  _dimensionField(_heightM, 'Height', 'm'),
                ];
                if (constraints.maxWidth < 520) {
                  return Column(
                    children: [
                      fields[0],
                      const SizedBox(height: 10),
                      fields[1],
                      const SizedBox(height: 10),
                      fields[2],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 10),
                    Expanded(child: fields[1]),
                    const SizedBox(width: 10),
                    Expanded(child: fields[2]),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _specBusy ? null : _findApproximateSpecs,
                icon: _specBusy
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _specBusy
                      ? 'Checking reviewed specs...'
                      : 'Find approximate specs',
                ),
              ),
            ),
            if (_specStatus != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _specStatusWarning
                      ? const Color(0xFFFFF7E8)
                      : const Color(0xFFEAF8F1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _specStatusWarning
                        ? const Color(0xFFF5C978)
                        : const Color(0xFFB9E3CA),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _specStatusWarning
                          ? Icons.info_outline
                          : Icons.verified_outlined,
                      color: _specStatusWarning ? _warning : _success,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _specStatus!,
                        style: const TextStyle(fontSize: 11, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  Widget _dimensionField(
    TextEditingController controller,
    String label,
    String suffix,
  ) =>
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Approx. $label',
          suffixText: suffix,
          prefixIcon: const Icon(Icons.straighten_outlined),
        ),
      );

  Widget _manualWeightEditor() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Kilograms (kg)')),
              ButtonSegment(value: true, label: Text('Pounds (lb)')),
            ],
            selected: {_usePounds},
            onSelectionChanged: (value) => _changeUnit(value.first),
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _weight,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Approximate total shipping weight',
              hintText: _usePounds ? 'Example: 12,500' : 'Example: 5,670',
              helperText:
                  'Best available planning estimate for the complete load.',
              prefixIcon: const Icon(Icons.scale_outlined),
              suffixText: _usePounds ? 'lb' : 'kg',
            ),
            validator: (_) =>
                _weightChoice == _FreightWeightChoice.manual &&
                        _manualWeightKg == null
                    ? 'Enter a valid weight or choose "I don\'t know - add later"'
                    : null,
          ),
          const SizedBox(height: 8),
          _weightAnalytics(
            kg: _manualWeightKg,
            source: 'Shipper-adjusted estimate',
            confidence: 'user entered',
            edited: true,
          ),
        ],
      );

  Widget _suggestedWeightCard() {
    final kg = _suggestedWeightKg;
    if (kg == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _line),
        ),
        child: const Text(
          'No reviewed planning weight is available yet. Use Spec Assist, enter your own estimate, or choose "I don\'t know - add later".',
          style: TextStyle(color: _muted, fontSize: 11, height: 1.35),
        ),
      );
    }
    return _weightAnalytics(
      kg: kg,
      source: _suggestedWeightSource,
      confidence: _suggestedWeightConfidence,
      edited: false,
    );
  }

  Widget _unknownWeightCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E8),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFF5C978)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule_outlined, color: _warning),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weight will be added later',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'The carrier request can still be published. Weight is marked TO CONFIRM and no estimated/catalog weight is used for vehicle payload suitability until it is confirmed.',
                    style: TextStyle(fontSize: 11, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _premiumSection({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0D1117),
              blurRadius: 18,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: child,
      );

  Widget _sectionHeading(IconData icon, String title, String subtitle) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _orangePressed, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _weightAnalytics({
    required double? kg,
    required String source,
    required String confidence,
    required bool edited,
  }) {
    if (kg == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _line),
        ),
        child: const Text(
          'Enter a weight to see planning conversions.',
          style: TextStyle(color: _muted, fontSize: 11),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: edited ? const Color(0xFFFFF7E8) : const Color(0xFFEAF8F1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: edited ? const Color(0xFFF5C978) : const Color(0xFFB9E3CA),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                edited ? Icons.edit_outlined : Icons.verified_outlined,
                size: 18,
                color: edited ? _warning : _success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$source - $confidence',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = [
                _metric('KILOGRAMS', _number(kg), 'kg'),
                _metric(
                  'METRIC TONNES',
                  (kg / 1000).toStringAsFixed(2),
                  't',
                ),
                _metric(
                  'POUNDS',
                  _number(kg * 2.2046226218),
                  'lb',
                ),
              ];
              if (constraints.maxWidth < 480) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    metrics[0],
                    const SizedBox(height: 8),
                    metrics[1],
                    const SizedBox(height: 8),
                    metrics[2],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: metrics[0]),
                  Expanded(child: metrics[1]),
                  Expanded(child: metrics[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, String unit) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '$value $unit',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      );

  String _number(num value) {
    final text = value.round().toString();
    return text.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }

  static String _catalogKeyPart(Object? value) => '${value ?? ''}'
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  static String _firstListingText(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = '${data[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static double? _positive(Object? value) {
    if (value is num) return value > 0 ? value.toDouble() : null;
    final parsed = double.tryParse(
      '${value ?? ''}'.trim().replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static double? _listingMeters(
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

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: _date,
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }
}

class _ListingLoadSummary extends StatelessWidget {
  const _ListingLoadSummary({
    required this.title,
    required this.pickup,
    required this.auction,
  });

  final String title;
  final String pickup;
  final bool auction;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF151A20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF29323D)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF2A1C12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFFFF6A00),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auction ? 'TIMED BUYING LOAD' : 'MARKETPLACE LOAD',
                    style: const TextStyle(
                      color: Color(0xFFFF6A00),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pickup.isEmpty
                        ? 'Pickup area not supplied'
                        : 'Pickup: $pickup',
                    style: const TextStyle(
                      color: Color(0xFFB7C0CC),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({
    required this.listingTitle,
    required this.draft,
  });

  final String listingTitle;
  final _FreightQuoteDraft draft;

  @override
  Widget build(BuildContext context) {
    final kg = draft.weightKg;
    final weight = kg == null
        ? 'TO CONFIRM - add before final dispatch planning'
        : '${_formatNumber(kg)} kg - ${(kg / 1000).toStringAsFixed(2)} t';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            listingTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Divider(height: 22),
          _line(Icons.trip_origin, 'Pickup', draft.pickup),
          _line(
            Icons.location_on_outlined,
            'Delivery',
            draft.delivery.publicName,
          ),
          _line(
            draft.weightUnknown
                ? Icons.help_outline
                : Icons.scale_outlined,
            'Planning weight',
            weight,
          ),
          _line(
            Icons.dataset_outlined,
            'Weight source',
            draft.weightUnknown ? 'Shipper will add later' : draft.weightSource,
          ),
          _line(
            Icons.calendar_month_outlined,
            'Requested date',
            MaterialLocalizations.of(context)
                .formatMediumDate(draft.truckingDate),
          ),
          const SizedBox(height: 8),
          const Text(
            'LOAD NOTES',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(draft.details),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: const Color(0xFFE85F00)),
            const SizedBox(width: 8),
            SizedBox(
              width: 112,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );

  static String _formatNumber(num value) {
    final text = value.round().toString();
    return text.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
}
