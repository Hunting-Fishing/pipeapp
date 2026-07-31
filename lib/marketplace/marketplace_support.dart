import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'marketplace_command_client.dart';
import 'marketplace_data_state.dart';

class _SupportCategory {
  const _SupportCategory(
      this.code, this.label, this.description, this.icon, this.target);

  final String code;
  final String label;
  final String description;
  final IconData icon;
  final String target;
}

const _supportCategories = <_SupportCategory>[
  _SupportCategory(
      'account_access',
      'Account access',
      'Sign-in, ownership, profile, or account security.',
      Icons.lock_outline,
      'Within 24 hours'),
  _SupportCategory(
      'transaction',
      'Offer or transaction',
      'Accepted offers, auction outcomes, disputes, or completion.',
      Icons.handshake_outlined,
      'Within 24 hours'),
  _SupportCategory(
      'safety',
      'Urgent safety concern',
      'Threats, fraud in progress, or an immediate marketplace safety issue.',
      Icons.gpp_maybe_outlined,
      'Within 4 hours'),
  _SupportCategory(
      'dispatch',
      'Dispatch',
      'Jobs, carrier quotes, fleet, delivery, or proof of delivery.',
      Icons.local_shipping_outlined,
      'Within 48 hours'),
  _SupportCategory(
      'technical',
      'Technical problem',
      'Upload, page, notification, or application failure.',
      Icons.build_outlined,
      'Within 48 hours'),
  _SupportCategory(
      'other',
      'Something else',
      'A question that does not match the categories above.',
      Icons.help_outline,
      'Within 48 hours'),
];

class MarketplaceSupportPage extends StatelessWidget {
  const MarketplaceSupportPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Help & Support')),
        body: const DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Material(
                color: Colors.white,
                child: TabBar(tabs: [
                  Tab(icon: Icon(Icons.add_comment_outlined), text: 'New case'),
                  Tab(icon: Icon(Icons.history_outlined), text: 'My cases'),
                ]),
              ),
              Expanded(
                child: TabBarView(children: [
                  _NewSupportCaseForm(),
                  _MySupportCases(),
                ]),
              ),
            ],
          ),
        ),
      );
}

class _NewSupportCaseForm extends StatefulWidget {
  const _NewSupportCaseForm();

  @override
  State<_NewSupportCaseForm> createState() => _NewSupportCaseFormState();
}

