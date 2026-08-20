import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_money.dart';

class DispatchQuoteVehicleOption {
  const DispatchQuoteVehicleOption({
    required this.id,
    required this.name,
    required this.subtitle,
  });

  final String id;
  final String name;
  final String subtitle;
}

class DispatchQuoteDraft {
  const DispatchQuoteDraft({
    required this.breakdown,
    required this.currency,
    required this.terms,
    this.vehicleId,
    this.vehicleName,
    this.availableDate,
  });

  final Map<String, dynamic> breakdown;
  final String currency;
  final String terms;
  final String? vehicleId;
  final String? vehicleName;
  final DateTime? availableDate;

  num get total => breakdown['total'] as num? ?? 0;
}

abstract final class MarketplaceDispatchQuoteForm {
  static Future<DispatchQuoteDraft?> show(
    BuildContext context, {
    required String title,
    required Map<String, dynamic> initial,
    String subtitle =
        'Build the quote from route, load, truck, pilot, permit and tax inputs.',
    String confirmLabel = 'Review quote',
    bool lockLaneIdentity = false,
    List<DispatchQuoteVehicleOption> vehicles = const [],
    String? initialVehicleId,
    DateTime? initialAvailableDate,
  }) async {
    return showDialog<DispatchQuoteDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DispatchQuoteFormDialog(
        title: title,
        subtitle: subtitle,
        confirmLabel: confirmLabel,
        initial: initial,
        lockLaneIdentity: lockLaneIdentity,
        vehicles: vehicles,
        initialVehicleId: initialVehicleId,
        initialAvailableDate: initialAvailableDate,
      ),
    );
  }
}

class _DispatchQuoteFormDialog extends StatefulWidget {
  const _DispatchQuoteFormDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.initial,
    required this.lockLaneIdentity,
    required this.vehicles,
    required this.initialVehicleId,
    required this.initialAvailableDate,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final Map<String, dynamic> initial;
  final bool lockLaneIdentity;
  final List<DispatchQuoteVehicleOption> vehicles;
  final String? initialVehicleId;
  final DateTime? initialAvailableDate;

  @override
  State<_DispatchQuoteFormDialog> createState() =>
      _DispatchQuoteFormDialogState();
}

class _DispatchQuoteFormDialogState extends State<_DispatchQuoteFormDialog> {
  late final Map<String, TextEditingController> _controllers;
  late final TextEditingController _terms;
  late String _currency;
  String? _vehicleId;
  DateTime? _availableDate;
  bool _manual = false;

  static const _numericKeys = <String>{
    'distanceKm',
    'deadheadKm',
    'mileageRate',
    'deadheadRate',
    'weightKg',
    'weightRate',
    'hours',
    'hourlyRate',
    'areaFee',
    'pilotCount',
    'pilotKmRate',
    'pilotHourlyRate',
    'pilotAreaFee',
    'permitFee',
    'baseFee',
    'surchargePercent',
    'taxPercent',
    'manualTotal',
  };

