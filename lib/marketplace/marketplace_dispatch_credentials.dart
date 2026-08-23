import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';
import 'marketplace_notification_service.dart';

enum DispatchCredentialType {
  generalLiabilityInsurance,
  cargoInsurance,
  commercialAutoInsurance,
  workersCompensation,
  operatingAuthority,
  safetyCertificate,
  pilotEscortCertification,
  craneRiggingQualification,
}

enum DispatchCredentialSelfReportedState {
  notProvided,
  current,
  expired,
  notApplicable,
}

const dispatchCredentialCoverageCurrencies = <String>['CAD', 'USD', 'MXN'];
const dispatchCredentialReminderDayOptions = <int>[90, 60, 30, 14, 7, 1];

extension DispatchCredentialTypeLabel on DispatchCredentialType {
  String get code => switch (this) {
        DispatchCredentialType.generalLiabilityInsurance =>
          'general_liability_insurance',
        DispatchCredentialType.cargoInsurance => 'cargo_insurance',
        DispatchCredentialType.commercialAutoInsurance =>
          'commercial_auto_insurance',
        DispatchCredentialType.workersCompensation => 'workers_compensation',
        DispatchCredentialType.operatingAuthority => 'operating_authority',
        DispatchCredentialType.safetyCertificate => 'safety_certificate',
        DispatchCredentialType.pilotEscortCertification =>
          'pilot_escort_certification',
        DispatchCredentialType.craneRiggingQualification =>
          'crane_rigging_qualification',
      };

  String get label => switch (this) {
        DispatchCredentialType.generalLiabilityInsurance =>
          'General liability insurance',
        DispatchCredentialType.cargoInsurance => 'Cargo insurance',
        DispatchCredentialType.commercialAutoInsurance =>
          'Commercial auto insurance',
        DispatchCredentialType.workersCompensation =>
          'Workers compensation / WCB / WSIB',
        DispatchCredentialType.operatingAuthority =>
          'Operating authority / carrier registration',
        DispatchCredentialType.safetyCertificate =>
          'Safety certificate / operating certificate',
        DispatchCredentialType.pilotEscortCertification =>
          'Pilot / escort certification',
        DispatchCredentialType.craneRiggingQualification =>
          'Crane / rigging qualification',
      };

  IconData get icon => switch (this) {
        DispatchCredentialType.generalLiabilityInsurance ||
        DispatchCredentialType.cargoInsurance ||
        DispatchCredentialType.commercialAutoInsurance =>
          Icons.shield_outlined,
        DispatchCredentialType.workersCompensation =>
          Icons.health_and_safety_outlined,
        DispatchCredentialType.operatingAuthority => Icons.badge_outlined,
        DispatchCredentialType.safetyCertificate => Icons.fact_check_outlined,
        DispatchCredentialType.pilotEscortCertification =>
          Icons.assistant_direction_outlined,
        DispatchCredentialType.craneRiggingQualification =>
          Icons.construction_outlined,
      };

  bool get isInsurance => switch (this) {
        DispatchCredentialType.generalLiabilityInsurance ||
        DispatchCredentialType.cargoInsurance ||
        DispatchCredentialType.commercialAutoInsurance =>
          true,
        _ => false,
      };
}

extension DispatchCredentialStateLabel on DispatchCredentialSelfReportedState {
  String get code => switch (this) {
        DispatchCredentialSelfReportedState.notProvided => 'not_provided',
        DispatchCredentialSelfReportedState.current => 'self_reported_current',
        DispatchCredentialSelfReportedState.expired => 'self_reported_expired',
        DispatchCredentialSelfReportedState.notApplicable => 'not_applicable',
      };

  String get label => switch (this) {
        DispatchCredentialSelfReportedState.notProvided => 'Not provided',
        DispatchCredentialSelfReportedState.current =>
          'Current - self reported',
        DispatchCredentialSelfReportedState.expired =>
          'Expired - self reported',
        DispatchCredentialSelfReportedState.notApplicable => 'Not applicable',
      };
}

class DispatchCredentialRecord {
  const DispatchCredentialRecord({
    required this.type,
    required this.state,
    required this.issuer,
    required this.referenceNumber,
    required this.expiryDate,
    required this.notes,
    required this.documentStoragePath,
    this.coverageLimit,
    this.aggregateLimit,
    this.coverageCurrency = 'CAD',
  });

  factory DispatchCredentialRecord.empty(DispatchCredentialType type) =>
      DispatchCredentialRecord(
        type: type,
        state: DispatchCredentialSelfReportedState.notProvided,
        issuer: '',
        referenceNumber: '',
        expiryDate: null,
        notes: '',
        documentStoragePath: '',
      );

  factory DispatchCredentialRecord.fromPrivateMap(
    DispatchCredentialType type,
    Map<String, dynamic> data,
  ) {
    return DispatchCredentialRecord(
      type: type,
      state: _stateFromCode('${data['state'] ?? ''}'),
      issuer: '${data['issuer'] ?? ''}'.trim(),
      referenceNumber: '${data['referenceNumber'] ?? ''}'.trim(),
      expiryDate: DateTime.tryParse('${data['expiryDate'] ?? ''}'.trim()),
      notes: '${data['notes'] ?? ''}'.trim(),
      documentStoragePath: '${data['documentStoragePath'] ?? ''}'.trim(),
      coverageLimit: _positiveNumber(data['coverageLimit']),
      aggregateLimit: _positiveNumber(data['aggregateLimit']),
      coverageCurrency:
          _normalizeCurrency('${data['coverageCurrency'] ?? 'CAD'}'),
    );
  }

