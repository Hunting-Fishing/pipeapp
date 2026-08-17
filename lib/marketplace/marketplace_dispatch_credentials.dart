import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';

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
        DispatchCredentialType.workersCompensation => Icons.health_and_safety_outlined,
        DispatchCredentialType.operatingAuthority => Icons.badge_outlined,
        DispatchCredentialType.safetyCertificate => Icons.fact_check_outlined,
        DispatchCredentialType.pilotEscortCertification =>
          Icons.assistant_direction_outlined,
        DispatchCredentialType.craneRiggingQualification =>
          Icons.construction_outlined,
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
    );
  }

  final DispatchCredentialType type;
  final DispatchCredentialSelfReportedState state;
  final String issuer;
  final String referenceNumber;
  final DateTime? expiryDate;
  final String notes;
  final String documentStoragePath;

  bool get hasPrivateEvidence => documentStoragePath.trim().isNotEmpty;

  String get expiryLabel {
    final value = expiryDate;
    if (value == null) return 'No expiry date supplied';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  DispatchCredentialRecord copyWith({
    DispatchCredentialSelfReportedState? state,
    String? issuer,
    String? referenceNumber,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    String? notes,
    String? documentStoragePath,
  }) {
    return DispatchCredentialRecord(
      type: type,
      state: state ?? this.state,
      issuer: issuer ?? this.issuer,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      expiryDate: clearExpiryDate ? null : expiryDate ?? this.expiryDate,
      notes: notes ?? this.notes,
      documentStoragePath: documentStoragePath ?? this.documentStoragePath,
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
      };

  static DispatchCredentialSelfReportedState _stateFromCode(String code) {
    final normalized = code.trim();
    for (final value in DispatchCredentialSelfReportedState.values) {
      if (value.code == normalized) return value;
    }
    return DispatchCredentialSelfReportedState.notProvided;
  }
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

  Future<List<DispatchCredentialRecord>> load() async {
    final snapshot =
        await _firestore.collection('business_private').doc(_uid).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final rawCredentials = _nestedMap(data['dispatchCredentials']);

    return DispatchCredentialType.values
        .map((type) {
          final raw = _nestedMap(rawCredentials[type.code]);
          return raw.isEmpty
              ? DispatchCredentialRecord.empty(type)
              : DispatchCredentialRecord.fromPrivateMap(type, raw);
        })
        .toList(growable: false);
  }

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
      throw StateError('Credential evidence path is outside the private owner area.');
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
  final ImagePicker _picker = ImagePicker();

  late Future<List<DispatchCredentialRecord>> _loadFuture;
  List<DispatchCredentialRecord> _records = const [];
  bool _saving = false;
  DispatchCredentialType? _uploadingType;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<List<DispatchCredentialRecord>> _load() async {
    final records = await _repository.load();
    if (mounted) _records = records;
    return records;
  }

  void _replaceRecord(DispatchCredentialRecord record) {
    setState(() {
      _records = _records
          .map((item) => item.type == record.type ? record : item)
          .toList(growable: false);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repository.save(_records);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Private credential metadata saved.')),
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
      await _repository.save(_records);
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
      await _repository.save(_records);
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
    final notes = TextEditingController(text: record.notes);
    var state = record.state;

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

            return AlertDialog(
              title: Text(record.type.label),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<DispatchCredentialSelfReportedState>(
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
                                  onPressed: () =>
                                      setDialogState(expiry.clear),
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
                    Navigator.of(dialogContext).pop(
                      record.copyWith(
                        state: state,
                        issuer: issuer.text,
                        referenceNumber: reference.text,
                        expiryDate: DateTime.tryParse(expiry.text.trim()),
                        clearExpiryDate: expiry.text.trim().isEmpty,
                        notes: notes.text,
                      ),
                    );
                  },
                  child: const Text('Save metadata'),
                ),
              ],
            );
          },
        ),
      );
      if (!mounted || updated == null) return;
      _replaceRecord(updated);
    } finally {
      issuer.dispose();
      reference.dispose();
      expiry.dispose();
      notes.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Credentials & insurance')),
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
            children: [
              const PipeBuyerPageHeader(
                eyebrow: 'PRIVATE DISPATCH RECORDS',
                title: 'Credentials & insurance',
                subtitle:
                    'Keep policy, certificate and supporting-document information organized without publishing private numbers or files to the Directory.',
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
                  'Self-reported status is not Pipe Buyer verification. Future verification results must come from a protected review workflow before any public verified badge is shown.',
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
        },
      ),
    );
  }

  Widget _credentialCard(DispatchCredentialRecord record) {
    final uploading = _uploadingType == record.type;
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
                  record.expiryDate != null) ...[
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
                      Text('Expiry: ${record.expiryLabel}'),
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
                      onPressed: uploading ? null : () => _removeEvidence(record),
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
