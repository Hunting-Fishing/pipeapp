import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'marketplace_dispatch_service_taxonomy.dart';

enum DispatchEquipmentType {
  truckTractor,
  trailer,
  pilotEscort,
  cranePicker,
  hydrovacVacuum,
  serviceTruck,
  heavyEquipment,
  other,
}

extension DispatchEquipmentTypeDetails on DispatchEquipmentType {
  String get code => switch (this) {
        DispatchEquipmentType.truckTractor => 'truck_tractor',
        DispatchEquipmentType.trailer => 'trailer',
        DispatchEquipmentType.pilotEscort => 'pilot_escort',
        DispatchEquipmentType.cranePicker => 'crane_picker',
        DispatchEquipmentType.hydrovacVacuum => 'hydrovac_vacuum',
        DispatchEquipmentType.serviceTruck => 'service_truck',
        DispatchEquipmentType.heavyEquipment => 'heavy_equipment',
        DispatchEquipmentType.other => 'other',
      };

  String get label => switch (this) {
        DispatchEquipmentType.truckTractor => 'Truck / Tractor',
        DispatchEquipmentType.trailer => 'Trailer',
        DispatchEquipmentType.pilotEscort => 'Pilot / Escort Vehicle',
        DispatchEquipmentType.cranePicker => 'Crane / Picker',
        DispatchEquipmentType.hydrovacVacuum => 'Hydrovac / Vacuum',
        DispatchEquipmentType.serviceTruck => 'Service Truck',
        DispatchEquipmentType.heavyEquipment => 'Heavy Equipment',
        DispatchEquipmentType.other => 'Other Equipment',
      };
}

class DispatchEquipmentCapabilityDraft {
  const DispatchEquipmentCapabilityDraft({
    this.id,
    required this.name,
    required this.equipmentType,
    required this.available,
    required this.serviceCodes,
    required this.capabilityValues,
  });

  final String? id;
  final String name;
  final DispatchEquipmentType equipmentType;
  final bool available;
  final List<String> serviceCodes;
  final Map<String, Object?> capabilityValues;