  final DispatchCredentialType type;
  final DispatchCredentialSelfReportedState state;
  final String issuer;
  final String referenceNumber;
  final DateTime? expiryDate;
  final String notes;
  final String documentStoragePath;
  final double? coverageLimit;
  final double? aggregateLimit;
  final String coverageCurrency;

  bool get hasPrivateEvidence => documentStoragePath.trim().isNotEmpty;
  bool get hasDeclaredCoverage =>
      type.isInsurance && coverageLimit != null && coverageLimit! > 0;

  String get expiryLabel {
    final value = expiryDate;
    if (value == null) return 'No expiry date supplied';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  String get coverageLabel {
    final value = coverageLimit;
    if (value == null || value <= 0) return 'No coverage limit supplied';
    return '${_formatWholeMoney(value)} ${coverageCurrency.toUpperCase()}';
  }

  String get aggregateCoverageLabel {
    final value = aggregateLimit;
    if (value == null || value <= 0) return 'No aggregate limit supplied';
    return '${_formatWholeMoney(value)} ${coverageCurrency.toUpperCase()} aggregate';
  }

  int? daysUntilExpiry([DateTime? from]) {
    final value = expiryDate;
    if (value == null) return null;
    final origin = from ?? DateTime.now();
    final start = DateTime(origin.year, origin.month, origin.day);
    final end = DateTime(value.year, value.month, value.day);
    return end.difference(start).inDays;
  }

  bool isCurrentOn([DateTime? on]) {
    if (state != DispatchCredentialSelfReportedState.current) return false;
    final days = daysUntilExpiry(on);
    return days == null || days >= 0;
  }

  bool meetsMinimumCoverage(
    double minimum,
    String currencyCode, {
    DateTime? on,
  }) {
    if (!type.isInsurance || !isCurrentOn(on) || minimum <= 0) return false;
    final value = coverageLimit;
    if (value == null || value <= 0) return false;
    if (_normalizeCurrency(currencyCode) != coverageCurrency.toUpperCase()) {
      return false;
    }
    return value >= minimum;
  }

  DispatchCredentialRecord copyWith({
    DispatchCredentialSelfReportedState? state,
    String? issuer,
    String? referenceNumber,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    String? notes,
    String? documentStoragePath,
    double? coverageLimit,
    bool clearCoverageLimit = false,
    double? aggregateLimit,
    bool clearAggregateLimit = false,
    String? coverageCurrency,
  }) {
    return DispatchCredentialRecord(
      type: type,
      state: state ?? this.state,
      issuer: issuer ?? this.issuer,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      expiryDate: clearExpiryDate ? null : expiryDate ?? this.expiryDate,
      notes: notes ?? this.notes,
      documentStoragePath: documentStoragePath ?? this.documentStoragePath,
      coverageLimit:
          clearCoverageLimit ? null : coverageLimit ?? this.coverageLimit,
      aggregateLimit:
          clearAggregateLimit ? null : aggregateLimit ?? this.aggregateLimit,
      coverageCurrency:
          _normalizeCurrency(coverageCurrency ?? this.coverageCurrency),
    );
  }

  Map<String, dynamic> toPrivateMap() => {
        'type': type.code,
        'state': state.code,
        'issuer': issuer.trim(),
        'referenceNumber': referenceNumber.trim(),
        'expiryDate': expiryDate == null ? '' : expiryLabel,
        'notes': notes.trim(),
        'documentStoragePath': documentStoragePath.trim(),
        if (type.isInsurance)
          'coverageCurrency': coverageCurrency.toUpperCase(),
        if (type.isInsurance && coverageLimit != null)
          'coverageLimit': coverageLimit,
        if (type.isInsurance && aggregateLimit != null)
          'aggregateLimit': aggregateLimit,
      };

  static DispatchCredentialSelfReportedState _stateFromCode(String code) {
    final normalized = code.trim();
    for (final value in DispatchCredentialSelfReportedState.values) {
      if (value.code == normalized) return value;
    }
    return DispatchCredentialSelfReportedState.notProvided;
  }

  static double? _positiveNumber(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : null;
  }
}

class DispatchCredentialReminderSettings {
  const DispatchCredentialReminderSettings({
    required this.enabled,
    required this.reminderDays,
  });

  static const defaults = DispatchCredentialReminderSettings(
    enabled: false,
    reminderDays: dispatchCredentialReminderDayOptions,
  );

  factory DispatchCredentialReminderSettings.fromPrivateMap(
    Map<String, dynamic> data,
  ) {
    final raw = data['reminderDays'];
    final values = raw is List
        ? raw.map((value) => int.tryParse('$value') ?? -1).toList()
        : const <int>[];
    return DispatchCredentialReminderSettings(
      enabled: data['enabled'] == true,
      reminderDays: _normalizeReminderDays(values),
    );
  }

