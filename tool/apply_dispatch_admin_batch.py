from __future__ import annotations

import re
from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one exact match, found {count}")
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"{label}: expected one regex match, found {count}")
    return updated


def update_dispatch_dashboard() -> None:
    path = Path("lib/marketplace/marketplace_dispatch_dashboard.dart")
    text = path.read_text()
    text = replace_once(
        text,
        "import 'marketplace_dispatch_repository.dart';\n",
        "import 'marketplace_dispatch_repository.dart';\n"
        "import 'marketplace_dispatch_onboarding.dart';\n",
        "dashboard onboarding import",
    )
    text = replace_once(
        text,
        "class MarketplaceDispatchDashboard extends StatefulWidget {\n"
        "  const MarketplaceDispatchDashboard({super.key, required this.repo});\n"
        "  final MarketplaceDispatchRepository repo;\n",
        "class MarketplaceDispatchDashboard extends StatefulWidget {\n"
        "  const MarketplaceDispatchDashboard({\n"
        "    super.key,\n"
        "    required this.repo,\n"
        "    required this.onPostLoad,\n"
        "    required this.onBrowseJobs,\n"
        "    required this.onJoinCarrier,\n"
        "  });\n\n"
        "  final MarketplaceDispatchRepository repo;\n"
        "  final VoidCallback onPostLoad;\n"
        "  final VoidCallback onBrowseJobs;\n"
        "  final VoidCallback onJoinCarrier;\n",
        "dashboard callback constructor",
    )
    text = regex_once(
        text,
        r"          builder: \(context, account\) \{\n"
        r"            if \(account\.data\?\.exists != true\) \{\n.*?"
        r"            \}\n"
        r"            final data = account\.data!\.data\(\)!;",
        "          builder: (context, account) {\n"
        "            if (account.connectionState == ConnectionState.waiting &&\n"
        "                !account.hasData) {\n"
        "              return const Center(child: CircularProgressIndicator());\n"
        "            }\n"
        "            if (account.hasError) {\n"
        "              return const Center(\n"
        "                child: Padding(\n"
        "                  padding: EdgeInsets.all(24),\n"
        "                  child: Card(\n"
        "                    child: ListTile(\n"
        "                      leading: Icon(Icons.cloud_off_outlined),\n"
        "                      title: Text('Dispatch profile unavailable'),\n"
        "                      subtitle: Text(\n"
        "                        'Check your connection and reload Dispatch.',\n"
        "                      ),\n"
        "                    ),\n"
        "                  ),\n"
        "                ),\n"
        "              );\n"
        "            }\n"
        "            if (account.data?.exists != true) {\n"
        "              return MarketplaceDispatchOnboarding(\n"
        "                onPostLoad: widget.onPostLoad,\n"
        "                onBrowseJobs: widget.onBrowseJobs,\n"
        "                onJoinCarrier: widget.onJoinCarrier,\n"
        "              );\n"
        "            }\n"
        "            final data = account.data!.data()!;",
        "dashboard empty state",
    )
    path.write_text(text)


def update_dispatch_page() -> None:
    path = Path("lib/marketplace/marketplace_dispatch_page.dart")
    text = path.read_text()
    text = replace_once(
        text,
        "              ? MarketplaceDispatchDashboard(repo: repo)\n",
        "              ? MarketplaceDispatchDashboard(\n"
        "                  repo: repo,\n"
        "                  onPostLoad: () => setState(() => section = 2),\n"
        "                  onBrowseJobs: () => setState(() => section = 1),\n"
        "                  onJoinCarrier: () => setState(() => section = 3),\n"
        "                )\n",
        "dispatch dashboard navigation callbacks",
    )
    path.write_text(text)


