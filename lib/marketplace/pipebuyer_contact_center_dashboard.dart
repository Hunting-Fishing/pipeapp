import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'marketplace_auth_page.dart';
import 'pipebuyer_yellow_pages_client.dart';

class PipeBuyerContactCenterDashboard extends StatefulWidget {
  const PipeBuyerContactCenterDashboard({super.key});

  @override
  State<PipeBuyerContactCenterDashboard> createState() =>
      _PipeBuyerContactCenterDashboardState();
}

class _PipeBuyerContactCenterDashboardState
    extends State<PipeBuyerContactCenterDashboard> {
  final PipeBuyerYellowPagesClient _client = PipeBuyerYellowPagesClient();
  StreamSubscription<User?>? _authSubscription;

  PipeBuyerYellowPagesAccess? _access;
  bool _loadingAccess = true;
  bool _loadingCompanies = false;
  String? _error;
  String _view = 'my_queue';
  String? _nextCursor;
  List<Map<String, dynamic>> _companies = const [];

  static const _views = <_ContactCenterView>[
    _ContactCenterView('my_queue', 'My Queue', Icons.assignment_ind_outlined),
    _ContactCenterView(
        'not_contacted', 'Not Contacted', Icons.phone_disabled_outlined),
    _ContactCenterView('follow_up', 'Follow-Ups', Icons.schedule_outlined),
    _ContactCenterView('unverified', 'Unverified', Icons.help_outline),
    _ContactCenterView(
        'verified_unpaid', 'Verified / Unpaid', Icons.verified_outlined),
    _ContactCenterView(
        'paid_confirmed', 'Paid / Confirmed', Icons.paid_outlined),
    _ContactCenterView('published', 'Published', Icons.public_outlined),
    _ContactCenterView(
        'expired', 'Unpaid / Expired', Icons.event_busy_outlined),
    _ContactCenterView(
        'do_not_contact', 'Do Not Contact', Icons.block_outlined),
    _ContactCenterView('all', 'All Companies', Icons.business_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _authSubscription =
        FirebaseAuth.instance.idTokenChanges().listen((_) => _refreshAccess());
    _refreshAccess(forceTokenRefresh: true);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshAccess({bool forceTokenRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _loadingAccess = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && forceTokenRefresh) {
        await user.getIdToken(true);
      }
      final access = await _client.getAccess();
      if (!mounted) return;
      setState(() {
        _access = access;
        _loadingAccess = false;
      });
      if (access.authorized) {
        await _loadView(_view, reset: true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingAccess = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _loadView(String view, {required bool reset}) async {
    if (_access?.authorized != true || _loadingCompanies) return;
    setState(() {
      _loadingCompanies = true;
      _error = null;
      if (reset) {
        _view = view;
        _companies = const [];
        _nextCursor = null;
      }
    });
    try {
      final page = await _client.listDashboardView(
        view,
        cursor: reset ? null : _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        _companies = reset
            ? page.items
            : List<Map<String, dynamic>>.unmodifiable(
                <Map<String, dynamic>>[..._companies, ...page.items],
              );
        _nextCursor = page.nextCursor;
        _loadingCompanies = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCompanies = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _openSignIn() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MarketplaceAuthPage()),
    );
    await _refreshAccess(forceTokenRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingAccess) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final access = _access;
    if (user == null || access?.reason == 'signed_out') {
      return _ContactCenterSignIn(onSignIn: _openSignIn);
    }
    if (access?.authorized != true) {
      return _ContactCenterDenied(
        reason: access?.reason,
        onRefresh: () => _refreshAccess(forceTokenRefresh: true),
      );
    }

    final selectedView = _views.firstWhere((item) => item.id == _view);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PIPEBUYER CONTACT CENTER',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Chip(
              avatar: const Icon(Icons.shield_outlined, size: 18),
              label: Text(_roleLabel(access!.role)),
            ),
          ),
          if (access.isAdministrator)
            IconButton(
              tooltip: 'Contact Center employees',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _StaffManagerDialog(client: _client),
              ),
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _loadView(_view, reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Private employee workspace. Internal contact information, outreach notes, billing evidence and suppression records are never published automatically.',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              scrollDirection: Axis.horizontal,
              itemCount: _views.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _views[index];
                return ChoiceChip(
                  selected: item.id == _view,
                  avatar: Icon(item.icon, size: 17),
                  label: Text(item.label),
                  onSelected: (_) => _loadView(item.id, reset: true),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                Icon(selectedView.icon),
                const SizedBox(width: 8),
                Text(
                  selectedView.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const Spacer(),
                Text('${_companies.length} loaded'),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(_error!),
                  trailing: TextButton(
                    onPressed: () => _loadView(_view, reset: true),
                    child: const Text('Retry'),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loadingCompanies && _companies.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _companies.isEmpty
                    ? const Center(
                        child: Text('No companies are currently in this queue.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                        itemCount: _companies.length + (_nextCursor != null ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _companies.length) {
                            return Padding(
                              padding: const EdgeInsets.all(12),
                              child: Center(
                                child: FilledButton.tonalIcon(
                                  onPressed: _loadingCompanies
                                      ? null
                                      : () => _loadView(_view, reset: false),
                                  icon: _loadingCompanies
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.expand_more),
                                  label: const Text('Load more'),
                                ),
                              ),
                            );
                          }
                          final company = _companies[index];
                          return _CompanyCard(company: company);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _message(Object error) {
    final raw = error.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
    return raw.length > 240 ? 'The Contact Center request failed.' : raw;
  }

  String _roleLabel(String? role) => switch (role) {
        'administrator' => 'Administrator',
        'manager' => 'Manager',
        'agent' => 'Contact Agent',
        _ => 'Restricted',
      };
}

class _ContactCenterView {
  const _ContactCenterView(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.company});

  final Map<String, dynamic> company;

  @override
  Widget build(BuildContext context) {
    final name = '${company['companyName'] ?? 'Unnamed company'}';
    final city = '${company['city'] ?? ''}'.trim();
    final region = '${company['regionCode'] ?? ''}'.trim();
    final website = '${company['website'] ?? ''}'.trim();
    final location = [city, region].where((item) => item.isNotEmpty).join(', ');
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (location.isNotEmpty) Text(location),
            if (website.isNotEmpty)
              Text(website, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _StatusChip('${company['outreachStatus'] ?? 'not_contacted'}'),
                _StatusChip('${company['verificationStatus'] ?? 'unverified'}'),
                _StatusChip('${company['billingStatus'] ?? 'unpaid'}'),
                _StatusChip('${company['publicationStatus'] ?? 'unpublished'}'),
                if (company['doNotContact'] == true)
                  const _StatusChip('DO NOT CONTACT', blocked: true),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label, {this.blocked = false});
  final String label;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(
          color: blocked ? Theme.of(context).colorScheme.error : Colors.black26,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: blocked ? Theme.of(context).colorScheme.error : null,
        ),
      ),
    );
  }
}

class _ContactCenterSignIn extends StatelessWidget {
  const _ContactCenterSignIn({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PipeBuyer Contact Center')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.support_agent_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Employee Sign In',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This private workspace is for authorized PipeBuyer Contact Center employees and administrators. Each employee must use their own verified account.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onSignIn,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in to Contact Center'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactCenterDenied extends StatelessWidget {
  const _ContactCenterDenied({required this.reason, required this.onRefresh});
  final String? reason;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final message = switch (reason) {
      'verified_email_required' =>
        'Verify the email address on this account before Contact Center access can be granted.',
      'mfa_required' =>
        'Multi-factor authentication must be enrolled and completed before Contact Center access is allowed.',
      'roster_inactive' =>
        'This employee account is not active on the Contact Center roster.',
      _ =>
        'This account does not have an active PipeBuyer Contact Center role. An administrator must grant employee access.',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('PipeBuyer Contact Center')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Contact Center Access Required',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh access'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffManagerDialog extends StatefulWidget {
  const _StaffManagerDialog({required this.client});
  final PipeBuyerYellowPagesClient client;

  @override
  State<_StaffManagerDialog> createState() => _StaffManagerDialogState();
}

class _StaffManagerDialogState extends State<_StaffManagerDialog> {
  final TextEditingController _emailController = TextEditingController();
  String _role = 'agent';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _staff = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final staff = await widget.client.listStaff();
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
      });
    }
  }

  Future<void> _grant() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.client.manageStaff(email: email, active: true, role: _role);
      _emailController.clear();
      await _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
      });
      return;
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _revoke(String email) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.client.manageStaff(email: email, active: false);
      await _reload();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contact Center Employees'),
      content: SizedBox(
        width: 680,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Employees must already have a verified Pipe Buyer account with MFA enrolled. Shared employee accounts are not permitted.',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Employee account email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'agent', child: Text('Agent')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _role = value ?? 'agent'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _saving ? null : _grant,
                  child: const Text('Grant access'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _staff.isEmpty
                      ? const Center(child: Text('No Contact Center employees yet.'))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _staff.length,
                          itemBuilder: (context, index) {
                            final employee = _staff[index];
                            final active = employee['active'] == true;
                            final email = '${employee['email'] ?? ''}';
                            return ListTile(
                              leading: Icon(active
                                  ? Icons.person_outline
                                  : Icons.person_off_outlined),
                              title: Text(email.isEmpty
                                  ? '${employee['uid'] ?? 'Employee'}'
                                  : email),
                              subtitle: Text(
                                  '${employee['role'] ?? 'inactive'} • ${active ? 'Active' : 'Disabled'}'),
                              trailing: active
                                  ? TextButton(
                                      onPressed: _saving || email.isEmpty
                                          ? null
                                          : () => _revoke(email),
                                      child: const Text('Revoke'),
                                    )
                                  : null,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
