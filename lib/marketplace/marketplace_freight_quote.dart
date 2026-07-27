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
          catalogWeightKg: estimate.kg,
          weightSource:
              draft.weightChanged ? 'shipper_adjusted' : estimate.source,
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

  static Future<bool> _reviewRequest(BuildContext context,
          {required _FreightQuoteDraft draft,
          required String listingTitle}) async =>
      await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                titlePadding: const EdgeInsets.fromLTRB(22, 20, 16, 10),
                title: Row(children: [
                  const CircleAvatar(
                      backgroundColor: Color(0xFFE5F2FF),
                      foregroundColor: Color(0xFF0878E8),
                      child: Icon(Icons.fact_check_outlined)),
                  const SizedBox(width: 11),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Publish carrier request?',
                            style: TextStyle(
                                fontSize: 21, fontWeight: FontWeight.w900)),
                        Text('Confirm the route, load and requested date',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF66758A)))
                      ])),
                  IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext, false),
                      icon: const Icon(Icons.close))
                ]),
                content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          _ReviewSummaryCard(
                              listingTitle: listingTitle, draft: draft),
                          const SizedBox(height: 12),
                          const Card(
                              margin: EdgeInsets.zero,
                              color: Color(0xFFEAF8F1),
                              child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.verified_user_outlined,
                                            color: Colors.green),
                                        SizedBox(width: 9),
                                        Expanded(
                                            child: Text(
                                                'Publishing opens this load to eligible Dispatch providers. Quotes remain separate from the item purchase, and you choose whether to award one.',
                                                style: TextStyle(fontSize: 11)))
                                      ])))
                        ]))),
                actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                actions: [
                  OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Go back')),
                  FilledButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      icon: const Icon(Icons.publish_outlined),
                      label: const Text('Publish for bids'))
                ],
              )) ??
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
    required this.details,
    required this.truckingDate,
    required this.weightChanged,
  });

  final String pickup;
  final MarketplaceLocation delivery;
  final double weightKg;
  final String details;
  final DateTime truckingDate;
  final bool weightChanged;
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

class _FreightQuoteDialogState extends State<_FreightQuoteDialog> {
  static const _blue = Color(0xFF0878E8);
  static const _muted = Color(0xFF66758A);