def update_account_hub() -> None:
    path = Path("lib/marketplace/marketplace_account_hub.dart")
    text = path.read_text()
    text = replace_once(
        text,
        "  late TabController _tabs;\n"
        "  bool _isAdminUser = false;\n"
        "  StreamSubscription<User?>? _adminTokenSubscription;\n",
        "  late TabController _tabs;\n"
        "  MarketplaceAdministratorState _adminState =\n"
        "      MarketplaceAdministratorState.signedOut;\n"
        "  StreamSubscription<User?>? _adminTokenSubscription;\n\n"
        "  bool get _isAdminUser =>\n"
        "      _adminState == MarketplaceAdministratorState.authorized;\n",
        "account admin state field",
    )
    text = replace_once(
        text,
        "    _adminTokenSubscription =\n"
        "        FirebaseAuth.instance.idTokenChanges().listen((_) => _checkAdmin());\n"
        "    _checkAdmin();\n",
        "    _adminTokenSubscription =\n"
        "        FirebaseAuth.instance.idTokenChanges().listen((_) => _checkAdmin());\n"
        "    _checkAdmin(forceRefresh: true);\n",
        "account initial admin refresh",
    )
    text = regex_once(
        text,
        r"  Future<void> _checkAdmin\(\) async \{.*?\n  \}\n\n  @override\n  void dispose",
        "  Future<void> _checkAdmin({bool forceRefresh = false}) async {\n"
        "    final generation = ++_adminCheckGeneration;\n"
        "    final state = await marketplaceAdministratorState(\n"
        "      forceRefresh: forceRefresh,\n"
        "    );\n"
        "    if (!mounted ||\n"
        "        generation != _adminCheckGeneration ||\n"
        "        state == _adminState) {\n"
        "      return;\n"
        "    }\n\n"
        "    final wasAuthorized = _isAdminUser;\n"
        "    final isAuthorized =\n"
        "        state == MarketplaceAdministratorState.authorized;\n"
        "    if (wasAuthorized == isAuthorized) {\n"
        "      setState(() => _adminState = state);\n"
        "      return;\n"
        "    }\n\n"
        "    final nextLength = isAuthorized ? 7 : 6;\n"
        "    final nextIndex = _tabs.index.clamp(0, nextLength - 1);\n"
        "    final oldTabs = _tabs;\n"
        "    setState(() {\n"
        "      _adminState = state;\n"
        "      _tabs = TabController(\n"
        "        length: nextLength,\n"
        "        initialIndex: nextIndex,\n"
        "        vsync: this,\n"
        "      );\n"
        "    });\n"
        "    oldTabs.dispose();\n"
        "  }\n\n"
        "  @override\n"
        "  void dispose",
        "account admin refresh method",
    )
    text = replace_once(
        text,
        "        const _AccountSettings(),\n",
        "        _AccountSettings(\n"
        "          adminState: _adminState,\n"
        "          onRefreshAdmin: () => _checkAdmin(forceRefresh: true),\n"
        "        ),\n",
        "account settings admin state wiring",
    )
    text = replace_once(
        text,
        "class _AccountSettings extends StatefulWidget {\n"
        "  const _AccountSettings();\n\n"
        "  @override\n",
        "class _AccountSettings extends StatefulWidget {\n"
        "  const _AccountSettings({\n"
        "    required this.adminState,\n"
        "    required this.onRefreshAdmin,\n"
        "  });\n\n"
        "  final MarketplaceAdministratorState adminState;\n"
        "  final Future<void> Function() onRefreshAdmin;\n\n"
        "  @override\n",
        "account settings constructor",
    )
    text = regex_once(
        text,
        r"      FutureBuilder<bool>\(\n"
        r"        future: marketplaceAdministratorAccess\(\),\n.*?"
        r"      \),\n"
        r"      ListTile\(\n"
        r"          leading: const Icon\(Icons\.lock_reset_outlined\),",
        "      _AdministratorAccessCard(\n"
        "        state: widget.adminState,\n"
        "        onRefresh: widget.onRefreshAdmin,\n"
        "      ),\n"
        "      ListTile(\n"
        "          leading: const Icon(Icons.lock_reset_outlined),",
        "account settings administrator card",
    )
    marker = "\nclass _ModerationNoticesCard extends StatelessWidget {"
    card = r'''

class _AdministratorAccessCard extends StatefulWidget {
  const _AdministratorAccessCard({
    required this.state,
    required this.onRefresh,
  });

  final MarketplaceAdministratorState state;
  final Future<void> Function() onRefresh;

  @override
  State<_AdministratorAccessCard> createState() =>
      _AdministratorAccessCardState();
}

class _AdministratorAccessCardState
    extends State<_AdministratorAccessCard> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await widget.onRefresh();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final authorized = state == MarketplaceAdministratorState.authorized;
    final mfaRequired = state == MarketplaceAdministratorState.mfaRequired;
    final unavailable = state == MarketplaceAdministratorState.unavailable;
    final title = switch (state) {
      MarketplaceAdministratorState.authorized =>
        'Administrator access active',
      MarketplaceAdministratorState.mfaRequired =>
        'Administrator sign-in requires MFA',
      MarketplaceAdministratorState.roleMissing =>
        'Administrator role not assigned',
      MarketplaceAdministratorState.unavailable =>
        'Administrator access could not be verified',
      MarketplaceAdministratorState.signedOut =>
        'Administrator access unavailable',
    };
    final description = switch (state) {
      MarketplaceAdministratorState.authorized =>
        'This session has the approved administrator claims and second-factor evidence.',
      MarketplaceAdministratorState.mfaRequired =>
        'The administrator role is present, but this session did not complete multi-factor authentication. Sign out, sign in with MFA, then refresh access.',
      MarketplaceAdministratorState.roleMissing =>
        'No administrator role is assigned to this account token. Email ownership alone never grants access; an approved production operator must provision the role.',
      MarketplaceAdministratorState.unavailable =>
        'The current token could not be checked. Confirm your connection and refresh access.',
      MarketplaceAdministratorState.signedOut =>
        'Sign in before administrator access can be checked.',
    };
    final color = authorized
        ? Colors.purple
        : mfaRequired
            ? Colors.orange
            : unavailable
                ? Colors.red
                : Colors.blueGrey;

    return Card(
      color: color.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings_outlined, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(description),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Refresh access'),
                ),
                if (authorized)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MarketplaceAdminDashboard(),
                      ),
                    ),
                    icon: const Icon(Icons.launch),
                    label: const Text('Open Admin Portal'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
'''
    if text.count(marker) != 1:
        raise RuntimeError("administrator access card insertion marker mismatch")
    text = text.replace(marker, card + marker, 1)
    path.write_text(text)


def validate() -> None:
    dashboard = Path("lib/marketplace/marketplace_dispatch_dashboard.dart").read_text()
    page = Path("lib/marketplace/marketplace_dispatch_page.dart").read_text()
    account = Path("lib/marketplace/marketplace_account_hub.dart").read_text()
    assert "MarketplaceDispatchOnboarding(" in dashboard
    assert "onPostLoad: () => setState(() => section = 2)" in page
    assert "MarketplaceAdministratorState _adminState" in account
    assert "Administrator role not assigned" in account
    assert "forceRefresh: true" in account
    assert "jordilwbailey@gmail.com" not in account
    assert "goldcity4u@icloud.com" not in account


update_dispatch_dashboard()
update_dispatch_page()
update_account_hub()
validate()
