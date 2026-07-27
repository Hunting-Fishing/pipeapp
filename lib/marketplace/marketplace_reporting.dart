import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'industrial_icon_assets.dart';
import 'marketplace_actions_repository.dart';
import 'marketplace_command_client.dart';
import 'marketplace_support.dart';

class MarketplaceReportReason {
  const MarketplaceReportReason(
      this.code, this.label, this.description, this.icon);
  final String code;
  final String label;
  final String description;
  final IconData icon;
}

const marketplaceReportReasons = <MarketplaceReportReason>[
  MarketplaceReportReason(
      'duplicate_listing',
      'Duplicate listing',
      'The same item has been posted in more than one active ad.',
      Icons.copy_all_outlined),
  MarketplaceReportReason(
      'reused_photos',
      'Photos reused from another listing',
      'These exact photos appear in another ad or may not belong to the seller.',
      Icons.photo_library_outlined),
  MarketplaceReportReason(
      'fraud_or_scam',
      'Fraud, scam, or impersonation',
      'Suspicious payment requests, false identity, or deliberately misleading claims.',
      Icons.gpp_bad_outlined),
  MarketplaceReportReason(
      'hate_or_racist_content',
      'Racist or hateful content',
      'Attacks or degrades people based on race, ethnicity, religion, or identity.',
      Icons.warning_amber_outlined),
  MarketplaceReportReason(
      'vulgar_or_harassing_content',
      'Vulgar, threatening, or harassing',
      'Sexually explicit, abusive, threatening, or persistently unwanted content.',
      Icons.record_voice_over_outlined),
  MarketplaceReportReason(
      'misleading_information',
      'False or misleading information',
      'Important product, condition, ownership, quantity, or location details appear untrue.',
      Icons.fact_check_outlined),
  MarketplaceReportReason(
      'prohibited_or_unsafe_item',
      'Prohibited or unsafe item',
      'The listing may violate marketplace rules or present a safety concern.',
      Icons.health_and_safety_outlined),
  MarketplaceReportReason(
      'spam',
      'Spam or commercial abuse',
      'Repeated, irrelevant, deceptive, or unsolicited content.',
      Icons.mark_email_unread_outlined),
  MarketplaceReportReason('other', 'Something else',
      'A serious issue not covered by the reasons above.', Icons.more_horiz),
];

