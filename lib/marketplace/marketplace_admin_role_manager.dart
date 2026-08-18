import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';

class MarketplaceAdminRoleManager extends StatefulWidget {
  const MarketplaceAdminRoleManager({super.key});

  @override
  State<MarketplaceAdminRoleManager> createState() =>
      _MarketplaceAdminRoleManagerState();
}

class _MarketplaceAdminRoleManagerState
    extends State<MarketplaceAdminRoleManager> {
  final MarketplaceCommandClient _commands = MarketplaceCommandClient();
  final TextEditingController _email = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _administrators = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _commands.execute('listAdministratorRoles', const {});
      final raw = result['administrators'];
      final administrators = raw is List
          ? raw
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() => _administrators = administrators);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback:
              'Administrator roster management is restricted to the primary administrator.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _grant() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      PipeFeedback.show(
        context,
        message:
            'Enter the Pipe Buyer account email to grant administrator access.',
        tone: PipeStatusTone.error,
      );
      return;
    }
    await _change(email, true);
  }

  Future<void> _revoke(Map<String, dynamic> administrator) async {
    final email = '${administrator['email'] ?? ''}'.trim();
    if (email.isEmpty || administrator['primaryManager'] == true) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Remove administrator access?'),
            content: Text(
              '$email will immediately lose administrator claims and existing sessions will be revoked.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove administrator'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await _change(email, false);
  }

  Future<void> _change(String email, bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await _commands.execute(
        'manageAdministratorRole',
        {'email': email, 'enabled': enabled},
      );
      if (!mounted) return;
      if (enabled) _email.clear();
      PipeFeedback.show(
        context,
        message: enabled
            ? 'Administrator access granted. The account must sign in again with MFA.'
            : 'Administrator access removed and existing sessions revoked.',
        tone: PipeStatusTone.success,
      );
      if (result['signInAgainRequired'] == true) {
        await _reload();
      }
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(
          error,
          fallback: 'Administrator access could not be updated.',
        ),
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrator access')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const PipeBuyerPageHeader(
            eyebrow: 'PRIMARY ADMINISTRATOR CONTROL',
            title: 'Administrator roster',
            subtitle:
                'Administrator access is granted through protected Firebase claims and requires verified email plus multi-factor authentication.',
            icon: Icons.admin_panel_settings_outlined,
          ),
          const SizedBox(height: 12),
          const PipeBuyerSectionCard(
            title: 'Security boundary',
            subtitle:
                'Changing a user profile field never grants administrator access.',
            leading: Icon(
              Icons.security_outlined,
              color: PipeBuyerColors.orange,
            ),
            child: Text(
              'Only the primary administrator can change this roster. Grants require an existing Pipe Buyer account with verified email and enrolled MFA. Revocation invalidates existing sessions.',
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            PipeStatusSurface(
              tone: PipeStatusTone.error,
              title: 'Roster management unavailable',
              message: _error!,
              action: TextButton(
                onPressed: _reload,
                child: const Text('Retry'),
              ),
            )
          else ...[
            PipeBuyerSectionCard(
              title: 'Add administrator',
              subtitle:
                  'The account must already have verified email and an enrolled Firebase MFA method.',
              leading: const Icon(Icons.person_add_alt_1_outlined),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Pipe Buyer account email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    onSubmitted: (_) {
                      if (!_busy) _grant();
                    },
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _grant,
                    icon: const Icon(Icons.verified_user_outlined),
                    label:
                        Text(_busy ? 'Working...' : 'Grant administrator access'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PipeBuyerSectionCard(
              title: 'Active administrators',
              subtitle:
                  '${_administrators.length} active administrator account${_administrators.length == 1 ? '' : 's'}',
              leading: const Icon(Icons.groups_2_outlined),
              child: _administrators.isEmpty
                  ? const Text('No active administrator records were returned.')
                  : Column(
                      children: _administrators.map((administrator) {
                        final email = '${administrator['email'] ?? ''}'.trim();
                        final primary = administrator['primaryManager'] == true;
                        final factors = int.tryParse(
                              '${administrator['enrolledFactorCount'] ?? 0}',
                            ) ??
                            0;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            primary
                                ? Icons.workspace_premium_outlined
                                : Icons.admin_panel_settings_outlined,
                            color: primary ? PipeBuyerColors.orange : null,
                          ),
                          title:
                              Text(email.isEmpty ? 'Missing Auth account' : email),
                          subtitle: Text(
                            primary
                                ? 'Primary administrator manager - MFA factors: $factors'
                                : 'Administrator - MFA factors: $factors',
                          ),
                          trailing: primary
                              ? const Chip(label: Text('Protected'))
                              : TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _revoke(administrator),
                                  icon:
                                      const Icon(Icons.person_remove_outlined),
                                  label: const Text('Remove'),
                                ),
                        );
                      }).toList(growable: false),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
