import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'pipebuyer_country_flag_icon.dart';
import 'pipebuyer_yellow_pages_client.dart';
import 'pipebuyer_yellow_pages_taxonomy.dart';

class PipeBuyerContactCenterDashboard extends StatefulWidget {
  const PipeBuyerContactCenterDashboard({
    super.key,
    this.client,
    this.initialSearchQuery = '',
    this.initialView = 'all',
  });

  final PipeBuyerYellowPagesClient? client;
  final String initialSearchQuery;
  final String initialView;

  @override
  State<PipeBuyerContactCenterDashboard> createState() =>
      _PipeBuyerContactCenterDashboardState();
}

class _PipeBuyerContactCenterDashboardState
    extends State<PipeBuyerContactCenterDashboard> {
  static const _managerViews = <(String, String, IconData)>[
    ('all', 'All Companies', Icons.business_outlined),
    ('my_queue', 'My Queue', Icons.assignment_ind_outlined),
    ('not_contacted', 'Not Contacted', Icons.phone_callback_outlined),
    ('follow_up', 'Follow-Ups', Icons.schedule_outlined),
    ('unverified', 'Unverified', Icons.pending_actions_outlined),
    ('verified_unpaid', 'Verified / Unpaid', Icons.verified_outlined),
    ('paid_confirmed', 'Paid / Confirmed', Icons.workspace_premium_outlined),
    ('published', 'Published Live', Icons.public_outlined),
    ('hidden_disabled', 'Viewing OFF', Icons.visibility_off_outlined),
    ('flagged_prohibited', 'Flagged / Prohibited', Icons.gpp_bad_outlined),
    ('listing_requests', 'List Services Requests', Icons.inbox_outlined),
    ('book_pages', '2015/2016 Book Pages', Icons.menu_book_outlined),
    ('do_not_contact', 'Do Not Contact', Icons.phone_disabled_outlined),
  ];

  static const _searchFilters = <(String, String)>[
    ('', 'All Matches'),
    ('flagged', 'Flagged / Prohibited'),
    ('hidden', 'Viewing OFF'),
    ('visible', 'Viewing ON'),
    ('paid', 'Paid Priority'),
    ('number_changed', 'Old -> New Phone'),
  ];

  late final PipeBuyerYellowPagesClient _client =
      widget.client ?? PipeBuyerYellowPagesClient();
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  PipeBuyerYellowPagesAccess? _access;
  String _selectedView = 'all';
  String _searchFilterState = '';
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _companies = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _listingRequests = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _bookPages = const <Map<String, dynamic>>[];

  bool get _isSearchActive =>
      _searchController.text.trim().isNotEmpty || _searchFilterState.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearchQuery);
    _selectedView = widget.initialView;
    _loadInitial();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _refreshData();
    });
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await _client.getAccess();
      if (!mounted) return;
      if (!access.authorized) {
        setState(() {
          _access = access;
          _loading = false;
        });
        return;
      }
      _access = access;
      if (access.role == 'agent') {
        _selectedView = 'my_queue';
      }
      await _refreshData();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _refreshData() async {
    final access = _access;
    if (access == null || !access.authorized) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (access.isManager && _isSearchActive) {
        final results = await _client.searchAdminCompanies(
          query: _searchController.text.trim(),
          filterState: _searchFilterState,
          pageSize: 80,
        );
        if (!mounted) return;
        setState(() {
          _companies = results;
          _listingRequests = const <Map<String, dynamic>>[];
          _bookPages = const <Map<String, dynamic>>[];
          _loading = false;
        });
        return;
      }

      final activeView = access.role == 'agent' ? 'my_queue' : _selectedView;
      final raw = await _client.listDashboardViewRaw(activeView, pageSize: 80);
      if (!mounted) return;

      final companies = (raw['companies'] is List)
          ? (raw['companies'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];

      final requests = (raw['listingRequests'] is List)
          ? (raw['listingRequests'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];

      final pages = (raw['bookPages'] is List)
          ? (raw['bookPages'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];

      setState(() {
        _companies = companies;
        _listingRequests = requests;
        _bookPages = pages;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _quickToggleViewing(
    Map<String, dynamic> company,
    bool enableViewing,
  ) async {
    final companyId = '${company['id'] ?? ''}';
    if (companyId.isEmpty) return;
    final companyName = '${company['companyName'] ?? 'Company'}';

    if (enableViewing && company['isFlaggedProhibited'] == true) {
      _showSnack(
        'Clear Flagged / Prohibited status first before enabling public viewing for $companyName.',
        isError: true,
      );
      return;
    }

    try {
      final needsQuickPublish = enableViewing &&
          ('${company['publicationStatus'] ?? ''}' != 'published' ||
              '${company['verificationStatus'] ?? ''}' != 'verified');
      await _client.setCompanyVisibility(
        companyId,
        visible: enableViewing,
        publishImmediately: needsQuickPublish,
        reason: enableViewing
            ? 'Admin turned public viewing ON'
            : 'Admin turned public viewing OFF',
      );
      if (!mounted) return;
      _showSnack(
        enableViewing
            ? 'Public viewing turned ON for $companyName.'
            : 'Public viewing turned OFF for $companyName (removed from website).',
      );
      await _refreshData();
    } catch (error) {
      if (!mounted) return;
      _showSnack(_cleanError(error), isError: true);
    }
  }

  Future<void> _promptFlagCompany(Map<String, dynamic> company) async {
    final companyId = '${company['id'] ?? ''}';
    if (companyId.isEmpty) return;
    final currentlyFlagged = company['isFlaggedProhibited'] == true;
    final companyName = '${company['companyName'] ?? 'Company'}';

    if (currentlyFlagged) {
      final confirmClear = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Clear Flagged / Prohibited Status?'),
          content: Text(
            'This unflags $companyName. Note: Public viewing remains OFF until you explicitly switch Viewing ON, and any numbers in the Blocked Numbers list can be managed in Blocked Numbers.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Clear Flag'),
            ),
          ],
        ),
      );
      if (confirmClear != true) return;
      try {
        await _client.setFlaggedStatus(
          companyId,
          flagged: false,
          reason: 'Admin cleared flag',
          blockPhones: false,
        );
        if (!mounted) return;
        _showSnack('Cleared prohibited flag for $companyName.');
        await _refreshData();
      } catch (error) {
        if (!mounted) return;
        _showSnack(_cleanError(error), isError: true);
      }
      return;
    }

    final reasonCtrl = TextEditingController();
    bool blockAllPhones = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.gpp_bad, color: PipeBuyerColors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text('Flag & Prohibit $companyName')),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flagging immediately removes this business from public search, sets Do Not Contact, and blocks self-serve listing submissions.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Prohibition / Flag Reason (Required)',
                    hintText:
                        'e.g., Prohibited business, fraudulent dispatch representation, safety violation...',
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: blockAllPhones,
                  onChanged: (val) =>
                      setModalState(() => blockAllPhones = val ?? true),
                  title: const Text(
                    'Blacklist all phone numbers (current, toll-free & 2015/2016 old numbers)',
                  ),
                  subtitle: const Text(
                    'Prevents anyone from re-registering these phone numbers on PipeBuyer.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PipeBuyerColors.danger,
              ),
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Flag & Prohibit Business'),
            ),
          ],
        ),
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirmed != true || reason.isEmpty) return;

    try {
      await _client.setFlaggedStatus(
        companyId,
        flagged: true,
        reason: reason,
        blockPhones: blockAllPhones,
      );
      if (!mounted) return;
      _showSnack('$companyName flagged & prohibited from PipeBuyer.');
      await _refreshData();
    } catch (error) {
      if (!mounted) return;
      _showSnack(_cleanError(error), isError: true);
    }
  }

  Future<void> _openCompanySheet(Map<String, dynamic> summary) async {
    final access = _access;
    if (access == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompanyControlSheet(
        client: _client,
        access: access,
        initialCompany: summary,
      ),
    );
    if (updated == true) {
      await _refreshData();
    }
  }

  Future<void> _openUpsertCompanyDialog(
      {Map<String, dynamic>? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CompanyUpsertDialog(
        client: _client,
        existing: existing,
      ),
    );
    if (saved == true) {
      await _refreshData();
    }
  }

  Future<void> _openBlockedNumbersDialog() async {
    final access = _access;
    if (access == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _BlockedNumbersDialog(
        client: _client,
        isAdmin: access.isAdministrator,
      ),
    );
  }

  Future<void> _openStaffDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _StaffManagerDialog(client: _client),
    );
  }

  Future<void> _openLogBookPageDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _BookPageAuditDialog(client: _client),
    );
    if (saved == true) {
      await _refreshData();
    }
  }

  Future<void> _reviewListingRequest(
    Map<String, dynamic> req, {
    required String decision,
    bool markPaid = false,
  }) async {
    final requestId = '${req['id'] ?? ''}';
    if (requestId.isEmpty) return;
    try {
      await _client.reviewListingRequest(
        requestId: requestId,
        decision: decision,
        markPaid: markPaid,
        reviewNote: decision == 'approved'
            ? (markPaid
                ? 'Approved & marked Paid Priority by Admin'
                : 'Approved & published by Admin')
            : 'Rejected by Admin',
      );
      if (!mounted) return;
      _showSnack(
        decision == 'approved'
            ? 'Listing approved & published to the Oilfield Directory!'
            : 'Listing request rejected.',
      );
      await _refreshData();
    } catch (error) {
      if (!mounted) return;
      _showSnack(_cleanError(error), isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? PipeBuyerColors.danger : PipeBuyerColors.ink,
      ),
    );
  }

  static String _cleanError(Object error) =>
      error.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');

  @override
  Widget build(BuildContext context) {
    final access = _access;
    return Scaffold(
      backgroundColor: PipeBuyerColors.canvas,
      appBar: AppBar(
        backgroundColor: PipeBuyerColors.ink,
        foregroundColor: Colors.white,
        title: const Text('Oilfield Directory Admin & Contact Center'),
        actions: [
          if (access != null && access.isManager)
            TextButton.icon(
              onPressed: () => _openUpsertCompanyDialog(),
              icon: const Icon(Icons.add_business_outlined,
                  color: Colors.white, size: 18),
              label: const Text(
                'Add Company',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          if (access != null && access.isManager)
            IconButton(
              tooltip: 'Blocked / Prohibited Phone Numbers',
              onPressed: _openBlockedNumbersDialog,
              icon: const Icon(Icons.phone_locked_outlined),
            ),
          if (access != null && access.isAdministrator)
            IconButton(
              tooltip: 'Manage Contact Center Employees (MFA)',
              onPressed: _openStaffDialog,
              icon: const Icon(Icons.badge_outlined),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refreshData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final access = _access;
    if (_loading && access == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (access != null && !access.authorized) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, color: PipeBuyerColors.orange),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Authorized Staff & Admin Access Only',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_accessReasonCopy(access.reason)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadInitial,
                    child: const Text('Check Access Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (access != null && access.isManager) _buildAdminSearchHeader(),
            if (access != null && access.isManager && !_isSearchActive)
              _buildViewSelectorBar(),
            if (_error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: PipeBuyerColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: PipeBuyerColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildActiveContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminSearchHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PipeBuyerColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.manage_search,
                  color: PipeBuyerColors.orange, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Admin Master Lookup — Search Company, Current Number, or Old 2015/2016 Book Number',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: PipeBuyerColors.ink,
                  ),
                ),
              ),
              if (_isSearchActive)
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchFilterState = '');
                    _refreshData();
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Search'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _refreshData(),
            decoration: InputDecoration(
              hintText:
                  'Search phone e.g. (780) 532-1234, 800-number, company name, or city — toggle Viewing ON/OFF or Flag...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Run Admin Search',
                onPressed: _refreshData,
                icon: const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _searchFilters.map((filter) {
              final selected = _searchFilterState == filter.$1;
              return ChoiceChip(
                label: Text(filter.$2),
                selected: selected,
                onSelected: (_) {
                  setState(() => _searchFilterState = filter.$1);
                  _refreshData();
                },
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSelectorBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: _managerViews.map((entry) {
          final selected = _selectedView == entry.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                entry.$3,
                size: 16,
                color: selected ? Colors.white : PipeBuyerColors.slate,
              ),
              selectedColor: PipeBuyerColors.ink,
              labelStyle: TextStyle(
                color: selected ? Colors.white : PipeBuyerColors.ink,
                fontWeight: FontWeight.w700,
              ),
              label: Text(entry.$2),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedView = entry.$1);
                _refreshData();
              },
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildActiveContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isSearchActive && _selectedView == 'listing_requests') {
      return _buildListingRequestsList();
    }
    if (!_isSearchActive && _selectedView == 'book_pages') {
      return _buildBookPagesList();
    }

    if (_companies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.find_in_page_outlined,
                  size: 42, color: PipeBuyerColors.muted),
              const SizedBox(height: 12),
              Text(
                _isSearchActive
                    ? 'No companies or phone numbers matched your search.'
                    : 'No companies currently in this queue.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PipeBuyerColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              if (_access?.isManager == true)
                OutlinedButton.icon(
                  onPressed: () => _openUpsertCompanyDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Company Record Manually'),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _companies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final company = _companies[index];
        return _AdminCompanyRowCard(
          company: company,
          isAdmin: _access?.isAdministrator == true,
          onTap: () => _openCompanySheet(company),
          onToggleViewing: (visible) => _quickToggleViewing(company, visible),
          onToggleFlag: () => _promptFlagCompany(company),
          onEdit: () => _openUpsertCompanyDialog(existing: company),
        );
      },
    );
  }

  Widget _buildListingRequestsList() {
    if (_listingRequests.isEmpty) {
      return const Center(
        child: Text(
          'No inbound "List Services" submissions awaiting review.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _listingRequests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final req = _listingRequests[index];
        final status = '${req['status'] ?? 'pending_review'}';
        final tier = '${req['requestedTier'] ?? 'paid_verified'}';
        final isPending = status == 'pending_review';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${req['companyName'] ?? 'Unnamed Business'}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _PillBadge(
                      label: 'Requested: $tier',
                      color: tier == 'featured_platinum'
                          ? PipeBuyerColors.orange
                          : PipeBuyerColors.industrialBlue,
                    ),
                    _PillBadge(
                      label: 'Status: $status',
                      color: status == 'approved'
                          ? PipeBuyerColors.success
                          : PipeBuyerColors.slate,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Contact: ${req['contactName'] ?? '—'} • Phone: ${req['phone'] ?? '—'} • Email: ${req['email'] ?? '—'}',
                  style: const TextStyle(color: PipeBuyerColors.slate),
                ),
                Row(
                  children: [
                    PipeBuyerCountryFlagIcon(
                      countryCode: '${req['countryCode'] ?? 'CA'}',
                      width: 17,
                      height: 12,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Location: ${req['city'] ?? ''}, ${req['regionCode'] ?? ''} (${req['countryCode'] ?? 'CA'}) • Website: ${req['website'] ?? '—'}',
                        style: const TextStyle(color: PipeBuyerColors.slate),
                      ),
                    ),
                  ],
                ),
                if (isPending && _access?.isAdministrator == true) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _reviewListingRequest(
                          req,
                          decision: 'approved',
                          markPaid: tier != 'free_verified',
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          tier == 'free_verified'
                              ? 'Approve & Publish (Basic)'
                              : 'Approve as Paid Priority & Publish',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _reviewListingRequest(
                          req,
                          decision: 'approved',
                          markPaid: false,
                        ),
                        child: const Text('Approve as Unpaid Verified'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: PipeBuyerColors.danger,
                        ),
                        onPressed: () => _reviewListingRequest(
                          req,
                          decision: 'rejected',
                        ),
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookPagesList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PipeBuyerColors.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_a_photo_outlined,
                    color: PipeBuyerColors.orange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2015/2016 Yellow Book — Google Drive Page Photo Audit Tracker',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Track photographed pages from the physical 2015/2016 COSSD 35th Anniversary Book, compare against live database records, and audit old -> new numbers.',
                        style: TextStyle(
                            fontSize: 12, color: PipeBuyerColors.slate),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _openLogBookPageDialog,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Log Drive Page'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _bookPages.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No physical 2015/2016 book pages logged yet. Upload photos to Google Drive and run bot4_book_drive_page_auditor.mjs or click "Log Drive Page".',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookPages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final page = _bookPages[index];
                    final driveUrl = '${page['driveFileUrl'] ?? ''}'.trim();
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: PipeBuyerColors.orangeSoft,
                          foregroundColor: PipeBuyerColors.orange,
                          child: Text(
                            'P.${page['pageNumber'] ?? '?'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          'Page ${page['pageNumber']} — ${page['categoryHeader'] ?? page['section'] ?? 'Yellow Services'}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          'Status: ${page['auditStatus'] ?? 'uploaded'} • Extracted: ${page['extractedCompanyCount'] ?? 0} • DB Matched: ${page['matchedDatabaseCount'] ?? 0} • Active Confirmed: ${page['activeConfirmedCount'] ?? 0} • Number Changed: ${page['numberChangedCount'] ?? 0}',
                        ),
                        trailing: driveUrl.isNotEmpty
                            ? OutlinedButton.icon(
                                onPressed: () => launchUrl(
                                  Uri.parse(driveUrl),
                                  mode: LaunchMode.externalApplication,
                                ),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Drive Photo'),
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _accessReasonCopy(String? reason) => switch (reason) {
        'signed_out' =>
          'Sign in with your PipeBuyer Admin or Contact Center account.',
        'email_unverified' =>
          'Verify your email address before opening the Oilfield Directory Contact Center.',
        'mfa_required' =>
          'Multi-factor authentication (MFA) is required before accessing private Contact Center phone records.',
        _ =>
          'Your account is not enrolled in the Oilfield Directory Contact Center or Admin roster.',
      };
}

class _AdminCompanyRowCard extends StatelessWidget {
  const _AdminCompanyRowCard({
    required this.company,
    required this.isAdmin,
    required this.onTap,
    required this.onToggleViewing,
    required this.onToggleFlag,
    required this.onEdit,
  });

  final Map<String, dynamic> company;
  final bool isAdmin;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleViewing;
  final VoidCallback onToggleFlag;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final flagged = company['isFlaggedProhibited'] == true;
    final viewingEnabled = company['adminViewingEnabled'] != false && !flagged;
    final published =
        company['publicationStatus'] == 'published' && viewingEnabled;
    final isVerified = company['verificationStatus'] == 'verified';
    final tier =
        '${company['effectiveTier'] ?? company['listingTier'] ?? 'free_basic'}';
    final opStatus = '${company['operationalStatus'] ?? 'unverified'}';
    final mainPhone =
        '${company['mainPhone'] ?? company['publicPhone'] ?? ''}'.trim();
    final tollFree = '${company['tollFreePhone'] ?? ''}'.trim();
    final legacyPhones = (company['legacyPhones'] is List)
        ? (company['legacyPhones'] as List)
            .map((e) => '$e')
            .toList(growable: false)
        : const <String>[];
    final callingWindow = company['callingWindow'] is Map
        ? Map<String, dynamic>.from(company['callingWindow'] as Map)
        : null;
    final canCallNow = callingWindow?['allowed'] == true;
    final localTimeLabel = '${callingWindow?['localTimeLabel'] ?? ''}'.trim();

    return Material(
      color: flagged
          ? const Color(0xFFFEF2F2)
          : (viewingEnabled ? Colors.white : const Color(0xFFF8FAFC)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: flagged
                  ? PipeBuyerColors.danger
                  : (published
                      ? PipeBuyerColors.success.withValues(alpha: 0.45)
                      : PipeBuyerColors.line),
              width: flagged ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${company['companyName'] ?? 'Unnamed Company'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: PipeBuyerColors.ink,
                          ),
                        ),
                        if (flagged)
                          const _PillBadge(
                            label: 'FLAGGED / PROHIBITED',
                            color: PipeBuyerColors.danger,
                          ),
                        _PillBadge(
                          label: published
                              ? 'LIVE ON WEBSITE'
                              : (viewingEnabled
                                  ? 'VIEWING ALLOWED (DRAFT)'
                                  : 'VIEWING OFF / HIDDEN'),
                          color: published
                              ? PipeBuyerColors.success
                              : (viewingEnabled
                                  ? PipeBuyerColors.slate
                                  : PipeBuyerColors.danger),
                        ),
                        if (isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(999),
                              border:
                                  Border.all(color: const Color(0xFF4ADE80)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 13,
                                  color: Color(0xFF16A34A),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'VERIFIED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const _PillBadge(
                            label: 'UNVERIFIED',
                            color: PipeBuyerColors.slate,
                          ),
                        _PillBadge(
                          label: switch (tier) {
                            'featured_platinum' => 'Tier 1: Featured Partner',
                            'paid_verified' => 'Tier 2: Verified Pro (Paid)',
                            'free_verified' => 'Tier 3: Basic (Verified)',
                            _ => 'Tier 3: Basic (Unverified)',
                          },
                          color: tier == 'featured_platinum'
                              ? PipeBuyerColors.orange
                              : (tier == 'paid_verified'
                                  ? PipeBuyerColors.industrialBlue
                                  : PipeBuyerColors.slate),
                        ),
                        _PillBadge(
                          label: 'Audit: $opStatus',
                          color: opStatus.startsWith('active')
                              ? PipeBuyerColors.success
                              : PipeBuyerColors.warning,
                        ),
                        if (localTimeLabel.isNotEmpty)
                          _PillBadge(
                            label: canCallNow
                                ? 'B2B Call Open ($localTimeLabel)'
                                : 'After Hours ($localTimeLabel)',
                            color: canCallNow
                                ? PipeBuyerColors.success
                                : PipeBuyerColors.muted,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PipeBuyerCountryFlagIcon(
                              countryCode: '${company['countryCode'] ?? 'CA'}',
                              width: 16,
                              height: 11,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Location: ${company['city'] ?? '—'}, ${company['regionCode'] ?? '—'} (${company['countryCode'] ?? 'CA'})',
                                style: const TextStyle(
                                  color: PipeBuyerColors.slate,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Current Phone: ${mainPhone.isEmpty ? 'None' : mainPhone}'
                          '${tollFree.isNotEmpty ? ' • Toll-Free: $tollFree' : ''}',
                          style: const TextStyle(
                            color: PipeBuyerColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (legacyPhones.isNotEmpty)
                          Text(
                            'Old 2015/2016 Phone: ${legacyPhones.join(', ')}',
                            style: const TextStyle(
                              color: PipeBuyerColors.orangePressed,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    if (flagged &&
                        '${company['flagReason'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Flag Reason: ${company['flagReason']}',
                        style: const TextStyle(
                          color: PipeBuyerColors.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          viewingEnabled ? 'Viewing ON' : 'Viewing OFF',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: viewingEnabled
                                ? PipeBuyerColors.success
                                : PipeBuyerColors.danger,
                          ),
                        ),
                        Switch(
                          value: viewingEnabled,
                          activeThumbColor: PipeBuyerColors.success,
                          onChanged: onToggleViewing,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit Phone History / Regions / Services',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: flagged
                              ? 'Clear Flagged / Prohibited Status'
                              : 'Flag & Prohibit Company',
                          onPressed: onToggleFlag,
                          icon: Icon(
                            flagged ? Icons.gpp_maybe : Icons.flag_outlined,
                            size: 20,
                            color: PipeBuyerColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _CompanyControlSheet extends StatefulWidget {
  const _CompanyControlSheet({
    required this.client,
    required this.access,
    required this.initialCompany,
  });

  final PipeBuyerYellowPagesClient client;
  final PipeBuyerYellowPagesAccess access;
  final Map<String, dynamic> initialCompany;

  @override
  State<_CompanyControlSheet> createState() => _CompanyControlSheetState();
}

class _CompanyControlSheetState extends State<_CompanyControlSheet> {
  late Map<String, dynamic> _company = widget.initialCompany;
  bool _loading = true;
  bool _mutating = false;
  bool _changed = false;

  final _callNoteCtrl = TextEditingController();
  String _disposition = 'verified_details';

  @override
  void initState() {
    super.initState();
    _loadFull();
  }

  @override
  void dispose() {
    _callNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFull() async {
    final id = '${_company['id'] ?? ''}';
    if (id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final full = await widget.client.getCompany(id);
      if (!mounted) return;
      setState(() {
        _company = full;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _runAction(Future<void> Function() fn) async {
    setState(() => _mutating = true);
    try {
      await fn();
      _changed = true;
      await _loadFull();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst(RegExp(r'^Bad state:\s*'), ''),
          ),
          backgroundColor: PipeBuyerColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = '${_company['id'] ?? ''}';
    final isAdmin = widget.access.isAdministrator;
    final isManager = widget.access.isManager;
    final flagged = _company['isFlaggedProhibited'] == true;
    final viewingEnabled = _company['adminViewingEnabled'] != false && !flagged;
    final events = (_company['contactEvents'] is List)
        ? (_company['contactEvents'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_company['companyName'] ?? 'Company Record'}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_changed),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_loading || _mutating) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _PillBadge(
                        label: 'Phone: ${_company['mainPhone'] ?? '—'}',
                        color: PipeBuyerColors.ink,
                      ),
                      if ('${_company['website'] ?? ''}'.isNotEmpty)
                        _PillBadge(
                          label: 'Web: ${_company['website']}',
                          color: PipeBuyerColors.industrialBlue,
                        ),
                      _PillBadge(
                        label:
                            'Verification: ${_company['verificationStatus'] ?? 'unverified'}',
                        color: _company['verificationStatus'] == 'verified'
                            ? PipeBuyerColors.success
                            : PipeBuyerColors.slate,
                      ),
                      _PillBadge(
                        label:
                            'Billing: ${_company['billingStatus'] ?? 'unpaid'} (${_company['listingTier'] ?? 'free_basic'})',
                        color: PipeBuyerColors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (isAdmin) ...[
                    const Text(
                      'Admin Website Visibility & Tier Controls',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: viewingEnabled
                                ? PipeBuyerColors.slate
                                : PipeBuyerColors.success,
                          ),
                          onPressed: _mutating
                              ? null
                              : () => _runAction(
                                    () => widget.client.setCompanyVisibility(
                                      id,
                                      visible: !viewingEnabled,
                                      publishImmediately: !viewingEnabled,
                                      reason: !viewingEnabled
                                          ? 'Admin enabled website viewing'
                                          : 'Admin disabled website viewing',
                                    ),
                                  ),
                          icon: Icon(viewingEnabled
                              ? Icons.visibility_off
                              : Icons.visibility),
                          label: Text(viewingEnabled
                              ? 'Turn Public Viewing OFF'
                              : 'Turn Viewing ON & Publish'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _mutating
                              ? null
                              : () => _runAction(
                                    () => widget.client.setBillingStatus(
                                      id,
                                      status: 'paid',
                                      listingTier: 'featured_platinum',
                                      paidThrough: DateTime.now()
                                          .add(const Duration(days: 365)),
                                    ),
                                  ),
                          icon: const Icon(Icons.workspace_premium_outlined),
                          label:
                              const Text('Set Tier 1: Featured Partner (1 Yr)'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _mutating
                              ? null
                              : () => _runAction(
                                    () => widget.client.setBillingStatus(
                                      id,
                                      status: 'paid',
                                      listingTier: 'paid_verified',
                                      paidThrough: DateTime.now()
                                          .add(const Duration(days: 365)),
                                    ),
                                  ),
                          icon: const Icon(Icons.verified_outlined),
                          label: const Text('Set Tier 2: Verified Pro (1 Yr)'),
                        ),
                        OutlinedButton(
                          onPressed: _mutating
                              ? null
                              : () => _runAction(
                                    () => widget.client.setBillingStatus(
                                      id,
                                      status: 'unpaid',
                                      listingTier:
                                          _company['verificationStatus'] ==
                                                  'verified'
                                              ? 'free_verified'
                                              : 'free_basic',
                                    ),
                                  ),
                          child: const Text('Set Tier 3: Unpaid Basic'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (isManager) ...[
                    const Text(
                      'Operational Audit Verification',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _mutating
                              ? null
                              : () => _runAction(
                                    () => widget.client.reviewVerification(
                                      id,
                                      status: 'verified',
                                      operationalStatus: 'active_in_operation',
                                      reviewNote:
                                          'Confirmed active in operation',
                                    ),
                                  ),
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                          ),
                          label: const Text('Mark Verified (Green Checkmark)'),
                        ),
                        if (_company['verificationStatus'] == 'verified')
                          OutlinedButton.icon(
                            onPressed: _mutating
                                ? null
                                : () => _runAction(
                                      () => widget.client.reviewVerification(
                                        id,
                                        status: 'unverified',
                                        operationalStatus:
                                            'active_in_operation',
                                        reviewNote: 'Reset to unverified',
                                      ),
                                    ),
                            icon: const Icon(Icons.remove_moderator_outlined),
                            label: const Text('Reset to Unverified'),
                          ),
                        OutlinedButton.icon(
                          onPressed: _mutating
                              ? null
                              : () => _runAction(
                                    () => widget.client.reviewVerification(
                                      id,
                                      status: 'inactive',
                                      operationalStatus: 'closed_inactive',
                                      reviewNote:
                                          'Business closed or disconnected',
                                    ),
                                  ),
                          icon: const Icon(Icons.domain_disabled_outlined),
                          label: const Text('Mark Closed / Out of Business'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  const Text(
                    'Log Outbound Contact / Verification Call',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _disposition,
                    decoration: const InputDecoration(labelText: 'Disposition'),
                    items: const [
                      DropdownMenuItem(
                        value: 'verified_details',
                        child: Text('Verified Active Business & Phone Details'),
                      ),
                      DropdownMenuItem(
                        value: 'interested',
                        child: Text('Interested in Paid Priority Listing'),
                      ),
                      DropdownMenuItem(
                        value: 'callback_requested',
                        child: Text('Callback Requested'),
                      ),
                      DropdownMenuItem(
                        value: 'no_answer',
                        child: Text('No Answer / Left Voicemail'),
                      ),
                      DropdownMenuItem(
                        value: 'wrong_number',
                        child: Text('Disconnected / Old Number Changed'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _disposition = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _callNoteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Call Summary / Audit Notes',
                      hintText:
                          'Spoke with dispatch, confirmed new phone number and COR certification...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _mutating
                          ? null
                          : () => _runAction(() async {
                                await widget.client.recordContactEvent(
                                  companyId: id,
                                  eventType: 'phone_call',
                                  disposition: _disposition,
                                  summary: _callNoteCtrl.text.trim(),
                                );
                                _callNoteCtrl.clear();
                              }),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save Call Log'),
                    ),
                  ),
                  if (events.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Recent Contact & Audit History',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    ...events.map(
                      (ev) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history, size: 18),
                        title: Text(
                          '${ev['disposition'] ?? ev['eventType'] ?? 'event'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('${ev['summary'] ?? ''}'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyUpsertDialog extends StatefulWidget {
  const _CompanyUpsertDialog({
    required this.client,
    this.existing,
  });

  final PipeBuyerYellowPagesClient client;
  final Map<String, dynamic>? existing;

  @override
  State<_CompanyUpsertDialog> createState() => _CompanyUpsertDialogState();
}

class _CompanyUpsertDialogState extends State<_CompanyUpsertDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mainPhoneCtrl;
  late final TextEditingController _tollFreeCtrl;
  late final TextEditingController _legacyPhonesCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _servicesCtrl;

  String _countryCode = 'CA';
  String _regionCode = 'AB';
  String _operationalStatus = 'active_in_operation';
  late final Set<String> _selectedCategories;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: '${ex?['companyName'] ?? ''}');
    _mainPhoneCtrl = TextEditingController(text: '${ex?['mainPhone'] ?? ''}');
    _tollFreeCtrl =
        TextEditingController(text: '${ex?['tollFreePhone'] ?? ''}');
    final legacy = (ex?['legacyPhones'] is List)
        ? (ex!['legacyPhones'] as List).join(', ')
        : '';
    _legacyPhonesCtrl = TextEditingController(text: legacy);
    _websiteCtrl = TextEditingController(text: '${ex?['website'] ?? ''}');
    _emailCtrl = TextEditingController(text: '${ex?['generalEmail'] ?? ''}');
    _cityCtrl = TextEditingController(text: '${ex?['city'] ?? ''}');
    final services =
        (ex?['services'] is List) ? (ex!['services'] as List).join(', ') : '';
    _servicesCtrl = TextEditingController(text: services);
    _countryCode = '${ex?['countryCode'] ?? 'CA'}'.isEmpty
        ? 'CA'
        : '${ex?['countryCode']}';
    _regionCode =
        '${ex?['regionCode'] ?? 'AB'}'.isEmpty ? 'AB' : '${ex?['regionCode']}';
    _operationalStatus = '${ex?['operationalStatus'] ?? 'active_in_operation'}';
    _selectedCategories = (ex?['categoryCodes'] is List)
        ? (ex!['categoryCodes'] as List).map((e) => '$e').toSet()
        : <String>{};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mainPhoneCtrl.dispose();
    _tollFreeCtrl.dispose();
    _legacyPhonesCtrl.dispose();
    _websiteCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _servicesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Company name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final legacyList = _legacyPhonesCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      final servicesList = _servicesCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
      final catLabels = _selectedCategories
          .map((c) => PipeBuyerYellowPagesTaxonomy.byCode(c)?.label ?? c)
          .toList(growable: false);

      await widget.client.upsertCompany(
        companyId: widget.existing?['id']?.toString(),
        company: <String, Object?>{
          'companyName': _nameCtrl.text.trim(),
          'mainPhone': _mainPhoneCtrl.text.trim(),
          'publicPhone': _mainPhoneCtrl.text.trim(),
          'tollFreePhone': _tollFreeCtrl.text.trim(),
          'legacyPhones': legacyList,
          'website': _websiteCtrl.text.trim(),
          'generalEmail': _emailCtrl.text.trim(),
          'publicEmail': _emailCtrl.text.trim(),
          'countryCode': _countryCode,
          'regionCode': _regionCode,
          'city': _cityCtrl.text.trim(),
          'operationalStatus': _operationalStatus,
          'categoryCodes': _selectedCategories.toList(growable: false),
          'categories': catLabels,
          'services': servicesList,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final regionOptions =
        PipeBuyerYellowPagesTaxonomy.regionsForCountry(_countryCode);
    if (!regionOptions.any((r) => r.regionCode == _regionCode) &&
        regionOptions.isNotEmpty) {
      _regionCode = regionOptions.first.regionCode;
    }

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Add Oil & Gas Service Company'
            : 'Edit Company & Old->New Phone Audit',
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(
                      color: PipeBuyerColors.danger,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Company Name *'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mainPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Current Verified Phone',
                        hintText: '(780) 532-0000',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _tollFreeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Toll-Free Number',
                        hintText: '(800) 555-0100',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _legacyPhonesCtrl,
                decoration: const InputDecoration(
                  labelText:
                      'Old 2015/2016 Book Phone Numbers (comma-separated)',
                  hintText:
                      'Automatically tracked when numbers change; searchable by Admin',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('crm-country-$_countryCode'),
                      initialValue: PipeBuyerYellowPagesTaxonomy.countryByCode(
                                _countryCode,
                              ) !=
                              null
                          ? _countryCode
                          : 'CA',
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Country'),
                      items: PipeBuyerYellowPagesTaxonomy.countries
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.code,
                              child: Row(
                                children: [
                                  PipeBuyerCountryFlagIcon(
                                    countryCode: c.code,
                                    width: 19,
                                    height: 13,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      '${c.name} (${c.code})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (val) {
                        if (val != null) {
                          final nextRegions =
                              PipeBuyerYellowPagesTaxonomy.regionsForCountry(
                                  val);
                          setState(() {
                            _countryCode = val;
                            _regionCode = nextRegions.isNotEmpty
                                ? nextRegions.first.regionCode
                                : '';
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: regionOptions.isNotEmpty
                        ? DropdownButtonFormField<String>(
                            key: ValueKey(
                              'crm-region-$_countryCode-$_regionCode',
                            ),
                            initialValue: regionOptions.any(
                              (r) => r.regionCode == _regionCode,
                            )
                                ? _regionCode
                                : regionOptions.first.regionCode,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Province / State / Region',
                            ),
                            items: regionOptions
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r.regionCode,
                                    child: Text(
                                      r.displayLabel,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _regionCode = val);
                              }
                            },
                          )
                        : TextFormField(
                            key: ValueKey('crm-custom-region-$_countryCode'),
                            initialValue: _regionCode,
                            decoration: const InputDecoration(
                              labelText: 'State / Region (Optional)',
                            ),
                            onChanged: (val) => _regionCode = val.trim(),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                          labelText: 'City / Operating Hub'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _operationalStatus,
                      decoration: const InputDecoration(
                          labelText: 'Operational Audit Status'),
                      items: const [
                        DropdownMenuItem(
                          value: 'active_in_operation',
                          child: Text('Active in Operation'),
                        ),
                        DropdownMenuItem(
                          value: 'active_number_updated',
                          child: Text('Active (Phone Updated)'),
                        ),
                        DropdownMenuItem(
                          value: 'unverified',
                          child: Text('Unverified'),
                        ),
                        DropdownMenuItem(
                          value: 'closed_inactive',
                          child: Text('Closed / Out of Operation'),
                        ),
                        DropdownMenuItem(
                          value: 'acquired_merged',
                          child: Text('Acquired / Merged'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _operationalStatus = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _websiteCtrl,
                      decoration: const InputDecoration(labelText: 'Website'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _emailCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Dispatch / Email'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _servicesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Services Provided (comma-separated)',
                  hintText:
                      'Hydrovac, Winch Trucks, Rig Moving, OCTG Inspection',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Service Categories',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: PipeBuyerYellowPagesTaxonomy.categories.map((cat) {
                  final selected = _selectedCategories.contains(cat.code);
                  return FilterChip(
                    label: Text(cat.shortLabel),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedCategories.add(cat.code);
                        } else {
                          _selectedCategories.remove(cat.code);
                        }
                      });
                    },
                  );
                }).toList(growable: false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save Company Record'),
        ),
      ],
    );
  }
}

class _BlockedNumbersDialog extends StatefulWidget {
  const _BlockedNumbersDialog({
    required this.client,
    required this.isAdmin,
  });

  final PipeBuyerYellowPagesClient client;
  final bool isAdmin;

  @override
  State<_BlockedNumbersDialog> createState() => _BlockedNumbersDialogState();
}

class _BlockedNumbersDialogState extends State<_BlockedNumbersDialog> {
  final _phoneCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _items = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.client.listBlockedNumbers();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addBlock() async {
    if (_phoneCtrl.text.trim().isEmpty) return;
    await widget.client.manageBlockedNumber(
      phone: _phoneCtrl.text.trim(),
      active: true,
      companyName: _companyCtrl.text.trim(),
      reason: _reasonCtrl.text.trim().isEmpty
          ? 'Blocked by Admin'
          : _reasonCtrl.text.trim(),
    );
    _phoneCtrl.clear();
    _companyCtrl.clear();
    _reasonCtrl.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Prohibited & Blocked Phone Numbers'),
      content: SizedBox(
        width: 540,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Blocked numbers cannot appear in public Oilfield Directory search and are automatically rejected in List Services.',
              style: TextStyle(fontSize: 13, color: PipeBuyerColors.slate),
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '(780) 555-0199',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Do not permit on website',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: PipeBuyerColors.danger,
                    ),
                    onPressed: _addBlock,
                    child: const Text('Block'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(
                          child: Text('No phone numbers currently blocked.'),
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.phone_locked,
                                  color: PipeBuyerColors.danger),
                              title: Text(
                                '${item['display'] ?? item['id']} '
                                '${'${item['companyName'] ?? ''}'.isNotEmpty ? '(${item['companyName']})' : ''}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text('${item['reason'] ?? ''}'),
                              trailing: widget.isAdmin
                                  ? TextButton(
                                      onPressed: () async {
                                        await widget.client.manageBlockedNumber(
                                          phone:
                                              '${item['digits10'] ?? item['id']}',
                                          active: false,
                                        );
                                        await _load();
                                      },
                                      child: const Text('Unblock'),
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

class _StaffManagerDialog extends StatefulWidget {
  const _StaffManagerDialog({required this.client});

  final PipeBuyerYellowPagesClient client;

  @override
  State<_StaffManagerDialog> createState() => _StaffManagerDialogState();
}

class _StaffManagerDialogState extends State<_StaffManagerDialog> {
  final _emailCtrl = TextEditingController();
  String _role = 'agent';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _staff = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.client.listStaff();
      if (!mounted) return;
      setState(() {
        _staff = list;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = err.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
      });
    }
  }

  Future<void> _grant() async {
    if (_emailCtrl.text.trim().isEmpty) return;
    setState(() => _error = null);
    try {
      await widget.client.manageStaff(
        email: _emailCtrl.text.trim(),
        active: true,
        role: _role,
      );
      _emailCtrl.clear();
      await _load();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contact Center Staff Roster (MFA Required)'),
      content: SizedBox(
        width: 520,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(
                    color: PipeBuyerColors.danger, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Employee Email',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'agent', child: Text('Agent')),
                      DropdownMenuItem(
                          value: 'manager', child: Text('Manager')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _role = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _grant, child: const Text('Grant')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _staff.length,
                      itemBuilder: (context, index) {
                        final s = _staff[index];
                        final active = s['active'] == true;
                        return ListTile(
                          dense: true,
                          title: Text('${s['email'] ?? s['uid']}'),
                          subtitle: Text(
                            active
                                ? 'Active • Role: ${s['role']}'
                                : 'Access Revoked',
                          ),
                          trailing: active
                              ? TextButton(
                                  onPressed: () async {
                                    await widget.client.manageStaff(
                                      email: '${s['email']}',
                                      active: false,
                                    );
                                    await _load();
                                  },
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

class _BookPageAuditDialog extends StatefulWidget {
  const _BookPageAuditDialog({required this.client});

  final PipeBuyerYellowPagesClient client;

  @override
  State<_BookPageAuditDialog> createState() => _BookPageAuditDialogState();
}

class _BookPageAuditDialogState extends State<_BookPageAuditDialog> {
  final _pageCtrl = TextEditingController();
  final _headerCtrl = TextEditingController();
  final _driveUrlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _headerCtrl.dispose();
    _driveUrlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pageNum = int.tryParse(_pageCtrl.text.trim()) ?? 0;
    if (pageNum <= 0) return;
    setState(() => _saving = true);
    try {
      await widget.client.upsertBookPageAudit(
        pageNumber: pageNum,
        categoryHeader: _headerCtrl.text.trim(),
        driveFileUrl: _driveUrlCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        auditStatus: 'uploaded_pending_ocr',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log 2015/2016 Book Page Photo (Google Drive)'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Printed Page Number *',
                hintText: 'e.g. 142',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _headerCtrl,
              decoration: const InputDecoration(
                labelText: 'Category Heading on Page',
                hintText: 'e.g. Trucking - Oilfield / Vacuum Trucks',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _driveUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Google Drive Photo Link',
                hintText: 'https://drive.google.com/file/d/...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Audit Notes',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save Page Record'),
        ),
      ],
    );
  }
}