Future<bool> showMarketplaceReportDialog(
  BuildContext context, {
  required String reportedUid,
  required String targetType,
  String? listingId,
  String? conversationId,
  String? offerId,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReportDialog(
      reportedUid: reportedUid,
      targetType: targetType,
      listingId: listingId,
      conversationId: conversationId,
      offerId: offerId,
    ),
  );
  return result ?? false;
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({
    required this.reportedUid,
    required this.targetType,
    this.listingId,
    this.conversationId,
    this.offerId,
  });
  final String reportedUid;
  final String targetType;
  final String? listingId;
  final String? conversationId;
  final String? offerId;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _details = TextEditingController();
  final List<XFile> _attachments = [];
  MarketplaceReportReason? _reason;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    final picked =
        await ImagePicker().pickMultiImage(imageQuality: 88, maxWidth: 2200);
    for (final file in picked) {
      if (_attachments.length >= 5) break;
      if (await file.length() <= 10 * 1024 * 1024) _attachments.add(file);
    }
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (_reason == null) {
      setState(
          () => _error = 'Select the reason that best describes the issue.');
      return;
    }
    if (_details.text.trim().length < 10) {
      setState(() => _error =
          'Please add at least 10 characters explaining what happened.');
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (confirmationContext) => AlertDialog(
            icon: const Icon(Icons.privacy_tip_outlined, size: 36),
            title: const Text('Submit this report?'),
            content: Text(
              'Reason: ${_reason!.label}\n\n'
              'Your explanation${_attachments.isEmpty ? '' : ' and ${_attachments.length} attachment${_attachments.length == 1 ? '' : 's'}'} '
              'will be sent privately to the Trust & Safety administrator. '
              'The reported account will not be penalized unless an administrator confirms a violation.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(confirmationContext, false),
                child: const Text('Go back'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(confirmationContext, true),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Yes, submit report'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final report =
          FirebaseFirestore.instance.collection('trust_reports').doc();
      final evidence = <Map<String, dynamic>>[];
      final actions = MarketplaceActionsRepository();
      for (var i = 0; i < _attachments.length; i++) {
        final file = _attachments[i];
        final bytes = await file.readAsBytes();
        final extension = file.name.split('.').last.toLowerCase();
        final contentType = extension == 'png'
            ? 'image/png'
            : extension == 'webp'
                ? 'image/webp'
                : 'image/jpeg';
        final authorization = await actions.authorizeUpload(
            purpose: 'report_evidence',
            originalName: file.name,
            contentType: contentType,
            sizeBytes: bytes.length,
            reportId: report.id);
        final authorizationId = '${authorization['authorizationId']}';
        final ref =
            FirebaseStorage.instance.ref('${authorization['storagePath']}');
        await ref.putData(bytes, SettableMetadata(contentType: contentType));
        final url = await ref.getDownloadURL();
        await actions.confirmUpload(authorizationId: authorizationId, url: url);
        evidence.add({
          'authorizationId': authorizationId,
          'url': url,
          'name': file.name
        });
      }
      await MarketplaceCommandClient().execute('submitMarketplaceReport', {
        'requestId': report.id,
        'reportedUid': widget.reportedUid,
        'targetType': widget.targetType,
        if (widget.listingId != null) 'listingId': widget.listingId,
        if (widget.conversationId != null)
          'conversationId': widget.conversationId,
        if (widget.offerId != null) 'offerId': widget.offerId,
        'reason': _reason!.code,
        'details': _details.text.trim(),
        'attachments': evidence,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = 'Could not submit the report. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
              child: Row(children: [
                SizedBox.square(
                    dimension: 46,
                    child: IndustrialAssetIcon(
                        label: widget.targetType == 'message'
                            ? 'Report message'
                            : 'Report listing',
                        assetPath: widget.targetType == 'message'
                            ? IndustrialIconAssets.reportMessage
                            : IndustrialIconAssets.reportListing,
                        size: 46,
                        borderRadius: 12,
                        fallback: const CircleAvatar(
                            child: Icon(Icons.flag_outlined)))),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Report a safety concern',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w900)),
                      Text(
                          'Your report is private and reviewed by a trained administrator.')
                    ])),
                IconButton(
                    tooltip: 'Close report form',
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close))
              ]),
            ),
            const Divider(height: 1),
            Expanded(
                child: ListView(padding: const EdgeInsets.all(20), children: [
              const Text('Why are you reporting this?',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              RadioGroup<MarketplaceReportReason>(
                groupValue: _reason,
                onChanged: _submitting
                    ? (_) {}
                    : (value) => setState(() => _reason = value),
                child: Column(
                  children: marketplaceReportReasons
                      .map((reason) => RadioListTile<MarketplaceReportReason>(
                            value: reason,
                            enabled: !_submitting,
                            secondary: IndustrialAssetIcon(
                                label: reason.label,
                                size: 38,
                                borderRadius: 9,
                                fallback: Icon(reason.icon)),
                            title: Text(reason.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(reason.description),
                            contentPadding: EdgeInsets.zero,
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                enabled: !_submitting,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  hintText:
                      'Include specific details, dates, claims, or where the duplicate content appears.',
                  border: OutlineInputBorder(),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _submitting || _attachments.length >= 5
                    ? null
                    : _pickEvidence,
                icon: const IndustrialAssetIcon(
                    label: 'Evidence attachment',
                    assetPath: IndustrialIconAssets.evidenceAttachment,
                    size: 24,
                    borderRadius: 5,
                    fallback: Icon(Icons.attach_file)),
                label: Text(_attachments.isEmpty
                    ? 'Attach screenshots or photos (optional)'
                    : '${_attachments.length} attachment${_attachments.length == 1 ? '' : 's'} selected'),
              ),
              const Text(
                  'Up to 5 images, 10 MB each. Do not include sensitive personal information.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w700)),
                ),
            ])),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Expanded(
                    child: Text(
                        'Reports do not automatically penalize an account.',
                        style: TextStyle(fontSize: 12, color: Colors.black54))),
                TextButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_outlined),
                  label: const Text('Submit report'),
                )
              ]),
            )
          ]),
        ),
      );
}