  List<String> get normalizedServiceCodes {
    final known =
        DispatchServiceTaxonomy.services.map((item) => item.code).toSet();
    final result = serviceCodes
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && known.contains(value))
        .toSet()
        .toList()
      ..sort();
    return result;
  }

  Map<String, Object?> get normalizedCapabilityValues {
    final result = <String, Object?>{};
    for (final entry in capabilityValues.entries) {
      final definition = DispatchServiceTaxonomy.capabilityByCode(entry.key);
      if (definition == null) continue;
      final normalized = _normalizeCapabilityValue(definition, entry.value);
      if (normalized != null) result[entry.key] = normalized;
    }
    return result;
  }

  static Object? _normalizeCapabilityValue(
    DispatchCapabilityFieldDefinition definition,
    Object? value,
  ) {
    switch (definition.valueType) {
      case DispatchCapabilityValueType.boolean:
        return value is bool ? value : null;
      case DispatchCapabilityValueType.number:
        final number =
            value is num ? value.toDouble() : double.tryParse('$value');
        return number != null && number.isFinite && number > 0 ? number : null;
      case DispatchCapabilityValueType.shortText:
        final text = '${value ?? ''}'.trim();
        if (text.isEmpty) return null;
        return text.length > 240 ? text.substring(0, 240) : text;
      case DispatchCapabilityValueType.singleChoice:
        final text = '${value ?? ''}'.trim();
        if (text.isEmpty) return null;
        if (definition.options.isNotEmpty &&
            !definition.options.contains(text)) {
          return null;
        }
        return text;
      case DispatchCapabilityValueType.multiChoice:
        final raw = value is Iterable ? value : '$value'.split(',');
        final values = raw
            .map((item) => '$item'.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .take(50)
            .toList();
        return values.isEmpty ? null : values;
    }
  }

  factory DispatchEquipmentCapabilityDraft.fromVehicle(
    String id,
    Map<String, dynamic> data,
  ) {
    final profile = _nestedMap(data['capabilityProfile']);
    final rawCodes = profile['serviceCodes'] ?? data['serviceCodes'];
    final serviceCodes = rawCodes is Iterable
        ? rawCodes.map((value) => '$value').toList()
        : _legacyServiceCodes(data['services']);
    final capabilities = <String, Object?>{
      ..._nestedMap(profile['capabilities']),
    };
    if (!capabilities.containsKey('max_payload')) {
      final payload = data['maximumPayloadKg'];
      if (payload is num && payload > 0) {
        capabilities['max_payload'] = payload.toDouble();
      }
    }

    return DispatchEquipmentCapabilityDraft(
      id: id,
      name:
          '${data['name'] ?? data['vehicleType'] ?? 'Fleet equipment'}'.trim(),
      equipmentType: _equipmentType(
        '${data['equipmentTypeCode'] ?? ''}',
        '${data['vehicleType'] ?? ''}',
        data['pilotTruck'] == true,
      ),
      available: data['available'] != false,
      serviceCodes: serviceCodes,
      capabilityValues: capabilities,
    );
  }

  static Map<String, dynamic> _nestedMap(Object? value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return <String, dynamic>{};
  }

  static List<String> _legacyServiceCodes(Object? value) {
    if (value is! Iterable) return const <String>[];
    final codes = <String>{};
    for (final item in value) {
      final service = DispatchServiceTaxonomy.fromLegacyLabel('$item');
      if (service != null) codes.add(service.code);
    }
    return codes.toList()..sort();
  }

  static DispatchEquipmentType _equipmentType(
    String code,
    String legacyType,
    bool pilotTruck,
  ) {
    for (final type in DispatchEquipmentType.values) {
      if (type.code == code) return type;
    }
    final normalized = legacyType.toLowerCase();
    if (pilotTruck ||
        normalized.contains('pilot') ||
        normalized.contains('escort')) {
      return DispatchEquipmentType.pilotEscort;
    }
    if (normalized.contains('trailer') ||
        normalized.contains('lowboy') ||
        normalized.contains('step deck') ||
        normalized.contains('flat deck')) {
      return DispatchEquipmentType.trailer;
    }
    if (normalized.contains('crane') || normalized.contains('picker')) {
      return DispatchEquipmentType.cranePicker;
    }
    if (normalized.contains('hydrovac') || normalized.contains('vacuum')) {
      return DispatchEquipmentType.hydrovacVacuum;
    }
    if (normalized.contains('service') ||
        normalized.contains('mechanic') ||
        normalized.contains('weld')) {
      return DispatchEquipmentType.serviceTruck;
    }
    if (normalized.contains('grader') ||
        normalized.contains('dozer') ||
        normalized.contains('excavator') ||
        normalized.contains('loader')) {
      return DispatchEquipmentType.heavyEquipment;
    }
    if (normalized.contains('truck') || normalized.contains('tractor')) {
      return DispatchEquipmentType.truckTractor;
    }
    return DispatchEquipmentType.other;
  }
}

class DispatchCapabilityDisplayUnits {
  const DispatchCapabilityDisplayUnits._();

  static String label(DispatchCapabilityFieldDefinition field) =>
      switch (field.canonicalUnit) {
        DispatchCapabilityUnit.kilogram => 'lb',
        DispatchCapabilityUnit.metre => 'ft',
        DispatchCapabilityUnit.kilometre => 'mi',
        DispatchCapabilityUnit.litre => 'US gal',
        DispatchCapabilityUnit.hour => 'hr',
        DispatchCapabilityUnit.pound => 'lb',
        DispatchCapabilityUnit.metricTonne => 't',
        DispatchCapabilityUnit.usTon => 'US ton',
        DispatchCapabilityUnit.foot => 'ft',
        DispatchCapabilityUnit.mile => 'mi',
        DispatchCapabilityUnit.usGallon => 'US gal',
        null => '',
      };

