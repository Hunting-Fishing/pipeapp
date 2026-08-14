import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/public_release_config.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';

class MarketplaceAboutPage extends StatelessWidget {
  const MarketplaceAboutPage({super.key});

  static final Uri _aboutUri = Uri.parse('https://www.pipebuyer.com/about');
  static final Uri _privacyUri = Uri.parse('https://www.pipebuyer.com/privacy');
  static final Uri _termsUri = Uri.parse('https://www.pipebuyer.com/terms');

  @override
  Widget build(BuildContext context) {
    final release = PublicReleaseConfiguration.current;
    final releaseSha = PublicReleaseConfiguration.releaseSha.trim();
    final displayedSha = releaseSha.isEmpty ? 'dev' : releaseSha;
    final supportMailto = release.supportMailto;
    final environment = release.normalizedEnvironment.isEmpty
        ? 'development'
        : release.normalizedEnvironment;

    return Scaffold(
      appBar: AppBar(title: const Text('About Pipe Buyer')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              children: [
                const _BrandHero(),
                const SizedBox(height: 16),
                PipeBuyerMetricGrid(
                  children: [
                    PipeBuyerMetricCard(
                      label: 'Environment',
                      value: environment,
                      icon: Icons.cloud_outlined,
                      caption: 'Current application environment',
                      tone: PipeBuyerStatusTone.info,
                    ),
                    PipeBuyerMetricCard(
                      label: 'Release revision',
                      value: displayedSha == 'dev'
                          ? 'Development'
                          : _shortSha(displayedSha),
                      icon: Icons.commit_outlined,
                      caption: displayedSha,
                      tone: PipeBuyerStatusTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PipeBuyerSectionCard(
                  title: 'Release information',
                  subtitle:
                      'Technical identity for the application currently running on this device.',
                  leading: const _SectionIcon(Icons.info_outline),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.info_outline,
                        label: 'Version and environment',
                        value: PublicReleaseConfiguration.formattedReleaseLabel,
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.commit_outlined,
                        label: 'Release revision',
                        value: displayedSha,
                        selectable: true,
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.support_agent_outlined,
                        label: 'Support email',
                        value: release.normalizedSupportEmail,
                        actionIcon:
                            supportMailto == null ? null : Icons.open_in_new,
                        onTap: supportMailto == null
                            ? null
                            : () => _launch(context, supportMailto),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PipeBuyerSectionCard(
                  title: 'Company & legal',
                  subtitle:
                      'Official information, privacy terms, and marketplace agreements.',
                  leading: const _SectionIcon(Icons.gavel_outlined),
                  child: Column(
                    children: [
                      _LinkRow(
                        icon: Icons.language_outlined,
                        title: 'About Pipe Buyer',
                        subtitle: 'Company and marketplace information',
                        onTap: () => _launch(context, _aboutUri),
                      ),
                      const Divider(height: 1),
                      _LinkRow(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'How personal and marketplace data is handled',
                        onTap: () => _launch(context, _privacyUri),
                      ),
                      const Divider(height: 1),
                      _LinkRow(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        subtitle: 'Marketplace terms and user obligations',
                        onTap: () => _launch(context, _termsUri),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: PipeBuyerColors.slate,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Release information identifies the running application build. It does not indicate app-store publication, payment-provider approval, or regulatory approval.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: .66),
                                height: 1.45,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _shortSha(String value) =>
      value.length <= 10 ? value : value.substring(0, 10);

  static Future<void> _launch(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This link could not be opened.')),
      );
    }
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PipeBuyerColors.orange.withValues(alpha: .09),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 6, color: PipeBuyerColors.orange),
            ),
            Padding(
              padding: const EdgeInsets.all(26),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 680;
                  final logo = Container(
                    width: compact ? 118 : 150,
                    height: compact ? 78 : 96,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.asset(
                      'assets/images/pipe_buyer_logo.png',
                      fit: BoxFit.contain,
                    ),
                  );
                  final copy = Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PipeBuyerStatusBadge(
                          label: 'INDUSTRIAL MARKETPLACE',
                          icon: Icons.precision_manufacturing_outlined,
                          tone: PipeBuyerStatusTone.premium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Pipe Buyer',
                          style:
                              Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Marketplace infrastructure for pipe, equipment, logistics, field operations, and industrial transactions.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(alignment: Alignment.centerLeft, child: logo),
                        const SizedBox(height: 18),
                        Row(children: [copy]),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      logo,
                      const SizedBox(width: 24),
                      copy,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon(this.icon);

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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.selectable = false,
    this.actionIcon,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool selectable;
  final IconData? actionIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final valueWidget = selectable
        ? SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          )
        : Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: PipeBuyerColors.slate),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .60),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  valueWidget,
                ],
              ),
            ),
            if (actionIcon != null) ...[
              const SizedBox(width: 10),
              Icon(actionIcon, color: PipeBuyerColors.orange),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PipeBuyerColors.orangeSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: PipeBuyerColors.orangePressed),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new),
        onTap: onTap,
      );
}