class AdminModerationDashboard extends StatelessWidget {
  const AdminModerationDashboard({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const Material(
              color: Colors.white,
              child: TabBar(
                tabs: [
                  Tab(
                    icon: Icon(Icons.verified_user_outlined),
                    text: 'Account verification',
                  ),
                  Tab(
                    icon: Icon(Icons.local_shipping_outlined),
                    text: 'Dispatch providers',
                  ),
                  Tab(icon: Icon(Icons.gpp_bad_outlined), text: 'Reports'),
                  Tab(
                      icon: Icon(Icons.support_agent_outlined),
                      text: 'Support'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _AccountVerificationQueue(),
                  _DispatchProviderReviewQueue(),
                  _ModerationCaseQueue(),
                  AdminSupportQueue(),
                ],
              ),
            ),
          ],
        ),
      );
}

class _AccountVerificationQueue extends StatelessWidget {
  const _AccountVerificationQueue();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('verification_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load account verification requests.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!.docs.toList()
            ..sort(
              (a, b) => _ModerationCaseQueue._millis(b.data()['requestedAt'])
                  .compareTo(
                _ModerationCaseQueue._millis(a.data()['requestedAt']),
              ),
            );
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Row(
                children: [
                  Icon(Icons.fact_check_outlined, size: 42, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Identity review queue',
                      style:
                          TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const Text(
                'Review verified contact ownership and the public profile evidence captured at submission.',
              ),
              const SizedBox(height: 14),
              if (requests.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.verified_outlined),
                    title: Text('No account reviews are waiting'),
                  ),
                ),
              ...requests.map((request) {
                final data = request.data();
                final evidence = Map<String, dynamic>.from(
                  data['evidence'] is Map ? data['evidence'] as Map : const {},
                );
                final displayName = '${data['displayName'] ?? ''}'.trim();
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (displayName.isEmpty
                                ? 'U'
                                : displayName.characters.first)
                            .toUpperCase(),
                      ),
                    ),
                    title: Text(
                      displayName.isEmpty ? 'Account review' : displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${data['accountType'] ?? evidence['accountType'] ?? 'personal'} account • revision ${data['revision'] ?? 1}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openRequest(context, request),
                  ),
                );
              }),
            ],
          );
        },
      );

  static Future<void> _openRequest(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    final data = request.data() ?? const <String, dynamic>{};
    final evidence = Map<String, dynamic>.from(
      data['evidence'] is Map ? data['evidence'] as Map : const {},
    );
    final checks = List<Map<String, dynamic>>.from(
      (evidence['checks'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${data['displayName'] ?? 'Account verification'}'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${data['accountType'] ?? 'Personal'} account • revision ${data['revision'] ?? 1}',
                ),
                const SizedBox(height: 12),
                if ('${evidence['photoUrl'] ?? ''}'.startsWith('https://'))
                  Center(
                    child: CircleAvatar(
                      radius: 45,
                      backgroundImage: NetworkImage('${evidence['photoUrl']}'),
                    ),
                  ),
                const SizedBox(height: 12),
                ...checks.map(
                  (check) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      check['complete'] == true
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color:
                          check['complete'] == true ? Colors.green : Colors.red,
                    ),
                    title: Text('${check['label'] ?? check['code']}'),
                  ),
                ),
                if ('${evidence['businessDescription'] ?? ''}'.isNotEmpty) ...[
                  const Divider(),
                  const Text(
                    'Public business evidence',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('${evidence['businessDescription']}'),
                  Text('Service area: ${evidence['serviceAreaLabel'] ?? '—'}'),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Approval confirms the reviewed ownership and public profile evidence. It is not a government identity guarantee.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _review(
              context,
              dialogContext,
              request.id,
              'changes_requested',
            ),
            child: const Text('Request changes'),
          ),
          TextButton(
            onPressed: () => _review(
              context,
              dialogContext,
              request.id,
              'rejected',
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Reject'),
          ),
          FilledButton.icon(
            onPressed: () => _review(
              context,
              dialogContext,
              request.id,
              'approved',
            ),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  static Future<void> _review(
    BuildContext pageContext,
    BuildContext requestDialogContext,
    String userUid,
    String decision,
  ) async {
    final controller = TextEditingController();
    final label = switch (decision) {
      'approved' => 'Approve account verification',
      'changes_requested' => 'Request profile changes',
      _ => 'Reject account verification',
    };
    final confirmed = await showDialog<bool>(
      context: requestDialogContext,
      builder: (noteContext) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Review note *',
            hintText: 'Explain the evidence reviewed or the changes required.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(noteContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length < 10) {
                ScaffoldMessenger.of(noteContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Add a clear review note of at least 10 characters.'),
                  ),
                );
                return;
              }
              Navigator.pop(noteContext, true);
            },
            child: const Text('Confirm decision'),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed != true) return;
    try {
      final requestId = FirebaseFirestore.instance
          .collection('account_verification_command_receipts')
          .doc()
          .id;
      await MarketplaceCommandClient().execute('reviewAccountVerification', {
        'requestId': requestId,
        'userUid': userUid,
        'decision': decision,
        'reason': reason,
      });
      if (requestDialogContext.mounted) {
        Navigator.pop(requestDialogContext);
      }
      if (pageContext.mounted) {
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(content: Text('Verification review saved: $decision.')),
        );
      }
    } catch (error) {
      if (pageContext.mounted) {
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(
            content: Text('$error'.replaceFirst('Bad state: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}

class _DispatchProviderReviewQueue extends StatelessWidget {
  const _DispatchProviderReviewQueue();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('dispatch_carriers')
            .where('status', whereIn: const [
              'pending_review',
              'active',
              'changes_requested',
              'suspended',
            ])
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load Dispatch provider applications.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final providers = snapshot.data!.docs.toList()
            ..sort(
              (a, b) => _ModerationCaseQueue._millis(b.data()['submittedAt'])
                  .compareTo(
                _ModerationCaseQueue._millis(a.data()['submittedAt']),
              ),
            );
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Row(
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 42, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dispatch provider review',
                      style:
                          TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const Text(
                'Review public operating information and service coverage. No insurance or personal identity documents are collected here.',
              ),
              const SizedBox(height: 14),
              if (providers.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.task_alt_outlined),
                    title: Text('No Dispatch providers are available'),
                  ),
                ),
              ...providers.map((provider) {
                final data = provider.data();
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.local_shipping_outlined),
                    ),
                    title: Text(
                      '${data['operatingName'] ?? 'Dispatch provider'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${data['companyName'] ?? ''}\n${data['serviceAreaLabel'] ?? 'Service area not available'} • ${('${data['status'] ?? ''}').replaceAll('_', ' ')}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(context, provider),
                  ),
                );
              }),
            ],
          );
        },
      );

  static Future<void> _open(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> provider,
  ) async {
    final data = provider.data() ?? const <String, dynamic>{};
    final status = '${data['status'] ?? ''}';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${data['operatingName'] ?? 'Dispatch provider'}'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${data['companyName'] ?? ''}'),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Service area'),
                  subtitle: Text('${data['serviceAreaLabel'] ?? '—'}'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Verified account email'),
                  subtitle: Text('${data['email'] ?? '—'}'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Verified account phone'),
                  subtitle: Text('${data['phoneE164'] ?? '—'}'),
                ),
                const Text(
                  'Approval enables carrier quoting. It does not certify insurance, permits, licensing, vehicle condition, or route legality.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (status == 'pending_review')
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          if (status == 'pending_review')
            TextButton(
              onPressed: () => _review(
                context,
                dialogContext,
                provider.id,
                'changes_requested',
              ),
              child: const Text('Request changes'),
            ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            onPressed: () => _review(
              context,
              dialogContext,
              provider.id,
              'rejected',
            ),
            child: const Text('Reject'),
          ),
          if (status == 'active')
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              onPressed: () => _review(
                context,
                dialogContext,
                provider.id,
                'suspended',
              ),
              icon: const Icon(Icons.block_outlined),
              label: const Text('Suspend provider'),
            ),
          if (status == 'pending_review')
            FilledButton.icon(
              onPressed: () => _review(
                context,
                dialogContext,
                provider.id,
                'approved',
              ),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Approve provider'),
            ),
        ],
      ),
    );
  }

  static Future<void> _review(
    BuildContext pageContext,
    BuildContext providerDialogContext,
    String providerUid,
    String decision,
  ) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: providerDialogContext,
      builder: (noteContext) => AlertDialog(
        title: const Text('Confirm provider decision'),
        content: TextField(
          controller: note,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Review note *',
            hintText: 'Record what was reviewed or what must be corrected.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(noteContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (note.text.trim().length < 10) {
                ScaffoldMessenger.of(noteContext).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Enter a clear note of at least 10 characters.'),
                  ),
                );
                return;
              }
              Navigator.pop(noteContext, true);
            },
            child: const Text('Confirm decision'),
          ),
        ],
      ),
    );
    final reason = note.text.trim();
    note.dispose();
    if (confirmed != true) return;
    try {
      final requestId = FirebaseFirestore.instance
          .collection('marketplace_command_receipts')
          .doc()
          .id;
      await MarketplaceCommandClient().execute('reviewDispatchProvider', {
        'requestId': requestId,
        'providerUid': providerUid,
        'decision': decision,
        'reason': reason,
      });
      if (providerDialogContext.mounted) {
        Navigator.pop(providerDialogContext);
      }
      if (pageContext.mounted) {
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(
              content: Text('Dispatch provider decision saved: $decision.')),
        );
      }
    } catch (error) {
      if (pageContext.mounted) {
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('$error'.replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }
}

class _ModerationCaseQueue extends StatelessWidget {
  const _ModerationCaseQueue();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('trust_reports')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Unable to load moderation cases.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cases = snapshot.data!.docs.toList()
            ..sort((a, b) => _millis(b.data()['createdAt'])
                .compareTo(_millis(a.data()['createdAt'])));
          return ListView(padding: const EdgeInsets.all(18), children: [
            const Row(children: [
              IndustrialAssetIcon(
                  label: 'Admin review queue',
                  assetPath: IndustrialIconAssets.adminReviewQueue,
                  size: 52,
                  borderRadius: 12,
                  fallback:
                      Icon(Icons.admin_panel_settings_outlined, size: 38)),
              SizedBox(width: 11),
              Expanded(
                  child: Text('Trust & Safety',
                      style:
                          TextStyle(fontSize: 25, fontWeight: FontWeight.w900)))
            ]),
            const Text(
                'Review user reports and automated moderation alerts. Evidence remains private.'),
            const SizedBox(height: 16),
            Wrap(spacing: 10, children: [
              _metric(
                  'Open',
                  cases
                      .where((e) => [
                            'pending',
                            'information_requested',
                            'appealed'
                          ].contains(e.data()['status']))
                      .length,
                  Colors.orange),
              _metric(
                  'High priority',
                  cases.where((e) => e.data()['priority'] == 'high').length,
                  Colors.red),
              _metric(
                  'AI detected',
                  cases.where((e) => e.data()['source'] == 'automated').length,
                  Colors.blue),
            ]),
            const SizedBox(height: 12),
            if (cases.isEmpty)
              const Card(child: ListTile(title: Text('No moderation cases'))),
            ...cases.map((doc) {
              final data = doc.data();
              return Card(
                  child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      data['priority'] == 'high' ? Colors.red.shade50 : null,
                  child: Icon(data['source'] == 'automated'
                      ? Icons.auto_awesome
                      : Icons.flag_outlined),
                ),
                title: Text(
                    '${data['reasonLabel'] ?? data['reason'] ?? 'Review required'}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                    '${data['targetType'] ?? 'content'} • ${data['status'] ?? 'pending'}'
                    '${(data['attachmentCount'] ?? 0) > 0 ? ' • ${data['attachmentCount']} attachment(s)' : ''}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openCase(context, doc),
              ));
            })
          ]);
        },
      );

  static Widget _metric(String label, int value, Color color) => Chip(
      avatar: CircleAvatar(
          backgroundColor: color,
          child: Text('$value',
              style: const TextStyle(color: Colors.white, fontSize: 11))),
      label: Text(label));

  static int _millis(dynamic value) =>
      value is Timestamp ? value.millisecondsSinceEpoch : 0;

  static Future<void> _openCase(
      BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final attachments = List<Map<String, dynamic>>.from(
        (data['attachments'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map)));
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(
                  '${data['reasonLabel'] ?? data['reason'] ?? 'Moderation case'}'),
              content: SizedBox(
                  width: 600,
                  child: SingleChildScrollView(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          'Status: ${data['status'] ?? 'pending'} • Source: ${data['source'] ?? 'user'}'),
                      const SizedBox(height: 12),
                      Text(
                          '${data['details'] ?? 'No additional explanation provided.'}'),
                      if (attachments.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Evidence',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: attachments
                                .map((item) => ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      '${item['url']}',
                                      width: 150,
                                      height: 110,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox(
                                              width: 150,
                                              height: 110,
                                              child: Icon(
                                                  Icons.broken_image_outlined)),
                                    )))
                                .toList())
                      ],
                      const SizedBox(height: 18),
                      const Text('Case history',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('trust_report_events')
                            .where('reportId', isEqualTo: doc.id)
                            .limit(100)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text(
                                'Case history is temporarily unavailable.');
                          }
                          if (!snapshot.hasData) {
                            return const LinearProgressIndicator();
                          }
                          final events = snapshot.data!.docs.toList()
                            ..sort((a, b) => _millis(b.data()['createdAt'])
                                .compareTo(_millis(a.data()['createdAt'])));
                          if (events.isEmpty) {
                            return const Text(
                                'No review actions recorded yet.');
                          }
                          return Column(
                            children: events.map((event) {
                              final value = event.data();
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.history_outlined),
                                title: Text('${value['event'] ?? 'case update'}'
                                    .replaceAll('_', ' ')),
                                subtitle: Text(
                                  '${value['status'] ?? ''}'
                                  '${'${value['reason'] ?? ''}'.trim().isEmpty ? '' : '\n${value['reason']}'}',
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close')),
                if (['pending', 'information_requested']
                    .contains('${data['status'] ?? 'pending'}'))
                  FilledButton.icon(
                    onPressed: () async {
                      final completed = await _reviewCase(
                        dialogContext,
                        reportId: doc.id,
                        targetType: '${data['targetType'] ?? ''}',
                      );
                      if (completed && dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Review case'),
                  ),
                if ('${data['status']}' == 'appealed')
                  FilledButton.icon(
                    onPressed: () async {
                      final completed =
                          await _reviewAppeal(dialogContext, doc.id);
                      if (completed && dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                    icon: const Icon(Icons.balance_outlined),
                    label: const Text('Review appeal'),
                  ),
              ],
            ));
  }

  static Future<bool> _reviewCase(
    BuildContext context, {
    required String reportId,
    required String targetType,
  }) async {
    var decision = 'dismissed';
    var enforcementAction = 'none';
    final reason = TextEditingController();
    var submitting = false;
    String? error;
    final completed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (reviewContext) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              icon: const Icon(Icons.gpp_good_outlined, size: 36),
              title: const Text('Record moderation decision'),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: decision,
                        decoration: const InputDecoration(
                          labelText: 'Decision',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'dismissed',
                              child: Text('Dismiss — no violation found')),
                          DropdownMenuItem(
                              value: 'information_requested',
                              child: Text('Request more information')),
                          DropdownMenuItem(
                              value: 'violation_confirmed',
                              child: Text('Confirm policy violation')),
                        ],
                        onChanged: submitting
                            ? null
                            : (value) => setState(() {
                                  decision = value ?? 'dismissed';
                                  if (decision != 'violation_confirmed') {
                                    enforcementAction = 'none';
                                  }
                                }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: enforcementAction,
                        decoration: const InputDecoration(
                          labelText: 'Enforcement action',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: 'none', child: Text('No enforcement')),
                          if (decision == 'violation_confirmed')
                            const DropdownMenuItem(
                                value: 'warning',
                                child: Text('Formal account warning')),
                          if (decision == 'violation_confirmed' &&
                              ['listing', 'message'].contains(targetType))
                            const DropdownMenuItem(
                                value: 'content_removed',
                                child: Text('Remove reported content')),
                        ],
                        onChanged: submitting
                            ? null
                            : (value) => setState(
                                () => enforcementAction = value ?? 'none'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reason,
                        enabled: !submitting,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Decision rationale *',
                          hintText:
                              'Record the evidence reviewed and why this decision is appropriate.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (decision == 'violation_confirmed')
                        const Card(
                          color: Color(0xFFFFF3E0),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'The affected user will receive this rationale and may appeal within 30 days.',
                            ),
                          ),
                        ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(error!,
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.pop(reviewContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (reason.text.trim().length < 10) {
                            setState(() => error =
                                'Enter a clear rationale of at least 10 characters.');
                            return;
                          }
                          setState(() {
                            submitting = true;
                            error = null;
                          });
                          try {
                            final requestId = FirebaseFirestore.instance
                                .collection('moderation_command_receipts')
                                .doc()
                                .id;
                            await MarketplaceCommandClient()
                                .execute('reviewModerationReport', {
                              'requestId': requestId,
                              'reportId': reportId,
                              'decision': decision,
                              'reason': reason.text.trim(),
                              'enforcementAction': enforcementAction,
                            });
                            if (reviewContext.mounted) {
                              Navigator.pop(reviewContext, true);
                            }
                          } catch (caught) {
                            setState(() {
                              submitting = false;
                              error = '$caught'.replaceFirst('Bad state: ', '');
                            });
                          }
                        },
                  icon: submitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.verified_outlined),
                  label: const Text('Confirm decision'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    reason.dispose();
    return completed;
  }

  static Future<bool> _reviewAppeal(
      BuildContext context, String reportId) async {
    var decision = 'upheld';
    final reason = TextEditingController();
    var submitting = false;
    String? error;
    final completed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (reviewContext) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              icon: const Icon(Icons.balance_outlined, size: 36),
              title: const Text('Review moderation appeal'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: decision,
                      decoration: const InputDecoration(
                        labelText: 'Appeal decision',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'upheld',
                            child: Text('Uphold original decision')),
                        DropdownMenuItem(
                            value: 'overturned',
                            child: Text('Overturn and restore content')),
                      ],
                      onChanged: submitting
                          ? null
                          : (value) =>
                              setState(() => decision = value ?? 'upheld'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reason,
                      enabled: !submitting,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Appeal rationale *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null)
                      Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.pop(reviewContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (reason.text.trim().length < 10) {
                            setState(() => error =
                                'Enter a clear rationale of at least 10 characters.');
                            return;
                          }
                          setState(() {
                            submitting = true;
                            error = null;
                          });
                          try {
                            final requestId = FirebaseFirestore.instance
                                .collection('moderation_command_receipts')
                                .doc()
                                .id;
                            await MarketplaceCommandClient()
                                .execute('reviewModerationAppeal', {
                              'requestId': requestId,
                              'reportId': reportId,
                              'decision': decision,
                              'reason': reason.text.trim(),
                            });
                            if (reviewContext.mounted) {
                              Navigator.pop(reviewContext, true);
                            }
                          } catch (caught) {
                            setState(() {
                              submitting = false;
                              error = '$caught'.replaceFirst('Bad state: ', '');
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Confirm appeal decision'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    reason.dispose();
    return completed;
  }
}
