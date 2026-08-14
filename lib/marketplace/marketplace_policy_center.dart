import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';

const requiredMarketplacePolicyIds = <String>[
  'terms_of_service',
  'privacy_notice',
  'prohibited_items',
  'mapping_location',
  'communications',
];

class MarketplacePolicyCenterPage extends StatefulWidget {
  const MarketplacePolicyCenterPage({super.key});

  @override
  State<MarketplacePolicyCenterPage> createState() =>
      _MarketplacePolicyCenterPageState();
}

class _MarketplacePolicyCenterPageState
    extends State<MarketplacePolicyCenterPage> {
  final _reviewed = <String>{};
  bool _submitting = false;

  void _notice(String message, {bool error = false}) {
    if (!mounted) return;
    PipeFeedback.show(
      context,
      message: message,
      tone: error ? PipeStatusTone.error : PipeStatusTone.success,
    );
  }

  Future<void> _openPolicy(
    QueryDocumentSnapshot<Map<String, dynamic>> policy,
  ) async {
    final url = Uri.tryParse('${policy.data()['documentUrl'] ?? ''}');
    if (url == null || url.scheme != 'https') {
      _notice('This policy link is unavailable. Contact support.', error: true);
      return;
    }
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) {
      _notice('The policy document could not be opened.', error: true);
      return;
    }
    if (mounted) setState(() => _reviewed.add(policy.id));
  }

  Future<void> _accept(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> policies,
  ) async {
    if (_submitting) return;
    if (policies.length != requiredMarketplacePolicyIds.length ||
        !_reviewed.containsAll(requiredMarketplacePolicyIds)) {
      _notice('Open and review every required policy before accepting.',
          error: true);
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.fact_check_outlined, size: 38),
            title: const Text('Accept current policies?'),
            content: const Text(
              'Your account will record the exact version and document hash '
              'of each policy. You will be asked again if a required policy changes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Go back'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Accept policies'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _submitting = true);
    try {
      final requestId = FirebaseFirestore.instance
          .collection('policy_command_receipts')
          .doc()
          .id;
      await MarketplaceCommandClient().execute('acceptRequiredPolicies', {
        'requestId': requestId,
        'policies': policies
            .map((policy) => {
                  'policyId': policy.id,
                  'version': '${policy.data()['version'] ?? ''}',
                  'contentSha256': '${policy.data()['contentSha256'] ?? ''}',
                })
            .toList(growable: false),
      });
      _notice('Your policy acceptance was recorded.');
    } catch (error) {
      _notice('$error'.replaceFirst('Bad state: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to review account policies.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Policies and agreements')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('platform_policies')
            .where('status', isEqualTo: 'published')
            .limit(10)
            .snapshots(),
        builder: (context, policiesSnapshot) {
          if (policiesSnapshot.hasError) {
            return _PolicyState(
              icon: Icons.cloud_off_outlined,
              title: 'Policies could not be loaded',
              message:
                  'Check your connection and try again. No acceptance was recorded.',
              onRetry: () => setState(() {}),
            );
          }
          if (!policiesSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final byId = {
            for (final policy in policiesSnapshot.data!.docs) policy.id: policy,
          };
          final policies = requiredMarketplacePolicyIds
              .map((id) => byId[id])
              .whereType<QueryDocumentSnapshot<Map<String, dynamic>>>()
              .toList(growable: false);
          if (policies.length != requiredMarketplacePolicyIds.length) {
            return const _PolicyState(
              icon: Icons.policy_outlined,
              title: 'Policies are being prepared',
              message:
                  'The reviewed launch documents have not all been published. '
                  'You cannot accidentally accept an incomplete set.',
            );
          }
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('policy_acceptances')
                .doc(user.uid)
                .snapshots(),
            builder: (context, acceptanceSnapshot) {
              final accepted = acceptanceSnapshot.data?.data();
              final versions = Map<String, dynamic>.from(
                accepted?['acceptedVersions'] is Map
                    ? accepted!['acceptedVersions'] as Map
                    : const {},
              );
              final hashes = Map<String, dynamic>.from(
                accepted?['acceptedHashes'] is Map
                    ? accepted!['acceptedHashes'] as Map
                    : const {},
              );
              final current = policies.every((policy) =>
                  versions[policy.id] == policy.data()['version'] &&
                  hashes[policy.id] == policy.data()['contentSha256']);
              final reviewedCount = current
                  ? policies.length
                  : policies
                      .where((policy) => _reviewed.contains(policy.id))
                      .length;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                    children: [
                      PipeBuyerPageHeader(
                        eyebrow: 'Trust & Agreements',
                        title: 'Policies and agreements',
                        subtitle:
                            'Review the exact marketplace documents attached to your account. New required versions always require a new acceptance.',
                        icon: Icons.policy_outlined,
                        actions: [
                          PipeBuyerStatusBadge(
                            label: current ? 'CURRENT' : 'REVIEW REQUIRED',
                            icon: current
                                ? Icons.verified_outlined
                                : Icons.rate_review_outlined,
                            tone: current
                                ? PipeBuyerStatusTone.success
                                : PipeBuyerStatusTone.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PipeBuyerMetricGrid(
                        children: [
                          PipeBuyerMetricCard(
                            label: 'Required policies',
                            value: '${policies.length}',
                            icon: Icons.description_outlined,
                            caption: 'Current published launch documents',
                            tone: PipeBuyerStatusTone.info,
                          ),
                          PipeBuyerMetricCard(
                            label: 'Reviewed',
                            value: '$reviewedCount / ${policies.length}',
                            icon: Icons.visibility_outlined,
                            caption: current
                                ? 'All current documents accepted'
                                : 'Open every document before acceptance',
                            tone: reviewedCount == policies.length
                                ? PipeBuyerStatusTone.success
                                : PipeBuyerStatusTone.premium,
                          ),
                          PipeBuyerMetricCard(
                            label: 'Acceptance status',
                            value: current ? 'Current' : 'Action needed',
                            icon: current
                                ? Icons.verified_user_outlined
                                : Icons.fact_check_outlined,
                            caption: current
                                ? 'Version and content hashes match'
                                : 'One or more current versions need acceptance',
                            tone: current
                                ? PipeBuyerStatusTone.success
                                : PipeBuyerStatusTone.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _PolicyOverview(
                        current: current,
                        reviewedCount: reviewedCount,
                        policyCount: policies.length,
                      ),
                      const SizedBox(height: 18),
                      const PipeBuyerPageHeader(
                        eyebrow: 'Required Documents',
                        title: 'Review each policy',
                        subtitle:
                            'Opening a document marks it reviewed on this screen. Acceptance is recorded only after your final confirmation.',
                        icon: Icons.menu_book_outlined,
                      ),
                      const SizedBox(height: 12),
                      ...policies.map((policy) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PolicyCard(
                              policy: policy,
                              reviewed:
                                  _reviewed.contains(policy.id) || current,
                              accepted: versions[policy.id] ==
                                      policy.data()['version'] &&
                                  hashes[policy.id] ==
                                      policy.data()['contentSha256'],
                              onOpen: () => _openPolicy(policy),
                            ),
                          )),
                      const SizedBox(height: 6),
                      const _PrivateAcceptanceNotice(),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: current || _submitting
                              ? null
                              : () => _accept(policies),
                          icon: _submitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(current
                                  ? Icons.verified_outlined
                                  : Icons.fact_check_outlined),
                          label: Text(current
                              ? 'Current policies accepted'
                              : reviewedCount == policies.length
                                  ? 'Accept reviewed policies'
                                  : 'Review and accept all'),
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
}

class _PolicyOverview extends StatelessWidget {
  const _PolicyOverview({
    required this.current,
    required this.reviewedCount,
    required this.policyCount,
  });

  final bool current;
  final int reviewedCount;
  final int policyCount;

  @override
  Widget build(BuildContext context) {
    final accent = current ? PipeBuyerColors.success : PipeBuyerColors.orange;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final icon = Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: accent.withValues(alpha: .30)),
            ),
            child: Icon(
              current ? Icons.verified_user_outlined : Icons.policy_outlined,
              color: accent,
              size: 28,
            ),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                current
                    ? 'Your agreements are current'
                    : 'Review required policies',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                current
                    ? 'The exact versions and content hashes below are recorded for your account.'
                    : 'Open every required document. A new policy version always requires a new acceptance.',
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.45,
                ),
              ),
              if (!current) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: policyCount == 0 ? 0 : reviewedCount / policyCount,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    color: PipeBuyerColors.orange,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$reviewedCount of $policyCount documents reviewed',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(height: 14),
                copy,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(child: copy),
            ],
          );
        },
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.policy,
    required this.reviewed,
    required this.accepted,
    required this.onOpen,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> policy;
  final bool reviewed;
  final bool accepted;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final data = policy.data();
    final effectiveAt = data['effectiveAt'] as Timestamp?;
    final effectiveLabel = effectiveAt == null
        ? null
        : DateFormat.yMMMd().format(effectiveAt.toDate());
    final version = '${data['version'] ?? ''}';
    final statusTone = accepted
        ? PipeBuyerStatusTone.success
        : reviewed
            ? PipeBuyerStatusTone.info
            : PipeBuyerStatusTone.warning;
    final statusLabel = accepted
        ? 'ACCEPTED'
        : reviewed
            ? 'REVIEWED'
            : 'OPEN TO REVIEW';

    return PipeBuyerSectionCard(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: pipeBuyerToneColor(statusTone).withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          accepted ? Icons.check_circle_outline : Icons.description_outlined,
          color: pipeBuyerToneColor(statusTone),
        ),
      ),
      trailing: PipeBuyerStatusBadge(
        label: statusLabel,
        icon: accepted
            ? Icons.verified_outlined
            : reviewed
                ? Icons.visibility_outlined
                : Icons.open_in_new,
        tone: statusTone,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data['title'] ?? 'Required policy'}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              PipeBuyerStatusBadge(
                label: version.isEmpty ? 'VERSION —' : 'VERSION $version',
                icon: Icons.tag_outlined,
                tone: PipeBuyerStatusTone.neutral,
              ),
              if (effectiveLabel != null)
                PipeBuyerStatusBadge(
                  label: 'EFFECTIVE $effectiveLabel',
                  icon: Icons.calendar_today_outlined,
                  tone: PipeBuyerStatusTone.neutral,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${data['summary'] ?? ''}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            label: Text(reviewed ? 'Open document again' : 'Open and review'),
          ),
        ],
      ),
    );
  }
}

class _PrivateAcceptanceNotice extends StatelessWidget {
  const _PrivateAcceptanceNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PipeBuyerColors.success.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: PipeBuyerColors.success.withValues(alpha: .22),
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: PipeBuyerColors.success),
            SizedBox(width: 11),
            Expanded(
              child: Text(
                'Acceptance records are private to your account. Administrators can audit the recorded version and hash, but cannot accept policies on your behalf.',
              ),
            ),
          ],
        ),
      );
}

class _PolicyState extends StatelessWidget {
  const _PolicyState({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PipeBuyerSectionCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.orangeSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      size: 30,
                      color: PipeBuyerColors.orangePressed,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