class _NewSupportCaseFormState extends State<_NewSupportCaseForm> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _relatedId = TextEditingController();
  _SupportCategory? _category;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    _relatedId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_category == null ||
        _subject.text.trim().length < 5 ||
        _description.text.trim().length < 20) {
      setState(() => _error =
          'Choose a category, enter a clear subject, and provide at least 20 characters of detail.');
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(_category!.icon, size: 36),
            title: const Text('Submit this support case?'),
            content: Text(
              '${_category!.label}\nExpected first response: ${_category!.target}\n\n'
              'The case and its replies remain private between your account and authorized support administrators.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Go back')),
              FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Submit case')),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final requestId = FirebaseFirestore.instance
          .collection('support_command_receipts')
          .doc()
          .id;
      final result =
          await MarketplaceCommandClient().execute('createSupportCase', {
        'requestId': requestId,
        'category': _category!.code,
        'subject': _subject.text.trim(),
        'description': _description.text.trim(),
        if (_relatedId.text.trim().isNotEmpty) ...{
          'relatedType': 'marketplace_reference',
          'relatedId': _relatedId.text.trim(),
        },
      });
      if (!mounted) return;
      _subject.clear();
      _description.clear();
      _relatedId.clear();
      setState(() => _category = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Support case ${result['caseId'] ?? requestId} was submitted.'),
      ));
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('How can we help?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const Text(
              'Choose the closest category so the case receives the correct service target.'),
          const SizedBox(height: 14),
          RadioGroup<_SupportCategory>(
            groupValue: _category,
            onChanged: _submitting
                ? (_) {}
                : (value) => setState(() => _category = value),
            child: Column(
              children: _supportCategories
                  .map((category) => Card(
                        color: _category?.code == category.code
                            ? Colors.blue.shade50
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: _category?.code == category.code
                                ? Colors.blue
                                : Colors.black12,
                            width: _category?.code == category.code ? 2 : 1,
                          ),
                        ),
                        child: RadioListTile<_SupportCategory>(
                          value: category,
                          enabled: !_submitting,
                          secondary: CircleAvatar(child: Icon(category.icon)),
                          title: Text(category.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                              '${category.description}\n${category.target}'),
                          isThreeLine: true,
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _subject,
            enabled: !_submitting,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Subject *',
              hintText: 'Example: Listing photo upload stops at 2%',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            enabled: !_submitting,
            minLines: 5,
            maxLines: 9,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'What happened? *',
              hintText:
                  'Describe what you were doing, what you expected, what occurred, and whether retrying changed anything.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _relatedId,
            enabled: !_submitting,
            maxLength: 180,
            decoration: const InputDecoration(
              labelText: 'Related listing, offer, job, or conversation ID',
              hintText: 'Optional — paste the reference if you have it',
              prefixIcon: Icon(Icons.link_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const Card(
            color: Color(0xFFE8F5E9),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(children: [
                Icon(Icons.privacy_tip_outlined, color: Colors.green),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'Never include passwords, verification codes, banking credentials, or government identification in a support message.'),
                ),
              ]),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.support_agent_outlined),
            label: const Text('Review and submit'),
          ),
        ],
      );
}

class _MySupportCases extends StatelessWidget {
  const _MySupportCases();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Sign in to view cases.'));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('support_cases')
          .where('ownerUid', isEqualTo: uid)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _SupportLoadState(
            kind: MarketplaceDataStateKind.error,
            icon: Icons.cloud_off_outlined,
            title: 'Support cases could not load',
            message: 'Check your connection and try again.',
          );
        }
        if (!snapshot.hasData) {
          return const MarketplaceDataStateView.loading(
            title: 'Loading support cases',
            message: 'Retrieving your private support history…',
          );
        }
        final cases = snapshot.data!.docs.toList()
          ..sort((a, b) => _timestamp(b.data()['updatedAt'])
              .compareTo(_timestamp(a.data()['updatedAt'])));
        if (cases.isEmpty) {
          return const _SupportLoadState(
            kind: MarketplaceDataStateKind.empty,
            icon: Icons.support_agent_outlined,
            title: 'No support cases',
            message: 'Cases you submit will appear here with their history.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('My support cases',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...cases.map((supportCase) => _SupportCaseCard(
                  document: supportCase,
                  onTap: () => showSupportCaseDialog(context, supportCase),
                )),
          ],
        );
      },
    );
  }
}

class AdminSupportQueue extends StatelessWidget {
  const AdminSupportQueue({super.key});

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('support_cases')
            .orderBy('updatedAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _SupportLoadState(
              kind: MarketplaceDataStateKind.error,
              icon: Icons.cloud_off_outlined,
              title: 'Support queue could not load',
              message: 'Check administrator access and try again.',
            );
          }
          if (!snapshot.hasData) {
            return const MarketplaceDataStateView.loading(
              title: 'Loading support queue',
              message: 'Retrieving the latest support cases…',
            );
          }
          final cases = snapshot.data!.docs;
          final open =
              cases.where((item) => item.data()['status'] != 'resolved').length;
          final urgent = cases
              .where((item) =>
                  item.data()['priority'] == 'urgent' &&
                  item.data()['status'] != 'resolved')
              .length;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text('Support operations',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              const Text(
                  'Private customer cases. Response targets are assigned by category.'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                Chip(label: Text('$open open')),
                Chip(
                    avatar: const Icon(Icons.priority_high, color: Colors.red),
                    label: Text('$urgent urgent')),
                const Chip(label: Text('Newest 100 cases')),
              ]),
              const SizedBox(height: 10),
              if (cases.isEmpty)
                const Card(child: ListTile(title: Text('No support cases'))),
              ...cases.map((supportCase) => _SupportCaseCard(
                    document: supportCase,
                    administrator: true,
                    onTap: () => showSupportCaseDialog(
                      context,
                      supportCase,
                      administrator: true,
                    ),
                  )),
            ],
          );
        },
      );
}