  final _form = GlobalKey<FormState>();
  late final TextEditingController _weight;
  late final TextEditingController _details;
  late final String _pickup;
  MarketplaceLocation? _delivery;
  late DateTime _date;
  bool _usePounds = false;
  bool _weightChanged = false;

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
    _weight = TextEditingController(
        text: widget.estimate.kg == null
            ? ''
            : widget.estimate.kg!.toStringAsFixed(0));
    _details = TextEditingController(
        text: '${listing['title'] ?? 'Marketplace load'}');
    _date = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _weight.dispose();
    _details.dispose();
    super.dispose();
  }

  double? get _enteredWeight {
    final value = double.tryParse(_weight.text.trim().replaceAll(',', ''));
    if (value == null || value <= 0) return null;
    return _usePounds ? value * 0.45359237 : value;
  }

  void _changeUnit(bool pounds) {
    final kg = _enteredWeight;
    setState(() {
      _usePounds = pounds;
      if (kg != null) {
        _weight.text = (pounds ? kg * 2.2046226218 : kg).toStringAsFixed(0);
        _weight.selection =
            TextSelection.collapsed(offset: _weight.text.length);
      }
    });
  }

  void _continue() {
    if (!_form.currentState!.validate()) return;
    if (_pickup.isEmpty || _delivery == null) {
      setState(() {});
      return;
    }
    Navigator.pop(
        context,
        _FreightQuoteDraft(
            pickup: _pickup,
            delivery: _delivery!,
            weightKg: _enteredWeight!,
            details: _details.text.trim(),
            truckingDate: _date,
            weightChanged: _weightChanged));
  }

  @override
  Widget build(BuildContext context) {
    final listingTitle = '${widget.listing['title'] ?? 'Selected listing'}';
    final daysAway =
        _date.difference(DateUtils.dateOnly(DateTime.now())).inDays;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      title: Row(children: [
        Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: const Color(0xFFE5F2FF),
                borderRadius: BorderRadius.circular(14)),
            child: const IndustrialAssetIcon(
                label: 'Trucking quote',
                assetPath: IndustrialIconAssets.truckingQuote,
                size: 36,
                borderRadius: 8,
                fallback: Icon(Icons.local_shipping_outlined, color: _blue))),
        const SizedBox(width: 11),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Request carrier quotes',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text('Build a clear load request for Dispatch providers',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w400, color: _muted))
        ])),
        IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close))
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ListingLoadSummary(
                  title: listingTitle,
                  pickup: _pickup,
                  auction: widget.auction),
              const SizedBox(height: 18),
              _sectionHeading(Icons.route_outlined, 'Route',
                  'Pickup comes from the listing. Choose the exact delivery destination.'),
              const SizedBox(height: 8),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FA),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFFDDE5EC))),
                  child: Row(children: [
                    const Icon(Icons.trip_origin, color: _blue),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('PICKUP',
                              style: TextStyle(
                                  color: _muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                          Text(
                              _pickup.isEmpty
                                  ? 'Pickup area not supplied'
                                  : _pickup,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800))
                        ])),
                    const Icon(Icons.lock_outline, size: 18, color: _muted)
                  ])),
              if (_pickup.isEmpty)
                const Padding(
                    padding: EdgeInsets.only(left: 4, top: 5),
                    child: Text(
                        'The seller must add a pickup area before carrier quotes can be requested.',
                        style: TextStyle(color: Colors.red, fontSize: 11))),
              const SizedBox(height: 10),
              MarketplaceDeliveryLocationSelector(
                  value: _delivery,
                  onChanged: (value) => setState(() => _delivery = value)),
              if (_delivery == null)
                const Padding(
                    padding: EdgeInsets.only(left: 4, top: 5),
                    child: Text('A mapped delivery destination is required.',
                        style: TextStyle(color: Colors.red, fontSize: 11))),
              const SizedBox(height: 18),
              _sectionHeading(Icons.scale_outlined, 'Load weight',
                  'Use the listing estimate or enter the best shipping weight available.'),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Kilograms (kg)')),
                    ButtonSegment(value: true, label: Text('Pounds (lb)'))
                  ],
                  selected: {_usePounds},
                  onSelectionChanged: (value) => _changeUnit(value.first)),
              const SizedBox(height: 9),
              TextFormField(
                  controller: _weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => _weightChanged = true),
                  decoration: InputDecoration(
                      labelText: 'Estimated shipping weight *',
                      hintText:
                          _usePounds ? 'Example: 12,500' : 'Example: 5,670',
                      helperText:
                          'Enter the estimated weight for the complete load.',
                      prefixIcon: const Icon(Icons.scale_outlined),
                      suffixText: _usePounds ? 'lb' : 'kg'),
                  validator: (_) => _enteredWeight == null
                      ? 'Enter a valid load weight'
                      : null),
              const SizedBox(height: 8),
              _weightAnalytics(),
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      onPressed: () =>
                          MarketplaceFreightQuote.suggestWeightCorrection(
                              context,
                              listingId: widget.listingId,
                              listing: widget.listing),
                      icon: const Icon(Icons.edit_note_outlined, size: 18),
                      label:
                          const Text('Suggest a catalog weight correction'))),
              const SizedBox(height: 6),
              _sectionHeading(Icons.inventory_2_outlined, 'Load details',
                  'Help carriers understand configuration, loading and access requirements.'),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _details,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                      labelText: 'Load configuration and notes *',
                      hintText:
                          'Example: 54 joints, forklift loading available, gravel yard, call before arrival.',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined)),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Describe the load and loading requirements'
                      : null),
              const SizedBox(height: 18),
              _sectionHeading(Icons.calendar_month_outlined, 'Timing',
                  'Select when the load should be collected.'),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: _pickDate,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14)),
                  child: Row(children: [
                    const Icon(Icons.local_shipping_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('REQUESTED TRUCKING DATE',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w800)),
                          Text(
                              MaterialLocalizations.of(context)
                                  .formatMediumDate(_date),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800))
                        ])),
                    Text(
                        daysAway == 0
                            ? 'Today'
                            : '$daysAway day${daysAway == 1 ? '' : 's'} away',
                        style: const TextStyle(
                            color: _muted, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right)
                  ])),
              const SizedBox(height: 12),
              const Card(
                  margin: EdgeInsets.zero,
                  color: Color(0xFFFFF4E5),
                  child: Padding(
                      padding: EdgeInsets.all(11),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFF08A24)),
                            SizedBox(width: 9),
                            Expanded(
                                child: Text(
                                    'The entered weight is for quote planning, not a certified legal load weight. The carrier remains responsible for axle, permit and route compliance.',
                                    style: TextStyle(fontSize: 11)))
                          ])))
            ]),
          ),
        ),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton.icon(
            onPressed: _continue,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Review carrier request'))
      ],
    );
  }

  Widget _sectionHeading(IconData icon, String title, String subtitle) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: const Color(0xFFE5F2FF),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _blue, size: 20)),
        const SizedBox(width: 9),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: _muted))
        ]))
      ]);

  Widget _weightAnalytics() {
    final kg = _enteredWeight;
    final hasCatalogWeight = widget.estimate.kg != null;
    final color = kg == null
        ? const Color(0xFFF4F7FA)
        : _weightChanged
            ? const Color(0xFFFFF4E5)
            : const Color(0xFFEAF8F1);
    return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: kg == null
                    ? const Color(0xFFDDE5EC)
                    : _weightChanged
                        ? const Color(0xFFF4C27A)
                        : const Color(0xFFB9E3CA))),
        child: kg == null
            ? const Text('Enter a weight to see load analytics.',
                style: TextStyle(color: _muted))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(
                      _weightChanged
                          ? Icons.edit_outlined
                          : Icons.verified_outlined,
                      size: 18,
                      color: _weightChanged
                          ? const Color(0xFFF08A24)
                          : Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(
                          _weightChanged
                              ? 'Shipper-adjusted estimate'
                              : '${widget.estimate.source} • ${widget.estimate.confidence}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12)))
                ]),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(child: _metric('KILOGRAMS', _number(kg), 'kg')),
                  Expanded(
                      child: _metric('METRIC TONNES',
                          (kg / 1000).toStringAsFixed(2), 't')),
                  Expanded(
                      child:
                          _metric('POUNDS', _number(kg * 2.2046226218), 'lb'))
                ]),
                if (!hasCatalogWeight && !_weightChanged) ...[
                  const SizedBox(height: 8),
                  const Text(
                      'No catalog weight was found. Confirm this estimate with the seller.',
                      style: TextStyle(fontSize: 10, color: _muted))
                ]
              ]));
  }

  Widget _metric(String label, String value, String unit) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: _muted, fontSize: 9, fontWeight: FontWeight.w800)),
        Text('$value $unit',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))
      ]);

  String _number(num value) {
    final text = value.round().toString();
    return text.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
        context: context,
        firstDate: DateUtils.dateOnly(DateTime.now()),
        lastDate: DateTime.now().add(const Duration(days: 730)),
        initialDate: _date);
    if (selected != null && mounted) setState(() => _date = selected);
  }
}