  final bool enabled;
  final List<int> reminderDays;

  DispatchCredentialReminderSettings copyWith({
    bool? enabled,
    List<int>? reminderDays,
  }) =>
      DispatchCredentialReminderSettings(
        enabled: enabled ?? this.enabled,
        reminderDays: _normalizeReminderDays(reminderDays ?? this.reminderDays),
      );

  Map<String, dynamic> toPrivateMap() => {
        'enabled': enabled,
        'reminderDays': _normalizeReminderDays(reminderDays),
      };
}

class DispatchCredentialBundle {
  const DispatchCredentialBundle({
    required this.records,
    required this.reminderSettings,
  });

  final List<DispatchCredentialRecord> records;
  final DispatchCredentialReminderSettings reminderSettings;
}

class MarketplaceDispatchCredentialsRepository {
  MarketplaceDispatchCredentialsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Sign in to manage Dispatch credentials.');
    }
    return uid;
  }

  Future<DispatchCredentialBundle> loadBundle() async {
    final snapshot =
        await _firestore.collection('business_private').doc(_uid).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final rawCredentials = _nestedMap(data['dispatchCredentials']);
    final records = DispatchCredentialType.values.map((type) {
      final raw = _nestedMap(rawCredentials[type.code]);
      return raw.isEmpty
          ? DispatchCredentialRecord.empty(type)
          : DispatchCredentialRecord.fromPrivateMap(type, raw);
    }).toList(growable: false);
    final settings = DispatchCredentialReminderSettings.fromPrivateMap(
      _nestedMap(data['dispatchCredentialReminderSettings']),
    );
    return DispatchCredentialBundle(
      records: records,
      reminderSettings: settings,
    );
  }

  Future<List<DispatchCredentialRecord>> load() async =>
      (await loadBundle()).records;

  Future<DispatchCredentialReminderSettings> loadReminderSettings() async =>
      (await loadBundle()).reminderSettings;

  Future<void> save(Iterable<DispatchCredentialRecord> records) async {
    final uid = _uid;
    final values = <String, dynamic>{};
    for (final record in records) {
      values[record.type.code] = record.toPrivateMap();
    }
    await _firestore.collection('business_private').doc(uid).set(
      {
        'ownerUid': uid,
        'memberUids': FieldValue.arrayUnion([uid]),
        'dispatchCredentials': values,
        'dispatchCredentialsUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveReminderSettings(
    DispatchCredentialReminderSettings settings,
  ) async {
    final uid = _uid;
    await _firestore.collection('business_private').doc(uid).set(
      {
        'ownerUid': uid,
        'memberUids': FieldValue.arrayUnion([uid]),
        'dispatchCredentialReminderSettings': settings.toPrivateMap(),
        'dispatchCredentialReminderSettingsUpdatedAt':
            FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveAll(
    Iterable<DispatchCredentialRecord> records,
    DispatchCredentialReminderSettings settings,
  ) async {
    final uid = _uid;
    final values = <String, dynamic>{};
    for (final record in records) {
      values[record.type.code] = record.toPrivateMap();
    }
    await _firestore.collection('business_private').doc(uid).set(
      {
        'ownerUid': uid,
        'memberUids': FieldValue.arrayUnion([uid]),
        'dispatchCredentials': values,
        'dispatchCredentialReminderSettings': settings.toPrivateMap(),
        'dispatchCredentialsUpdatedAt': FieldValue.serverTimestamp(),
        'dispatchCredentialReminderSettingsUpdatedAt':
            FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String> uploadPrivateEvidence(
    DispatchCredentialType type,
    XFile file,
  ) async {
    final uid = _uid;
    final bytes = await file.readAsBytes();
    if (bytes.length > 15 * 1024 * 1024) {
      throw StateError('Credential evidence must be smaller than 15 MB.');
    }

    final contentType = file.mimeType ?? 'image/jpeg';
    if (!contentType.startsWith('image/')) {
      throw StateError(
        'This screen currently accepts credential photos or images only.',
      );
    }

    final path =
        'business_documents/$uid/dispatch_credential_${type.code}_evidence';
    await _storage.ref(path).putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
    return path;
  }

  Future<void> deletePrivateEvidence(String path) async {
    final uid = _uid;
    final requiredPrefix = 'business_documents/$uid/dispatch_credential_';
    if (!path.startsWith(requiredPrefix)) {
      throw StateError(
        'Credential evidence path is outside the private owner area.',
      );
    }
    await _storage.ref(path).delete();
  }

  static Map<String, dynamic> _nestedMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }
}

class MarketplaceDispatchCredentialsPage extends StatefulWidget {
  const MarketplaceDispatchCredentialsPage({super.key});

  @override
  State<MarketplaceDispatchCredentialsPage> createState() =>
      _MarketplaceDispatchCredentialsPageState();
}

class _MarketplaceDispatchCredentialsPageState
    extends State<MarketplaceDispatchCredentialsPage> {
  final MarketplaceDispatchCredentialsRepository _repository =
      MarketplaceDispatchCredentialsRepository();
  final MarketplaceCommandClient _commands = MarketplaceCommandClient();
  final ImagePicker _picker = ImagePicker();

  late Future<List<DispatchCredentialRecord>> _loadFuture;
  List<DispatchCredentialRecord> _records = const [];
  DispatchCredentialReminderSettings _reminderSettings =
      DispatchCredentialReminderSettings.defaults;
  MarketplaceNotificationStatus _notificationStatus =
      MarketplaceNotificationStatus.notEnabled;
  bool _saving = false;
  bool _savingReminderSettings = false;
  bool _enablingNotifications = false;
  DispatchCredentialType? _uploadingType;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<List<DispatchCredentialRecord>> _load() async {
    final bundle = await _repository.loadBundle();
    final notificationStatus =
        await MarketplaceNotificationService.instance.status();
    if (mounted) {
      _records = bundle.records;
      _reminderSettings = bundle.reminderSettings;
      _notificationStatus = notificationStatus;
    }
    return bundle.records;
  }

  void _replaceRecord(DispatchCredentialRecord record) {
    setState(() {
      _records = _records
          .map((item) => item.type == record.type ? record : item)
          .toList(growable: false);
    });
  }

  Future<void> _persistRecordUpdate(DispatchCredentialRecord updated) async {
    if (_saving) return;
    final previousRecords = _records;
    final nextRecords = _records
        .map((item) => item.type == updated.type ? updated : item)
        .toList(growable: false);
    setState(() {
      _records = nextRecords;
      _saving = true;
    });
    try {
      await _repository.saveAll(nextRecords, _reminderSettings);
      final scheduleWarning = await _syncReminderSchedule();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scheduleWarning ?? 'Credential metadata saved privately.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _records = previousRecords);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Credential metadata was not saved: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _syncReminderSchedule() async {
    try {
      await _commands
          .execute('syncDispatchCredentialReminderSchedule', const {});
      return null;
    } catch (error) {
      return 'Credential data was saved, but the reminder schedule could not be synchronized: $error';
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repository.saveAll(_records, _reminderSettings);
      final scheduleWarning = await _syncReminderSchedule();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scheduleWarning ??
                'Private credential metadata and reminder settings saved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credential metadata was not saved: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveReminderSettings() async {
    if (_savingReminderSettings) return;
    setState(() => _savingReminderSettings = true);
    try {
      await _repository.saveReminderSettings(_reminderSettings);
      final scheduleWarning = await _syncReminderSchedule();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scheduleWarning ?? 'Credential expiry reminder settings saved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder settings were not saved: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingReminderSettings = false);
    }
  }

  Future<void> _enableDeviceNotifications() async {
    if (_enablingNotifications) return;
    setState(() => _enablingNotifications = true);
    try {
      final status = await MarketplaceNotificationService.instance.enable();
      if (!mounted) return;
      setState(() => _notificationStatus = status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Device notification status: ${_notificationStatusLabel(status)}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Device notifications could not be enabled: $error')),
      );
    } finally {
      if (mounted) setState(() => _enablingNotifications = false);
    }
  }

  Future<void> _uploadEvidence(DispatchCredentialRecord record) async {
    if (_uploadingType != null) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null) return;

    setState(() => _uploadingType = record.type);
    try {
      final path = await _repository.uploadPrivateEvidence(record.type, picked);
      final updated = record.copyWith(documentStoragePath: path);
      _replaceRecord(updated);
      await _repository.saveAll(_records, _reminderSettings);
      await _syncReminderSchedule();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Credential evidence uploaded privately. Uploading does not mean it is verified.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Private evidence upload failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _uploadingType = null);
    }
  }

  Future<void> _removeEvidence(DispatchCredentialRecord record) async {
    if (!record.hasPrivateEvidence || _uploadingType != null) return;
    setState(() => _uploadingType = record.type);
    try {
      await _repository.deletePrivateEvidence(record.documentStoragePath);
      final updated = record.copyWith(documentStoragePath: '');
      _replaceRecord(updated);
      await _repository.saveAll(_records, _reminderSettings);
      await _syncReminderSchedule();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Private credential evidence removed.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Credential evidence was not removed: $error')),
      );
    } finally {
      if (mounted) setState(() => _uploadingType = null);
    }
  }

  Future<void> _editMetadata(DispatchCredentialRecord record) async {
    final issuer = TextEditingController(text: record.issuer);
    final reference = TextEditingController(text: record.referenceNumber);
    final expiry = TextEditingController(
      text: record.expiryDate == null ? '' : record.expiryLabel,
    );
    final coverage = TextEditingController(
      text: record.coverageLimit == null
          ? ''
          : record.coverageLimit!.toStringAsFixed(0),
    );
    final aggregate = TextEditingController(
      text: record.aggregateLimit == null
          ? ''
          : record.aggregateLimit!.toStringAsFixed(0),
    );
    final notes = TextEditingController(text: record.notes);
    var state = record.state;
    var currency = record.coverageCurrency.toUpperCase();
    String? coverageError;

    try {
      final updated = await showDialog<DispatchCredentialRecord>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickExpiry() async {
              final selected = await showDatePicker(
                context: dialogContext,
                initialDate: record.expiryDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (!dialogContext.mounted || selected == null) return;
              String two(int number) => number.toString().padLeft(2, '0');
              setDialogState(() {
                expiry.text =
                    '${selected.year}-${two(selected.month)}-${two(selected.day)}';
              });
            }

            final currencyOptions = <String>{
              ...dispatchCredentialCoverageCurrencies,
              if (currency.isNotEmpty) currency,
            }.toList();

            return AlertDialog(
              title: Text(record.type.label),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<
                          DispatchCredentialSelfReportedState>(
                        initialValue: state,
                        decoration: const InputDecoration(
                          labelText: 'Self-reported status',
                        ),
                        items: DispatchCredentialSelfReportedState.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => state = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: issuer,
                        decoration: const InputDecoration(
                          labelText: 'Insurer / issuer / authority',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: reference,
                        decoration: const InputDecoration(
                          labelText: 'Policy / certificate / reference number',
                        ),
                      ),
                      if (record.type.isInsurance) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: coverage,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,$ ]'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Primary coverage limit',
                                  hintText: 'Example: 5000000',
                                  errorText: coverageError,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: currencyOptions.contains(currency)
                                    ? currency
                                    : 'CAD',
                                decoration: const InputDecoration(
                                  labelText: 'Currency',
                                ),
                                items: currencyOptions
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setDialogState(() => currency = value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: aggregate,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,$ ]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Aggregate coverage limit (optional)',
                            hintText: 'Useful for general liability policies',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Coverage amounts stay private. Future Dispatch matching can compare a customer minimum against this self-reported amount without publishing the policy number or exact limit.',
                            style: TextStyle(
                              color: PipeBuyerColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: expiry,
                        readOnly: true,
                        onTap: pickExpiry,
                        decoration: InputDecoration(
                          labelText: 'Expiry date',
                          hintText: 'Optional',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (expiry.text.isNotEmpty)
                                IconButton(
                                  tooltip: 'Clear expiry date',
                                  onPressed: () => setDialogState(expiry.clear),
                                  icon: const Icon(Icons.clear),
                                ),
                              IconButton(
                                tooltip: 'Choose expiry date',
                                onPressed: pickExpiry,
                                icon: const Icon(Icons.event_outlined),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notes,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Private notes (optional)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'This metadata is private account data. It is not a Pipe Buyer verification result.',
                        style: TextStyle(
                          color: PipeBuyerColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final parsedCoverage = _parseCoverageAmount(coverage.text);
                    final parsedAggregate =
                        _parseCoverageAmount(aggregate.text);
                    if (record.type.isInsurance &&
                        coverage.text.trim().isNotEmpty &&
                        parsedCoverage == null) {
                      setDialogState(() {
                        coverageError = 'Enter a positive coverage amount.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      record.copyWith(
                        state: state,
                        issuer: issuer.text,
                        referenceNumber: reference.text,
                        expiryDate: DateTime.tryParse(expiry.text.trim()),
                        clearExpiryDate: expiry.text.trim().isEmpty,
                        notes: notes.text,
                        coverageLimit: parsedCoverage,
                        clearCoverageLimit: coverage.text.trim().isEmpty,
                        aggregateLimit: parsedAggregate,
                        clearAggregateLimit: aggregate.text.trim().isEmpty,
                        coverageCurrency: currency,
                      ),
                    );
                  },
                  child: const Text('Save & close'),
                ),
              ],
            );
          },
        ),
      );
      if (!mounted || updated == null) return;
      await _persistRecordUpdate(updated);
    } finally {
      issuer.dispose();
      reference.dispose();
      expiry.dispose();
      coverage.dispose();
      aggregate.dispose();
      notes.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Credentials & insurance'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.folder_copy_outlined), text: 'Records'),
              Tab(
                  icon: Icon(Icons.insights_outlined),
                  text: 'Analytics & alerts'),
            ],
          ),
        ),
        body: FutureBuilder<List<DispatchCredentialRecord>>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 42),
                      const SizedBox(height: 12),
                      const Text(
                        'Private credential records could not be loaded.',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _loadFuture = _load();
                        }),
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Reload credentials'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return TabBarView(
              children: [
                _recordsView(),
                _analyticsView(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _recordsView() => ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
        children: [
          const PipeBuyerPageHeader(
            eyebrow: 'PRIVATE DISPATCH RECORDS',
            title: 'Credentials & insurance',
            subtitle:
                'Keep policy, certificate and supporting-document information organized without publishing private numbers, coverage amounts or files to the Directory.',
            icon: Icons.verified_user_outlined,
          ),
          const SizedBox(height: 12),
          const PipeBuyerSectionCard(
            title: 'Privacy boundary',
            subtitle:
                'Credential metadata is stored only in your private business record. Evidence images use the existing private business-document storage area.',
            leading: Icon(
              Icons.lock_outline,
              color: PipeBuyerColors.orange,
            ),
            child: Text(
              'Self-reported status and coverage are not Pipe Buyer verification. Future verification results must come from a protected review workflow before any public verified badge is shown.',
            ),
          ),
          const SizedBox(height: 12),
          ..._records.map(_credentialCard),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving ? 'Saving...' : 'Save all credential metadata',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Credential evidence uploads on this screen currently accept images. The private storage boundary also supports PDF documents for a future file-picker workflow.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PipeBuyerColors.muted, fontSize: 11),
          ),
        ],
      );

  Widget _analyticsView() {
    final now = DateTime.now();
    final current =
        _records.where((record) => record.isCurrentOn(now)).toList();
    final expired = _records.where((record) {
      final days = record.daysUntilExpiry(now);
      return record.state == DispatchCredentialSelfReportedState.expired ||
          (record.state == DispatchCredentialSelfReportedState.current &&
              days != null &&
              days < 0);
    }).toList();
    final missing = _records
        .where(
          (record) =>
              record.state == DispatchCredentialSelfReportedState.notProvided,
        )
        .toList();
    final complete = _records.length - missing.length;
    final readiness = _records.isEmpty ? 0.0 : complete / _records.length;
    final evidenceRecords =
        _records.where((record) => record.hasPrivateEvidence).toList();
    final insurance =
        _records.where((record) => record.type.isInsurance).toList();
    final insuranceWithLimits = insurance
        .where(
          (record) => record.isCurrentOn(now) && record.hasDeclaredCoverage,
        )
        .toList();
    final insuredWithLimits = insuranceWithLimits.length;
    final upcoming = _records.where((record) {
      final days = record.daysUntilExpiry(now);
      return record.state == DispatchCredentialSelfReportedState.current &&
          days != null &&
          days >= 0;
    }).toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
    final recommendations = _credentialRecommendations(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
      children: [
        const PipeBuyerPageHeader(
          eyebrow: 'PRIVATE BUSINESS INTELLIGENCE',
          title: 'Credential analytics & alerts',
          subtitle:
              'See expiry risk, record completeness, private evidence coverage and insurance matching readiness without exposing private policy details.',
          icon: Icons.insights_outlined,
        ),
        const SizedBox(height: 12),
        PipeBuyerSectionCard(
          title: 'Credential readiness',
          subtitle:
              'This is an account-completeness aid, not a trust score or Pipe Buyer verification rating.',
          leading: const Icon(Icons.fact_check_outlined),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: readiness),
              const SizedBox(height: 8),
              Text(
                '${(readiness * 100).round()}% of credential records addressed',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select any status tile below to see the credential records behind the number and take action.',
                style: TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metricTile(
                    label: 'Current',
                    records: current,
                    icon: Icons.check_circle_outline,
                    emptyMessage:
                        'No credentials are currently marked current.',
                  ),
                  _metricTile(
                    label: 'Expired',
                    records: expired,
                    icon: Icons.event_busy_outlined,
                    emptyMessage:
                        'No supplied credential is currently expired.',
                  ),
                  _metricTile(
                    label: 'Not provided',
                    records: missing,
                    icon: Icons.help_outline,
                    emptyMessage: 'Every credential record has been addressed.',
                  ),
                  _metricTile(
                    label: 'Evidence files',
                    records: evidenceRecords,
                    icon: Icons.lock_outline,
                    emptyMessage:
                        'No private credential evidence is currently on file.',
                  ),
                  _metricTile(
                    label: 'Insurance limits',
                    records: insuranceWithLimits,
                    icon: Icons.shield_outlined,
                    emptyMessage:
                        'No current insurance record has a declared primary coverage limit.',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PipeBuyerSectionCard(
          title: 'Expiry reminders',
          subtitle:
              'Choose when Pipe Buyer should create credential-expiry notifications. Reminder preferences and expiry dates stay private.',
          leading: const Icon(
            Icons.notifications_active_outlined,
            color: PipeBuyerColors.orange,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _reminderSettings.enabled,
                title: const Text(
                  'Credential expiry reminders',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'The server checks only scheduled due dates; it does not publish credential data.',
                ),
                onChanged: (value) => setState(() {
                  _reminderSettings =
                      _reminderSettings.copyWith(enabled: value);
                }),
              ),
              const SizedBox(height: 6),
              const Text(
                'Remind me before expiry:',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: dispatchCredentialReminderDayOptions.map((days) {
                  final selected =
                      _reminderSettings.reminderDays.contains(days);
                  return FilterChip(
                    selected: selected,
                    label: Text('$days day${days == 1 ? '' : 's'}'),
                    onSelected: !_reminderSettings.enabled
                        ? null
                        : (value) {
                            final updated = [..._reminderSettings.reminderDays];
                            if (value) {
                              updated.add(days);
                            } else if (updated.length > 1) {
                              updated.remove(days);
                            }
                            setState(() {
                              _reminderSettings = _reminderSettings.copyWith(
                                reminderDays: updated,
                              );
                            });
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                'Device notifications: ${_notificationStatusLabel(_notificationStatus)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed:
                        _savingReminderSettings ? null : _saveReminderSettings,
                    icon: _savingReminderSettings
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save reminder settings'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _notificationStatus ==
                                MarketplaceNotificationStatus.enabled ||
                            _enablingNotifications
                        ? null
                        : _enableDeviceNotifications,
                    icon: _enablingNotifications
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.notifications_outlined),
                    label: const Text('Enable device notifications'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PipeBuyerSectionCard(
          title: 'Insurance matching readiness',
          subtitle:
              'Customers will be able to require a minimum self-reported insurance amount when requesting Dispatch service.',
          leading: const Icon(Icons.rule_folder_outlined),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$insuredWithLimits of ${insurance.length} insurance categories currently have a usable declared coverage limit.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              const Text(
                'Exact policy numbers and coverage amounts remain private. The matching layer will compare a request minimum to the provider record server-side and return eligible providers instead of publishing the private amount. Currency must match unless a future approved FX service performs conversion.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PipeBuyerSectionCard(
          title: 'Upcoming expiries',
          subtitle: upcoming.isEmpty
              ? 'No current credential has a supplied future expiry date.'
              : 'The nearest supplied expiry dates are listed first.',
          leading: const Icon(Icons.calendar_month_outlined),
          child: upcoming.isEmpty
              ? const Text('Add expiry dates to receive useful renewal alerts.')
              : Column(
                  children: upcoming.take(8).map((record) {
                    final days = record.daysUntilExpiry(now) ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(record.type.icon),
                      title: Text(record.type.label),
                      subtitle: Text('Expires ${record.expiryLabel}'),
                      trailing: Text(
                        days == 0 ? 'TODAY' : '$days d',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: days <= 30
                              ? PipeBuyerColors.orangePressed
                              : PipeBuyerColors.muted,
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 12),
        PipeBuyerSectionCard(
          title: 'Suggested next actions',
          subtitle:
              'These recommendations are calculated only from your private credential records.',
          leading: const Icon(Icons.lightbulb_outline),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: recommendations
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.arrow_right_rounded,
                          color: PipeBuyerColors.orange,
                        ),
                        const SizedBox(width: 5),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  List<String> _credentialRecommendations(DateTime now) {
    final recommendations = <String>[];
    final missing = _records
        .where(
          (record) =>
              record.state == DispatchCredentialSelfReportedState.notProvided,
        )
        .length;
    if (missing > 0) {
      recommendations.add(
        'Review $missing credential record${missing == 1 ? '' : 's'} that still show Not provided.',
      );
    }
    final insuranceWithoutLimit = _records
        .where(
          (record) =>
              record.type.isInsurance &&
              record.isCurrentOn(now) &&
              !record.hasDeclaredCoverage,
        )
        .length;
    if (insuranceWithoutLimit > 0) {
      recommendations.add(
        'Add primary coverage limits to $insuranceWithoutLimit current insurance record${insuranceWithoutLimit == 1 ? '' : 's'} so future minimum-insurance matching can evaluate them.',
      );
    }
    final expiringSoon = _records.where((record) {
      final days = record.daysUntilExpiry(now);
      return record.state == DispatchCredentialSelfReportedState.current &&
          days != null &&
          days >= 0 &&
          days <= 30;
    }).length;
    if (expiringSoon > 0) {
      recommendations.add(
        '$expiringSoon credential${expiringSoon == 1 ? '' : 's'} expire within 30 days. Start renewal or update the record.',
      );
    }
    final missingEvidence = _records
        .where(
          (record) =>
              record.state == DispatchCredentialSelfReportedState.current &&
              !record.hasPrivateEvidence,
        )
        .length;
    if (missingEvidence > 0) {
      recommendations.add(
        'Consider uploading private supporting evidence for $missingEvidence current credential${missingEvidence == 1 ? '' : 's'}. Evidence remains private and does not create verification.',
      );
    }
    if (!_reminderSettings.enabled) {
      recommendations.add(
        'Turn on credential expiry reminders if you want Pipe Buyer to alert you before supplied expiry dates.',
      );
    }
    if (recommendations.isEmpty) {
      recommendations.add(
        'Your supplied credential records currently have no obvious completeness or expiry action.',
      );
    }
    return recommendations;
  }

  String _analyticsRecordSummary(DispatchCredentialRecord record) {
    final parts = <String>[record.state.label];
    if (record.expiryDate != null) parts.add('Expiry ${record.expiryLabel}');
    if (record.hasDeclaredCoverage) parts.add(record.coverageLabel);
    parts.add(
      record.hasPrivateEvidence
          ? 'Private evidence on file'
          : 'No private evidence',
    );
    return parts.join(' | ');
  }

  String _metricExplanation(String label) => switch (label) {
        'Current' =>
          'Credentials currently marked current from your private self-reported records.',
        'Expired' =>
          'Credentials marked expired or whose supplied expiry date has passed.',
        'Not provided' =>
          'Credential categories that still need a status or supporting information.',
        'Evidence files' =>
          'Credential records with a private supporting image on file. These files are not public verification.',
        'Insurance limits' =>
          'Current insurance records with a declared primary coverage limit for future private matching.',
        _ => 'Credential records included in this private analytics total.',
      };

  Future<void> _showCredentialMetricDetails({
    required String label,
    required List<DispatchCredentialRecord> records,
    required IconData icon,
    required String emptyMessage,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final listHeight = records.isEmpty
            ? 96.0
            : (records.length * 82.0).clamp(96.0, 410.0).toDouble();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: PipeBuyerColors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$label (${records.length})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_metricExplanation(label)),
                const SizedBox(height: 12),
                SizedBox(
                  height: listHeight,
                  child: records.isEmpty
                      ? Center(child: Text(emptyMessage))
                      : ListView.separated(
                          itemCount: records.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final record = records[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(record.type.icon),
                              title: Text(record.type.label),
                              subtitle: Text(_analyticsRecordSummary(record)),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                Future<void>.delayed(Duration.zero, () async {
                                  if (!mounted) return;
                                  await _showCredentialQuickActions(record);
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCredentialQuickActions(
    DispatchCredentialRecord record,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(record.type.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_analyticsRecordSummary(record)),
            if (record.issuer.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Issuer: ${record.issuer}'),
            ],
            if (record.hasPrivateEvidence) ...[
              const SizedBox(height: 8),
              const Text(
                'Private evidence is on file for this credential. You can replace or remove it here.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          if (record.hasPrivateEvidence)
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop('remove_evidence'),
              child: const Text('Remove evidence'),
            ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop('evidence'),
            child: Text(
              record.hasPrivateEvidence
                  ? 'Replace evidence'
                  : 'Upload evidence',
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('edit'),
            child: const Text('Edit metadata'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        await _editMetadata(record);
        break;
      case 'evidence':
        await _uploadEvidence(record);
        break;
      case 'remove_evidence':
        await _removeEvidence(record);
        break;
    }
  }

  Widget _metricTile({
    required String label,
    required List<DispatchCredentialRecord> records,
    required IconData icon,
    required String emptyMessage,
  }) {
    final value = records.length;
    return Semantics(
      button: true,
      label: '$label: $value. View credential details.',
      child: SizedBox(
        width: 190,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _showCredentialMetricDetails(
                label: label,
                records: records,
                icon: icon,
                emptyMessage: emptyMessage,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$value',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'View details',
                          style: TextStyle(
                            color: PipeBuyerColors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _credentialCard(DispatchCredentialRecord record) {
    final uploading = _uploadingType == record.type;
    final days = record.daysUntilExpiry();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(record.type.icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.type.label,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(record.state.label),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _editMetadata(record),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ],
              ),
              if (record.issuer.isNotEmpty ||
                  record.referenceNumber.isNotEmpty ||
                  record.expiryDate != null ||
                  record.hasDeclaredCoverage) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    if (record.issuer.isNotEmpty)
                      Text('Issuer: ${record.issuer}'),
                    if (record.referenceNumber.isNotEmpty)
                      Text('Reference: ${record.referenceNumber}'),
                    if (record.expiryDate != null)
                      Text(
                        days != null && days < 0
                            ? 'Expiry: ${record.expiryLabel} (expired)'
                            : 'Expiry: ${record.expiryLabel}',
                      ),
                    if (record.hasDeclaredCoverage)
                      Text('Coverage: ${record.coverageLabel}'),
                    if (record.aggregateLimit != null)
                      Text('Aggregate: ${record.aggregateCoverageLabel}'),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: uploading ? null : () => _uploadEvidence(record),
                    icon: uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(
                      record.hasPrivateEvidence
                          ? 'Replace private evidence'
                          : 'Upload private evidence',
                    ),
                  ),
                  if (record.hasPrivateEvidence)
                    TextButton.icon(
                      onPressed:
                          uploading ? null : () => _removeEvidence(record),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove evidence'),
                    ),
                ],
              ),
              if (record.hasPrivateEvidence) ...[
                const SizedBox(height: 6),
                const Text(
                  'Private evidence on file - visible only to the account owner and authorized administrators.',
                  style: TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

List<int> _normalizeReminderDays(Iterable<int> values) {
  final result = values
      .where((value) => value >= 1 && value <= 365)
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));
  return result.isEmpty ? [...dispatchCredentialReminderDayOptions] : result;
}

String _normalizeCurrency(String value) {
  final normalized = value.trim().toUpperCase();
  return RegExp(r'^[A-Z]{3}$').hasMatch(normalized) ? normalized : 'CAD';
}

double? _parseCoverageAmount(String value) {
  final normalized =
      value.replaceAll(',', '').replaceAll(r'$', '').replaceAll(' ', '').trim();
  final parsed = double.tryParse(normalized);
  return parsed != null && parsed > 0 ? parsed : null;
}

String _formatWholeMoney(double value) {
  final whole = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) buffer.write(',');
    buffer.write(whole[index]);
  }
  return '\$${buffer.toString()}';
}

String _notificationStatusLabel(MarketplaceNotificationStatus status) =>
    switch (status) {
      MarketplaceNotificationStatus.enabled => 'Enabled',
      MarketplaceNotificationStatus.notEnabled => 'Not enabled',
      MarketplaceNotificationStatus.denied => 'Denied by this device',
      MarketplaceNotificationStatus.unsupported => 'Unsupported on this device',
      MarketplaceNotificationStatus.missingWebConfiguration =>
        'Web notification configuration missing',
      MarketplaceNotificationStatus.unavailable => 'Unavailable',
    };