  static double toDisplay(
    DispatchCapabilityFieldDefinition field,
    num canonicalValue,
  ) {
    final value = canonicalValue.toDouble();
    return switch (field.canonicalUnit) {
      DispatchCapabilityUnit.kilogram => value * 2.2046226218,
      DispatchCapabilityUnit.metre => value * 3.280839895,
      DispatchCapabilityUnit.kilometre => value * 0.6213711922,
      DispatchCapabilityUnit.litre => value * 0.2641720524,
      _ => value,
    };
  }

  static double toCanonical(
    DispatchCapabilityFieldDefinition field,
    num displayValue,
  ) {
    final value = displayValue.toDouble();
    return switch (field.canonicalUnit) {
      DispatchCapabilityUnit.kilogram => value / 2.2046226218,
      DispatchCapabilityUnit.metre => value / 3.280839895,
      DispatchCapabilityUnit.kilometre => value / 0.6213711922,
      DispatchCapabilityUnit.litre => value / 0.2641720524,
      _ => value,
    };
  }
}

class MarketplaceDispatchEquipmentCapabilityRepository {
  MarketplaceDispatchEquipmentCapabilityRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Sign in to manage Dispatch fleet capabilities.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _fleet => _firestore
      .collection('dispatch_carriers')
      .doc(_uid)
      .collection('vehicles');

  Stream<List<DispatchEquipmentCapabilityDraft>> watchFleet() =>
      _fleet.limit(100).snapshots().map((snapshot) {
        final result = snapshot.docs
            .map(
              (doc) => DispatchEquipmentCapabilityDraft.fromVehicle(
                doc.id,
                doc.data(),
              ),
            )
            .toList();
        result.sort((a, b) => a.name.compareTo(b.name));
        return result;
      });

  Future<void> save(DispatchEquipmentCapabilityDraft draft) async {
    final uid = _uid;
    final name = draft.name.trim();
    if (name.isEmpty || name.length > 160) {
      throw ArgumentError(
        'Equipment name is required and must be 160 characters or fewer.',
      );
    }

    final reference = draft.id == null ? _fleet.doc() : _fleet.doc(draft.id);
    final serviceDefinitions = draft.normalizedServiceCodes
        .map(DispatchServiceTaxonomy.findByCode)
        .whereType<DispatchServiceDefinition>()
        .toList();
    final services =
        serviceDefinitions.map((service) => service.label).toList();
    final capabilities = draft.normalizedCapabilityValues;
    final maxPayload = capabilities['max_payload'];
    final pilotTruck =
        draft.equipmentType == DispatchEquipmentType.pilotEscort ||
            serviceDefinitions.any(
              (service) =>
                  service.category ==
                  DispatchServiceCategoryCode.pilotOversizeSupport,
            );

    final values = <String, dynamic>{
      'ownerUid': uid,
      'name': name,
      'vehicleType': draft.equipmentType.label,
      'equipmentTypeCode': draft.equipmentType.code,
      'available': draft.available,
      'serviceCodes': draft.normalizedServiceCodes,
      'services': services,
      'pilotTruck': pilotTruck,
      if (maxPayload is num) 'maximumPayloadKg': maxPayload,
      'capabilityProfile': {
        'schemaVersion': 1,
        'serviceCodes': draft.normalizedServiceCodes,
        'capabilities': capabilities,
        'source': 'provider_declared',
      },
      'updatedAt': FieldValue.serverTimestamp(),
      if (draft.id == null) 'createdAt': FieldValue.serverTimestamp(),
    };

    if (draft.id == null) {
      await reference.set(values);
      return;
    }

    final snapshot = await reference.get();
    if (!snapshot.exists || snapshot.data()?['ownerUid'] != uid) {
      throw StateError('This fleet equipment record is unavailable.');
    }
    await reference.set(values, SetOptions(merge: true));
  }
}

class MarketplaceDispatchEquipmentCapabilitiesPage extends StatefulWidget {
  const MarketplaceDispatchEquipmentCapabilitiesPage({super.key});

  @override
  State<MarketplaceDispatchEquipmentCapabilitiesPage> createState() =>
      _MarketplaceDispatchEquipmentCapabilitiesPageState();
}