class _ListingLoadSummary extends StatelessWidget {
  const _ListingLoadSummary(
      {required this.title, required this.pickup, required this.auction});

  final String title;
  final String pickup;
  final bool auction;

  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: const Color(0xFFEAF4FD),
          borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleAvatar(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF0878E8),
            child: Icon(Icons.inventory_2_outlined)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(auction ? 'AUCTION LOAD' : 'MARKETPLACE LOAD',
              style: const TextStyle(
                  color: Color(0xFF0878E8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900)),
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(pickup.isEmpty ? 'Pickup area not supplied' : 'Pickup: $pickup',
              style: const TextStyle(color: Color(0xFF53657A), fontSize: 11))
        ]))
      ]));
}

class _ReviewSummaryCard extends StatelessWidget {
  const _ReviewSummaryCard({required this.listingTitle, required this.draft});

  final String listingTitle;
  final _FreightQuoteDraft draft;

  @override
  Widget build(BuildContext context) {
    final kg = draft.weightKg;
    final weight =
        '${_formatNumber(kg)} kg • ${(kg / 1000).toStringAsFixed(2)} t';
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: const Color(0xFFF4F7FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDE5EC))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(listingTitle,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const Divider(height: 20),
          _line(Icons.trip_origin, 'Pickup', draft.pickup),
          _line(Icons.location_on_outlined, 'Delivery',
              draft.delivery.publicName),
          _line(Icons.scale_outlined, 'Estimated weight', weight),
          _line(
              Icons.calendar_month_outlined,
              'Requested date',
              MaterialLocalizations.of(context)
                  .formatMediumDate(draft.truckingDate)),
          const SizedBox(height: 7),
          const Text('LOAD NOTES',
              style: TextStyle(
                  color: Color(0xFF66758A),
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
          Text(draft.details)
        ]));
  }

  Widget _line(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: const Color(0xFF0878E8)),
        const SizedBox(width: 8),
        SizedBox(
            width: 102,
            child: Text(label,
                style:
                    const TextStyle(color: Color(0xFF66758A), fontSize: 11))),
        Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))
      ]));

  static String _formatNumber(num value) {
    final text = value.round().toString();
    return text.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
  }
}
