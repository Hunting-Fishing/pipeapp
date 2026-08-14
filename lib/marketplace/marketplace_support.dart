import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
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
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Help & Support'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.add_comment_outlined), text: 'New case'),
                Tab(icon: Icon(Icons.history_outlined), text: 'My cases'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _NewSupportCaseForm(),
              _MySupportCases(),
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
        behavior: SnackBarBehavior.floating,
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
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 40),
            children: [
              const PipeBuyerPageHeader(
                eyebrow: 'CUSTOMER CARE',
                title: 'How can we help?',
                subtitle:
                    'Route your case to the right team with the correct response target.',
                icon: Icons.support_agent_outlined,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined,
                        color: PipeBuyerColors.orange, size: 26),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Private support channel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Case details and replies are visible only to your account and authorized support administrators.',
                            style: TextStyle(color: Colors.white70, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PipeBuyerSectionCard(
                title: 'Choose a support category',
                subtitle:
                    'Selecting the closest category applies the correct service target.',
                leading: const _SupportSectionIcon(Icons.route_outlined),
                child: RadioGroup<_SupportCategory>(
                  groupValue: _category,
                  onChanged: _submitting
                      ? (_) {}
                      : (value) => setState(() => _category = value),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 720 ? 2 : 1;
                      const gap = 10.0;
                      final width = columns == 1
                          ? constraints.maxWidth
                          : (constraints.maxWidth - gap) / 2;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: _supportCategories
                            .map((category) => SizedBox(
                                  width: width,
                                  child: _SupportCategoryCard(
                                    category: category,
                                    selected:
                                        _category?.code == category.code,
                                    submitting: _submitting,
                                  ),
                                ))
                            .toList(growable: false),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PipeBuyerSectionCard(
                title: 'Case details',
                subtitle:
                    'Include enough context for support to reproduce or investigate the issue.',
                leading: const _SupportSectionIcon(Icons.description_outlined),
                child: Column(
                  children: [
                    TextField(
                      controller: _subject,
                      enabled: !_submitting,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Subject *',
                        hintText: 'Example: Listing photo upload stops at 2%',
                        prefixIcon: Icon(Icons.short_text_outlined),
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
                        prefixIcon: Icon(Icons.notes_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _relatedId,
                      enabled: !_submitting,
                      maxLength: 180,
                      decoration: const InputDecoration(
                        labelText:
                            'Related listing, offer, job, or conversation ID',
                        hintText: 'Optional — paste the reference if you have it',
                        prefixIcon: Icon(Icons.link_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: PipeBuyerColors.success.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: PipeBuyerColors.success.withValues(alpha: .18),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.privacy_tip_outlined,
                        color: PipeBuyerColors.success),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Never include passwords, verification codes, banking credentials, or government identification in a support message.',
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.support_agent_outlined),
                  label: Text(_submitting
                      ? 'Submitting support case…'
                      : 'Review and submit case'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SupportCategoryCard extends StatelessWidget {
  const _SupportCategoryCard({
    required this.category,
    required this.selected,
    required this.submitting,
  });

  final _SupportCategory category;
  final bool selected;
  final bool submitting;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? PipeBuyerColors.orange
                : Theme.of(context).dividerColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: RadioListTile<_SupportCategory>(
          value: category,
          enabled: !submitting,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          secondary: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? PipeBuyerColors.orangeSoft
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              category.icon,
              color: selected
                  ? PipeBuyerColors.orangePressed
                  : PipeBuyerColors.slate,
            ),
          ),
          title: Text(
            category.label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.description),
                const SizedBox(height: 5),
                Text(
                  category.target,
                  style: TextStyle(
                    color: selected
                        ? PipeBuyerColors.orangePressed
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .58),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MySupportCases extends StatelessWidget {
  const _MySupportCases();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.unavailable,
        icon: Icons.login_outlined,
        title: 'Sign in to view support cases',
        message: 'Your private support history is available after sign-in.',
      );
    }
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
        final open =
            cases.where((item) => item.data()['status'] != 'resolved').length;
        final urgent = cases
            .where((item) =>
                item.data()['priority'] == 'urgent' &&
                item.data()['status'] != 'resolved')
            .length;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 40),
              children: [
                const PipeBuyerPageHeader(
                  eyebrow: 'CUSTOMER CARE',
                  title: 'My support cases',
                  subtitle:
                      'Review private case status, response history, and follow-up messages.',
                  icon: Icons.history_outlined,
                ),
                const SizedBox(height: 16),
                PipeBuyerMetricGrid(
                  children: [
                    PipeBuyerMetricCard(
                      label: 'Open cases',
                      value: '$open',
                      icon: Icons.mark_chat_unread_outlined,
                      tone: open > 0
                          ? PipeBuyerStatusTone.info
                          : PipeBuyerStatusTone.success,
                    ),
                    PipeBuyerMetricCard(
                      label: 'Urgent cases',
                      value: '$urgent',
                      icon: Icons.gpp_maybe_outlined,
                      tone: urgent > 0
                          ? PipeBuyerStatusTone.danger
                          : PipeBuyerStatusTone.neutral,
                    ),
                    PipeBuyerMetricCard(
                      label: 'Case history',
                      value: '${cases.length}',
                      icon: Icons.receipt_long_outlined,
                      tone: PipeBuyerStatusTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...cases.map((supportCase) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SupportCaseCard(
                        document: supportCase,
                        onTap: () =>
                            showSupportCaseDialog(context, supportCase),
                      ),
                    )),
              ],
            ),
          ),
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
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
            children: [
              const PipeBuyerPageHeader(
                eyebrow: 'SUPPORT OPERATIONS',
                title: 'Customer support queue',
                subtitle:
                    'Private customer cases with category-based response targets.',
                icon: Icons.support_agent_outlined,
              ),
              const SizedBox(height: 16),
              PipeBuyerMetricGrid(
                children: [
                  PipeBuyerMetricCard(
                    label: 'Open',
                    value: '$open',
                    icon: Icons.inbox_outlined,
                    tone: PipeBuyerStatusTone.info,
                  ),
                  PipeBuyerMetricCard(
                    label: 'Urgent',
                    value: '$urgent',
                    icon: Icons.priority_high_rounded,
                    tone: urgent > 0
                        ? PipeBuyerStatusTone.danger
                        : PipeBuyerStatusTone.neutral,
                  ),
                  PipeBuyerMetricCard(
                    label: 'Queue window',
                    value: '${cases.length}',
                    icon: Icons.view_list_outlined,
                    caption: 'Newest 100 cases',
                    tone: PipeBuyerStatusTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (cases.isEmpty)
                const MarketplaceDataStateView(
                  kind: MarketplaceDataStateKind.empty,
                  icon: Icons.support_agent_outlined,
                  title: 'No support cases',
                  message: 'The support queue is currently clear.',
                  compact: true,
                ),
              ...cases.map((supportCase) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SupportCaseCard(
                      document: supportCase,
                      administrator: true,
                      onTap: () => showSupportCaseDialog(
                        context,
                        supportCase,
                        administrator: true,
                      ),
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
    final tone = overdue || priority == 'urgent'
        ? PipeBuyerStatusTone.danger
        : status == 'resolved'
            ? PipeBuyerStatusTone.success
            : PipeBuyerStatusTone.info;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _priorityColor(priority).withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _categoryIcon('${data['category'] ?? ''}'),
                  color: _priorityColor(priority),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data['subject'] ?? 'Support case'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        PipeBuyerStatusBadge(
                          label: status.replaceAll('_', ' ').toUpperCase(),
                          tone: tone,
                        ),
                        PipeBuyerStatusBadge(
                          label: '${priority.toUpperCase()} PRIORITY',
                          tone: priority == 'urgent'
                              ? PipeBuyerStatusTone.danger
                              : PipeBuyerStatusTone.neutral,
                        ),
                        if (overdue)
                          const PipeBuyerStatusBadge(
                            label: 'TARGET OVERDUE',
                            tone: PipeBuyerStatusTone.danger,
                            icon: Icons.schedule_outlined,
                          ),
                      ],
                    ),
                    if (administrator) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Case ${document.id}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
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
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SupportSectionIcon(Icons.support_agent_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['subject'] ?? 'Support case'}',
                          style: Theme.of(dialogContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            PipeBuyerStatusBadge(
                              label: '${data['status'] ?? 'open'}'
                                  .replaceAll('_', ' ')
                                  .toUpperCase(),
                              tone: '${data['status']}' == 'resolved'
                                  ? PipeBuyerStatusTone.success
                                  : PipeBuyerStatusTone.info,
                            ),
                            PipeBuyerStatusBadge(
                              label:
                                  '${data['priority'] ?? 'normal'} PRIORITY'
                                      .toUpperCase(),
                              tone: '${data['priority']}' == 'urgent'
                                  ? PipeBuyerStatusTone.danger
                                  : PipeBuyerStatusTone.neutral,
                            ),
                            PipeBuyerStatusBadge(
                              label:
                                  'TARGET ${data['firstResponseHours'] ?? 48}H',
                              tone: PipeBuyerStatusTone.neutral,
                              icon: Icons.schedule_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PipeBuyerSectionCard(
                      title: 'Case description',
                      leading: const _SupportSectionIcon(Icons.notes_outlined),
                      child: Text('${data['description'] ?? ''}'),
                    ),
                    if ('${data['relatedId'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      PipeBuyerSectionCard(
                        title: 'Related marketplace reference',
                        leading: const _SupportSectionIcon(Icons.link_outlined),
                        child: SelectableText('${data['relatedId']}'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    PipeBuyerSectionCard(
                      title: 'Case history',
                      subtitle: 'Private updates recorded for this support case.',
                      leading:
                          const _SupportSectionIcon(Icons.history_outlined),
                      child: StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        stream: eventQuery.limit(100).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Text(
                                'Case history is temporarily unavailable.');
                          }
                          if (!snapshot.hasData) {
                            return const LinearProgressIndicator();
                          }
                          final events = snapshot.data!.docs.toList()
                            ..sort((a, b) => _timestamp(a.data()['createdAt'])
                                .compareTo(
                                    _timestamp(b.data()['createdAt'])));
                          if (events.isEmpty) {
                            return const Text('No case events recorded yet.');
                          }
                          return Column(
                            children: events.map((event) {
                              final item = event.data();
                              final admin =
                                  item['actorRole'] == 'administrator';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: (admin
                                                ? PipeBuyerColors.orange
                                                : PipeBuyerColors.industrialBlue)
                                            .withValues(alpha: .10),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        admin
                                            ? Icons.support_agent_outlined
                                            : Icons.person_outline,
                                        size: 18,
                                        color: admin
                                            ? PipeBuyerColors.orangePressed
                                            : PipeBuyerColors.industrialBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item['event'] ?? 'update'}'
                                                .replaceAll('_', ' '),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800),
                                          ),
                                          if ('${item['message'] ?? ''}'
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text('${item['message'] ?? ''}'),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(growable: false),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  if (administrator)
                    FilledButton.icon(
                      onPressed: () async {
                        final changed =
                            await _adminUpdateCase(dialogContext, document);
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
                        final changed =
                            await _replyToCase(dialogContext, document.id);
                        if (changed && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      },
                      icon: const Icon(Icons.reply_outlined),
                      label: const Text('Reply'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                  decoration: const InputDecoration(labelText: 'Action'),
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
                  decoration: InputDecoration(labelText: label),
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

class _SupportSectionIcon extends StatelessWidget {
  const _SupportSectionIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: PipeBuyerColors.orangeSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: PipeBuyerColors.orangePressed),
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
      'urgent' => PipeBuyerColors.danger,
      'high' => PipeBuyerColors.warning,
      _ => PipeBuyerColors.industrialBlue,
    };