class _MarketplaceDispatchEquipmentCapabilitiesPageState
    extends State<MarketplaceDispatchEquipmentCapabilitiesPage> {
  final MarketplaceDispatchEquipmentCapabilityRepository _repository =
      MarketplaceDispatchEquipmentCapabilityRepository();

  Future<void> _edit(DispatchEquipmentCapabilityDraft draft) async {
    var name = draft.name;
    var equipmentType = draft.equipmentType;
    var available = draft.available;
    final serviceCodes = draft.normalizedServiceCodes.toSet();
    final capabilityValues = Map<String, Object?>.from(
      draft.normalizedCapabilityValues,
    );
    var saving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final capabilityFields = _capabilityFields(serviceCodes);
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820, maxHeight: 820),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            draft.id == null
                                ? 'Add fleet equipment'
                                : 'Edit fleet capabilities',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: saving
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        TextFormField(
                          initialValue: name,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Equipment name',
                            hintText: 'Example: Unit 12 Lowboy',
                          ),
                          onChanged: (value) => name = value,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<DispatchEquipmentType>(
                          initialValue: equipmentType,
                          decoration: const InputDecoration(
                            labelText: 'Equipment type',
                          ),
                          items: DispatchEquipmentType.values
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type.label),
                                ),
                              )
                              .toList(),
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() => equipmentType = value);
                                },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: available,
                          onChanged: saving
                              ? null
                              : (value) =>
                                  setDialogState(() => available = value),
                          title: const Text('Available for work'),
                          subtitle: const Text(
                            'This is operational availability, not a guarantee of schedule acceptance.',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Services this equipment can perform',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        ...DispatchServiceTaxonomy.categories.map((category) {
                          final services = DispatchServiceTaxonomy.services
                              .where((service) =>
                                  service.category == category.code)
                              .toList();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: services
                                      .map(
                                        (service) => FilterChip(
                                          label: Text(service.label),
                                          selected: serviceCodes
                                              .contains(service.code),
                                          onSelected: saving
                                              ? null
                                              : (selected) {
                                                  setDialogState(() {
                                                    if (selected) {
                                                      serviceCodes
                                                          .add(service.code);
                                                    } else {
                                                      serviceCodes
                                                          .remove(service.code);
                                                    }
                                                  });
                                                },
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (capabilityFields.isNotEmpty) ...[
                          const Divider(height: 28),
                          Text(
                            'Structured capabilities',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Only enter capabilities that are current and supported by this equipment.',
                          ),
                          const SizedBox(height: 10),
                          ...capabilityFields.map(
                            (field) => _CapabilityFieldEditor(
                              definition: field,
                              value: capabilityValues[field.code],
                              enabled: !saving,
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == null) {
                                    capabilityValues.remove(field.code);
                                  } else {
                                    capabilityValues[field.code] = value;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  setDialogState(() {
                                    saving = true;
                                    errorMessage = null;
                                  });
                                  try {
                                    await _repository.save(
                                      DispatchEquipmentCapabilityDraft(
                                        id: draft.id,
                                        name: name,
                                        equipmentType: equipmentType,
                                        available: available,
                                        serviceCodes: serviceCodes.toList(),
                                        capabilityValues: capabilityValues,
                                      ),
                                    );
                                    if (!mounted || !dialogContext.mounted)
                                      return;
                                    Navigator.of(dialogContext).pop();
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Fleet capabilities saved.'),
                                      ),
                                    );
                                  } catch (error) {
                                    setDialogState(() {
                                      saving = false;
                                      errorMessage = '$error';
                                    });
                                  }
                                },
                          icon: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label:
                              Text(saving ? 'Saving...' : 'Save capabilities'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<DispatchCapabilityFieldDefinition> _capabilityFields(
    Set<String> serviceCodes,
  ) {
    final codes = <String>{};
    for (final serviceCode in serviceCodes) {
      final service = DispatchServiceTaxonomy.findByCode(serviceCode);
      if (service != null) codes.addAll(service.capabilityFieldCodes);
    }
    final result = codes
        .map(DispatchServiceTaxonomy.capabilityByCode)
        .whereType<DispatchCapabilityFieldDefinition>()
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return result;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fleet & equipment capabilities')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(
            const DispatchEquipmentCapabilityDraft(
              name: '',
              equipmentType: DispatchEquipmentType.truckTractor,
              available: true,
              serviceCodes: <String>[],
              capabilityValues: <String, Object?>{},
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add equipment'),
        ),
        body: StreamBuilder<List<DispatchEquipmentCapabilityDraft>>(
          stream: _repository.watchFleet(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Fleet equipment could not be loaded: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final equipment =
                snapshot.data ?? const <DispatchEquipmentCapabilityDraft>[];
            if (equipment.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No fleet equipment is listed yet. Add the trucks, trailers, pilot vehicles, cranes or field-service equipment customers can request.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: equipment.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = equipment[index];
                final serviceLabels = item.normalizedServiceCodes
                    .map(DispatchServiceTaxonomy.findByCode)
                    .whereType<DispatchServiceDefinition>()
                    .map((service) => service.label)
                    .toList();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              item.equipmentType ==
                                      DispatchEquipmentType.pilotEscort
                                  ? Icons.assistant_direction_outlined
                                  : item.equipmentType ==
                                          DispatchEquipmentType.cranePicker
                                      ? Icons.construction_outlined
                                      : Icons.local_shipping_outlined,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(item.equipmentType.label),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(
                                item.available ? 'Available' : 'Unavailable',
                              ),
                            ),
                          ],
                        ),
                        if (serviceLabels.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: serviceLabels
                                .take(8)
                                .map((label) => Chip(label: Text(label)))
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => _edit(item),
                            icon: const Icon(Icons.tune_outlined),
                            label: const Text('Edit capabilities'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class _CapabilityFieldEditor extends StatelessWidget {
  const _CapabilityFieldEditor({
    required this.definition,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final DispatchCapabilityFieldDefinition definition;
  final Object? value;
  final bool enabled;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (definition.valueType) {
      case DispatchCapabilityValueType.boolean:
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: value == true,
          onChanged: enabled ? (checked) => onChanged(checked == true) : null,
          title: Text(definition.label),
          subtitle:
              definition.helpText.isEmpty ? null : Text(definition.helpText),
        );
      case DispatchCapabilityValueType.number:
        final Object? numberValue = value;
        final num? canonical = numberValue is num ? numberValue : null;
        final display = canonical == null
            ? ''
            : DispatchCapabilityDisplayUnits.toDisplay(definition, canonical)
                .toStringAsFixed(1)
                .replaceFirst(RegExp(r'\.0$'), '');
        final unit = DispatchCapabilityDisplayUnits.label(definition);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            key: ValueKey('capability-${definition.code}-$display'),
            initialValue: display,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: unit.isEmpty
                  ? definition.label
                  : '${definition.label} ($unit)',
              helperText:
                  definition.helpText.isEmpty ? null : definition.helpText,
            ),
            onChanged: (text) {
              final number = double.tryParse(text.trim());
              if (number == null || number <= 0) {
                onChanged(null);
              } else {
                onChanged(
                  DispatchCapabilityDisplayUnits.toCanonical(
                      definition, number),
                );
              }
            },
          ),
        );
      case DispatchCapabilityValueType.shortText:
      case DispatchCapabilityValueType.singleChoice:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            initialValue: '${value ?? ''}',
            enabled: enabled,
            decoration: InputDecoration(
              labelText: definition.label,
              helperText:
                  definition.helpText.isEmpty ? null : definition.helpText,
            ),
            onChanged: (text) => onChanged(
              text.trim().isEmpty ? null : text.trim(),
            ),
          ),
        );
      case DispatchCapabilityValueType.multiChoice:
        final Object? multiValue = value;
        final text = multiValue is Iterable
            ? multiValue.join(', ')
            : '${multiValue ?? ''}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            initialValue: text,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: definition.label,
              hintText: 'Separate entries with commas',
              helperText:
                  definition.helpText.isEmpty ? null : definition.helpText,
            ),
            onChanged: (raw) {
              final values = raw
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList();
              onChanged(values.isEmpty ? null : values);
            },
          ),
        );
    }
  }
}
