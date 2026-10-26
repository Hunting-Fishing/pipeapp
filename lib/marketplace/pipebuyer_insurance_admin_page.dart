import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'pipebuyer_insurance_client.dart';
import 'pipebuyer_insurance_taxonomy.dart';

enum InsuranceAdminTab {
  providerApplications,
  rateApplications,
  directoryProviders,
}

class PipeBuyerInsuranceAdminPage extends StatefulWidget {
  const PipeBuyerInsuranceAdminPage({
    super.key,
    this.client,
    this.initialTab = InsuranceAdminTab.providerApplications,
  });

  final PipeBuyerInsuranceClient? client;
  final InsuranceAdminTab initialTab;

  @override
  State<PipeBuyerInsuranceAdminPage> createState() =>
      _PipeBuyerInsuranceAdminPageState();
}

class _PipeBuyerInsuranceAdminPageState
    extends State<PipeBuyerInsuranceAdminPage> {
  late PipeBuyerInsuranceClient _client;
  late InsuranceAdminTab _activeTab;

  bool _checkingAuth = true;
  bool _authorized = false;
  bool _loadingDashboard = false;
  String? _errorMessage;
  PipeBuyerInsuranceAdminDashboardData? _dashboard;

  final Map<String, bool> _featureOnApproveByAppId = <String, bool>{};
  final Set<String> _busyItemIds = <String>{};

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerInsuranceClient();
    _activeTab = widget.initialTab;
    _initializeAccess();
  }

  @override
  void didUpdateWidget(covariant PipeBuyerInsuranceAdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.client != oldWidget.client) {
      _client = widget.client ?? PipeBuyerInsuranceClient();
      _dashboard = null;
      _initializeAccess();
    }
  }

  Future<void> _initializeAccess() async {
    setState(() {
      _checkingAuth = true;
      _errorMessage = null;
    });
    final hasAccess = await _client.checkAdministratorAccess(
      forceRefresh: true,
    );
    if (!mounted) return;
    if (!hasAccess) {
      setState(() {
        _authorized = false;
        _checkingAuth = false;
      });
      return;
    }
    setState(() {
      _authorized = true;
      _checkingAuth = false;
    });
    await _refreshDashboard();
  }

  Future<void> _refreshDashboard() async {
    if (!_authorized) return;
    setState(() {
      _loadingDashboard = true;
      _errorMessage = null;
    });
    try {
      final data = await _client.listAdminDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = data;
        _loadingDashboard = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$error'.replaceFirst('Bad state: ', '');
        _loadingDashboard = false;
      });
    }
  }

  Future<void> _reviewProviderApplication({
    required String applicationId,
    required String decision,
  }) async {
    setState(() => _busyItemIds.add(applicationId));
    try {
      final featured = _featureOnApproveByAppId[applicationId] ?? false;
      await _client.reviewProviderApplication(
        applicationId: applicationId,
        decision: decision,
        featured: decision == 'approved' && featured,
        reviewNote: decision == 'approved'
            ? 'Verified and published to Pipe Buyer Commercial Insurance Directory.'
            : 'Declined during underwriting compliance review.',
      );
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: decision == 'approved'
            ? 'Provider approved and published to the public directory.'
            : 'Provider application declined.',
        tone: PipeStatusTone.success,
      );
      await _refreshDashboard();
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: '$error'.replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busyItemIds.remove(applicationId));
      }
    }
  }

  Future<void> _openRateStatusDialog(
    InsuranceRateApplicationSummary application,
  ) async {
    final result = await showDialog<
      ({
        String status,
        List<String> matchedProviderNames,
        String brokerResponseNotes,
      })
    >(
      context: context,
      builder: (_) => _RateStatusUpdateDialog(application: application),
    );

    if (result == null || !mounted) return;

    setState(() => _busyItemIds.add(application.applicationId));
    try {
      await _client.updateRateApplicationStatus(
        applicationId: application.applicationId,
        status: result.status,
        matchedProviderNames: result.matchedProviderNames,
        brokerResponseNotes: result.brokerResponseNotes,
      );
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message:
            'Updated ${application.companyName} status to ${result.status.toUpperCase()}.',
        tone: PipeStatusTone.success,
      );
      await _refreshDashboard();
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: '$error'.replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busyItemIds.remove(application.applicationId));
      }
    }
  }

  Future<void> _openUpsertProviderDialog({
    Map<String, dynamic>? existing,
  }) async {
    final existingId =
        '${existing?['providerId'] ?? existing?['id'] ?? ''}'.trim();
    final payload = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _UpsertProviderDialog(existing: existing),
    );

    if (payload == null || !mounted) return;

    try {
      await _client.upsertProvider(
        providerId: existingId.isEmpty ? null : existingId,
        provider: payload,
      );
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'Insurance provider saved.',
        tone: PipeStatusTone.success,
      );
      await _refreshDashboard();
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: '$error'.replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_authorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Commercial Insurance Admin')),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 460),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Administrator Privileges Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'This account does not have the administrator role required for this workspace. Sign in with an approved administrator account and complete multi-factor authentication.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final counts = _dashboard?.counts ?? const <String, int>{};

    return Scaffold(
      backgroundColor: PipeBuyerColors.canvas,
      appBar: AppBar(
        backgroundColor: PipeBuyerColors.ink,
        foregroundColor: Colors.white,
        title: const Text('COMMERCIAL INSURANCE ADMIN'),
        actions: [
          IconButton(
            tooltip: 'Refresh Dashboard',
            onPressed: _loadingDashboard ? null : _refreshDashboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              key: const Key('admin_add_provider_button'),
              onPressed: () => _openUpsertProviderDialog(),
              icon: const Icon(Icons.add_business_outlined, size: 18),
              label: const Text('Add Provider'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1220),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildKpiRow(counts),
                const SizedBox(height: 16),
                _buildTabSwitcher(),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      color: PipeBuyerColors.danger.withValues(alpha: .08),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: PipeBuyerColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_loadingDashboard && _dashboard == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  switch (_activeTab) {
                    InsuranceAdminTab.providerApplications =>
                      _buildProviderApplicationsSection(),
                    InsuranceAdminTab.rateApplications =>
                      _buildRateApplicationsSection(),
                    InsuranceAdminTab.directoryProviders =>
                      _buildDirectoryProvidersSection(),
                  },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiRow(Map<String, int> counts) {
    final items = <({String label, int value, Color accent})>[
      (
        label: 'Pending Carrier Apps',
        value: counts['pendingProviderApps'] ?? 0,
        accent: PipeBuyerColors.orange,
      ),
      (
        label: 'New Rate Requests',
        value: counts['newRateApps'] ?? 0,
        accent: PipeBuyerColors.industrialBlue,
      ),
      (
        label: 'Total Rate Requests',
        value: counts['totalRateApps'] ?? 0,
        accent: PipeBuyerColors.slate,
      ),
      (
        label: 'Active Providers',
        value: counts['activeProviders'] ?? 0,
        accent: PipeBuyerColors.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 880
            ? 4
            : constraints.maxWidth >= 500
                ? 2
                : 1;
        final cardWidth =
            (constraints.maxWidth - ((cols - 1) * 12)) / cols;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.value}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: item.accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: PipeBuyerColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildTabSwitcher() {
    final tabs = <({InsuranceAdminTab tab, String label, Key key})>[
      (
        tab: InsuranceAdminTab.providerApplications,
        label:
            'Provider Applications (${_dashboard?.providerApplications.length ?? 0})',
        key: const Key('admin_tab_provider_apps'),
      ),
      (
        tab: InsuranceAdminTab.rateApplications,
        label:
            'Company Rate Requests (${_dashboard?.rateApplications.length ?? 0})',
        key: const Key('admin_tab_rate_apps'),
      ),
      (
        tab: InsuranceAdminTab.directoryProviders,
        label: 'Directory Providers (${_dashboard?.providers.length ?? 0})',
        key: const Key('admin_tab_providers'),
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: tabs
          .map(
            (item) => ChoiceChip(
              key: item.key,
              label: Text(item.label),
              selected: _activeTab == item.tab,
              onSelected: (_) => setState(() => _activeTab = item.tab),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildProviderApplicationsSection() {
    final apps =
        _dashboard?.providerApplications ?? const <Map<String, dynamic>>[];
    if (apps.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No carrier or broker onboarding applications yet.'),
        ),
      );
    }

    return Column(
      children: apps.map((app) {
        final appId =
            '${app['applicationId'] ?? app['id'] ?? ''}'.trim();
        final status = '${app['status'] ?? 'pending_review'}'.trim();
        final isPending = status == 'pending_review';
        final busy = _busyItemIds.contains(appId);
        final rawLines = app['coverageLines'];
        final lines = rawLines is List
            ? rawLines.map((e) => '$e').toList(growable: false)
            : const <String>[];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${app['companyName'] ?? 'Unnamed Provider'}',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Chip(
                        label: Text(status.toUpperCase()),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Type: ${app['providerType'] ?? ''} • Contact: ${app['contactName'] ?? ''} (${app['email'] ?? ''} • ${app['phone'] ?? ''})',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: PipeBuyerColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Licenses: ${app['licenseSummary'] ?? 'N/A'} • A.M. Best: ${app['amBestRating'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ('${app['summary'] ?? ''}'.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${app['summary']}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ],
                  if (lines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: lines
                          .map(
                            (code) => Chip(
                              label: Text(
                                PipeBuyerInsuranceTaxonomy.coverageShortLabel(
                                  code,
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (isPending && appId.isNotEmpty) ...[
                    const Divider(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilterChip(
                          key: Key('feature_toggle_$appId'),
                          label: const Text('Feature in Directory'),
                          selected: _featureOnApproveByAppId[appId] ?? false,
                          onSelected: busy
                              ? null
                              : (val) => setState(
                                    () => _featureOnApproveByAppId[appId] = val,
                                  ),
                        ),
                        FilledButton.icon(
                          key: Key('approve_provider_app_$appId'),
                          onPressed: busy
                              ? null
                              : () => _reviewProviderApplication(
                                    applicationId: appId,
                                    decision: 'approved',
                                  ),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Approve & Publish'),
                        ),
                        OutlinedButton.icon(
                          key: Key('decline_provider_app_$appId'),
                          onPressed: busy
                              ? null
                              : () => _reviewProviderApplication(
                                    applicationId: appId,
                                    decision: 'declined',
                                  ),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Decline'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildRateApplicationsSection() {
    final apps =
        _dashboard?.rateApplications ?? const <InsuranceRateApplicationSummary>[];
    if (apps.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No commercial insurance rate applications submitted yet.'),
        ),
      );
    }

    return Column(
      children: apps.map((app) {
        final busy = _busyItemIds.contains(app.applicationId);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        app.companyName,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Chip(
                        label: Text(app.statusLabel),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Contact: ${app.contactName} (${app.email} • ${app.phone}) • Location: ${app.city}, ${app.regionCode}, ${app.countryCode}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: PipeBuyerColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fleet: ${app.fleetVehicleCount} units • Equipment: ${PipeBuyerInsuranceTaxonomy.formatCompactUsd(app.equipmentValueUsd)} • Revenue: ${PipeBuyerInsuranceTaxonomy.revenueBandLabel(app.annualRevenueBand)} • Mode: ${app.isTargeted ? 'Targeted (${app.targetProviderName})' : 'Multi-Carrier'}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: app.coverageLines
                        .map(
                          (code) => Chip(
                            label: Text(
                              PipeBuyerInsuranceTaxonomy.coverageShortLabel(
                                code,
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(growable: false),
                  ),
                  if (app.brokerResponseNotes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Notes: ${app.brokerResponseNotes}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: Key('update_rate_app_${app.applicationId}'),
                    onPressed: busy ? null : () => _openRateStatusDialog(app),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Update Status & Quote Notes'),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildDirectoryProvidersSection() {
    final providers =
        _dashboard?.providers ?? const <Map<String, dynamic>>[];
    if (providers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No master insurance providers configured yet.'),
        ),
      );
    }

    return Column(
      children: providers.map((provider) {
        final providerId =
            '${provider['providerId'] ?? provider['id'] ?? ''}'.trim();
        final active = provider['active'] != false;
        final featured = provider['featured'] == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${provider['companyName'] ?? 'Provider'}',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (featured)
                            const Chip(
                              label: Text('FEATURED'),
                              visualDensity: VisualDensity.compact,
                            ),
                          Chip(
                            label: Text(active ? 'ACTIVE' : 'INACTIVE'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${provider['providerType'] ?? ''} • ${provider['headquartersCity'] ?? ''}, ${provider['regionCode'] ?? ''}, ${provider['countryCode'] ?? ''} • ${provider['licenseSummary'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: PipeBuyerColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: Key('edit_provider_$providerId'),
                    onPressed: () =>
                        _openUpsertProviderDialog(existing: provider),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Provider'),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _RateStatusUpdateDialog extends StatefulWidget {
  const _RateStatusUpdateDialog({required this.application});

  final InsuranceRateApplicationSummary application;

  @override
  State<_RateStatusUpdateDialog> createState() =>
      _RateStatusUpdateDialogState();
}

class _RateStatusUpdateDialogState extends State<_RateStatusUpdateDialog> {
  late String _selectedStatus;
  late final TextEditingController _matchedController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _selectedStatus = PipeBuyerInsuranceTaxonomy.rateStatuses.contains(
          widget.application.status,
        )
        ? widget.application.status
        : 'new';
    _matchedController = TextEditingController(
      text: widget.application.matchedProviderNames.join(', '),
    );
    _notesController = TextEditingController(
      text: widget.application.brokerResponseNotes,
    );
  }

  @override
  void dispose() {
    _matchedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Update Rate Request • ${widget.application.companyName}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('admin_rate_status_dropdown'),
                initialValue: _selectedStatus,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Application Status',
                ),
                items: PipeBuyerInsuranceTaxonomy.rateStatuses
                    .map(
                      (code) => DropdownMenuItem<String>(
                        value: code,
                        child: Text(code.toUpperCase()),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedStatus = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('admin_rate_matched_carriers_field'),
                controller: _matchedController,
                decoration: const InputDecoration(
                  labelText: 'Matched Carrier / Broker Names',
                  hintText: 'Comma-separated provider names',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('admin_rate_response_notes_field'),
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText:
                      'Underwriting / Quote Notes (Visible to Applicant)',
                  hintText:
                      'e.g. Indicative fleet & MSA GL quote issued; awaiting driver MVR schedule.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('admin_rate_status_save_button'),
          onPressed: () {
            final matchedNames = _matchedController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(growable: false);
            Navigator.of(context).pop((
              status: _selectedStatus,
              matchedProviderNames: matchedNames,
              brokerResponseNotes: _notesController.text.trim(),
            ));
          },
          child: const Text('Save Update'),
        ),
      ],
    );
  }
}

class _UpsertProviderDialog extends StatefulWidget {
  const _UpsertProviderDialog({this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<_UpsertProviderDialog> createState() => _UpsertProviderDialogState();
}

class _UpsertProviderDialogState extends State<_UpsertProviderDialog> {
  late final String _existingId;
  late final TextEditingController _companyController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _websiteController;
  late final TextEditingController _cityController;
  late final TextEditingController _regionController;
  late final TextEditingController _licenseController;
  late final TextEditingController _amBestController;
  late final TextEditingController _summaryController;

  late String _providerType;
  late String _countryCode;
  late final Set<String> _selectedLines;
  late bool _active;
  late bool _featured;
  late bool _msaCompliant;
  late bool _fastCoi24x7;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _existingId =
        '${existing?['providerId'] ?? existing?['id'] ?? ''}'.trim();
    _companyController = TextEditingController(
      text: '${existing?['companyName'] ?? ''}'.trim(),
    );
    _emailController = TextEditingController(
      text: '${existing?['publicEmail'] ?? existing?['email'] ?? ''}'.trim(),
    );
    _phoneController = TextEditingController(
      text: '${existing?['publicPhone'] ?? existing?['phone'] ?? ''}'.trim(),
    );
    _websiteController = TextEditingController(
      text: '${existing?['website'] ?? ''}'.trim(),
    );
    _cityController = TextEditingController(
      text: '${existing?['headquartersCity'] ?? ''}'.trim(),
    );
    _regionController = TextEditingController(
      text: '${existing?['regionCode'] ?? 'TX'}'.trim(),
    );
    _licenseController = TextEditingController(
      text: '${existing?['licenseSummary'] ?? ''}'.trim(),
    );
    _amBestController = TextEditingController(
      text: '${existing?['amBestRating'] ?? 'A (Excellent)'}'.trim(),
    );
    _summaryController = TextEditingController(
      text: '${existing?['summary'] ?? ''}'.trim(),
    );

    _providerType =
        '${existing?['providerType'] ?? 'specialty_broker'}'.trim();
    if (!PipeBuyerInsuranceTaxonomy.providerTypes.any(
      (item) => item.code == _providerType,
    )) {
      _providerType = 'specialty_broker';
    }
    _countryCode =
        '${existing?['countryCode'] ?? 'US'}'.trim().toUpperCase();
    if (_countryCode != 'US' && _countryCode != 'CA') {
      _countryCode = 'US';
    }

    final existingLines = existing?['coverageLines'];
    _selectedLines = <String>{
      if (existingLines is List)
        ...existingLines.map((e) => '$e'.trim()).where((e) => e.isNotEmpty)
      else ...<String>[
        'commercial_auto_fleet',
        'oilfield_general_liability',
      ],
    };
    _active = existing == null ? true : existing['active'] != false;
    _featured = existing?['featured'] == true;
    _msaCompliant = existing == null ? true : existing['msaCompliant'] == true;
    _fastCoi24x7 = existing == null ? true : existing['fastCoi24x7'] == true;
  }

  @override
  void dispose() {
    _companyController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _licenseController.dispose();
    _amBestController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _existingId.isEmpty
            ? 'Add Insurance Provider'
            : 'Edit Insurance Provider',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('admin_provider_company_field'),
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company Name *',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _providerType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Provider Type',
                ),
                items: PipeBuyerInsuranceTaxonomy.providerTypes
                    .map(
                      (t) => DropdownMenuItem<String>(
                        value: t.code,
                        child: Text(
                          t.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _providerType = val);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('admin_provider_email_field'),
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Public Submissions Email *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('admin_provider_phone_field'),
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Public Phone *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _websiteController,
                decoration: const InputDecoration(
                  labelText: 'Website URL',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _countryCode,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'US',
                          child: Text('US'),
                        ),
                        DropdownMenuItem(
                          value: 'CA',
                          child: Text('CA'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _countryCode = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _regionController,
                      decoration: const InputDecoration(
                        labelText: 'Region',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Headquarters City',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('admin_provider_license_field'),
                controller: _licenseController,
                decoration: const InputDecoration(
                  labelText: 'License / NAIC Summary *',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amBestController,
                decoration: const InputDecoration(
                  labelText: 'A.M. Best Rating',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _summaryController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Directory Summary',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Coverage Lines *',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: PipeBuyerInsuranceTaxonomy.coverageLines
                    .map(
                      (line) => FilterChip(
                        label: Text(line.shortLabel),
                        selected: _selectedLines.contains(line.code),
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedLines.add(line.code);
                            } else if (_selectedLines.length > 1) {
                              _selectedLines.remove(line.code);
                            }
                          });
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (val) => setState(() => _active = val ?? true),
                title: const Text('Active in Public Directory'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _featured,
                onChanged: (val) => setState(() => _featured = val ?? false),
                title: const Text('Featured Placement'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _msaCompliant,
                onChanged: (val) =>
                    setState(() => _msaCompliant = val ?? false),
                title: const Text('MSA-Compliant Endorsements'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _fastCoi24x7,
                onChanged: (val) => setState(() => _fastCoi24x7 = val ?? false),
                title: const Text('24/7 Fast COI Issuance'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('admin_provider_save_button'),
          onPressed: () {
            Navigator.of(context).pop(<String, Object?>{
              'companyName': _companyController.text.trim(),
              'providerType': _providerType,
              'publicEmail': _emailController.text.trim(),
              'publicPhone': _phoneController.text.trim(),
              'website': _websiteController.text.trim(),
              'countryCode': _countryCode,
              'regionCode': _regionController.text.trim().toUpperCase(),
              'headquartersCity': _cityController.text.trim(),
              'licensedCountries': <String>[_countryCode],
              'licensedRegions': <String>[
                if (_regionController.text.trim().isNotEmpty)
                  _regionController.text.trim().toUpperCase(),
              ],
              'coverageLines': _selectedLines.toList(growable: false),
              'licenseSummary': _licenseController.text.trim(),
              'amBestRating': _amBestController.text.trim(),
              'summary': _summaryController.text.trim(),
              'active': _active,
              'featured': _featured,
              'msaCompliant': _msaCompliant,
              'fastCoi24x7': _fastCoi24x7,
              'verified': true,
            });
          },
          child: const Text('Save Provider'),
        ),
      ],
    );
  }
}
