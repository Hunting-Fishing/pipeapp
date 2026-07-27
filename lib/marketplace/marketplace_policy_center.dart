import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
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
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _PolicyOverview(current: current),
                  const SizedBox(height: 14),
                  ...policies.map((policy) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PolicyCard(
                          policy: policy,
                          reviewed: _reviewed.contains(policy.id) || current,
                          accepted:
                              versions[policy.id] == policy.data()['version'] &&
                                  hashes[policy.id] ==
                                      policy.data()['contentSha256'],
                          onOpen: () => _openPolicy(policy),
                        ),
                      )),
                  const SizedBox(height: 4),
                  const Card(
                    color: Color(0xFFEAF6EF),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_outline, color: Colors.green),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Acceptance records are private to your account. '
                              'Administrators can audit the version and hash, but '
                              'cannot accept policies on your behalf.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed:
                        current || _submitting ? null : () => _accept(policies),
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(current
                            ? Icons.verified_outlined
                            : Icons.fact_check_outlined),
                    label: Text(current
                        ? 'Current policies accepted'
                        : 'Review and accept all'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PolicyOverview extends StatelessWidget {
  const _PolicyOverview({required this.current});

  final bool current;

  @override
  Widget build(BuildContext context) => Card(
        color: current ? Colors.green.shade50 : Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                current ? Icons.verified_user_outlined : Icons.policy_outlined,
                color: current ? Colors.green.shade700 : Colors.blue.shade700,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current
                          ? 'Your agreements are current'
                          : 'Review required policies',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(current
                        ? 'The exact versions below are recorded for your account.'
                        : 'Open every document. A new version always requires a new acceptance.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor:
                      accepted ? Colors.green.shade50 : Colors.blue.shade50,
                  child: Icon(
                    accepted ? Icons.check : Icons.description_outlined,
                    color:
                        accepted ? Colors.green.shade700 : Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['title'] ?? 'Required policy'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text('Version ${data['version'] ?? ''}'
                          '${effectiveAt == null ? '' : ' • Effective ${DateFormat.yMMMd().format(effectiveAt.toDate())}'}'),
                    ],
                  ),
                ),
                if (reviewed)
                  const Tooltip(
                    message: 'Document opened for review',
                    child: Icon(Icons.check_circle, color: Colors.green),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text('${data['summary'] ?? ''}'),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new),
              label: Text(reviewed ? 'Open again' : 'Open and review'),
            ),
          ],
        ),
      ),
    );
  }
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: Colors.blueGrey),
                const SizedBox(height: 12),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                if (onRetry != null) ...[
                  const SizedBox(height: 14),
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
      );
}
