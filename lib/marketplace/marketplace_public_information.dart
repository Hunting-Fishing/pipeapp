import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/config/public_release_config.dart';
import 'marketplace_data_state.dart';

enum MarketplacePublicInformationKind {
  privacy,
  terms,
  support,
  accountDeletion,
}

extension MarketplacePublicInformationKindDetails
    on MarketplacePublicInformationKind {
  String get title => switch (this) {
        MarketplacePublicInformationKind.privacy => 'Privacy notice',
        MarketplacePublicInformationKind.terms => 'Terms of service',
        MarketplacePublicInformationKind.support => 'Help and support',
        MarketplacePublicInformationKind.accountDeletion =>
          'Delete your account',
      };

  String get subtitle => switch (this) {
        MarketplacePublicInformationKind.privacy =>
          'How Pipe Buyer handles account and marketplace information.',
        MarketplacePublicInformationKind.terms =>
          'The current rules for using Pipe Buyer.',
        MarketplacePublicInformationKind.support =>
          'Get help with your account, listing, transaction, or safety concern.',
        MarketplacePublicInformationKind.accountDeletion =>
          'How to request deletion and what happens before it is finalized.',
      };

  IconData get icon => switch (this) {
        MarketplacePublicInformationKind.privacy => Icons.privacy_tip_outlined,
        MarketplacePublicInformationKind.terms => Icons.description_outlined,
        MarketplacePublicInformationKind.support =>
          Icons.support_agent_outlined,
        MarketplacePublicInformationKind.accountDeletion =>
          Icons.person_remove_outlined,
      };

  String? get policyId => switch (this) {
        MarketplacePublicInformationKind.privacy => 'privacy_notice',
        MarketplacePublicInformationKind.terms => 'terms_of_service',
        MarketplacePublicInformationKind.support ||
        MarketplacePublicInformationKind.accountDeletion =>
          null,
      };
}

class MarketplacePublicInformationPage extends StatelessWidget {
  const MarketplacePublicInformationPage({
    required this.kind,
    this.releaseConfiguration = PublicReleaseConfiguration.current,
    super.key,
  });

  final MarketplacePublicInformationKind kind;
  final PublicReleaseConfiguration releaseConfiguration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Return to Pipe Buyer',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Pipe Buyer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PublicPageHeader(kind: kind),
                  const SizedBox(height: 20),
                  if (kind.policyId != null)
                    _PublishedPolicy(policyId: kind.policyId!)
                  else if (kind == MarketplacePublicInformationKind.support)
                    _PublicSupport(configuration: releaseConfiguration)
                  else
                    _AccountDeletion(configuration: releaseConfiguration),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicPageHeader extends StatelessWidget {
  const _PublicPageHeader({required this.kind});

  final MarketplacePublicInformationKind kind;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                kind.icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kind.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kind.subtitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PublishedPolicy extends StatelessWidget {
  const _PublishedPolicy({required this.policyId});

  final String policyId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('platform_policies')
          .doc(policyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MarketplaceDataStateView.failure(
            error: snapshot.error,
            resource: 'The current approved document',
          );
        }
        if (!snapshot.hasData) {
          return const MarketplaceDataStateView.loading(
            title: 'Loading approved document',
            message: 'Checking the current published version…',
          );
        }
        final document = snapshot.data!;
        final data = document.data();
        if (!document.exists || data == null || data['status'] != 'published') {
          return const PipeStatusSurface(
            tone: PipeStatusTone.warning,
            icon: Icons.policy_outlined,
            title: 'This document is not published yet',
            message:
                'Pipe Buyer will not substitute placeholder legal text. Public launch remains blocked until the reviewed document is published.',
            liveRegion: true,
          );
        }
        return _PublishedPolicyCard(data: data);
      },
    );
  }
}

class _PublishedPolicyCard extends StatelessWidget {
  const _PublishedPolicyCard({required this.data});

  final Map<String, dynamic> data;

