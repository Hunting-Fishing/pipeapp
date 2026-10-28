import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_admin_access.dart';
import 'pipebuyer_business_logo_widgets.dart';
import 'pipebuyer_partner_client.dart';
import 'pipebuyer_partner_taxonomy.dart';

class PipeBuyerPartnerAdminPage extends StatefulWidget {
  const PipeBuyerPartnerAdminPage({
    super.key,
    this.client,
    this.adminAccessOverride,
  });

  final PipeBuyerPartnerClient? client;
  final Future<bool> Function()? adminAccessOverride;

  @override
  State<PipeBuyerPartnerAdminPage> createState() =>
      _PipeBuyerPartnerAdminPageState();
}

class _PipeBuyerPartnerAdminPageState extends State<PipeBuyerPartnerAdminPage>
    with SingleTickerProviderStateMixin {
  late final PipeBuyerPartnerClient _client;
  late final TabController _tabController;

  bool _checkingAuth = true;
  bool _authorized = false;
  bool _loading = false;
  String _statusFilter = 'all';

  List<Map<String, dynamic>> _inquiries = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _showcases = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _dealLeads = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerPartnerClient();
    _tabController = TabController(length: 3, vsync: this);
    _initialize();
  }

  @override
  void didUpdateWidget(covariant PipeBuyerPartnerAdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adminAccessOverride != widget.adminAccessOverride ||
        oldWidget.client != widget.client) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    try {
      final check =
          widget.adminAccessOverride ?? marketplaceAdministratorAccess;
      final allowed = await check();
      if (!mounted) return;
      setState(() {
        _authorized = allowed;
        _checkingAuth = false;
      });
      if (allowed) {
        await _refresh();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authorized = false;
        _checkingAuth = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final data = await _client.listAdminDashboard();
      if (!mounted) return;
      List<Map<String, dynamic>> readList(Object? raw) {
        if (raw is! List) return const <Map<String, dynamic>>[];
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }

      setState(() {
        _inquiries = readList(data['inquiries']);
        _showcases = readList(data['showcases']);
        _dealLeads = readList(data['dealLeads']);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reviewInquiry(
    Map<String, dynamic> inquiry, {
    required String status,
    bool publishShowcase = false,
    bool featured = false,
  }) async {
    final id = '${inquiry['inquiryId'] ?? ''}'.trim();
    if (id.isEmpty) return;
    try {
      await _client.reviewPartnerInquiry(
        inquiryId: id,
        status: status,
        publishShowcase: publishShowcase,
        featured: featured,
      );
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: publishShowcase
            ? 'Inquiry approved and published to Partner Showcase.'
            : 'Inquiry updated to $status.',
        tone: PipeStatusTone.success,
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  Future<void> _openCreateOrEditShowcase(
      [Map<String, dynamic>? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UpsertShowcaseDialog(
        client: _client,
        existing: existing,
      ),
    );
    if (saved == true) {
      await _refresh();
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
        appBar: AppBar(title: const Text('Partner Program Admin')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 60, color: Colors.red),
                  SizedBox(height: 14),
                  Text(
                    'Administrator Privileges Required',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sign in with an approved administrator account and multi-factor authentication to manage corporate partnerships and showcases.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PipeBuyerColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final filteredInquiries = _statusFilter == 'all'
        ? _inquiries
        : _inquiries
            .where((item) => '${item['status'] ?? 'new'}' == _statusFilter)
            .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner With Us • Admin Queue'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _openCreateOrEditShowcase(),
              icon: const Icon(Icons.add_business_outlined, size: 18),
              label: const Text('New Showcase / Deal'),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'Partner Inquiries (${_inquiries.length})'),
            Tab(text: 'Live Showcases & Deals (${_showcases.length})'),
            Tab(text: 'Fleet & Deal Leads (${_dealLeads.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInquiriesTab(filteredInquiries),
          _buildShowcasesTab(),
          _buildLeadsTab(),
        ],
      ),
    );
  }

  Widget _buildInquiriesTab(List<Map<String, dynamic>> items) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in const [
              'all',
              'new',
              'in_review',
              'approved',
              'declined',
            ])
              ChoiceChip(
                label: Text(status.toUpperCase()),
                selected: _statusFilter == status,
                onSelected: (_) => setState(() => _statusFilter = status),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No corporate partner inquiries in this view.'),
            ),
          )
        else
          for (final item in items)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PipeBuyerCompanyLogoBadge(
                              logoUrl: '${item['logoUrl'] ?? ''}'.trim(),
                              companyName: '${item['companyName'] ?? 'Brand'}',
                              width: 48,
                              height: 38,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                '${item['companyName'] ?? 'Brand'} — ${item['headline'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${item['status'] ?? 'new'}'.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Category: ${item['brandCategory'] ?? ''} • Model: ${item['commercialModel'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: PipeBuyerColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ('${item['dealOrDiscountOffer'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Proposed Oilfield Offer: ${item['dealOrDiscountOffer']}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: PipeBuyerColors.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text('${item['productSummary'] ?? ''}'),
                    const SizedBox(height: 8),
                    Text(
                      'Contact: ${item['contactName'] ?? ''} (${item['contactTitle'] ?? 'Representative'}) • ${item['email'] ?? ''} • ${item['phone'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: PipeBuyerColors.slate,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              _reviewInquiry(item, status: 'in_review'),
                          child: const Text('Mark In Review'),
                        ),
                        FilledButton.tonal(
                          onPressed: () =>
                              _reviewInquiry(item, status: 'approved'),
                          child: const Text('Approve Only'),
                        ),
                        FilledButton.icon(
                          onPressed: () => _reviewInquiry(
                            item,
                            status: 'approved',
                            publishShowcase: true,
                            featured: true,
                          ),
                          icon: const Icon(Icons.publish_rounded, size: 17),
                          label: const Text('Approve & Publish Showcase'),
                        ),
                        TextButton(
                          onPressed: () =>
                              _reviewInquiry(item, status: 'declined'),
                          child: const Text('Decline'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildShowcasesTab() {
    if (_showcases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No custom database showcases published yet. Default curated showcases remain visible until you add or approve custom partner deals.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _openCreateOrEditShowcase(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Publish Partner Showcase'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _showcases.length,
      itemBuilder: (context, index) {
        final item = _showcases[index];
        final active = item['active'] != false;
        final featured = item['featured'] == true;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: PipeBuyerCompanyLogoBadge(
              logoUrl: '${item['logoUrl'] ?? ''}'.trim(),
              companyName: '${item['partnerName'] ?? 'Partner'}',
              width: 48,
              height: 38,
              featured: featured,
            ),
            title: Text(
              '${item['partnerName'] ?? ''} • ${item['headline'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${active ? 'ACTIVE' : 'PAUSED'}${featured ? ' • FEATURED' : ''} • ${item['discountDetails'] ?? item['offerBadge'] ?? ''}',
            ),
            trailing: IconButton(
              tooltip: 'Edit Showcase',
              onPressed: () => _openCreateOrEditShowcase(item),
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeadsTab() {
    if (_dealLeads.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No buyer fleet or oilfield deal leads submitted yet.'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _dealLeads.length,
      itemBuilder: (context, index) {
        final lead = _dealLeads[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(
              '${lead['companyName'] ?? ''} → ${lead['partnerName'] ?? lead['showcaseId'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${lead['contactName'] ?? ''} • ${lead['email'] ?? ''} • ${lead['phone'] ?? ''}\n'
              'Need: ${lead['fleetOrQuantityNeed'] ?? 'N/A'} • Region: ${lead['region'] ?? 'N/A'}',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _UpsertShowcaseDialog extends StatefulWidget {
  const _UpsertShowcaseDialog({
    required this.client,
    this.existing,
  });

  final PipeBuyerPartnerClient client;
  final Map<String, dynamic>? existing;

  @override
  State<_UpsertShowcaseDialog> createState() => _UpsertShowcaseDialogState();
}

class _UpsertShowcaseDialogState extends State<_UpsertShowcaseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _partnerName;
  late final TextEditingController _headline;
  late final TextEditingController _summary;
  late final TextEditingController _offerBadge;
  late final TextEditingController _discountDetails;
  late final TextEditingController _highlights;
  late final TextEditingController _ctaUrl;
  late String _brandCategory;
  late String _logoUrl;
  late String _bannerUrl;
  bool _featured = true;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? const <String, dynamic>{};
    _partnerName = TextEditingController(text: '${e['partnerName'] ?? ''}');
    _headline = TextEditingController(text: '${e['headline'] ?? ''}');
    _summary = TextEditingController(text: '${e['summary'] ?? ''}');
    _offerBadge = TextEditingController(
      text: '${e['offerBadge'] ?? 'OEM Fleet & Deal'}',
    );
    _discountDetails =
        TextEditingController(text: '${e['discountDetails'] ?? ''}');
    final rawHighlights = e['productHighlights'];
    _highlights = TextEditingController(
      text: rawHighlights is List ? rawHighlights.join(', ') : '',
    );
    _ctaUrl = TextEditingController(text: '${e['ctaUrl'] ?? ''}');
    _brandCategory = '${e['brandCategory'] ?? 'oem_fleet_crew_trucks'}';
    _logoUrl = '${e['logoUrl'] ?? ''}'.trim();
    _bannerUrl = '${e['bannerUrl'] ?? ''}'.trim();
    _featured = e['featured'] == true;
    _active = e['active'] != false;
  }

  @override
  void dispose() {
    _partnerName.dispose();
    _headline.dispose();
    _summary.dispose();
    _offerBadge.dispose();
    _discountDetails.dispose();
    _highlights.dispose();
    _ctaUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final highlights = _highlights.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      await widget.client.upsertPartnerShowcaseDeal(<String, Object?>{
        if (widget.existing?['showcaseId'] != null)
          'showcaseId': widget.existing!['showcaseId'],
        'partnerName': _partnerName.text.trim(),
        'brandCategory': _brandCategory,
        'programTypes': const <String>[
          'promote_brand',
          'showcase_sell_products',
          'oilfield_deals_discounts',
        ],
        'headline': _headline.text.trim(),
        'summary': _summary.text.trim(),
        'offerBadge': _offerBadge.text.trim(),
        'discountDetails': _discountDetails.text.trim(),
        'productHighlights': highlights,
        'ctaUrl': _ctaUrl.text.trim(),
        'logoUrl': _logoUrl.trim(),
        'bannerUrl': _bannerUrl.trim(),
        'featured': _featured,
        'active': _active,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Publish Partner Showcase'
            : 'Edit Partner Showcase',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _partnerName,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Partner / Brand Name *'),
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                PipeBuyerBusinessLogoField(
                  fieldKeyPrefix: 'admin_partner_logo',
                  logoUrl: _logoUrl,
                  companyName: _partnerName.text,
                  purpose: 'partner_brand',
                  title: 'Partner Brand Logo',
                  onChanged: (url) => setState(() => _logoUrl = url),
                ),
                const SizedBox(height: 10),
                PipeBuyerPromoBannerField(
                  fieldKeyPrefix: 'admin_partner_banner',
                  bannerUrl: _bannerUrl,
                  companyName: _partnerName.text,
                  purpose: 'partner_banner',
                  title: 'Featured Promo Banner Image (16:9)',
                  onChanged: (url) => setState(() => _bannerUrl = url),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _brandCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category *'),
                  items: PipeBuyerPartnerTaxonomy.brandCategories
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c.code,
                          child: Text(c.label, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) {
                    if (v != null) setState(() => _brandCategory = v);
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _headline,
                  decoration:
                      const InputDecoration(labelText: 'Showcase Headline *'),
                  validator: (v) =>
                      (v == null || v.trim().length < 4) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _offerBadge,
                  decoration: const InputDecoration(labelText: 'Badge Label'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _discountDetails,
                  decoration: const InputDecoration(
                    labelText: 'Oilfield Deal / Fleet Rebate Callout',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _summary,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Summary *'),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Min 10 chars'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _highlights,
                  decoration: const InputDecoration(
                    labelText: 'Highlights (comma-separated)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ctaUrl,
                  decoration:
                      const InputDecoration(labelText: 'Landing Page URL'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _featured,
                  title: const Text('Featured Spotlight'),
                  onChanged: (v) => setState(() => _featured = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  title: const Text('Active / Visible on Site'),
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
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
          child: Text(_saving ? 'Saving...' : 'Save Showcase'),
        ),
      ],
    );
  }
}
