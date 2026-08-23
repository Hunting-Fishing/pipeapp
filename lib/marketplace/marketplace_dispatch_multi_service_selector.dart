import 'package:flutter/material.dart';

import 'marketplace_dispatch_service_taxonomy.dart';

// Candidate template. The gate copies this file into
// lib/marketplace/marketplace_dispatch_multi_service_selector.dart before
// canonical-mirror analysis and production promotion.
class MarketplaceDispatchMultiServiceSelector extends StatefulWidget {
  const MarketplaceDispatchMultiServiceSelector({
    super.key,
    required this.onChanged,
    this.allowedServiceCodes = const <String>[],
    this.initialServiceCodes = const <String>[],
    this.maximumItems = 8,
    this.label = 'Services needed',
    this.helperText =
        'Choose the service required. Use + Add Service when the same request needs more than one service.',
  });

  final ValueChanged<List<String>> onChanged;
  final List<String> allowedServiceCodes;
  final List<String> initialServiceCodes;
  final int maximumItems;
  final String label;
  final String helperText;

  @override
  State<MarketplaceDispatchMultiServiceSelector> createState() =>
      _MarketplaceDispatchMultiServiceSelectorState();
}

class _MarketplaceDispatchMultiServiceSelectorState
    extends State<MarketplaceDispatchMultiServiceSelector> {
  late List<String?> _rows;

  List<DispatchServiceDefinition> get _allowedServices {
    final allowed = widget.allowedServiceCodes
        .map(DispatchServiceTaxonomy.findByCode)
        .whereType<DispatchServiceDefinition>()
        .toList(growable: false);
    return allowed.isEmpty ? DispatchServiceTaxonomy.services : allowed;
  }

  @override
  void initState() {
    super.initState();
    _rows = _initialRows(widget.initialServiceCodes);
  }

  @override
  void didUpdateWidget(
    covariant MarketplaceDispatchMultiServiceSelector oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (!_sameStrings(
        oldWidget.allowedServiceCodes, widget.allowedServiceCodes)) {
      final allowedCodes =
          _allowedServices.map((service) => service.code).toSet();
      _rows = _rows
          .map((value) =>
              value != null && allowedCodes.contains(value) ? value : null)
          .toList(growable: true);
      if (_rows.isEmpty) _rows.add(null);
      _notify();
    }
  }

  List<String?> _initialRows(List<String> values) {
    final allowedCodes =
        _allowedServices.map((service) => service.code).toSet();
    final unique = <String>[];
    for (final value in values) {
      if (allowedCodes.contains(value) && !unique.contains(value))
        unique.add(value);
      if (unique.length >= widget.maximumItems) break;
    }
    return unique.isEmpty ? <String?>[null] : unique.cast<String?>();
  }

  void _notify() {
    widget.onChanged(
      _rows.whereType<String>().toSet().toList(growable: false),
    );
  }

  void _setRow(int index, String? value) {
    setState(() => _rows[index] = value);
    _notify();
  }

  void _addRow() {
    if (_rows.length >= widget.maximumItems ||
        _selectedCodes.length >= _allowedServices.length) {
      return;
    }
    setState(() => _rows.add(null));
  }

  void _removeRow(int index) {
    setState(() {
      _rows.removeAt(index);
      if (_rows.isEmpty) _rows.add(null);
    });
    _notify();
  }

  Set<String> get _selectedCodes => _rows.whereType<String>().toSet();

  @override
  Widget build(BuildContext context) {
    final services = _allowedServices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(widget.helperText, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        for (var index = 0; index < _rows.length; index++) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final current = _rows[index];
              final otherSelected = <String>{..._selectedCodes}
                ..remove(current);
              final items = services
                  .where((service) =>
                      service.code == current ||
                      !otherSelected.contains(service.code))
                  .map(
                    (service) => DropdownMenuItem<String>(
                      value: service.code,
                      child: Text(
                        '${dispatchServiceCategoryLabel(service.category)} · ${service.label}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false);
              final canAdd = index == _rows.length - 1 &&
                  _rows.length < widget.maximumItems &&
                  _selectedCodes.length < services.length;
              final dropdown = DropdownButtonFormField<String>(
                initialValue: current,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Service item ${index + 1}',
                  prefixIcon: const Icon(Icons.handyman_outlined),
                ),
                items: items,
                onChanged: (value) => _setRow(index, value),
              );

              if (constraints.maxWidth < 470) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    dropdown,
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        if (_rows.length > 1)
                          TextButton.icon(
                            onPressed: () => _removeRow(index),
                            icon: const Icon(Icons.remove_circle_outline),
                            label: const Text('Remove'),
                          ),
                        if (canAdd)
                          OutlinedButton.icon(
                            onPressed: _addRow,
                            icon: const Icon(Icons.add),
                            label: const Text('+ Add Service'),
                          ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: dropdown),
                  if (_rows.length > 1) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Remove service item',
                      onPressed: () => _removeRow(index),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                  if (canAdd) ...[
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add),
                      label: const Text('+ Add Service'),
                    ),
                  ],
                ],
              );
            },
          ),
          if (index < _rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

String dispatchServiceCategoryLabel(DispatchServiceCategoryCode code) {
  for (final category in DispatchServiceTaxonomy.categories) {
    if (category.code == code) return category.label;
  }
  return 'Industrial Service';
}

String dispatchServiceLabelForCode(String code) =>
    DispatchServiceTaxonomy.findByCode(code)?.label ?? code;

bool _sameStrings(List<String> first, List<String> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