class _SupportCaseCard extends StatelessWidget {
  const _SupportCaseCard({
    required this.document,
    required this.onTap,
    this.administrator = false,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final VoidCallback onTap;
  final bool administrator;

  @override
  Widget build(BuildContext context) {
    final data = document.data();
    final status = '${data['status'] ?? 'open'}';
    final priority = '${data['priority'] ?? 'normal'}';
    final due = data['firstResponseDueAt'] as Timestamp?;
    final overdue = data['firstRespondedAt'] == null &&
        due != null &&
        due.toDate().isBefore(DateTime.now());
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: overdue || priority == 'urgent'
              ? Colors.red
              : status == 'resolved'
                  ? Colors.green
                  : Colors.black12,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _priorityColor(priority).withValues(alpha: .12),
          child: Icon(_categoryIcon('${data['category'] ?? ''}'),
              color: _priorityColor(priority)),
        ),
        title: Text('${data['subject'] ?? 'Support case'}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${status.replaceAll('_', ' ')} • $priority'
          '${administrator ? '\nCase ${document.id}' : ''}'
          '${overdue ? '\nResponse target overdue' : ''}',
        ),
        isThreeLine: administrator || overdue,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

Future<void> showSupportCaseDialog(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> document, {
  bool administrator = false,
}) async {
  final data = document.data();
  Query<Map<String, dynamic>> eventQuery = FirebaseFirestore.instance
      .collection('support_case_events')
      .where('caseId', isEqualTo: document.id);
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (!administrator && uid != null) {
    eventQuery = eventQuery.where('ownerUid', isEqualTo: uid);
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('${data['subject'] ?? 'Support case'}'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 8, children: [
                Chip(
                    label: Text(
                        '${data['status'] ?? 'open'}'.replaceAll('_', ' '))),
                Chip(label: Text('${data['priority'] ?? 'normal'} priority')),
                Chip(
                    label: Text('Target ${data['firstResponseHours'] ?? 48}h')),
              ]),
              Text('${data['description'] ?? ''}'),
              if ('${data['relatedId'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Related reference: ${data['relatedId']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 16),
              const Text('Case history',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: eventQuery.limit(100).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                        'Case history is temporarily unavailable.');
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final events = snapshot.data!.docs.toList()
                    ..sort((a, b) => _timestamp(a.data()['createdAt'])
                        .compareTo(_timestamp(b.data()['createdAt'])));
                  return Column(
                    children: events.map((event) {
                      final item = event.data();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(item['actorRole'] == 'administrator'
                            ? Icons.support_agent_outlined
                            : Icons.person_outline),
                        title: Text('${item['event'] ?? 'update'}'
                            .replaceAll('_', ' ')),
                        subtitle: Text('${item['message'] ?? ''}'),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close')),
        if (administrator)
          FilledButton.icon(
            onPressed: () async {
              final changed = await _adminUpdateCase(dialogContext, document);
              if (changed && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Update case'),
          )
        else if ('${data['status']}' != 'resolved')
          FilledButton.icon(
            onPressed: () async {
              final changed = await _replyToCase(dialogContext, document.id);
              if (changed && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            icon: const Icon(Icons.reply_outlined),
            label: const Text('Reply'),
          ),
      ],
    ),
  );
}

Future<bool> _replyToCase(BuildContext context, String caseId) async {
  final controller = TextEditingController();
  final result = await _supportMessageDialog(
    context,
    title: 'Reply to support',
    label: 'Additional information *',
    controller: controller,
    submitLabel: 'Send reply',
    onSubmit: (message) async {
      final requestId = FirebaseFirestore.instance
          .collection('support_command_receipts')
          .doc()
          .id;
      await MarketplaceCommandClient().execute('replySupportCase', {
        'requestId': requestId,
        'caseId': caseId,
        'message': message,
      });
    },
  );
  controller.dispose();
  return result;
}

Future<bool> _adminUpdateCase(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> document,
) async {
  final current = '${document.data()['status'] ?? 'open'}';
  final actions = <String>[
    if (current == 'open') 'acknowledge',
    if (current != 'resolved') 'respond',
    if (current != 'resolved') 'resolve',
    if (!['resolved', 'escalated'].contains(current)) 'escalate',
    if (current == 'resolved') 'reopen',
  ];
  var action = actions.first;
  final controller = TextEditingController();
  var submitting = false;
  String? error;
  final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Update support case'),
            content: SizedBox(
              width: 520,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: action,
                  decoration: const InputDecoration(
                    labelText: 'Action',
                    border: OutlineInputBorder(),
                  ),
                  items: actions
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.replaceAll('_', ' ')),
                          ))
                      .toList(),
                  onChanged: submitting
                      ? null
                      : (value) => setState(() => action = value ?? action),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  enabled: !submitting,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Customer-visible response *',
                    hintText:
                        'Record what was reviewed, the next step, and any information the customer must provide.',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (controller.text.trim().length < 10) {
                          setState(() => error =
                              'Enter a clear response of at least 10 characters.');
                          return;
                        }
                        setState(() {
                          submitting = true;
                          error = null;
                        });
                        try {
                          final requestId = FirebaseFirestore.instance
                              .collection('support_command_receipts')
                              .doc()
                              .id;
                          await MarketplaceCommandClient()
                              .execute('updateSupportCase', {
                            'requestId': requestId,
                            'caseId': document.id,
                            'action': action,
                            'message': controller.text.trim(),
                          });
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
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
                    : const Text('Save update'),
              ),
            ],
          ),
        ),
      ) ??
      false;
  controller.dispose();
  return result;
}

Future<bool> _supportMessageDialog(
  BuildContext context, {
  required String title,
  required String label,
  required TextEditingController controller,
  required String submitLabel,
  required Future<void> Function(String message) onSubmit,
}) async {
  var submitting = false;
  String? error;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 500,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: controller,
                  enabled: !submitting,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: label,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final message = controller.text.trim();
                        if (message.length < 10) {
                          setState(() => error =
                              'Provide at least 10 characters of useful detail.');
                          return;
                        }
                        setState(() {
                          submitting = true;
                          error = null;
                        });
                        try {
                          await onSubmit(message);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
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
                    : Text(submitLabel),
              ),
            ],
          ),
        ),
      ) ??
      false;
}

class _SupportLoadState extends StatelessWidget {
  const _SupportLoadState({
    required this.kind,
    required this.icon,
    required this.title,
    required this.message,
  });

  final MarketplaceDataStateKind kind;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => MarketplaceDataStateView(
        kind: kind,
        icon: icon,
        title: title,
        message: message,
      );
}

int _timestamp(Object? value) =>
    value is Timestamp ? value.millisecondsSinceEpoch : 0;

IconData _categoryIcon(String category) => switch (category) {
      'account_access' => Icons.lock_outline,
      'transaction' => Icons.handshake_outlined,
      'safety' => Icons.gpp_maybe_outlined,
      'dispatch' => Icons.local_shipping_outlined,
      'technical' => Icons.build_outlined,
      _ => Icons.help_outline,
    };

Color _priorityColor(String priority) => switch (priority) {
      'urgent' => Colors.red,
      'high' => Colors.orange,
      _ => Colors.blue,
    };