  Future<void> _openDocument(BuildContext context) async {
    final uri = Uri.tryParse('${data['documentUrl'] ?? ''}');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      PipeFeedback.show(
        context,
        message: 'The approved document link is unavailable.',
        tone: PipeStatusTone.error,
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      PipeFeedback.show(
        context,
        message: 'The approved document could not be opened.',
        tone: PipeStatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAt = data['effectiveAt'] as Timestamp?;
    final version = '${data['version'] ?? ''}'.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['title'] ?? 'Published policy'}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (version.isNotEmpty || effectiveAt != null) ...[
                  const SizedBox(height: 4),
                  Text([
                    if (version.isNotEmpty) 'Version $version',
                    if (effectiveAt != null)
                      'Effective ${DateFormat.yMMMd().format(effectiveAt.toDate())}',
                  ].join(' • ')),
                ],
                const SizedBox(height: 14),
                Text(
                  '${data['summary'] ?? 'Open the reviewed document for complete information.'}',
                  style: const TextStyle(height: 1.45),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _openDocument(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open approved document'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const PipeStatusSurface(
          tone: PipeStatusTone.info,
          icon: Icons.verified_user_outlined,
          title: 'Version-controlled publication',
          message:
              'Only administrator-published policy metadata is shown. Account acceptance records the exact reviewed version and document hash.',
        ),
      ],
    );
  }
}

class _PublicSupport extends StatelessWidget {
  const _PublicSupport({required this.configuration});

  final PublicReleaseConfiguration configuration;

  Future<void> _email(BuildContext context) async {
    final uri = configuration.supportMailto;
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      PipeFeedback.show(
        context,
        message: 'Your email application could not be opened.',
        tone: PipeStatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InformationCard(
            icon: Icons.account_circle_outlined,
            title: 'Signed-in support',
            message:
                'Open Account, then Settings and Help & Support. Your case and replies remain private between your account and authorized support administrators.',
          ),
          const SizedBox(height: 12),
          _InformationCard(
            icon: Icons.lock_reset_outlined,
            title: 'Cannot access your account?',
            message: configuration.hasValidSupportEmail
                ? 'Email ${configuration.normalizedSupportEmail}. Do not send passwords, verification codes, banking credentials, or government identification.'
                : 'The public support address is not configured in this non-release build. Public launch remains blocked until it is available.',
            action: configuration.hasValidSupportEmail
                ? FilledButton.icon(
                    onPressed: () => _email(context),
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email support'),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          const PipeStatusSurface(
            tone: PipeStatusTone.warning,
            icon: Icons.emergency_outlined,
            title: 'Immediate danger or active crime',
            message:
                'Contact the appropriate local emergency or law-enforcement service. Pipe Buyer support is not an emergency service.',
          ),
        ],
      );
}

class _AccountDeletion extends StatelessWidget {
  const _AccountDeletion({required this.configuration});

  final PublicReleaseConfiguration configuration;

  Future<void> _email(BuildContext context) async {
    final uri = configuration.supportMailto;
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      PipeFeedback.show(
        context,
        message: 'Your email application could not be opened.',
        tone: PipeStatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InformationCard(
            icon: Icons.settings_outlined,
            title: 'Request deletion in Pipe Buyer',
            message:
                'Sign in, open Account, choose Settings, then Privacy & account and Schedule account deletion. Recent authentication and an exact confirmation are required.',
          ),
          const SizedBox(height: 12),
          const _InformationCard(
            icon: Icons.event_available_outlined,
            title: 'Fourteen-day cancellation period',
            message:
                'You can cancel the request during the 14-day waiting period. The service rechecks active listings, offers, transactions, Dispatch work, disputes, and administrator responsibilities before final deletion.',
          ),
          const SizedBox(height: 12),
          const _InformationCard(
            icon: Icons.inventory_2_outlined,
            title: 'Records that must be retained',
            message:
                'Private profile and owned media are removed when deletion completes. Records required for safety, disputes, completed transactions, fraud prevention, or legal obligations may be anonymized and retained under the approved retention policy.',
          ),
          if (configuration.hasValidSupportEmail) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _email(context),
              icon: const Icon(Icons.email_outlined),
              label: Text(
                'Account-access help: ${configuration.normalizedSupportEmail}',
              ),
            ),
          ],
        ],
      );
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(message, style: const TextStyle(height: 1.45)),
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      );
}