  @override
  void initState() {
    super.initState();
    String initial(String key, [Object fallback = '0']) =>
        '${widget.initial[key] ?? fallback}';
    _controllers = {
      'name': TextEditingController(text: initial('name', '')),
      'origin': TextEditingController(text: initial('origin', '')),
      'destination': TextEditingController(text: initial('destination', '')),
      'distanceKm': TextEditingController(text: initial('distanceKm')),
      'deadheadKm': TextEditingController(text: initial('deadheadKm')),
      'mileageRate': TextEditingController(text: initial('mileageRate')),
      'deadheadRate': TextEditingController(text: initial('deadheadRate')),
      'weightKg': TextEditingController(text: initial('weightKg')),
      'weightRate': TextEditingController(text: initial('weightRate')),
      'hours': TextEditingController(text: initial('hours')),
      'hourlyRate': TextEditingController(text: initial('hourlyRate')),
      'areaFee': TextEditingController(text: initial('areaFee')),
      'pilotCount': TextEditingController(text: initial('pilotCount')),
      'pilotKmRate': TextEditingController(text: initial('pilotKmRate')),
      'pilotHourlyRate':
          TextEditingController(text: initial('pilotHourlyRate')),
      'pilotAreaFee': TextEditingController(text: initial('pilotAreaFee')),
      'permitFee': TextEditingController(text: initial('permitFee')),
      'baseFee': TextEditingController(text: initial('baseFee')),
      'surchargePercent':
          TextEditingController(text: initial('surchargePercent')),
      'taxPercent': TextEditingController(text: initial('taxPercent')),
      'manualTotal': TextEditingController(text: initial('manualTotal')),
    };
    _terms = TextEditingController(text: initial('terms', ''));
    _manual = widget.initial['manual'] == true;
    _currency = '${widget.initial['currency'] ?? 'CAD'}'.toUpperCase();
    if (!const {'CAD', 'USD'}.contains(_currency)) _currency = 'CAD';
    _vehicleId = widget.initialVehicleId ??
        (widget.vehicles.isEmpty ? null : widget.vehicles.first.id);
    _availableDate = widget.initialAvailableDate;
    for (final controller in _controllers.values) {
      controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    _terms.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  double _number(String key) =>
      double.tryParse(_controllers[key]?.text.trim() ?? '') ?? 0;

  Map<String, double> get _calculation {
    final loadedMileage = _number('distanceKm') * _number('mileageRate');
    final deadhead = _number('deadheadKm') * _number('deadheadRate');
    final weight = _number('weightKg') / 1000 * _number('weightRate');
    final time = _number('hours') * _number('hourlyRate');
    final pilot = _number('pilotCount') *
        (_number('distanceKm') * _number('pilotKmRate') +
            _number('hours') * _number('pilotHourlyRate') +
            _number('pilotAreaFee'));
    final subtotal = _number('baseFee') +
        loadedMileage +
        deadhead +
        weight +
        time +
        _number('areaFee') +
        _number('permitFee') +
        pilot;
    final surcharge = subtotal * _number('surchargePercent') / 100;
    final beforeTax = subtotal + surcharge;
    final tax = beforeTax * _number('taxPercent') / 100;
    return {
      'loadedMileage': loadedMileage,
      'deadhead': deadhead,
      'weight': weight,
      'time': time,
      'pilot': pilot,
      'subtotal': subtotal,
      'surcharge': surcharge,
      'tax': tax,
      'total': _manual ? _number('manualTotal') : beforeTax + tax,
    };
  }

  DispatchQuoteVehicleOption? get _selectedVehicle {
    if (_vehicleId == null) return null;
    for (final vehicle in widget.vehicles) {
      if (vehicle.id == _vehicleId) return vehicle;
    }
    return null;
  }

  Future<void> _pickAvailableDate() async {
    final today = DateTime.now();
    final current = _availableDate ?? today;
    final initialDate = current.isBefore(today) ? today : current;
    final selected = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      initialDate: initialDate,
    );
    if (selected != null && mounted) {
      setState(() => _availableDate = selected);
    }
  }

  void _submit() {
    final name = _controllers['name']!.text.trim();
    final origin = _controllers['origin']!.text.trim();
    final destination = _controllers['destination']!.text.trim();
    if (name.isEmpty || origin.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a quote name, origin and destination.'),
        ),
      );
      return;
    }
    if (_calculation['total']! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quote total must be greater than zero.')),
      );
      return;
    }
    if (widget.vehicles.isNotEmpty && _selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the fleet unit for this quote.')),
      );
      return;
    }
    if (widget.vehicles.isNotEmpty && _availableDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose the carrier available date.')),
      );
      return;
    }

    final calculation = _calculation;
    final breakdown = <String, dynamic>{
      'name': name,
      'origin': origin,
      'destination': destination,
      for (final key in _numericKeys) key: _number(key),
      ...calculation,
      'manual': _manual,
      'currency': _currency,
      'formulaVersion': 2,
    };
    final vehicle = _selectedVehicle;
    Navigator.pop(
      context,
      DispatchQuoteDraft(
        breakdown: breakdown,
        currency: _currency,
        terms: _terms.text.trim(),
        vehicleId: vehicle?.id,
        vehicleName: vehicle?.name,
        availableDate: _availableDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _calculation;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 860),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.orangeSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.request_quote_outlined,
                      color: PipeBuyerColors.orangePressed,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(widget.subtitle, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section(
                      'Quote identity',
                      Icons.route_outlined,
                      Column(
                        children: [
                          _field('name', 'Quote / lane name'),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stack = constraints.maxWidth < 560;
                              final origin = _field(
                                'origin',
                                'Origin',
                                readOnly: widget.lockLaneIdentity,
                              );
                              final destination = _field(
                                'destination',
                                'Destination',
                                readOnly: widget.lockLaneIdentity,
                              );
                              if (stack) {
                                return Column(children: [origin, destination]);
                              }
                              return Row(
                                children: [
                                  Expanded(child: origin),
                                  const SizedBox(width: 8),
                                  Expanded(child: destination),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'CAD', label: Text('CAD')),
                                ButtonSegment(value: 'USD', label: Text('USD')),
                              ],
                              selected: {_currency},
                              onSelectionChanged: (value) =>
                                  setState(() => _currency = value.first),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.vehicles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _section(
                        'Carrier assignment',
                        Icons.local_shipping_outlined,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: widget.vehicles
                                  .map(
                                    (vehicle) => ChoiceChip(
                                      label: Text(vehicle.name),
                                      tooltip: vehicle.subtitle,
                                      selected: vehicle.id == _vehicleId,
                                      onSelected: (_) =>
                                          setState(() => _vehicleId = vehicle.id),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedVehicle?.subtitle ??
                                  'Choose an available fleet unit.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.calendar_month_outlined),
                              title: const Text('Carrier available date'),
                              subtitle: Text(_availableDate == null
                                  ? 'Choose date'
                                  : '${_availableDate!.year}-${_availableDate!.month.toString().padLeft(2, '0')}-${_availableDate!.day.toString().padLeft(2, '0')}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _pickAvailableDate,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _section(
                      'Route & load',
                      Icons.straighten_outlined,
                      _numberGrid([
                        ('distanceKm', 'Loaded distance', 'km'),
                        ('deadheadKm', 'Deadhead distance', 'km'),
                        ('weightKg', 'Shipping weight', 'kg'),
                        ('hours', 'Estimated time', 'hours'),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _section(
                      'Truck charges',
                      Icons.local_shipping_outlined,
                      _numberGrid([
                        ('baseFee', 'Base / call-out', r'$'),
                        ('mileageRate', 'Loaded mileage', r'$/km'),
                        ('deadheadRate', 'Deadhead', r'$/km'),
                        ('weightRate', 'Weight charge', r'$/tonne'),
                        ('hourlyRate', 'Time charge', r'$/hour'),
                        ('areaFee', 'Area / zone fee', r'$'),
                        ('permitFee', 'Permits / fixed costs', r'$'),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _section(
                      'Pilot vehicles',
                      Icons.assistant_direction_outlined,
                      _numberGrid([
                        ('pilotCount', 'Pilot vehicles needed', '#'),
                        ('pilotKmRate', 'Pilot mileage', r'$/km each'),
                        ('pilotHourlyRate', 'Pilot time', r'$/hour each'),
                        ('pilotAreaFee', 'Pilot area fee', r'$ each'),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _section(
                      'Adjustments & terms',
                      Icons.tune_rounded,
                      Column(
                        children: [
                          _numberGrid([
                            ('surchargePercent', 'Fuel / service surcharge', '%'),
                            ('taxPercent', 'Tax', '%'),
                          ]),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Manual quote override',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text(
                              'The calculated amount remains in the version record for audit comparison.',
                            ),
                            value: _manual,
                            onChanged: (value) => setState(() => _manual = value),
                          ),
                          if (_manual)
                            _field('manualTotal', 'Manual quoted total'),
                          TextField(
                            controller: _terms,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Equipment, timing and quote terms',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _totalCard(total),
                    const SizedBox(height: 10),
                    const Text(
                      'Each submitted change becomes a new immutable quote version. Earlier versions remain in participant-only history and are no longer the active quote.',
                      style: TextStyle(fontSize: 11.5, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(widget.confirmLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String key, String label, {bool readOnly = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: _controllers[key],
          readOnly: readOnly,
          keyboardType: _numericKeys.contains(key)
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget _numberGrid(List<(String, String, String)> fields) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720
              ? 3
              : constraints.maxWidth >= 470
                  ? 2
                  : 1;
          const gap = 8.0;
          final width = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: fields
                .map(
                  (field) => SizedBox(
                    width: width,
                    child: TextField(
                      controller: _controllers[field.$1],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: field.$2,
                        suffixText: field.$3,
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      );

  Widget _section(String title, IconData icon, Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.orangeSoft,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    color: PipeBuyerColors.orangePressed,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _totalCard(Map<String, double> total) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: PipeBuyerColors.success.withValues(alpha: .065),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: PipeBuyerColors.success.withValues(alpha: .22),
          ),
        ),
        child: Column(
          children: [
            _line('Loaded mileage', total['loadedMileage']!),
            _line('Deadhead', total['deadhead']!),
            _line('Weight', total['weight']!),
            _line('Time', total['time']!),
            _line('Pilot vehicles', total['pilot']!),
            _line('Subtotal', total['subtotal']!),
            _line('Surcharge', total['surcharge']!),
            _line('Tax', total['tax']!),
            const Divider(),
            _line('QUOTE TOTAL ($_currency)', total['total']!, strong: true),
          ],
        ),
      );

  Widget _line(String label, double amount, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: strong ? FontWeight.w900 : FontWeight.normal,
                ),
              ),
            ),
            Text(
              marketplaceMoney(amount),
              style: TextStyle(
                fontSize: strong ? 18 : 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}
