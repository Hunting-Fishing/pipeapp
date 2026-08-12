import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import 'marketplace_command_client.dart';

class MarketplaceTaxComplianceAdminPage extends StatefulWidget {
  const MarketplaceTaxComplianceAdminPage({super.key});

  @override
  State<MarketplaceTaxComplianceAdminPage> createState() =>
      _MarketplaceTaxComplianceAdminPageState();
}

class _MarketplaceTaxComplianceAdminPageState
    extends State<MarketplaceTaxComplianceAdminPage> {
  final _commands = MarketplaceCommandClient();
  final _recoveryTransaction = TextEditingController();
  final _recoveryAmount = TextEditingController();
  final _recoveryReason = TextEditingController();
  final _recoveryAuthority = TextEditingController();

  bool _loading = true;
  bool _creatingRecovery = false;
  String? _error;
  Map<String, dynamic> _counts = const {};
  List<Map<String, dynamic>> _profiles = const [];
  List<Map<String, dynamic>> _claims = const [];
  List<Map<String, dynamic>> _recoveryCases = const [];
  String _responsibleParty = 'seller';
  String _taxType = 'bc_pst';
  String _currency = 'CAD';

  Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
      : const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _recoveryTransaction.dispose();
    _recoveryAmount.dispose();
    _recoveryReason.dispose();
    _recoveryAuthority.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final values = await Future.wait([
        _commands.execute('getMarketplaceTaxComplianceAdmin', const {}),
        _commands.execute('getMarketplaceTaxRegistrationAdmin', const {}),
        _commands.execute('getMarketplaceTaxRecoveryAdmin', const {}),
      ]);
      if (!mounted) return;
      setState(() {
        _counts = _map(values[0]['counts']);
        _claims = _list(values[0]['pendingClaims']);
        _profiles = _list(values[1]['pendingProfiles']);
        _recoveryCases = _list(values[2]['openCases']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Tax compliance records could not be loaded.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _reviewNumber(
    Map<String, dynamic> profile,
    String field,
    String label,
  ) async {
    final current = '${profile[field] ?? ''}'.trim();
    if (current.isEmpty) return;
    String status = 'verified';
    final note = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Review $label'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  current,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Decision'),
                  items: const [
                    DropdownMenuItem(
                      value: 'verified',
                      child: Text('Verified'),
                    ),
                    DropdownMenuItem(value: 'invalid', child: Text('Invalid')),
                    DropdownMenuItem(
                      value: 'review_required',
                      child: Text('Further review required'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => status = value ?? 'review_required',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Verification source / review note',
                    hintText:
                        'Record the official lookup, supporting document, date, or reason.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save review'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) {
      note.dispose();
      return;
    }
    try {
      await _commands.execute('reviewMarketplaceTaxRegistration', {
        'uid': '${profile['uid'] ?? ''}',
        'field': field,
        'status': status,
        'reviewNote': note.text.trim(),
      });
      if (mounted) {
        PipeFeedback.show(
          context,
          message: '$label review saved.',
          tone: PipeStatusTone.success,
        );
        await _load();
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The tax registration review could not be saved.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      note.dispose();
    }
  }

  Future<void> _openEvidence(String path) async {
    if (path.isEmpty) return;
    try {
      final ref = FirebaseStorage.instance.ref(path);
      final metadata = await ref.getMetadata();
      if (metadata.contentType?.startsWith('image/') != true) {
        throw StateError(
          'This evidence format requires a controlled document viewer.',
        );
      }
      final bytes = await ref.getData(15 * 1024 * 1024);
      if (bytes == null || !mounted) {
        throw StateError('The evidence file is unavailable.');
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  automaticallyImplyLeading: true,
                  title: const Text('Private tax evidence'),
                  actions: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: error is StateError
              ? error.message
              : 'The private evidence file could not be opened.',
          tone: PipeStatusTone.error,
        );
      }
    }
  }

  Future<void> _reviewClaim(Map<String, dynamic> claim) async {
    String status = 'approved';
    bool evidenceVerified = false;
    final note = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review B.C. PST exemption'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Type: ${claim['exemptionType'] ?? ''}'),
                  Text('Jurisdiction: ${claim['jurisdiction'] ?? ''}'),
                  if ('${claim['certificateReference'] ?? ''}'.isNotEmpty)
                    Text('Certificate: ${claim['certificateReference']}'),
                  if ('${claim['transactionId'] ?? ''}'.isNotEmpty)
                    Text('Transaction: ${claim['transactionId']}'),
                  const SizedBox(height: 8),
                  Text('${claim['intendedUse'] ?? ''}'),
                  const SizedBox(height: 12),
                  if ('${claim['evidenceStoragePath'] ?? ''}'.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => _openEvidence(
                        '${claim['evidenceStoragePath'] ?? ''}',
                      ),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View private supporting evidence'),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: evidenceVerified,
                    onChanged: (value) => setDialogState(
                      () => evidenceVerified = value == true,
                    ),
                    title: const Text(
                      'I reviewed the required exemption evidence and transaction facts.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Decision'),
                    items: const [
                      DropdownMenuItem(
                        value: 'approved',
                        child: Text('Approve'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Reject'),
                      ),
                      DropdownMenuItem(
                        value: 'needs_info',
                        child: Text('Need more information'),
                      ),
                    ],
                    onChanged: (value) => setDialogState(
                      () => status = value ?? 'needs_info',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Review note',
                      hintText:
                          'Document why the exemption qualifies or why it was rejected.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save decision'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) {
      note.dispose();
      return;
    }
    try {
      await _commands.execute('reviewMarketplaceTaxExemptionClaim', {
        'claimId': '${claim['id'] ?? ''}',
        'status': status,
        'evidenceVerified': evidenceVerified,
        'reviewNote': note.text.trim(),
      });
      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Exemption review saved.',
          tone: PipeStatusTone.success,
        );
        await _load();
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The exemption review could not be saved.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      note.dispose();
    }
  }

  Future<void> _createRecoveryCase() async {
    final majorAmount = double.tryParse(_recoveryAmount.text.trim());
    if (_recoveryTransaction.text.trim().isEmpty ||
        majorAmount == null ||
        majorAmount <= 0 ||
        _recoveryReason.text.trim().length < 12) {
      PipeFeedback.show(
        context,
        message:
            'Enter the transaction ID, positive recovery amount, and a detailed reason.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    final amountMinor = (majorAmount * 100).round();
    setState(() => _creatingRecovery = true);
    try {
      final result = await _commands.execute(
        'createMarketplaceTaxRecoveryCase',
        {
          'transactionId': _recoveryTransaction.text.trim(),
          'responsibleParty': _responsibleParty,
          'taxType': _taxType,
          'currency': _currency,
          'amountMinor': amountMinor,
          'reason': _recoveryReason.text.trim(),
          'authorityReference': _recoveryAuthority.text.trim(),
        },
      );
      if (!mounted) return;
      _recoveryTransaction.clear();
      _recoveryAmount.clear();
      _recoveryReason.clear();
      _recoveryAuthority.clear();
      PipeFeedback.show(
        context,
        message:
            'Tax recovery case ${result['caseId'] ?? ''} opened. Compliance holds are active; no stored card was charged.',
        tone: PipeStatusTone.success,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The tax recovery case could not be created.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _creatingRecovery = false);
    }
  }

  Future<void> _resolveRecovery(Map<String, dynamic> recoveryCase) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Resolve tax recovery case'),
            content: TextField(
              controller: note,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Resolution note',
                hintText:
                    'Record payment, authority disposition, correction, or other basis for closing this case.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Resolve case'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      note.dispose();
      return;
    }
    try {
      await _commands.execute('resolveMarketplaceTaxRecoveryCase', {
        'caseId': '${recoveryCase['id'] ?? ''}',
        'resolution': note.text.trim(),
      });
      if (mounted) {
        PipeFeedback.show(
          context,
          message: 'Tax recovery case resolved and eligible holds re-evaluated.',
          tone: PipeStatusTone.success,
        );
        await _load();
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The tax recovery case could not be resolved.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      note.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Compliance Queue'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.gavel_outlined),
                        title: Text('MFA administrator verification required'),
                        subtitle: Text(
                          'User-entered tax IDs and PST exemption claims never self-approve. Record the official verification source and retain exemption evidence before approval.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _countChip('Profiles', _counts['profiles']),
                        _countChip('PST pending', _counts['pstPending']),
                        _countChip('PST verified', _counts['pstVerified']),
                        _countChip('GST pending', _counts['gstPending']),
                        _countChip('GST verified', _counts['gstVerified']),
                        _countChip(
                          'Exemptions pending',
                          _counts['exemptionPending'],
                        ),
                        _countChip(
                          'Exemptions approved',
                          _counts['exemptionApproved'],
                        ),
                        _countChip('Open recoveries', _recoveryCases.length),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Tax registration verification',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    if (_profiles.isEmpty)
                      const Card(
                        child: ListTile(title: Text('No tax IDs need review.')),
                      ),
                    ..._profiles.map(_profileCard),
                    const SizedBox(height: 24),
                    const Text(
                      'B.C. PST exemption claims',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    if (_claims.isEmpty)
                      const Card(
                        child: ListTile(
                          title: Text('No exemption claims need review.'),
                        ),
                      ),
                    ..._claims.map(_claimCard),
                    const SizedBox(height: 26),
                    _buildRecoverySection(),
                    const SizedBox(height: 30),
                  ],
                ),
    );
  }

  Widget _buildRecoverySection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tax recovery & account holds',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use only after a tax shortfall has been reasonably substantiated. Opening a case creates an auditable obligation and compliance hold. Seller responsibility also places a payout hold. It does not silently charge a stored buyer card.',
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _recoveryTransaction,
                    decoration: const InputDecoration(
                      labelText: 'Marketplace transaction ID',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _responsibleParty,
                          decoration:
                              const InputDecoration(labelText: 'Responsible'),
                          items: const [
                            DropdownMenuItem(
                              value: 'buyer',
                              child: Text('Buyer'),
                            ),
                            DropdownMenuItem(
                              value: 'seller',
                              child: Text('Seller'),
                            ),
                            DropdownMenuItem(
                              value: 'both',
                              child: Text('Buyer + seller'),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => _responsibleParty = value ?? 'seller',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _taxType,
                          decoration:
                              const InputDecoration(labelText: 'Tax type'),
                          items: const [
                            DropdownMenuItem(
                              value: 'bc_pst',
                              child: Text('B.C. PST'),
                            ),
                            DropdownMenuItem(
                              value: 'gst_hst',
                              child: Text('GST/HST'),
                            ),
                            DropdownMenuItem(value: 'qst', child: Text('QST')),
                            DropdownMenuItem(
                              value: 'pst_rst',
                              child: Text('PST/RST'),
                            ),
                            DropdownMenuItem(
                              value: 'us_sales_tax',
                              child: Text('U.S. sales tax'),
                            ),
                            DropdownMenuItem(value: 'vat', child: Text('VAT')),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _taxType = value ?? 'bc_pst'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration:
                              const InputDecoration(labelText: 'Currency'),
                          items: const [
                            DropdownMenuItem(value: 'CAD', child: Text('CAD')),
                            DropdownMenuItem(value: 'USD', child: Text('USD')),
                          ],
                          onChanged: (value) =>
                              setState(() => _currency = value ?? 'CAD'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _recoveryAmount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Total recovery amount',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _recoveryAuthority,
                    decoration: const InputDecoration(
                      labelText: 'Tax authority / audit reference (optional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _recoveryReason,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Reason and supporting facts',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed:
                          _creatingRecovery ? null : _createRecoveryCase,
                      icon: const Icon(Icons.lock_clock_outlined),
                      label: Text(
                        _creatingRecovery
                            ? 'Opening case…'
                            : 'Open recovery case & hold',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_recoveryCases.isEmpty)
            const Card(
              child: ListTile(title: Text('No open tax recovery cases.')),
            ),
          ..._recoveryCases.map(_recoveryCard),
        ],
      );

  Widget _profileCard(Map<String, dynamic> profile) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${profile['legalBusinessName'] ?? 'Tax profile'}',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              Text(
                '${profile['countryCode'] ?? ''}-${profile['regionCode'] ?? ''} • ${profile['uid'] ?? ''}',
              ),
              const Divider(height: 22),
              _registrationRow(
                profile,
                'businessNumber',
                'Business Number',
                '${profile['businessNumberStatus'] ?? 'not_provided'}',
              ),
              _registrationRow(
                profile,
                'gstHstNumber',
                'GST/HST',
                '${profile['gstHstStatus'] ?? 'not_provided'}',
              ),
              _registrationRow(
                profile,
                'pstBcNumber',
                'B.C. PST',
                '${profile['pstBcStatus'] ?? 'not_provided'}',
              ),
              Text(
                'Seller normal GST/HST regime: ${profile['sellerNormalGstHstRegistered'] ?? 'pending'}',
              ),
            ],
          ),
        ),
      );

  Widget _registrationRow(
    Map<String, dynamic> profile,
    String field,
    String label,
    String status,
  ) {
    final value = '${profile[field] ?? ''}'.trim();
    if (value.isEmpty) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text('$label • $value'),
      subtitle: Text(status.replaceAll('_', ' ')),
      trailing: status == 'pending_verification' || status == 'review_required'
          ? TextButton(
              onPressed: () => _reviewNumber(profile, field, label),
              child: const Text('Review'),
            )
          : null,
    );
  }

  Widget _claimCard(Map<String, dynamic> claim) => Card(
        child: ListTile(
          leading: const Icon(Icons.fact_check_outlined),
          title: Text('${claim['exemptionType'] ?? 'Exemption claim'}'),
          subtitle: Text(
            '${claim['jurisdiction'] ?? ''} • ${claim['status'] ?? ''}\n${claim['intendedUse'] ?? ''}',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          isThreeLine: true,
          trailing: FilledButton(
            onPressed: () => _reviewClaim(claim),
            child: const Text('Review'),
          ),
        ),
      );

  Widget _recoveryCard(Map<String, dynamic> recoveryCase) {
    final amount = ((recoveryCase['amountMinor'] as num?)?.toInt() ?? 0) / 100;
    return Card(
      color: const Color(0xFFFFF7E6),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded),
        title: Text(
          '${recoveryCase['currency'] ?? ''} \$${amount.toStringAsFixed(2)} • ${recoveryCase['taxType'] ?? ''}',
        ),
        subtitle: Text(
          'Transaction ${recoveryCase['transactionId'] ?? ''}\nResponsible: ${recoveryCase['responsibleParty'] ?? ''} • ${recoveryCase['reason'] ?? ''}',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: TextButton(
          onPressed: () => _resolveRecovery(recoveryCase),
          child: const Text('Resolve'),
        ),
      ),
    );
  }

  Widget _countChip(String label, Object? value) => Chip(
        avatar: const Icon(Icons.shield_outlined, size: 16),
        label: Text('$label: ${(value as num?)?.toInt() ?? 0}'),
      );
}
