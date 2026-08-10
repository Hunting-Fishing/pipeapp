import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import 'marketplace_command_client.dart';

class MarketplaceTaxProfilePage extends StatefulWidget {
  const MarketplaceTaxProfilePage({super.key});

  @override
  State<MarketplaceTaxProfilePage> createState() =>
      _MarketplaceTaxProfilePageState();
}

class _MarketplaceTaxProfilePageState extends State<MarketplaceTaxProfilePage> {
  final _commands = MarketplaceCommandClient();
  final _formKey = GlobalKey<FormState>();
  final _legalName = TextEditingController();
  final _country = TextEditingController(text: 'CA');
  final _region = TextEditingController(text: 'BC');
  final _businessNumber = TextEditingController();
  final _gstHstNumber = TextEditingController();
  final _pstBcNumber = TextEditingController();
  final _certificateReference = TextEditingController();
  final _intendedUse = TextEditingController();
  final _transactionId = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _submittingClaim = false;
  bool _uploadingEvidence = false;
  bool _responsibilityAcknowledged = false;
  bool _claimAcknowledged = false;
  String _sellerGstStatus = 'pending';
  String _businessNumberStatus = 'not_provided';
  String _gstHstStatus = 'not_provided';
  String _pstBcStatus = 'not_provided';
  String _responsibilitySummary = '';
  String _exemptionType = 'resale';
  String _evidenceStoragePath = '';
  List<Map<String, dynamic>> _exemptionTypes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _legalName,
      _country,
      _region,
      _businessNumber,
      _gstHstNumber,
      _pstBcNumber,
      _certificateReference,
      _intendedUse,
      _transactionId,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final result = await _commands.execute('getMarketplaceTaxProfile', const {});
      final profile = _map(result['profile']);
      final types = result['exemptionTypes'];
      if (!mounted) return;
      setState(() {
        _legalName.text = '${profile['legalBusinessName'] ?? ''}';
        _country.text = '${profile['countryCode'] ?? 'CA'}';
        _region.text = '${profile['regionCode'] ?? 'BC'}';
        _businessNumber.text = '${profile['businessNumber'] ?? ''}';
        _gstHstNumber.text = '${profile['gstHstNumber'] ?? ''}';
        _pstBcNumber.text = '${profile['pstBcNumber'] ?? ''}';
        _businessNumberStatus =
            '${profile['businessNumberStatus'] ?? 'not_provided'}';
        _gstHstStatus = '${profile['gstHstStatus'] ?? 'not_provided'}';
        _pstBcStatus = '${profile['pstBcStatus'] ?? 'not_provided'}';
        _sellerGstStatus =
            '${profile['sellerNormalGstHstRegistered'] ?? 'pending'}';
        _responsibilityAcknowledged =
            '${profile['taxResponsibilityPolicyVersion'] ?? ''}'.isNotEmpty;
        _responsibilitySummary = '${result['responsibilitySummary'] ?? ''}';
        _exemptionTypes = types is List
            ? types
                .whereType<Map>()
                .map((value) => Map<String, dynamic>.from(value))
                .toList(growable: false)
            : const [];
        if (_exemptionTypes.isNotEmpty &&
            !_exemptionTypes.any((item) => item['value'] == _exemptionType)) {
          _exemptionType = '${_exemptionTypes.first['value']}';
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(
          error,
          fallback: 'Your private tax profile could not be loaded.',
        ),
        tone: PipeStatusTone.error,
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_responsibilityAcknowledged) {
      PipeFeedback.show(
        context,
        message: 'Accept the tax information and responsibility terms first.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _commands.execute('updateMarketplaceTaxProfile', {
        'legalBusinessName': _legalName.text.trim(),
        'countryCode': _country.text.trim().toUpperCase(),
        'regionCode': _region.text.trim().toUpperCase(),
        'businessNumber': _businessNumber.text.trim(),
        'gstHstNumber': _gstHstNumber.text.trim(),
        'pstBcNumber': _pstBcNumber.text.trim(),
        'sellerNormalGstHstRegistered': _sellerGstStatus,
        'taxResponsibilityAcknowledged': true,
      });
      final verification = _map(result['verification']);
      if (!mounted) return;
      setState(() {
        _businessNumberStatus =
            '${verification['businessNumberStatus'] ?? _businessNumberStatus}';
        _gstHstStatus = '${verification['gstHstStatus'] ?? _gstHstStatus}';
        _pstBcStatus = '${verification['pstBcStatus'] ?? _pstBcStatus}';
      });
      PipeFeedback.show(
        context,
        message:
            'Tax profile saved. New or changed tax numbers require administrator verification.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The tax profile could not be saved.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickEvidence() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _uploadingEvidence) return;
    setState(() => _uploadingEvidence = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 15 * 1024 * 1024) {
        throw StateError('Tax evidence images must be smaller than 15 MB.');
      }
      final safeName = picked.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final fileName =
          'tax_${DateTime.now().millisecondsSinceEpoch}_${safeName.isEmpty ? 'evidence.jpg' : safeName}';
      final path = 'business_documents/${user.uid}/$fileName';
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(
        bytes,
        SettableMetadata(contentType: picked.mimeType ?? 'image/jpeg'),
      );
      if (!mounted) return;
      setState(() => _evidenceStoragePath = path);
      PipeFeedback.show(
        context,
        message: 'Tax exemption evidence uploaded privately for review.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: error is StateError
              ? error.message
              : 'The tax evidence image could not be uploaded.',
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingEvidence = false);
    }
  }

  Future<void> _submitExemption() async {
    if (_intendedUse.text.trim().isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Describe how the purchased goods will be used.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    if (!_claimAcknowledged) {
      PipeFeedback.show(
        context,
        message: 'Certify the exemption claim before submitting it.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    setState(() => _submittingClaim = true);
    try {
      final result = await _commands.execute(
        'submitMarketplaceTaxExemptionClaim',
        {
          'jurisdiction': 'CA-BC',
          'exemptionType': _exemptionType,
          'certificateReference': _certificateReference.text.trim(),
          'evidenceStoragePath': _evidenceStoragePath,
          'intendedUse': _intendedUse.text.trim(),
          'transactionId': _transactionId.text.trim(),
          'claimAcknowledged': true,
        },
      );
      if (!mounted) return;
      setState(() {
        _claimAcknowledged = false;
        _certificateReference.clear();
        _intendedUse.clear();
        _transactionId.clear();
        _evidenceStoragePath = '';
      });
      PipeFeedback.show(
        context,
        message:
            'Exemption claim ${result['claimId'] ?? ''} submitted for Pipe Buyer review. No tax is removed until it is approved.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The exemption claim could not be submitted.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submittingClaim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Tax & Exemptions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.security_outlined),
                      title: Text('Private tax profile'),
                      subtitle: Text(
                        'Tax IDs and exemption documents are private. A PST number does not automatically make a transaction PST-exempt; exemption claims require evidence and review.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(_legalName, 'Legal business / entity name', required: true),
                  Row(children: [
                    Expanded(child: _field(_country, 'Country code', required: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _field(_region, 'Province / state', required: true)),
                  ]),
                  _taxField(
                    controller: _businessNumber,
                    label: 'Business Number (BN)',
                    status: _businessNumberStatus,
                  ),
                  _taxField(
                    controller: _gstHstNumber,
                    label: 'GST/HST registration number',
                    status: _gstHstStatus,
                  ),
                  _taxField(
                    controller: _pstBcNumber,
                    label: 'B.C. PST registration number',
                    status: _pstBcStatus,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _sellerGstStatus,
                    decoration: const InputDecoration(
                      labelText: 'Registered under normal GST/HST regime?',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'yes', child: Text('Yes')),
                      DropdownMenuItem(value: 'no', child: Text('No')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending / unsure')),
                    ],
                    onChanged: (value) =>
                        setState(() => _sellerGstStatus = value ?? 'pending'),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    color: const Color(0xFFFFF7E6),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tax information responsibility',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 7),
                          Text(_responsibilitySummary),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _responsibilityAcknowledged,
                            onChanged: (value) => setState(() =>
                                _responsibilityAcknowledged = value == true),
                            title: const Text(
                              'I certify this tax information is complete and accurate and accept the tax responsibility terms.',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save private tax profile'),
                  ),
                  const SizedBox(height: 26),
                  const Divider(),
                  const Text(
                    'B.C. PST exemption claim',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Claims are reviewed per transaction/use. Pipe Buyer does not remove PST solely because a PST number was entered.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _exemptionType,
                    decoration: const InputDecoration(labelText: 'Exemption type'),
                    items: (_exemptionTypes.isEmpty
                            ? const [
                                {'value': 'resale', 'label': 'Purchase for resale'},
                                {
                                  'value': 'production_machinery_equipment',
                                  'label': 'Production machinery and equipment'
                                },
                                {
                                  'value': 'oil_gas_pme',
                                  'label': 'Oil & gas qualifying PM&E'
                                },
                                {
                                  'value': 'goods_shipped_out_of_bc',
                                  'label': 'Goods shipped out of B.C.'
                                },
                              ]
                            : _exemptionTypes)
                        .map((item) => DropdownMenuItem<String>(
                              value: '${item['value']}',
                              child: Text('${item['label']}'),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _exemptionType = value ?? 'resale'),
                  ),
                  const SizedBox(height: 10),
                  _field(
                    _certificateReference,
                    'Certificate / exemption reference',
                    hint: 'Example: FIN 490, FIN 492, FIN 464 or certificate reference',
                  ),
                  _field(
                    _intendedUse,
                    'How will the goods be used?',
                    required: true,
                    maxLines: 4,
                  ),
                  _field(
                    _transactionId,
                    'Marketplace transaction ID (optional until checkout)',
                  ),
                  OutlinedButton.icon(
                    onPressed: _uploadingEvidence ? null : _pickEvidence,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(_uploadingEvidence
                        ? 'Uploading evidence…'
                        : _evidenceStoragePath.isEmpty
                            ? 'Upload certificate/evidence image'
                            : 'Evidence uploaded • replace image'),
                  ),
                  if (_evidenceStoragePath.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Evidence is stored privately and can be read only by the account owner and MFA administrators.',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _claimAcknowledged,
                    onChanged: (value) =>
                        setState(() => _claimAcknowledged = value == true),
                    title: const Text(
                      'I certify the exemption claim, intended use, delivery facts and supporting evidence are accurate.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  FilledButton.icon(
                    onPressed: _submittingClaim ? null : _submitExemption,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: Text(_submittingClaim
                        ? 'Submitting…'
                        : 'Submit exemption for review'),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool required = false,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, hintText: hint),
          validator: required
              ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
              : null,
        ),
      );

  Widget _taxField({
    required TextEditingController controller,
    required String label,
    required String status,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: Tooltip(
              message: status.replaceAll('_', ' '),
              child: Icon(
                status == 'verified'
                    ? Icons.verified_outlined
                    : status == 'invalid'
                        ? Icons.error_outline
                        : Icons.schedule_outlined,
                color: status == 'verified'
                    ? Colors.green
                    : status == 'invalid'
                        ? Colors.red
                        : Colors.orange,
              ),
            ),
            helperText: 'Verification: ${status.replaceAll('_', ' ')}',
          ),
        ),
      );
}
