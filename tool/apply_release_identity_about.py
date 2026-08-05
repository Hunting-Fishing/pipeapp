from pathlib import Path

ACCOUNT_PATH = Path("lib/marketplace/marketplace_account_hub.dart")
MARKETPLACE_PATH = Path("lib/marketplace/oil_gas_marketplace.dart")
ABOUT_PATH = Path("lib/marketplace/marketplace_about_page.dart")
TEST_PATH = Path("test/marketplace_about_page_test.dart")

about_page = """import 'package:flutter/material.dart';
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
"""

about_test = """import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipe_app/marketplace/marketplace_about_page.dart';

void main() {
  testWidgets('shows release identity in the Account About destination',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MarketplaceAboutPage()),
    );

    expect(find.text('About Pipe Buyer'), findsWidgets);
    expect(find.textContaining('v1.0.0+1'), findsOneWidget);
    expect(find.text('Release revision'), findsOneWidget);
    expect(find.text('support@pipebuyer.com'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Terms of Service'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
  });
}
"""

account = ACCOUNT_PATH.read_text(encoding="utf-8")
account_import = "import 'marketplace_about_page.dart';\n"
account_import_marker = "import 'marketplace_admin_dashboard.dart';\n"
if account_import not in account:
    if account_import_marker not in account:
        raise SystemExit("Account import marker not found")
    account = account.replace(
        account_import_marker,
        account_import_marker + account_import,
        1,
    )

settings_marker = """      ListTile(
          leading: const Icon(Icons.policy_outlined),
          title: const Text('Policies and agreements'),
          subtitle: const Text(
              'Check current versions and review your account acceptance.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MarketplacePolicyCenterPage()))),
      const SizedBox(height: 12),
      const _WatchKeywords(),
"""
settings_replacement = """      ListTile(
          leading: const Icon(Icons.policy_outlined),
          title: const Text('Policies and agreements'),
          subtitle: const Text(
              'Check current versions and review your account acceptance.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MarketplacePolicyCenterPage()))),
      ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About Pipe Buyer'),
          subtitle: const Text(
              'Version, environment, support, and legal information.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MarketplaceAboutPage()))),
      const SizedBox(height: 12),
      const _WatchKeywords(),
"""
if "builder: (_) => const MarketplaceAboutPage()" not in account:
    if settings_marker not in account:
        raise SystemExit("Account settings marker not found")
    account = account.replace(settings_marker, settings_replacement, 1)

marketplace = MARKETPLACE_PATH.read_text(encoding="utf-8")
marketplace = marketplace.replace(
    "import '../core/config/public_release_config.dart';\n",
    "",
    1,
)

release_action = """          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x3338BDF8), width: 1),
              ),
              child: Text(
                PublicReleaseConfiguration.formattedReleaseLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
"""
if release_action not in marketplace:
    raise SystemExit("App-bar release identity marker not found")
marketplace = marketplace.replace(release_action, "", 1)

drawer_release = """              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  PublicReleaseConfiguration.formattedReleaseLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
"""
if drawer_release not in marketplace:
    raise SystemExit("Drawer release identity marker not found")
marketplace = marketplace.replace(drawer_release, "", 1)

body_release = """        body: Stack(
          children: [
            IndexedStack(index: _tab, children: pages),
            Positioned(
              bottom: 8,
              right: 12,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xE60F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0x3338BDF8),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    PublicReleaseConfiguration.formattedReleaseLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
"""
if body_release not in marketplace:
    raise SystemExit("Overlay release identity marker not found")
marketplace = marketplace.replace(
    body_release,
    "        body: IndexedStack(index: _tab, children: pages),\n",
    1,
)

if "PublicReleaseConfiguration.formattedReleaseLabel" in marketplace:
    raise SystemExit("Persistent release identity remains in marketplace shell")

ACCOUNT_PATH.write_text(account, encoding="utf-8")
MARKETPLACE_PATH.write_text(marketplace, encoding="utf-8")
ABOUT_PATH.write_text(about_page, encoding="utf-8")
TEST_PATH.write_text(about_test, encoding="utf-8")
