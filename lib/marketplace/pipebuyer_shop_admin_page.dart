import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_account_security_page.dart';
import 'marketplace_admin_role_manager.dart';
import 'marketplace_admin_user_permissions_panel.dart';
import 'marketplace_auth_page.dart';
import 'pipebuyer_shop_client.dart';
import 'pipebuyer_shop_csv_helper.dart';
import 'pipebuyer_shop_file_transfer.dart';
import 'pipebuyer_shop_taxonomy.dart';

class PipeBuyerShopAdminPage extends StatefulWidget {
  const PipeBuyerShopAdminPage({
    super.key,
    this.client,
    this.adminAccessOverride,
    this.sessionOverride,
  });

  final PipeBuyerShopClient? client;
  final Future<bool> Function()? adminAccessOverride;
  final Future<PipeBuyerShopRoleSession> Function()? sessionOverride;

  @override
  State<PipeBuyerShopAdminPage> createState() => _PipeBuyerShopAdminPageState();
}

class _PipeBuyerShopAdminPageState extends State<PipeBuyerShopAdminPage>
    with TickerProviderStateMixin {
  late PipeBuyerShopClient _client;
  late TabController _tabController;

  bool _checkingAccess = true;
  PipeBuyerShopRoleSession _session = const PipeBuyerShopRoleSession.signedOut();
  bool _loading = true;
  String? _loadError;

  PipeBuyerShopSettings _settings = const PipeBuyerShopSettings();
  List<PipeBuyerShopProduct> _firestoreProducts = const <PipeBuyerShopProduct>[];
  List<Map<String, dynamic>> _applications = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _vendors = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _staff = const <Map<String, dynamic>>[];
  Map<String, dynamic> _analytics = const <String, dynamic>{};

  String _catalogQuery = '';
  String _catalogCategory = '';
  String _catalogSubcategory = '';

  // Settings form controllers
  final _usTagController = TextEditingController();
  final _caTagController = TextEditingController();
  final _ukTagController = TextEditingController();
  final _auTagController = TextEditingController();
  final _sgTagController = TextEditingController();
  final _aliKeyController = TextEditingController();
  final _shopeeSubController = TextEditingController();
  final _lazadaSubController = TextEditingController();
  final _involveSubController = TextEditingController();
  final _ebayCampController = TextEditingController();
  final _skimlinksController = TextEditingController();
  final _utmSourceController = TextEditingController();
  final _utmMediumController = TextEditingController();
  final _disclosureController = TextEditingController();
  final _linkTesterController = TextEditingController(
    text: 'https://www.amazon.com/dp/B077H7JP1D',
  );
  bool _storeEnabled = true;
  bool _vendorAppsOpen = true;
  bool _forceOverrideTag = false;
  bool _savingSettings = false;
  bool _seedingStarter = false;

  // Staff role form
  final _staffEmailController = TextEditingController();
  String _selectedStaffRole = 'catalog_editor';
  bool _savingStaff = false;

  int get _expectedTabCount {
    if (_session.canManageSettingsAndRoles) return 6;
    if (_session.canReviewVendors) return 5;
    return 3;
  }

  void _syncTabController() {
    final targetLength = _expectedTabCount;
    if (_tabController.length == targetLength) return;
    final old = _tabController;
    _tabController = TabController(
      length: targetLength,
      initialIndex: old.index.clamp(0, targetLength - 1),
      vsync: this,
    );
    old.dispose();
  }

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerShopClient();
    _tabController = TabController(length: 6, vsync: this);
    _checkAdminAndLoad();
  }

  @override
  void didUpdateWidget(covariant PipeBuyerShopAdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adminAccessOverride != widget.adminAccessOverride ||
        oldWidget.sessionOverride != widget.sessionOverride ||
        oldWidget.client != widget.client) {
      if (widget.client != null) {
        _client = widget.client!;
      }
      _checkAdminAndLoad();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usTagController.dispose();
    _caTagController.dispose();
    _ukTagController.dispose();
    _auTagController.dispose();
    _sgTagController.dispose();
    _aliKeyController.dispose();
    _shopeeSubController.dispose();
    _lazadaSubController.dispose();
    _involveSubController.dispose();
    _ebayCampController.dispose();
    _skimlinksController.dispose();
    _utmSourceController.dispose();
    _utmMediumController.dispose();
    _disclosureController.dispose();
    _linkTesterController.dispose();
    _staffEmailController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAndLoad() async {
    setState(() {
      _checkingAccess = true;
      _loadError = null;
    });

    PipeBuyerShopRoleSession resolved = const PipeBuyerShopRoleSession.signedOut();
    try {
      if (widget.sessionOverride != null) {
        resolved = await widget.sessionOverride!();
      } else if (widget.adminAccessOverride != null) {
        final ok = await widget.adminAccessOverride!();
        resolved = ok
            ? const PipeBuyerShopRoleSession.authorizedAdmin()
            : const PipeBuyerShopRoleSession(
                authorized: false,
                reason: 'role_missing',
              );
      } else if (Firebase.apps.isNotEmpty) {
        resolved = await _client.resolveShopRoleSession(forceRefresh: true);
      }
    } catch (_) {
      resolved = const PipeBuyerShopRoleSession(
        authorized: false,
        reason: 'unavailable',
      );
    }

    if (!mounted) return;
    if (!resolved.authorized) {
      setState(() {
        _checkingAccess = false;
        _session = resolved;
      });
      return;
    }

    setState(() {
      _checkingAccess = false;
      _session = resolved;
      _syncTabController();
    });
    await _reloadDashboard();
  }

  Future<void> _reloadDashboard() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final snap = await _client.getAdminDashboard();
      if (!mounted) return;
      _applySettingsToControllers(snap.settings);
      setState(() {
        if (widget.sessionOverride == null &&
            widget.adminAccessOverride == null) {
          _session = snap.actor;
        }
        _syncTabController();
        _settings = snap.settings;
        _firestoreProducts = snap.products;
        _applications = snap.applications;
        _vendors = snap.vendors;
        _staff = snap.staff;
        _analytics = snap.analytics;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  List<PipeBuyerShopProduct> get _allManageableProducts =>
      PipeBuyerShopClient.mergeAdminCatalog(
        _firestoreProducts,
        hiddenStarterIds: _settings.hiddenStarterIds,
      );

  void _applySettingsToControllers(PipeBuyerShopSettings settings) {
    _usTagController.text = settings.amazonAssociateTagUs;
    _caTagController.text = settings.amazonAssociateTagCa;
    _ukTagController.text = settings.amazonAssociateTagUk;
    _auTagController.text = settings.amazonAssociateTagAu;
    _sgTagController.text = settings.amazonAssociateTagSg;
    _aliKeyController.text = settings.aliexpressTrackingId;
    _shopeeSubController.text = settings.shopeeAffiliateSubId;
    _lazadaSubController.text = settings.lazadaAffiliateSubId;
    _involveSubController.text = settings.involveAsiaSubId;
    _ebayCampController.text = settings.ebayCampaignId;
    _skimlinksController.text = settings.skimlinksPublisherId;
    _utmSourceController.text = settings.defaultUtmSource;
    _utmMediumController.text = settings.defaultUtmMedium;
    _disclosureController.text = settings.disclosureText;
    _storeEnabled = settings.storeEnabled;
    _vendorAppsOpen = settings.vendorApplicationsOpen;
    _forceOverrideTag = settings.forceOverrideAmazonTag;
  }

  PipeBuyerShopSettings _draftSettingsFromForm() {
    return PipeBuyerShopSettings(
      storeEnabled: _storeEnabled,
      vendorApplicationsOpen: _vendorAppsOpen,
      amazonAssociateTagUs: _usTagController.text.trim(),
      amazonAssociateTagCa: _caTagController.text.trim(),
      amazonAssociateTagUk: _ukTagController.text.trim(),
      amazonAssociateTagAu: _auTagController.text.trim(),
      amazonAssociateTagSg: _sgTagController.text.trim(),
      aliexpressTrackingId: _aliKeyController.text.trim(),
      shopeeAffiliateSubId: _shopeeSubController.text.trim(),
      lazadaAffiliateSubId: _lazadaSubController.text.trim(),
      involveAsiaSubId: _involveSubController.text.trim(),
      ebayCampaignId: _ebayCampController.text.trim(),
      skimlinksPublisherId: _skimlinksController.text.trim(),
      forceOverrideAmazonTag: _forceOverrideTag,
      defaultUtmSource: _utmSourceController.text.trim().isEmpty
          ? 'pipebuyer'
          : _utmSourceController.text.trim(),
      defaultUtmMedium: _utmMediumController.text.trim().isEmpty
          ? 'affiliate_store'
          : _utmMediumController.text.trim(),
      disclosureText: _disclosureController.text.trim().isEmpty
          ? _settings.disclosureText
          : _disclosureController.text.trim(),
      priceDisclaimerText: _settings.priceDisclaimerText,
      hiddenStarterIds: _settings.hiddenStarterIds,
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _savingSettings = true);
    try {
      final updated =
          await _client.updateStoreSettings(_draftSettingsFromForm());
      if (!mounted) return;
      setState(() {
        _settings = updated;
        _savingSettings = false;
      });
      PipeFeedback.show(
        context,
        message:
            'Amazon Associate tags and Store settings updated across all active products.',
        tone: PipeStatusTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingSettings = false);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  Future<void> _seedStarterCatalog() async {
    setState(() => _seedingStarter = true);
    try {
      final count = await _client.seedStarterCatalogToFirestore();
      if (!mounted) return;
      setState(() => _seedingStarter = false);
      PipeFeedback.show(
        context,
        message: 'Synced $count industrial starter items to Firestore.',
        tone: PipeStatusTone.success,
      );
      await _reloadDashboard();
    } catch (error) {
      if (!mounted) return;
      setState(() => _seedingStarter = false);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  Future<void> _openProductEditor({PipeBuyerShopProduct? existing}) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => PipeBuyerAffiliateLinkEditorDialog(
        client: _client,
        settings: _settings,
        existing: existing,
      ),
    );
    if (!mounted) return;
    if (result == 'saved') {
      PipeFeedback.show(
        context,
        message: existing == null
            ? 'Affiliate link published to the PipeBuyer Store.'
            : 'Affiliate link updated.',
        tone: PipeStatusTone.success,
      );
      await _reloadDashboard();
    } else if (result == 'deleted') {
      PipeFeedback.show(
        context,
        message: 'Affiliate link removed from the Store.',
        tone: PipeStatusTone.info,
      );
      await _reloadDashboard();
    }
  }

  Future<void> _confirmAndDeleteProduct(PipeBuyerShopProduct product) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Remove Affiliate Link?'),
            content: Text(
              'Remove "${product.title}" (${product.brand}) from the PipeBuyer Store and in-app affiliate cards?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: PipeBuyerColors.danger,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove Link'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      await _client.deleteProduct(
        productId: product.id,
        title: product.title,
      );
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'Removed "${product.title}" from the Store.',
        tone: PipeStatusTone.info,
      );
      await _reloadDashboard();
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  Future<void> _openBulkSpreadsheetImporter() async {
    final importedCount = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PipeBuyerBulkSpreadsheetImportDialog(
        client: _client,
        settings: _settings,
      ),
    );
    if (importedCount != null && importedCount > 0 && mounted) {
      PipeFeedback.show(
        context,
        message:
            'Published $importedCount Store item(s) from spreadsheet import.',
        tone: PipeStatusTone.success,
      );
      await _reloadDashboard();
    }
  }

  Future<void> _exportCatalogCsv() async {
    final csv = PipeBuyerShopCsvHelper.exportProductsToCsv(
      _allManageableProducts,
    );
    final downloaded = await downloadSpreadsheetCsv(
      fileName: 'pipebuyer_store_catalog_export.csv',
      csvContent: csv,
    );
    if (!downloaded) {
      await Clipboard.setData(ClipboardData(text: csv));
    }
    if (!mounted) return;
    PipeFeedback.show(
      context,
      message: downloaded
          ? 'Downloaded pipebuyer_store_catalog_export.csv.'
          : 'Copied Store catalog CSV (${_allManageableProducts.length} items) to clipboard.',
      tone: PipeStatusTone.success,
    );
  }

  Future<void> _restoreHiddenStarterItems() async {
    try {
      await _client.restoreStarterProducts();
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'Restored removed starter affiliate items.',
        tone: PipeStatusTone.success,
      );
      await _reloadDashboard();
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  Future<void> _toggleProductStatus(
    PipeBuyerShopProduct product, {
    String? nextStatus,
    bool? nextFeatured,
  }) async {
    final existsInFirestore =
        _firestoreProducts.any((p) => p.id == product.id);
    try {
      await _client.setProductVisibility(
        productId: product.id,
        status: nextStatus,
        featured: nextFeatured,
        starterProduct: existsInFirestore ? null : product,
      );
      if (!mounted) return;
      await _reloadDashboard();
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  Future<void> _reviewApplication(
    String applicationId,
    String decision,
  ) async {
    try {
      await _client.reviewVendorApplication(
        applicationId: applicationId,
        status: decision,
      );
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'Application marked as $decision.',
        tone: PipeStatusTone.success,
      );
      await _reloadDashboard();
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  Future<void> _grantStaffRole() async {
    final email = _staffEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      PipeFeedback.show(
        context,
        message: 'Enter a valid Pipe Buyer account email address.',
        tone: PipeStatusTone.error,
      );
      return;
    }
    setState(() => _savingStaff = true);
    try {
      await _client.manageShopStaff(
        email: email,
        role: _selectedStaffRole,
        active: true,
      );
      if (!mounted) return;
      _staffEmailController.clear();
      setState(() => _savingStaff = false);
        PipeFeedback.show(
        context,
        message:
            'Store role ($_selectedStaffRole) granted. Verified Google Sign-in & email accounts can add products immediately.',
        tone: PipeStatusTone.success,
      );
      await _reloadDashboard();
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingStaff = false);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  Future<void> _revokeStaffRole(String email) async {
    if (email.trim().isEmpty) return;
    setState(() => _savingStaff = true);
    try {
      await _client.manageShopStaff(
        email: email,
        role: 'catalog_editor',
        active: false,
      );
      if (!mounted) return;
      setState(() => _savingStaff = false);
      PipeFeedback.show(
        context,
        message: 'Store management role removed for $email.',
        tone: PipeStatusTone.info,
      );
      await _reloadDashboard();
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingStaff = false);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_session.authorized) {
      return _buildUnauthorizedView(context);
    }

    final catalogItems = _allManageableProducts;
    final canSettingsAndRoles = _session.canManageSettingsAndRoles;
    final canVendors = _session.canReviewVendors;

    return Scaffold(
      backgroundColor: PipeBuyerColors.canvas,
      appBar: AppBar(
        backgroundColor: PipeBuyerColors.ink,
        foregroundColor: Colors.white,
        title: const Text('Store & Affiliate Revenue Control'),
        actions: [
          IconButton(
            tooltip: 'Refresh Store Admin',
            onPressed: _loading ? null : _reloadDashboard,
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _openProductEditor(),
              icon: const Icon(Icons.add_link_rounded, size: 18),
              label: const Text('Add Affiliate Link'),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: PipeBuyerColors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(
              icon: Icon(Icons.insights_rounded, size: 18),
              text: 'Overview & Clicks',
            ),
            Tab(
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              text: 'Affiliate Links (${catalogItems.length})',
            ),
            const Tab(
              icon: Icon(Icons.public_rounded, size: 18),
              text: 'Passive Income Platforms (25+)',
            ),
            if (canSettingsAndRoles)
              const Tab(
                icon: Icon(Icons.link_rounded, size: 18),
                text: 'Amazon & Affiliate Tags',
              ),
            if (canVendors)
              Tab(
                icon: const Icon(Icons.handshake_outlined, size: 18),
                text: 'Vendor Applications (${_applications.length})',
              ),
            if (canVendors)
              const Tab(
                icon: Icon(Icons.verified_user_outlined, size: 18),
                text: 'Roles & Access',
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: PipeBuyerColors.danger),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _reloadDashboard,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildCatalogTab(catalogItems),
                    _buildAffiliatePlatformsDirectoryTab(),
                    if (canSettingsAndRoles) _buildSettingsTab(),
                    if (canVendors) _buildApplicationsTab(),
                    if (canVendors) _buildRolesTab(),
                  ],
                ),
    );
  }

  Widget _buildUnauthorizedView(BuildContext context) {
    final isMfaMissing = _session.reason == 'mfa_required';
    final isSignedOut = _session.reason == 'signed_out';
    final heading = isMfaMissing
        ? 'Administrator Sign-In Requires MFA'
        : isSignedOut
            ? 'Sign In Required'
            : 'Administrator Access Required';
    final description = isMfaMissing
        ? 'Your account has an approved Store/Administrator role, but this session has not completed multi-factor authentication. Complete MFA in Account Security or sign in again with MFA, then tap Refresh Access.'
        : isSignedOut
            ? 'Sign in with an approved administrator or Store manager account to add and remove affiliate links.'
            : 'Sign in with an approved administrator, Store manager, or catalog editor account with multi-factor authentication enabled to manage Store affiliate links, Amazon Associate tags, and vendor applications.';

    return Scaffold(
      appBar: AppBar(title: const Text('Store & Affiliate Admin')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMfaMissing
                        ? Icons.phonelink_lock_outlined
                        : Icons.admin_panel_settings_outlined,
                    size: 46,
                    color: isMfaMissing
                        ? PipeBuyerColors.warning
                        : PipeBuyerColors.danger,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    heading,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: PipeBuyerColors.muted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (isSignedOut)
                        FilledButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => const MarketplaceAuthPage(),
                              ),
                            );
                            if (mounted) _checkAdminAndLoad();
                          },
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Sign In'),
                        ),
                      if (isMfaMissing)
                        FilledButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const MarketplaceAccountSecurityPage(),
                              ),
                            );
                            if (mounted) _checkAdminAndLoad();
                          },
                          icon: const Icon(Icons.security_outlined),
                          label: const Text('Open Account Security (MFA)'),
                        ),
                      OutlinedButton.icon(
                        onPressed: _checkAdminAndLoad,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh Access'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final totalClicks =
        (_analytics['totalRecordedClicks'] as num?)?.toInt() ?? 0;
    final activeProducts =
        _allManageableProducts.where((p) => p.status == 'active').length;
    final pendingApps =
        (_analytics['pendingApplicationCount'] as num?)?.toInt() ?? 0;
    final approvedVendors =
        (_analytics['approvedVendorCount'] as num?)?.toInt() ?? _vendors.length;

    final bySource = _analytics['clicksBySource'] is Map
        ? Map<String, dynamic>.from(_analytics['clicksBySource'] as Map)
        : const <String, dynamic>{};
    final byPlacement = _analytics['clicksByPlacement'] is Map
        ? Map<String, dynamic>.from(_analytics['clicksByPlacement'] as Map)
        : const <String, dynamic>{};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PipeBuyerColors.line),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: PipeBuyerColors.success,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Active Role: ${_session.roleDisplayLabel} • Full Add & Remove Affiliate Link Access',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _openProductEditor(),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_link_rounded, size: 17),
                label: const Text('Quick-Add Amazon / Partner Link'),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              label: 'Outbound Affiliate Clicks',
              value: '$totalClicks',
              icon: Icons.ads_click_rounded,
              color: PipeBuyerColors.orange,
            ),
            _MetricCard(
              label: 'Active Store Links',
              value: '$activeProducts',
              icon: Icons.shopping_bag_outlined,
              color: PipeBuyerColors.industrialBlue,
            ),
            _MetricCard(
              label: 'Pending Partner Apps',
              value: '$pendingApps',
              icon: Icons.pending_actions_rounded,
              color: PipeBuyerColors.warning,
            ),
            _MetricCard(
              label: 'Approved Store Vendors',
              value: '$approvedVendors',
              icon: Icons.verified_outlined,
              color: PipeBuyerColors.success,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFFFF7ED),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amazon SiteStripe, 1,000-Item Spreadsheet & Starter Controls',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add links one-by-one from Amazon SiteStripe, or bulk-import up to 1,000 categorized items from Excel / Google Sheets (.CSV). Blank link rows are skipped automatically so you can upload incrementally anytime. Includes ${PipeBuyerShopTaxonomy.starterCatalog.length} built-in starter items.',
                        style: const TextStyle(fontSize: 12.5, height: 1.35),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _openBulkSpreadsheetImporter,
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('Import Spreadsheet (.CSV)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _exportCatalogCsv,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Export CSV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _seedingStarter ? null : _seedStarterCatalog,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                        _seedingStarter
                            ? 'Syncing...'
                            : 'Sync Starter Items to Firestore',
                      ),
                    ),
                    if (_settings.hiddenStarterIds.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _restoreHiddenStarterItems,
                        icon: const Icon(Icons.restore_rounded),
                        label: Text(
                          'Restore ${_settings.hiddenStarterIds.length} Removed Starter Item(s)',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clicks by Monetization Channel & Placement',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const SizedBox(height: 10),
                if (bySource.isEmpty && byPlacement.isEmpty)
                  const Text(
                    'Click telemetry will populate automatically as users click Amazon Affiliate, Brand Partner, and Distributor links across the Store, Home Showcase, and Listing Detail cards.',
                    style: TextStyle(color: PipeBuyerColors.muted),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...bySource.entries.map(
                        (e) => Chip(
                          label: Text('${e.key}: ${e.value} clicks'),
                          backgroundColor: PipeBuyerColors.orangeSoft,
                        ),
                      ),
                      ...byPlacement.entries.map(
                        (e) => Chip(
                          label: Text('Placement ${e.key}: ${e.value}'),
                          backgroundColor: PipeBuyerColors.surfaceMuted,
                        ),
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

  Widget _buildCatalogTab(List<PipeBuyerShopProduct> allProducts) {
    final subcatOptions = _catalogCategory.isNotEmpty
        ? PipeBuyerShopTaxonomy.subcategoriesForCategory(_catalogCategory)
        : allProducts
            .map((p) => p.subcategory.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList(growable: false);
    final effectiveSubcat =
        subcatOptions.contains(_catalogSubcategory) ? _catalogSubcategory : '';

    final filtered = allProducts.where((p) {
      if (_catalogCategory.isNotEmpty && p.categoryCode != _catalogCategory) {
        return false;
      }
      if (effectiveSubcat.isNotEmpty && p.subcategory != effectiveSubcat) {
        return false;
      }
      if (_catalogQuery.trim().isNotEmpty) {
        final q = _catalogQuery.trim().toLowerCase();
        return p.title.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q) ||
            p.subcategory.toLowerCase().contains(q) ||
            p.asin.toLowerCase().contains(q) ||
            p.destinationUrl.toLowerCase().contains(q);
      }
      return true;
    }).toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 240, maxWidth: 460),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText:
                        'Search affiliate links by title, brand, subcategory, ASIN...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) => setState(() => _catalogQuery = v),
                ),
              ),
              DropdownButton<String>(
                value: _catalogCategory,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All Categories'),
                  ),
                  ...PipeBuyerShopTaxonomy.categories.map(
                    (c) => DropdownMenuItem(
                      value: c.code,
                      child: Text(c.shortLabel),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _catalogCategory = v ?? '';
                  _catalogSubcategory = '';
                }),
              ),
              if (subcatOptions.isNotEmpty)
                SizedBox(
                  width: 230,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: effectiveSubcat,
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text(
                          'All Subcategories',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...subcatOptions.map(
                        (sub) => DropdownMenuItem(
                          value: sub,
                          child: Text(
                            sub,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _catalogSubcategory = v ?? ''),
                  ),
                ),
              FilledButton.icon(
                onPressed: () => _openProductEditor(),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('Add Affiliate Link'),
              ),
              OutlinedButton.icon(
                onPressed: _openBulkSpreadsheetImporter,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Import Spreadsheet (.CSV)'),
              ),
              OutlinedButton.icon(
                onPressed: _exportCatalogCsv,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export CSV'),
              ),
              if (_settings.hiddenStarterIds.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _restoreHiddenStarterItems,
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: Text(
                    'Restore Removed (${_settings.hiddenStarterIds.length})',
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No affiliate links match this filter.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => _openProductEditor(),
                          icon: const Icon(Icons.add_link_rounded),
                          label: const Text('Add Affiliate Link'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final active = item.status == 'active';
                    final isLiveCustom =
                        _firestoreProducts.any((p) => p.id == item.id);
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isLiveCustom
                                    ? PipeBuyerColors.industrialBlue
                                        .withValues(alpha: .10)
                                    : PipeBuyerColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isLiveCustom ? 'Custom / Synced' : 'Starter',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isLiveCustom
                                      ? PipeBuyerColors.industrialBlue
                                      : PipeBuyerColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${item.brand} • ${item.sourceType.label} • ${item.category.shortLabel}${item.subcategory.isNotEmpty ? ' › ${item.subcategory}' : ''} • Clicks: ${item.clickCount}${item.asin.isNotEmpty ? ' • ASIN: ${item.asin}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              tooltip: item.featured
                                  ? 'Featured on Home & Top of Store'
                                  : 'Mark as Featured',
                              onPressed: () => _toggleProductStatus(
                                item,
                                nextFeatured: !item.featured,
                              ),
                              icon: Icon(
                                item.featured
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: item.featured
                                    ? PipeBuyerColors.orange
                                    : PipeBuyerColors.muted,
                              ),
                            ),
                            Switch(
                              value: active,
                              activeThumbColor: PipeBuyerColors.success,
                              onChanged: (val) => _toggleProductStatus(
                                item,
                                nextStatus: val ? 'active' : 'paused',
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit Affiliate Link',
                              onPressed: () =>
                                  _openProductEditor(existing: item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Remove Affiliate Link',
                              onPressed: () => _confirmAndDeleteProduct(item),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: PipeBuyerColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAffiliatePlatformsDirectoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFFFFF7ED),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Global Passive-Income Affiliate Platforms & Networks Ready in Pipe Buyer',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Every platform below is built into Pipe Buyer\'s Smart Quick-Paste parser and automatic attribution engine. Sign up for any program, paste shortlinks or product URLs into "Add Affiliate Link", and earn passive commissions on every qualifying click.',
                  style: TextStyle(fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openProductEditor(),
                      icon: const Icon(Icons.add_link_rounded, size: 18),
                      label: const Text('Add Multi-Platform Product'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openBulkSpreadsheetImporter,
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('Bulk Import CSV'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...PipeBuyerShopTaxonomy.affiliatePlatformsDirectory.map((platform) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            platform.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Regions: ${platform.regions} • Cookie: ${platform.cookieWindow}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: PipeBuyerColors.muted,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Commission: ${platform.commissionRange}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    platform.bestFor,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Link Format: ${platform.trackingHint}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: PipeBuyerColors.industrialBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          final uri = Uri.tryParse(platform.signupUrl);
                          if (uri != null) {
                            launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Join / Open Partner Portal'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _openProductEditor(),
                        icon: const Icon(Icons.add_link_rounded, size: 16),
                        label: const Text('Paste Product Link'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSettingsTab() {
    final draftSettings = _draftSettingsFromForm();
    final parsedPreview = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
      _linkTesterController.text,
      draftSettings,
    );
    final previewUs = parsedPreview?.monetizedPreviewUs ?? '';
    final previewCa = parsedPreview?.monetizedPreviewCa ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Amazon Associates Store IDs & Attribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your official Amazon Associates Tracking IDs. Every Amazon link in the Store and in-app contextual cards automatically injects the matching regional Associate tag.',
                  style:
                      TextStyle(color: PipeBuyerColors.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Store Publicly Enabled',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  value: _storeEnabled,
                  onChanged: (v) => setState(() => _storeEnabled = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Accept Distributor, Brand & Vendor Applications',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  value: _vendorAppsOpen,
                  onChanged: (v) => setState(() => _vendorAppsOpen = v),
                ),
                const Divider(height: 24),
                TextField(
                  controller: _usTagController,
                  decoration: const InputDecoration(
                    labelText: 'US Amazon Associate Tag (amazon.com)',
                    hintText: 'e.g., pipebuyer-20',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _caTagController,
                  decoration: const InputDecoration(
                    labelText: 'Canada Amazon Associate Tag (amazon.ca)',
                    hintText: 'e.g., pipebuyer0c-20',
                    prefixIcon: Icon(Icons.flag_circle_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ukTagController,
                        decoration: const InputDecoration(
                          labelText: 'UK Tag (amazon.co.uk — optional)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                      Expanded(
                      child: TextField(
                        controller: _auTagController,
                        decoration: const InputDecoration(
                          labelText: 'AU Tag (amazon.com.au — optional)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _sgTagController,
                        decoration: const InputDecoration(
                          labelText: 'SG Tag (amazon.sg — optional)',
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                const Text(
                  'Global Marketplace & Network Tracking IDs (AliExpress, Shopee, Lazada, Involve Asia, eBay)',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pre-shortened affiliate links (s.click.aliexpress.com, shope.ee, s.lazada.*, invol.co, ebay.us) already carry your affiliate ID automatically. Optional tracking IDs below auto-monetize full product URLs.',
                  style: TextStyle(color: PipeBuyerColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aliKeyController,
                        decoration: const InputDecoration(
                          labelText: 'AliExpress Portals Tracking Key (sk=)',
                          hintText: 'e.g., _dPipeAli',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _shopeeSubController,
                        decoration: const InputDecoration(
                          labelText: 'Shopee Affiliate Sub-ID (Alphanumeric)',
                          hintText: 'e.g., PipeBuyerShopee1',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lazadaSubController,
                        decoration: const InputDecoration(
                          labelText: 'Lazada LazAffiliate Sub-ID (aff_sub=)',
                          hintText: 'e.g., pipebuyer_laz',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _involveSubController,
                        decoration: const InputDecoration(
                          labelText: 'Involve Asia Sub-ID (subid=)',
                          hintText: 'e.g., pb_involve',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ebayCampController,
                        decoration: const InputDecoration(
                          labelText: 'eBay Partner Network 10-Digit Campaign ID',
                          hintText: 'e.g., 5338999999',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _skimlinksController,
                        decoration: const InputDecoration(
                          labelText: 'Skimlinks / Sovrn Publisher ID (optional)',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Force Override Existing ?tag= on Pasted Amazon Links',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  subtitle: const Text(
                    'When off, SiteStripe pre-tagged URLs keep their tag while untagged URLs receive the Store default tag.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _forceOverrideTag,
                  onChanged: (v) => setState(() => _forceOverrideTag = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _utmSourceController,
                        decoration: const InputDecoration(
                          labelText: 'Partner UTM Source',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _utmMediumController,
                        decoration: const InputDecoration(
                          labelText: 'Partner UTM Medium',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _disclosureController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'FTC & Amazon Associate Disclosure Text',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _savingSettings ? null : _saveSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _savingSettings
                        ? 'Saving Affiliate Settings...'
                        : 'Save Amazon & Affiliate Settings',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Live SiteStripe & Affiliate Link Verifier',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkTesterController,
                  decoration: const InputDecoration(
                    labelText:
                        'Paste any SiteStripe link, amzn.to short link, HTML snippet, or ASIN',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  'US Output: ${previewUs.isEmpty ? "Enter a valid Amazon link or ASIN" : previewUs}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  'CA Output: ${previewCa.isEmpty ? "Enter a valid Amazon link or ASIN" : previewCa}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PipeBuyerColors.industrialBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (previewUs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: previewUs));
                      PipeFeedback.show(
                        context,
                        message: 'Monetized link copied to clipboard.',
                        tone: PipeStatusTone.info,
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy US Monetized Link'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApplicationsTab() {
    if (_applications.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No distributor, brand, or business vendor applications submitted yet.',
            style: TextStyle(color: PipeBuyerColors.muted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _applications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final app = _applications[index];
        final id = app['id']?.toString() ?? '';
        final status = app['status']?.toString() ?? 'pending';
        final brands = (app['brandsCarried'] is Iterable)
            ? (app['brandsCarried'] as Iterable).join(', ')
            : '';
        final categories = (app['categories'] is Iterable)
            ? (app['categories'] as Iterable).join(', ')
            : '';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app['companyName']?.toString() ?? 'Applicant',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(status.toUpperCase()),
                      backgroundColor: status == 'approved'
                          ? PipeBuyerColors.success.withValues(alpha: .15)
                          : PipeBuyerColors.orangeSoft,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Track: ${app['partnershipTrack']} • Contact: ${app['contactName']} (${app['email']} • ${app['phone']})',
                  style: const TextStyle(fontSize: 12.5),
                ),
                if (brands.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Brands: $brands',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (categories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Categories: $categories • Size: ${app['estimatedSkuCount'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: PipeBuyerColors.muted,
                      ),
                    ),
                  ),
                if ((app['catalogNotes']?.toString() ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      app['catalogNotes'].toString(),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: status == 'approved'
                          ? null
                          : () => _reviewApplication(id, 'approved'),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve Partner'),
                    ),
                    OutlinedButton(
                      onPressed: () => _reviewApplication(id, 'waitlisted'),
                      child: const Text('Waitlist'),
                    ),
                    TextButton(
                      onPressed: () => _reviewApplication(id, 'declined'),
                      child: const Text('Decline'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRolesTab() {
    final activeStaff = _staff
        .where((s) => s['active'] == true)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PipeBuyer Admin & Store Role Matrix',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Every Platform Administrator (claims: admin=true, role=administrator + MFA) automatically has full authority to add/remove affiliate links, update Amazon Associate tags, approve vendors, and assign Store team roles.',
                  style: TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                const _RolePermissionSummaryRow(
                  roleTitle: 'Platform Administrator (administrator)',
                  description:
                      'Full platform & Store control: add/edit/remove affiliate links, configure US/CA Amazon Associate tags, review vendor applications, and manage staff roles.',
                ),
                const _RolePermissionSummaryRow(
                  roleTitle: 'Store Manager (store_manager)',
                  description:
                      'Add, edit, feature, pause, and remove Store affiliate links across all platforms plus review distributor/brand vendor applications.',
                ),
                const _RolePermissionSummaryRow(
                  roleTitle: 'Affiliate Catalog Editor (catalog_editor)',
                  description:
                      'Add, edit, feature, pause, remove, and bulk-import Amazon, AliExpress, Lazada, Shopee & partner affiliate links (supports Google Sign-in).',
                ),
                const _RolePermissionSummaryRow(
                  roleTitle: 'Affiliate Product Contributor (affiliate_contributor)',
                  description:
                      'Add and edit affiliate products across allowed platforms (Amazon, AliExpress, Lazada, Shopee, eBay, etc.) immediately via Google Sign-in.',
                ),
                if (_session.canManageSettingsAndRoles) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                  title: const Text(
                                    'User Permissions, Affiliate Access & Restrictions',
                                  ),
                                ),
                                body:
                                    const MarketplaceAdminUserPermissionsPanel(),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.manage_accounts_outlined),
                        label: const Text(
                          'Manage All User Permissions & Restrictions',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const MarketplaceAdminRoleManager(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Open Platform Administrator Roster'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_session.canManageSettingsAndRoles) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assign Store Manager or Affiliate Catalog Editor',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Grant delegated Store link permissions to team members who have verified their email and enrolled multi-factor authentication.',
                    style: TextStyle(
                      color: PipeBuyerColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 260,
                          maxWidth: 420,
                        ),
                        child: TextField(
                          controller: _staffEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Team Member PipeBuyer Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                      ),
                      DropdownButton<String>(
                        value: _selectedStaffRole,
                        items: const [
                          DropdownMenuItem(
                            value: 'affiliate_contributor',
                            child: Text('Affiliate Product Contributor'),
                          ),
                          DropdownMenuItem(
                            value: 'catalog_editor',
                            child: Text('Affiliate Catalog Editor'),
                          ),
                          DropdownMenuItem(
                            value: 'store_manager',
                            child: Text('Store Manager'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedStaffRole = v);
                        },
                      ),
                      FilledButton.icon(
                        onPressed: _savingStaff ? null : _grantStaffRole,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(
                          _savingStaff ? 'Saving...' : 'Grant Store Role',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delegated Store Staff (${activeStaff.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                if (activeStaff.isEmpty)
                  const Text(
                    'No separate Store-only staff assigned yet. All active Platform Administrators already have full Store access.',
                    style: TextStyle(color: PipeBuyerColors.muted),
                  )
                else
                  ...activeStaff.map((member) {
                    final email = member['email']?.toString() ?? '';
                    final role = member['role']?.toString() ?? 'catalog_editor';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.badge_outlined,
                        color: PipeBuyerColors.industrialBlue,
                      ),
                      title: Text(
                        email,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('Store Role: $role (MFA verified)'),
                      trailing: _session.canManageSettingsAndRoles
                          ? TextButton.icon(
                              onPressed: _savingStaff
                                  ? null
                                  : () => _revokeStaffRole(email),
                              icon: const Icon(
                                Icons.person_remove_outlined,
                                color: PipeBuyerColors.danger,
                              ),
                              label: const Text('Remove'),
                            )
                          : null,
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RolePermissionSummaryRow extends StatelessWidget {
  const _RolePermissionSummaryRow({
    required this.roleTitle,
    required this.description,
  });

  final String roleTitle;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 17,
            color: PipeBuyerColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style.copyWith(
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                children: [
                  TextSpan(
                    text: '$roleTitle: ',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text: description,
                    style: const TextStyle(color: PipeBuyerColors.slate),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PipeBuyerColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: PipeBuyerColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class PipeBuyerAffiliateLinkEditorDialog extends StatefulWidget {
  const PipeBuyerAffiliateLinkEditorDialog({
    super.key,
    required this.client,
    required this.settings,
    this.existing,
  });

  final PipeBuyerShopClient client;
  final PipeBuyerShopSettings settings;
  final PipeBuyerShopProduct? existing;

  @override
  State<PipeBuyerAffiliateLinkEditorDialog> createState() =>
      _PipeBuyerAffiliateLinkEditorDialogState();
}

class _PipeBuyerAffiliateLinkEditorDialogState
    extends State<PipeBuyerAffiliateLinkEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quickPasteController;
  late final TextEditingController _titleController;
  late final TextEditingController _brandController;
  late final TextEditingController _vendorController;
  late final TextEditingController _asinController;
  late final TextEditingController _urlController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _priceController;
  late final TextEditingController _badgeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _highlightsController;

  late String _categoryCode;
  late String _subcategory;
  late PipeBuyerShopSourceType _sourceType;
  late bool _featured;
  bool _saving = false;
  PipeBuyerParsedAffiliateSubmission? _parsedPreview;

  String _defaultSubcategoryFor(String categoryCode) {
    final subs = PipeBuyerShopTaxonomy.subcategoriesForCategory(categoryCode);
    return subs.isNotEmpty ? subs.first : '';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _quickPasteController = TextEditingController(
      text: e?.destinationUrl ?? '',
    );
    _titleController = TextEditingController(text: e?.title ?? '');
    _brandController = TextEditingController(text: e?.brand ?? '');
    _vendorController = TextEditingController(text: e?.vendorName ?? 'Amazon');
    _asinController = TextEditingController(text: e?.asin ?? '');
    _urlController = TextEditingController(text: e?.destinationUrl ?? '');
    _imageUrlController = TextEditingController(text: e?.imageUrl ?? '');
    _priceController = TextEditingController(text: e?.priceDisplay ?? '');
    _badgeController = TextEditingController(text: e?.badgeText ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _highlightsController =
        TextEditingController(text: e?.highlights.join('\n') ?? '');
    _categoryCode = e?.categoryCode ?? 'power_hand_tools';
    _subcategory = (e?.subcategory.trim().isNotEmpty ?? false)
        ? e!.subcategory.trim()
        : _defaultSubcategoryFor(_categoryCode);
    _sourceType = e?.sourceType ?? PipeBuyerShopSourceType.amazonAffiliate;
    _featured = e?.featured ?? false;
    if (_urlController.text.isNotEmpty) {
      _parsedPreview = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
        _urlController.text,
        widget.settings,
      );
    }
  }

  @override
  void dispose() {
    _quickPasteController.dispose();
    _titleController.dispose();
    _brandController.dispose();
    _vendorController.dispose();
    _asinController.dispose();
    _urlController.dispose();
    _imageUrlController.dispose();
    _priceController.dispose();
    _badgeController.dispose();
    _descriptionController.dispose();
    _highlightsController.dispose();
    super.dispose();
  }

  void _applySmartPaste(String raw) {
    final parsed = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
      raw,
      widget.settings,
    );
    setState(() {
      _parsedPreview = parsed;
      if (parsed == null) return;

      _urlController.text = parsed.destinationUrl;
      _sourceType = parsed.sourceType;
      _vendorController.text = parsed.suggestedVendorName.isNotEmpty
          ? parsed.suggestedVendorName
          : (parsed.isAmazonLink ? 'Amazon' : parsed.suggestedBrand);

      if (parsed.asin.isNotEmpty) {
        _asinController.text = parsed.asin;
      }
      if (parsed.suggestedTitle.isNotEmpty &&
          (_titleController.text.trim().isEmpty || widget.existing == null)) {
        _titleController.text = parsed.suggestedTitle;
      }
      if (parsed.suggestedBrand.isNotEmpty &&
          (_brandController.text.trim().isEmpty || widget.existing == null)) {
        _brandController.text = parsed.suggestedBrand;
      }
      if (parsed.imageUrl.isNotEmpty &&
          _imageUrlController.text.trim().isEmpty) {
        _imageUrlController.text = parsed.imageUrl;
      }
      if (widget.existing == null) {
        _categoryCode = parsed.suggestedCategoryCode;
        final validSubs =
            PipeBuyerShopTaxonomy.subcategoriesForCategory(_categoryCode);
        if (!validSubs.contains(_subcategory)) {
          _subcategory = _defaultSubcategoryFor(_categoryCode);
        }
      }
      if (_descriptionController.text.trim().isEmpty &&
          _titleController.text.trim().isNotEmpty) {
        final cat = PipeBuyerShopTaxonomy.categoryByCode(_categoryCode);
        _descriptionController.text =
            'Field-proven ${cat?.shortLabel.toLowerCase() ?? "industrial"} gear selected for Pipe Buyer contractors, fabricators, and field crews.';
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    _quickPasteController.text = text;
    _applySmartPaste(text);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final highlights = _highlightsController.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      final brandText = _brandController.text.trim().isEmpty
          ? 'Industrial Select'
          : _brandController.text.trim();
      await widget.client.upsertProduct(<String, Object?>{
        if (widget.existing != null) 'id': widget.existing!.id,
        'rawAffiliateInput': _quickPasteController.text.trim(),
        'title': _titleController.text.trim(),
        'brand': brandText,
        'vendorName': _vendorController.text.trim().isEmpty
            ? (_sourceType == PipeBuyerShopSourceType.amazonAffiliate
                ? 'Amazon'
                : brandText)
            : _vendorController.text.trim(),
        'sourceType': _sourceType.code,
        'status': widget.existing?.status ?? 'active',
        'categoryCode': _categoryCode,
        'subcategory': _subcategory,
        'asin': _asinController.text.trim(),
        'destinationUrl': _urlController.text.trim(),
        'imageUrl': _imageUrlController.text.trim(),
        'priceDisplay': _priceController.text.trim(),
        'badgeText': _badgeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'highlights': highlights,
        'featured': _featured,
      });
      if (!mounted) return;
      Navigator.of(context).pop('saved');
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

  Future<void> _deleteCurrent() async {
    final existing = widget.existing;
    if (existing == null) return;
    setState(() => _saving = true);
    try {
      await widget.client.deleteProduct(
        productId: existing.id,
        title: existing.title,
      );
      if (!mounted) return;
      Navigator.of(context).pop('deleted');
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
    final preview = _parsedPreview;

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Add Amazon / Partner Affiliate Link'
            : 'Edit Store Affiliate Link',
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: PipeBuyerColors.orange.withValues(alpha: .35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: PipeBuyerColors.orangePressed,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              '1-Step Amazon SiteStripe / Share Quick-Paste',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pasteFromClipboard,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.content_paste_rounded, size: 15),
                            label: const Text(
                              'Paste Clipboard',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Paste any affiliate link or share text from Amazon SiteStripe (amzn.to / full URL / ASIN), AliExpress (s.click.aliexpress.com), Shopee (shope.ee), Lazada (s.lazada.*), Involve Asia (invol.co), eBay, VEVOR, Home Depot, Temu, TikTok Shop, or Alibaba — platform & product details auto-fill below.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: PipeBuyerColors.slate,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _quickPasteController,
                        decoration: const InputDecoration(
                          labelText:
                              'Paste Amazon SiteStripe Link, amzn.to, Share Text, HTML, or ASIN',
                          hintText:
                              'https://amzn.to/... or https://www.amazon.com/.../dp/B077H7JP1D',
                          prefixIcon: Icon(Icons.add_link_rounded),
                          fillColor: Colors.white,
                        ),
                        onChanged: _applySmartPaste,
                      ),
                      if (preview != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _ComplianceBadge(
                              ok: true,
                              label: 'Platform: ${preview.platformName}',
                            ),
                            _ComplianceBadge(
                              ok: preview.effectiveAssociateTag.isNotEmpty,
                              label: preview.effectiveAssociateTag.isNotEmpty
                                  ? 'Attribution: ${preview.effectiveAssociateTag}'
                                  : 'Set Store Associate Tag in Settings',
                            ),
                            if (preview.asin.isNotEmpty)
                              _ComplianceBadge(
                                ok: true,
                                label: 'ASIN: ${preview.asin}',
                              ),
                            const _ComplianceBadge(
                              ok: true,
                              label: 'Pre-Click Disclosure & External Launch',
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PipeBuyerShopSourceType>(
                  isExpanded: true,
                  initialValue: _sourceType,
                  decoration: const InputDecoration(labelText: 'Partner Channel'),
                  items: PipeBuyerShopSourceType.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) {
                    if (v != null) setState(() => _sourceType = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _categoryCode,
                  decoration: const InputDecoration(labelText: 'Store Category'),
                  items: PipeBuyerShopTaxonomy.categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(
                            c.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _categoryCode = v;
                        final subs =
                            PipeBuyerShopTaxonomy.subcategoriesForCategory(v);
                        if (!subs.contains(_subcategory)) {
                          _subcategory = _defaultSubcategoryFor(v);
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final subs = <String>{
                      ...PipeBuyerShopTaxonomy.subcategoriesForCategory(
                        _categoryCode,
                      ),
                      if (_subcategory.trim().isNotEmpty) _subcategory.trim(),
                    }.toList(growable: false);
                    final effectiveSub = subs.contains(_subcategory)
                        ? _subcategory
                        : (subs.isNotEmpty ? subs.first : '');
                    return DropdownButtonFormField<String>(
                      key: ValueKey<String>(
                        'subcat_${_categoryCode}_$effectiveSub',
                      ),
                      isExpanded: true,
                      initialValue: effectiveSub,
                      decoration: const InputDecoration(
                        labelText: 'Subcategory',
                      ),
                      items: subs
                          .map(
                            (sub) => DropdownMenuItem(
                              value: sub,
                              child: Text(
                                sub,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) {
                        if (v != null) setState(() => _subcategory = v);
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Product Title *'),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Enter product title (at least 3 characters).'
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(
                          labelText: 'Brand (e.g., Milwaukee, RIDGID)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _vendorController,
                        decoration: const InputDecoration(
                          labelText: 'Fulfilled / Sold By',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Clean Affiliate / Partner HTTPS URL *',
                    hintText: 'https://www.amazon.com/dp/B077H7JP1D',
                  ),
                  validator: (v) {
                    final trimmed = v?.trim() ?? '';
                    if (trimmed.isEmpty &&
                        _asinController.text.trim().length == 10) {
                      return null;
                    }
                    if (!PipeBuyerShopUrlBuilder.isSafeHttpsUrl(trimmed)) {
                      return 'Enter a valid HTTPS Amazon or Partner URL.';
                    }
                    return null;
                  },
                  onChanged: (val) {
                    final parsed =
                        PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
                      val,
                      widget.settings,
                    );
                    setState(() => _parsedPreview = parsed);
                    if (parsed != null &&
                        parsed.asin.isNotEmpty &&
                        _asinController.text.isEmpty) {
                      _asinController.text = parsed.asin;
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _asinController,
                        decoration: const InputDecoration(
                          labelText: 'Amazon ASIN (auto-detected)',
                          hintText: 'B077H7JP1D',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _badgeController,
                        decoration: const InputDecoration(
                          labelText: 'Callout Badge (optional)',
                          hintText: 'Pipeline Pick',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Field Use Commentary (Amazon Original Context)',
                    helperText:
                        'Brief jobsite/trade commentary keeps Store pages compliant with Amazon content rules.',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Official Product Image HTTPS URL (optional)',
                          helperText:
                              'Uses proportional scaling or built-in trade icon.',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price Note (leave blank for live Amazon price)',
                          helperText: 'Blank = "Check live price & Prime delivery"',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _highlightsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Key Specs (optional, one per line)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Feature on Home & Top of Store'),
                  value: _featured,
                  onChanged: (v) => setState(() => _featured = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton.icon(
            onPressed: _saving ? null : _deleteCurrent,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: PipeBuyerColors.danger,
              size: 18,
            ),
            label: const Text(
              'Remove Link',
              style: TextStyle(color: PipeBuyerColors.danger),
            ),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.publish_rounded, size: 18),
          label: Text(_saving ? 'Saving...' : 'Publish Affiliate Link'),
        ),
      ],
    );
  }
}

class _ComplianceBadge extends StatelessWidget {
  const _ComplianceBadge({
    required this.ok,
    required this.label,
  });

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = ok ? PipeBuyerColors.success : PipeBuyerColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PipeBuyerBulkSpreadsheetImportDialog extends StatefulWidget {
  const PipeBuyerBulkSpreadsheetImportDialog({
    super.key,
    required this.client,
    required this.settings,
  });

  final PipeBuyerShopClient client;
  final PipeBuyerShopSettings settings;

  @override
  State<PipeBuyerBulkSpreadsheetImportDialog> createState() =>
      _PipeBuyerBulkSpreadsheetImportDialogState();
}

class _PipeBuyerBulkSpreadsheetImportDialogState
    extends State<PipeBuyerBulkSpreadsheetImportDialog> {
  final TextEditingController _textController = TextEditingController();
  String _selectedFileName = '';
  bool _importing = false;
  int _completedCount = 0;
  int _totalCount = 0;
  String? _errorText;
  PipeBuyerSpreadsheetParseResult _parsed =
      const PipeBuyerSpreadsheetParseResult(
    readyPayloads: <Map<String, Object?>>[],
    totalDataRows: 0,
    pendingBlankLinkRows: 0,
    invalidRows: <String>[],
  );

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _reparse(String value) {
    final result = PipeBuyerShopCsvHelper.parseSpreadsheetText(
      value,
      widget.settings,
    );
    setState(() {
      _parsed = result;
      _errorText = null;
    });
  }

  Future<void> _pickCsvFile() async {
    final picked = await pickSpreadsheetTextFile();
    if (picked == null || !mounted) return;
    _textController.text = picked.content;
    setState(() {
      _selectedFileName = picked.fileName;
    });
    _reparse(picked.content);
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty || !mounted) return;
    _textController.text = text;
    setState(() {
      _selectedFileName = 'Clipboard Paste';
    });
    _reparse(text);
  }

  Future<void> _runImport() async {
    final items = _parsed.readyPayloads;
    if (items.isEmpty || _importing) return;
    setState(() {
      _importing = true;
      _completedCount = 0;
      _totalCount = items.length;
      _errorText = null;
    });
    try {
      final result = await widget.client.bulkUpsertProducts(
        items,
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _completedCount = completed;
            _totalCount = total;
          });
        },
      );
      if (!mounted) return;
      final importedCount =
          (result['importedCount'] as num?)?.toInt() ?? items.length;
      Navigator.of(context).pop(importedCount);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _errorText = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final readyCount = _parsed.readyPayloads.length;
    final progress = _totalCount > 0 ? (_completedCount / _totalCount) : null;

    return AlertDialog(
      title: const Text('Import 1,000-Item Store Spreadsheet (.CSV / Excel)'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: PipeBuyerColors.orange.withValues(alpha: .35),
                  ),
                ),
                child: const Text(
                  'Open pipebuyer_store_1000_items_master.xlsx in Excel or Google Sheets -> click "amazon_search_helper_url" while logged into Amazon -> copy the SiteStripe link into "amazon_affiliate_link" -> Save as CSV (or copy rows directly) and import here. Blank link rows are safely skipped so you can upload 25, 100, or all 1,000 items anytime.',
                  style: TextStyle(
                    fontSize: 12,
                    color: PipeBuyerColors.slate,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (supportsBrowserSpreadsheetFilePicker)
                    FilledButton.tonalIcon(
                      onPressed: _importing ? null : _pickCsvFile,
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: const Text('Choose .CSV File'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _importing ? null : _pasteClipboard,
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    label: const Text('Paste from Excel / Sheets'),
                  ),
                  if (_selectedFileName.isNotEmpty)
                    Chip(
                      label: Text(
                        _selectedFileName,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('bulk_spreadsheet_input_field'),
                controller: _textController,
                enabled: !_importing,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'CSV Content or Tab-Separated Excel / Sheets Rows',
                  hintText:
                      'item_id,category_code,category_name,subcategory,title,brand,amazon_search_helper_url,amazon_affiliate_link,...',
                  alignLabelWithHint: true,
                ),
                onChanged: _reparse,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ComplianceBadge(
                    ok: _parsed.totalDataRows > 0,
                    label: 'Total Rows: ${_parsed.totalDataRows}',
                  ),
                  _ComplianceBadge(
                    ok: readyCount > 0,
                    label: 'Ready w/ Links: $readyCount',
                  ),
                  _ComplianceBadge(
                    ok: true,
                    label:
                        'Pending Blank Links (Skipped): ${_parsed.pendingBlankLinkRows}',
                  ),
                  if (_parsed.invalidRows.isNotEmpty)
                    _ComplianceBadge(
                      ok: false,
                      label: 'Invalid Rows: ${_parsed.invalidRows.length}',
                    ),
                ],
              ),
              if (readyCount > 0) ...[
                const SizedBox(height: 10),
                const Text(
                  'Ready to Publish Preview:',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                ...(_parsed.readyPayloads.take(5).map((row) {
                  final title = '${row['title'] ?? ''}';
                  final brand = '${row['brand'] ?? ''}';
                  final sub = '${row['subcategory'] ?? ''}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '• $title ($brand)${sub.isNotEmpty ? ' — $sub' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: PipeBuyerColors.slate,
                      ),
                    ),
                  );
                })),
                if (readyCount > 5)
                  Text(
                    '+ ${readyCount - 5} more item(s) ready to publish',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: PipeBuyerColors.industrialBlue,
                    ),
                  ),
              ],
              if (_parsed.invalidRows.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.warning.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: PipeBuyerColors.warning.withValues(alpha: .35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _parsed.invalidRows
                        .take(5)
                        .map(
                          (msg) => Text(
                            msg,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
              if (_importing) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 4),
                Text(
                  'Publishing $_completedCount of $_totalCount Store items...',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: PipeBuyerColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: (_importing || readyCount == 0) ? null : _runImport,
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: Text(
            _importing
                ? 'Publishing...'
                : 'Publish $readyCount Ready Item${readyCount == 1 ? '' : 's'}',
          ),
        ),
      ],
    );
  }
}
