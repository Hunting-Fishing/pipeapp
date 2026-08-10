import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _counts = const {};
  List<Map<String, dynamic>> _profiles = const [];
  List<Map<String, dynamic>> _claims = const [];

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

  Future<void> _load() async {
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _commands.execute('getMarketplaceTaxComplianceAdmin', const {}),
        _commands.execute('getMarketplaceTaxRegistrationAdmin', const {}),
      ]);
      if (!mounted) return;
      setState(() {
        _counts = _map(values[0]['counts']);
        _claims = _list(values[0]['pendingClaims']);
        _profiles = _list(values[1]['pendingProfiles']);
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
                SelectableText(current,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Decision'),
                  items: const [
                    DropdownMenuItem(value: 'verified', child: Text('Verified')),
                    DropdownMenuItem(value: 'invalid', child: Text('Invalid')),
                    DropdownMenuItem(
                        value: 'review_required', child: Text('Further review required')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? 'review_required'),
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
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save review')),
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
        PipeFeedback.show(context,
            message: '$label review saved.', tone: PipeStatusTone.success);
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
      final url = await FirebaseStorage.instance.ref(path).getDownloadURL();
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        throw StateError('The evidence file could not be opened.');
      }
    } catch (_) {
      if (mounted) {
        PipeFeedback.show(context,
            message: 'The private evidence file could not be opened.',
            tone: PipeStatusTone.error);
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
                          '${claim['evidenceStoragePath'] ?? ''}'),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open private supporting evidence'),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: evidenceVerified,
                    onChanged: (value) => setDialogState(
                        () => evidenceVerified = value == true),
                    title: const Text(
                        'I reviewed the required exemption evidence and transaction facts.'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Decision'),
                    items: const [
                      DropdownMenuItem(value: 'approved', child: Text('Approve')),
                      DropdownMenuItem(value: 'rejected', child: Text('Reject')),
                      DropdownMenuItem(
                          value: 'needs_info', child: Text('Need more information')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => status = value ?? 'needs_info'),
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
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save decision')),
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
        PipeFeedback.show(context,
            message: 'Exemption review saved.', tone: PipeStatusTone.success);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Compliance Queue'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
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
                        _countChip('Exemptions pending', _counts['exemptionPending']),
                        _countChip('Exemptions approved', _counts['exemptionApproved']),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Tax registration verification',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (_profiles.isEmpty)
                      const Card(child: ListTile(title: Text('No tax IDs need review.'))),
                    ..._profiles.map(_profileCard),
                    const SizedBox(height: 24),
                    const Text('B.C. PST exemption claims',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (_claims.isEmpty)
                      const Card(child: ListTile(title: Text('No exemption claims need review.'))),
                    ..._claims.map(_claimCard),
                    const SizedBox(height: 30),
                  ],
                ),
    );
  }

  Widget _profileCard(Map<String, dynamic> profile) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${profile['legalBusinessName'] ?? 'Tax profile'}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text('${profile['countryCode'] ?? ''}-${profile['regionCode'] ?? ''} • ${profile['uid'] ?? ''}'),
            const Divider(height: 22),
            _registrationRow(profile, 'businessNumber', 'Business Number',
                '${profile['businessNumberStatus'] ?? 'not_provided'}'),
            _registrationRow(profile, 'gstHstNumber', 'GST/HST',
                '${profile['gstHstStatus'] ?? 'not_provided'}'),
            _registrationRow(profile, 'pstBcNumber', 'B.C. PST',
                '${profile['pstBcStatus'] ?? 'not_provided'}'),
            Text(
                'Seller normal GST/HST regime: ${profile['sellerNormalGstHstRegistered'] ?? 'pending'}'),
          ]),
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
              child: const Text('Review'))
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
              onPressed: () => _reviewClaim(claim), child: const Text('Review')),
        ),
      );

  Widget _countChip(String label, Object? value) => Chip(
        avatar: const Icon(Icons.shield_outlined, size: 16),
        label: Text('$label: ${(value as num?)?.toInt() ?? 0}'),
      );
}
