import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'industrial_icon_assets.dart';
import 'marketplace_actions_repository.dart';
import 'marketplace_command_client.dart';

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
        await actions.confirmUpload(
            authorizationId: authorizationId, url: url);
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
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('trust_reports').snapshots(),
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
                  cases.where((e) => e.data()['status'] == 'pending').length,
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
                      ]
                    ],
                  ))),
              actions: [
                TextButton(
                    onPressed: () async {
                      await doc.reference.update({
                        'status': 'dismissed',
                        'reviewedAt': FieldValue.serverTimestamp(),
                        'reviewedByUid': FirebaseAuth.instance.currentUser?.uid
                      });
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    child: const Text('Dismiss')),
                FilledButton(
                    onPressed: () async {
                      await doc.reference.update({
                        'status': 'actioned',
                        'reviewedAt': FieldValue.serverTimestamp(),
                        'reviewedByUid': FirebaseAuth.instance.currentUser?.uid
                      });
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    child: const Text('Confirm violation')),
              ],
            ));
  }
}
