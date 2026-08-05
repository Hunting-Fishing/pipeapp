import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/public_release_config.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('About Pipe Buyer')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          child: Icon(Icons.precision_manufacturing_outlined,
                              size: 34),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'PIPE BUYER',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Industrial marketplace for pipe, equipment, logistics, and field operations.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Version and environment'),
                        subtitle: Text(
                          PublicReleaseConfiguration.formattedReleaseLabel,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.commit_outlined),
                        title: const Text('Release revision'),
                        subtitle: SelectableText(displayedSha),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.support_agent_outlined),
                        title: const Text('Support email'),
                        subtitle: Text(release.normalizedSupportEmail),
                        trailing: supportMailto == null
                            ? null
                            : const Icon(Icons.open_in_new),
                        onTap: supportMailto == null
                            ? null
                            : () => _launch(context, supportMailto),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.language_outlined),
                        title: const Text('About Pipe Buyer'),
                        subtitle:
                            const Text('Company and marketplace information'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => _launch(context, _aboutUri),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => _launch(context, _privacyUri),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Terms of Service'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => _launch(context, _termsUri),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Release information identifies the running application build. '
                  'It does not indicate app-store publication, payment-provider '
                  'approval, or regulatory approval.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _launch(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This link could not be opened.')),
      );
    }
  }
}
