import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    this.embedded = false,
    this.initialTabIndex = 0,
    this.initialSection = '',
  });

  final PipeBuyerShopClient? client;
  final Future<bool> Function()? adminAccessOverride;
  final Future<PipeBuyerShopRoleSession> Function()? sessionOverride;
  final bool embedded;
  final int initialTabIndex;
  final String initialSection;

  @override
  State<PipeBuyerShopAdminPage> createState() => _PipeBuyerShopAdminPageState();
}

class _PipeBuyerShopAdminPageState extends State<PipeBuyerShopAdminPage>
    with TickerProviderStateMixin {
  late PipeBuyerShopClient _client;
  late TabController _tabController;

  bool _checkingAccess = true;
  PipeBuyerShopRoleSession _session =
      const PipeBuyerShopRoleSession.signedOut();
  bool _loading = true;
  String? _loadError;

  PipeBuyerShopSettings _settings = const PipeBuyerShopSettings();
  List<PipeBuyerShopProduct> _firestoreProducts =
      const <PipeBuyerShopProduct>[];
  List<Map<String, dynamic>> _applications = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _staff = const <Map<String, dynamic>>[];
  Map<String, dynamic> _analytics = const <String, dynamic>{};
  List<PipeBuyerProductSuggestion> _suggestions =
      const <PipeBuyerProductSuggestion>[];
  String _suggestionStatusFilter = 'all';
  String _applicationStatusFilter = 'all';
  String _applicationQuery = '';
  bool _appliedInitialSection = false;

  String _catalogQuery = '';
  String _catalogCategory = '';
  String _catalogSubcategory = '';
  String _catalogPlatformGroup = 'all';
  String _catalogOriginFilter = 'all';
  String _catalogCountryFilter = 'ALL';
  bool _hidingStarters = false;

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
  final _adminEmailsController = TextEditingController();
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
    if (_session.canManageSettingsAndRoles) return 7;
    if (_session.canReviewVendors) return 5;
    return 4;
  }

  int? get _applicationsTabIndex {
    if (!_session.canReviewVendors) return null;
    return _session.canManageSettingsAndRoles ? 5 : 4;
  }

  int? _sectionIndexForSession(String rawSection) {
    final normalized = rawSection.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return switch (normalized) {
      'overview' => 0,
      'catalog' || 'links' => 1,
      'suggestions' => 2,
      'platforms' => 3,
      'settings' || 'tags' => _session.canManageSettingsAndRoles ? 4 : null,
      'applications' || 'vendors' => _applicationsTabIndex,
      'roles' || 'staff' => _session.canManageSettingsAndRoles ? 6 : null,
      _ => null,
    };
  }

  void _syncTabController() {
    final targetLength = _expectedTabCount;
    int desiredIndex = _tabController.index;
    if (!_appliedInitialSection && widget.initialSection.trim().isNotEmpty) {
      final resolved = _sectionIndexForSession(widget.initialSection);
      if (resolved != null) {
        desiredIndex = resolved;
        _appliedInitialSection = true;
      }
    }
    desiredIndex = desiredIndex.clamp(0, targetLength - 1);
    if (_tabController.length == targetLength) {
      if (_tabController.index != desiredIndex) {
        _tabController.index = desiredIndex;
      }
      return;
    }
    final old = _tabController;
    _tabController = TabController(
      length: targetLength,
      initialIndex: desiredIndex,
      vsync: this,
    );
    old.dispose();
  }

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerShopClient();
    _tabController = TabController(
      length: 7,
      initialIndex: widget.initialTabIndex.clamp(0, 6),
      vsync: this,
    );
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
    _adminEmailsController.dispose();
    _linkTesterController.dispose();
    _staffEmailController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAndLoad() async {
    setState(() {
      _checkingAccess = true;
      _loadError = null;
    });

    PipeBuyerShopRoleSession resolved =
        const PipeBuyerShopRoleSession.signedOut();
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
      final snapFuture = _client.getAdminDashboard();
      final suggestionsFuture = _client.listProductSuggestions().catchError(
            (_) => const <PipeBuyerProductSuggestion>[],
          );
      final snap = await snapFuture;
      final suggestions = await suggestionsFuture;
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
        _staff = snap.staff;
        _analytics = snap.analytics;
        _suggestions = suggestions;
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
    _adminEmailsController.text = settings.adminNotificationEmails.join(', ');
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
      adminNotificationEmails: _adminEmailsController.text
          .split(RegExp(r'[,;\n]+'))
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.contains('@') && e.contains('.'))
          .toList(growable: false),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _savingSettings = true);
    try {
      final updated = await _client.updateStoreSettings(
        _draftSettingsFromForm(),
      );
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

  List<PipeBuyerShopProduct> get _visibleBuiltInStarterProducts {
    final liveIds = _firestoreProducts.map((p) => p.id.toLowerCase()).toSet();
    final hiddenIds =
        _settings.hiddenStarterIds.map((id) => id.toLowerCase()).toSet();
    return PipeBuyerShopTaxonomy.starterCatalog
        .where(
          (item) =>
              !liveIds.contains(item.id.toLowerCase()) &&
              !hiddenIds.contains(item.id.toLowerCase()),
        )
        .toList(growable: false);
  }

  Future<String?> _openProductEditor({
    PipeBuyerShopProduct? existing,
    PipeBuyerShopSourceType? initialSourceType,
    String? initialVendorName,
    String? initialSuggestedTitle,
    String? initialSuggestedUrl,
    String? initialCategoryCode,
    String? initialSuggestionNotes,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => PipeBuyerAffiliateLinkEditorDialog(
        client: _client,
        settings: _settings,
        existing: existing,
        initialSourceType: initialSourceType,
        initialVendorName: initialVendorName,
        initialSuggestedTitle: initialSuggestedTitle,
        initialSuggestedUrl: initialSuggestedUrl,
        initialCategoryCode: initialCategoryCode,
        initialSuggestionNotes: initialSuggestionNotes,
      ),
    );
    if (!mounted) return null;
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
    return result;
  }

  Future<void> _convertSuggestionToProduct(
    PipeBuyerProductSuggestion suggestion,
  ) async {
    final result = await _openProductEditor(
      initialSuggestedTitle: suggestion.productName,
      initialSuggestedUrl: suggestion.productUrl,
      initialCategoryCode: suggestion.categoryCode,
      initialSuggestionNotes: suggestion.notes,
    );
    if (!mounted || result != 'saved') return;
    try {
      await _client.updateProductSuggestionStatus(
        suggestionId: suggestion.id,
        status: 'added',
      );
      if (!mounted) return;
      await _reloadDashboard();
    } catch (_) {
      // Product already published cleanly; ignore status update failure.
    }
  }

  Future<void> _updateSuggestionStatus(
    PipeBuyerProductSuggestion suggestion,
    String nextStatus,
  ) async {
    try {
      await _client.updateProductSuggestionStatus(
        suggestionId: suggestion.id,
        status: nextStatus,
      );
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: nextStatus == 'dismissed'
            ? 'Suggestion dismissed.'
            : nextStatus == 'added'
                ? 'Marked suggestion as added to Store.'
                : 'Suggestion reopened.',
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

  Future<void> _testOpenAffiliateLink(PipeBuyerShopProduct item) async {
    final opened = await _client.openProductAffiliateLink(
      product: item,
      settings: _settings,
      regionCode: 'US',
      placement: 'admin_test',
    );
    if (!mounted) return;
    if (!opened) {
      PipeFeedback.show(
        context,
        message:
            'Could not open buy link (${item.destinationUrl}). Click Edit to verify the HTTPS URL.',
        tone: PipeStatusTone.warning,
      );
    }
  }

  Future<void> _hideAllStarterItems() async {
    final visibleStarters = _visibleBuiltInStarterProducts;
    if (visibleStarters.isEmpty || _hidingStarters) return;
    setState(() => _hidingStarters = true);
    try {
      await _client.hideStarterProducts(
        PipeBuyerShopTaxonomy.starterCatalog
            .map((item) => item.id)
            .toList(growable: false),
      );
      if (!mounted) return;
      setState(() => _hidingStarters = false);
      PipeFeedback.show(
        context,
        message:
            'Hidden ${visibleStarters.length} built-in demo starter templates. Only your real affiliate products are now shown.',
        tone: PipeStatusTone.success,
      );
      await _reloadDashboard();
    } catch (error) {
      if (!mounted) return;
      setState(() => _hidingStarters = false);
      PipeFeedback.show(
        context,
        message: error.toString().replaceFirst('Bad state: ', ''),
        tone: PipeStatusTone.error,
      );
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
      await _client.deleteProduct(productId: product.id, title: product.title);
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
    final existsInFirestore = _firestoreProducts.any((p) => p.id == product.id);
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
    String decision, {
    String reviewNotes = '',
    bool notifyApplicant = true,
  }) async {
    try {
      await _client.reviewVendorApplication(
        applicationId: applicationId,
        status: decision,
        reviewNotes: reviewNotes,
        notifyApplicant: notifyApplicant,
      );
      if (!mounted) return;
      final label = decision.replaceAll('_', ' ');
      PipeFeedback.show(
        context,
        message: notifyApplicant
            ? 'Application marked as $label and partner notified.'
            : 'Application marked as $label.',
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

  Future<void> _openReviewApplicationDialog(
    Map<String, dynamic> app, {
    String initialDecision = 'approved',
  }) async {
    final id = app['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final result = await showDialog<
        ({String decision, String notes, bool notifyApplicant})>(
      context: context,
      builder: (_) => _VendorApplicationReviewDialog(
        app: app,
        initialDecision: initialDecision,
      ),
    );

    if (result == null || !mounted) return;
    await _reviewApplication(
      id,
      result.decision,
      reviewNotes: result.notes,
      notifyApplicant: result.notifyApplicant,
    );
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
      if (widget.embedded) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_session.authorized) {
      return _buildUnauthorizedView(context);
    }

    final catalogItems = _allManageableProducts;
    final canSettingsAndRoles = _session.canManageSettingsAndRoles;
    final canVendors = _session.canReviewVendors;
    final pendingSuggestionsCount =
        _suggestions.where((s) => s.isPending).length;

    final tabs = <Widget>[
      const Tab(
        icon: Icon(Icons.insights_rounded, size: 18),
        text: 'Overview & Clicks',
      ),
      Tab(
        icon: const Icon(Icons.inventory_2_outlined, size: 18),
        text: 'Affiliate Links (${catalogItems.length})',
      ),
      Tab(
        icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
        text: 'Suggestions ($pendingSuggestionsCount)',
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
      if (canSettingsAndRoles)
        const Tab(
          icon: Icon(Icons.verified_user_outlined, size: 18),
          text: 'Roles & Access',
        ),
    ];

    final bodyContent = _loading
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
                  _buildSuggestionsTab(),
                  _buildAffiliatePlatformsDirectoryTab(),
                  if (canSettingsAndRoles) _buildSettingsTab(),
                  if (canVendors) _buildApplicationsTab(),
                  if (canSettingsAndRoles) _buildRolesTab(),
                ],
              );

    if (widget.embedded) {
      return ColoredBox(
        color: PipeBuyerColors.canvas,
        child: Column(
          children: [
            Material(
              color: PipeBuyerColors.ink,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Store & Affiliate Workspace',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Refresh Store Admin',
                              onPressed: _loading ? null : _reloadDashboard,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _openProductEditor(),
                              icon: const Icon(
                                Icons.add_link_rounded,
                                size: 18,
                              ),
                              label: const Text('Add Affiliate Link'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: PipeBuyerColors.orange,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: tabs,
                  ),
                ],
              ),
            ),
            Expanded(child: bodyContent),
          ],
        ),
      );
    }

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
          tabs: tabs,
        ),
      ),
      body: bodyContent,
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

  static bool _matchesPlatformGroup(
    PipeBuyerShopSourceType sourceType,
    String group,
  ) {
    return switch (group) {
      'amazon' => sourceType == PipeBuyerShopSourceType.amazonAffiliate,
      'aliexpress' => sourceType == PipeBuyerShopSourceType.aliexpressAffiliate,
      'lazada' => sourceType == PipeBuyerShopSourceType.lazadaAffiliate,
      'shopee' => sourceType == PipeBuyerShopSourceType.shopeeAffiliate,
      'network' => sourceType == PipeBuyerShopSourceType.affiliateNetwork,
      'ebay' => sourceType == PipeBuyerShopSourceType.ebayPartner ||
          sourceType == PipeBuyerShopSourceType.walmartAffiliate,
      'retail' => sourceType == PipeBuyerShopSourceType.hardwareProRetail ||
          sourceType == PipeBuyerShopSourceType.brandPartner ||
          sourceType == PipeBuyerShopSourceType.distributorAffiliate ||
          sourceType == PipeBuyerShopSourceType.vendorCatalog,
      'temu_tiktok' => sourceType == PipeBuyerShopSourceType.temuAffiliate ||
          sourceType == PipeBuyerShopSourceType.tiktokShopAffiliate,
      'alibaba' => sourceType == PipeBuyerShopSourceType.alibabaB2b,
      _ => true,
    };
  }

  Widget _buildDemoStarterNoticeBanner({bool compact = false}) {
    final visibleStarters = _visibleBuiltInStarterProducts;
    if (visibleStarters.isEmpty) {
      if (_settings.hiddenStarterIds.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: EdgeInsets.only(bottom: compact ? 8 : 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: PipeBuyerColors.success.withValues(alpha: .35),
          ),
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
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: PipeBuyerColors.success,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Built-in demo templates are hidden (${_settings.hiddenStarterIds.length} hidden) — shoppers only see your real uploaded affiliate products.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: PipeBuyerColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _restoreHiddenStarterItems,
              icon: const Icon(Icons.restore_rounded, size: 16),
              label: const Text('Restore Demo Templates'),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 8 : 14),
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PipeBuyerColors.warning.withValues(alpha: .45),
        ),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: PipeBuyerColors.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${visibleStarters.length} Built-In Demo Starter Templates Visible (${_firestoreProducts.length} Live Team Upload${_firestoreProducts.length == 1 ? '' : 's'})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: PipeBuyerColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        compact
                            ? 'Items badged "DEMO TEMPLATE" are built-in starter placeholders without product photos. Hide all ${visibleStarters.length} demo items in 1 click so only your real affiliate links show, or click "Test Buy Link" on any card to open it.'
                            : 'Why are ${visibleStarters.length} items already here without photos? Those are built-in starter placeholders (Amazon search links with no photos). Click "Hide All Demo Templates" to start with a clean Store showing only your real uploads, or edit/test any card in the Affiliate Links tab.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PipeBuyerColors.slate,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _hidingStarters ? null : _hideAllStarterItems,
                style: FilledButton.styleFrom(
                  backgroundColor: PipeBuyerColors.warning.withValues(
                    alpha: .18,
                  ),
                  foregroundColor: PipeBuyerColors.ink,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.visibility_off_outlined, size: 17),
                label: Text(
                  _hidingStarters
                      ? 'Hiding...'
                      : 'Hide All Demo Templates (${visibleStarters.length})',
                ),
              ),
              if (!compact)
                OutlinedButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Review Catalog'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final totalClicks =
        (_analytics['totalRecordedClicks'] as num?)?.toInt() ?? 0;
    final activeProducts =
        _allManageableProducts.where((p) => p.status == 'active').length;
    final liveUploadCount = _firestoreProducts.length;
    final pendingApps = (_analytics['pendingApplicationCount'] as num?)
            ?.toInt() ??
        _applications
            .where((a) => (a['status']?.toString() ?? 'pending') == 'pending')
            .length;
    final openApps = (_analytics['openApplicationCount'] as num?)?.toInt() ??
        _applications.where((a) {
          final s = (a['status']?.toString() ?? 'pending');
          return s == 'pending' || s == 'under_review';
        }).length;

    final bySource = _analytics['clicksBySource'] is Map
        ? Map<String, dynamic>.from(_analytics['clicksBySource'] as Map)
        : const <String, dynamic>{};
    final byPlacement = _analytics['clicksByPlacement'] is Map
        ? Map<String, dynamic>.from(_analytics['clicksByPlacement'] as Map)
        : const <String, dynamic>{};

    const quickLaunchPlatforms = <_AffiliateQuickLaunchSpec>[
      _AffiliateQuickLaunchSpec(
        title: 'Amazon Associates',
        regions: 'US • CA • UK • AU • SG',
        subtitle: 'Paste SiteStripe shortlink (amzn.to), product URL, or ASIN',
        icon: Icons.shopping_cart_checkout_rounded,
        accent: Color(0xFFD97706),
        sourceType: PipeBuyerShopSourceType.amazonAffiliate,
        vendorName: 'Amazon',
      ),
      _AffiliateQuickLaunchSpec(
        title: 'AliExpress Portals',
        regions: 'Worldwide Delivery',
        subtitle: 'Global industrial tools, gauges, welding & electronics',
        icon: Icons.public_rounded,
        accent: Color(0xFFDC2626),
        sourceType: PipeBuyerShopSourceType.aliexpressAffiliate,
        vendorName: 'AliExpress',
      ),
      _AffiliateQuickLaunchSpec(
        title: 'Lazada LazAffiliate',
        regions: 'PH • SG • MY • TH • ID • VN',
        subtitle: 'Auto-detects country store so only local buyers see it',
        icon: Icons.local_mall_outlined,
        accent: Color(0xFF2563EB),
        sourceType: PipeBuyerShopSourceType.lazadaAffiliate,
        vendorName: 'Lazada',
      ),
      _AffiliateQuickLaunchSpec(
        title: 'Shopee Affiliate',
        regions: 'PH • SG • MY • TH • ID • VN • BR',
        subtitle: 'Paste shope.ee or Shopee product URL with auto geo-tag',
        icon: Icons.storefront_outlined,
        accent: Color(0xFFEA580C),
        sourceType: PipeBuyerShopSourceType.shopeeAffiliate,
        vendorName: 'Shopee',
      ),
      _AffiliateQuickLaunchSpec(
        title: 'Involve Asia / Impact / CJ',
        regions: 'SEA & Global Networks',
        subtitle: 'Paste invol.co or partner deep-link for 500+ brands',
        icon: Icons.hub_outlined,
        accent: Color(0xFF7C3AED),
        sourceType: PipeBuyerShopSourceType.affiliateNetwork,
        vendorName: 'Involve Asia Partner',
      ),
      _AffiliateQuickLaunchSpec(
        title: 'eBay Partner Network',
        regions: 'US • CA • UK • AU • Global',
        subtitle: 'Surplus pipe tools, RIDGID/Miller gear & MRO parts',
        icon: Icons.gavel_rounded,
        accent: Color(0xFF0284C7),
        sourceType: PipeBuyerShopSourceType.ebayPartner,
        vendorName: 'eBay',
      ),
      _AffiliateQuickLaunchSpec(
        title: 'VEVOR & Pro Hardware',
        regions: 'US • CA • Global Retail',
        subtitle: 'VEVOR, Home Depot, Tractor Supply, Northern Tool',
        icon: Icons.handyman_outlined,
        accent: Color(0xFF059669),
        sourceType: PipeBuyerShopSourceType.hardwareProRetail,
        vendorName: 'VEVOR',
      ),
      _AffiliateQuickLaunchSpec(
        title: 'Temu, TikTok & Alibaba',
        regions: 'Global & Bulk B2B',
        subtitle: 'Workshop deals, viral tools & bulk pipe/valve sourcing',
        icon: Icons.precision_manufacturing_outlined,
        accent: Color(0xFF0F766E),
        sourceType: PipeBuyerShopSourceType.temuAffiliate,
        vendorName: 'Temu',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[PipeBuyerColors.ink, Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: PipeBuyerColors.orange.withValues(alpha: .35),
            ),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.orange.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_session.roleDisplayLabel.toUpperCase()} • MULTI-PLATFORM AFFILIATE STUDIO',
                        style: const TextStyle(
                          color: PipeBuyerColors.orange,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Publish Products Across Amazon, AliExpress, Lazada, Shopee & 25+ Programs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paste any affiliate link to auto-fill the product photo, title, brand, and orderable countries — shoppers automatically see only items that ship to their country.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openProductEditor(),
                    style: FilledButton.styleFrom(
                      backgroundColor: PipeBuyerColors.orange,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_link_rounded, size: 18),
                    label: const Text('Add Affiliate Product'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _tabController.animateTo(1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .35),
                      ),
                    ),
                    icon: const Icon(Icons.grid_view_rounded, size: 17),
                    label: const Text('Manage Visual Catalog'),
                  ),
                  if (_session.role != 'affiliate_contributor')
                    OutlinedButton.icon(
                      onPressed: _openBulkSpreadsheetImporter,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: .35),
                        ),
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 17),
                      label: const Text('Import Spreadsheet (.CSV)'),
                    ),
                ],
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
              label: 'Your Live Team Uploads',
              value: '$liveUploadCount',
              icon: Icons.cloud_done_outlined,
              color: PipeBuyerColors.industrialBlue,
            ),
            _MetricCard(
              label: 'Active Store Links',
              value: '$activeProducts',
              icon: Icons.shopping_bag_outlined,
              color: PipeBuyerColors.success,
            ),
            _MetricCard(
              label: 'Pending Partner Apps',
              value: '$pendingApps',
              icon: Icons.pending_actions_rounded,
              color: PipeBuyerColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_session.canReviewVendors && openApps > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: PipeBuyerColors.industrialBlue.withValues(alpha: .40),
              ),
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
                      Icons.notifications_active_rounded,
                      color: PipeBuyerColors.industrialBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '$openApps brand, OEM, or distributor listing request(s) waiting for Admin review.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: PipeBuyerColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    final idx = _applicationsTabIndex;
                    if (idx != null) {
                      _tabController.animateTo(idx);
                    }
                  },
                  icon: const Icon(Icons.storefront_outlined, size: 16),
                  label: const Text('Review Partner Requests'),
                ),
              ],
            ),
          ),
        if (_suggestions.any((s) => s.isPending))
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: PipeBuyerColors.orange.withValues(alpha: .40),
              ),
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
                      Icons.lightbulb_rounded,
                      color: PipeBuyerColors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '${_suggestions.where((s) => s.isPending).length} shopper product suggestion(s) waiting for review — add requested gear with 1 click.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: PipeBuyerColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _tabController.animateTo(2),
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: const Text('Review Suggestions'),
                ),
              ],
            ),
          ),
        _buildDemoStarterNoticeBanner(),
        const SizedBox(height: 6),
        const Text(
          '1-CLICK ADD BY AFFILIATE PROGRAM',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: PipeBuyerColors.slate,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose a platform below to open the visual product studio pre-set for that affiliate network (or paste any link directly).',
          style: TextStyle(fontSize: 12, color: PipeBuyerColors.muted),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cols = width >= 1080
                ? 4
                : width >= 680
                    ? 2
                    : 1;
            const gap = 10.0;
            final cardW = (width - (gap * (cols - 1))) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: quickLaunchPlatforms.map((spec) {
                return SizedBox(
                  width: cardW,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openProductEditor(
                      initialSourceType: spec.sourceType,
                      initialVendorName: spec.vendorName,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
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
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: spec.accent.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  spec.icon,
                                  size: 18,
                                  color: spec.accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: PipeBuyerColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(
                                        999,
                                      ),
                                    ),
                                    child: Text(
                                      spec.regions,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: PipeBuyerColors.slate,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            spec.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            spec.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: PipeBuyerColors.muted,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Add Link',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: spec.accent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: spec.accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk Spreadsheet (.CSV) Import & Catalog Backup Tools',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Optional power tools: import multi-platform affiliate links in bulk from Excel or Google Sheets (supports eligible_countries, image_url, price & all affiliate networks), or export your catalog to CSV.',
                        style: TextStyle(
                          fontSize: 12,
                          color: PipeBuyerColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
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
                    if (_session.canManageSettingsAndRoles)
                      TextButton.icon(
                        onPressed: _seedingStarter ? null : _seedStarterCatalog,
                        icon: const Icon(Icons.cloud_upload_outlined, size: 17),
                        label: Text(
                          _seedingStarter
                              ? 'Syncing...'
                              : 'Sync Starter Items to Firestore',
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
                    'Click telemetry populates automatically as shoppers open your Amazon, AliExpress, Lazada, Shopee, eBay, and partner links across the Store and contextual cards.',
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
    final liveIds = _firestoreProducts.map((p) => p.id.toLowerCase()).toSet();
    final visibleStarterCount = _visibleBuiltInStarterProducts.length;
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
      final isLiveCustom = liveIds.contains(p.id.toLowerCase());
      if (_catalogPlatformGroup != 'all' &&
          !_matchesPlatformGroup(p.sourceType, _catalogPlatformGroup)) {
        return false;
      }
      if (_catalogOriginFilter == 'live' && !isLiveCustom) return false;
      if (_catalogOriginFilter == 'demo' && isLiveCustom) return false;
      if (_catalogOriginFilter == 'featured' && !p.featured) return false;
      if (_catalogOriginFilter == 'missing_photo' &&
          p.imageUrl.trim().isNotEmpty) {
        return false;
      }
      if (_catalogCountryFilter != 'ALL') {
        if (_catalogCountryFilter == 'GLOBAL') {
          if (!p.effectiveEligibleCountries.contains('GLOBAL')) return false;
        } else if (!p.shipsToCountry(_catalogCountryFilter)) {
          return false;
        }
      }
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
            p.vendorName.toLowerCase().contains(q) ||
            p.subcategory.toLowerCase().contains(q) ||
            p.asin.toLowerCase().contains(q) ||
            p.destinationUrl.toLowerCase().contains(q);
      }
      return true;
    }).toList(growable: false);

    const platformChips = <(String, String)>[
      ('all', 'All Platforms'),
      ('amazon', 'Amazon'),
      ('aliexpress', 'AliExpress'),
      ('lazada', 'Lazada'),
      ('shopee', 'Shopee'),
      ('network', 'Involve Asia / Networks'),
      ('ebay', 'eBay / Walmart'),
      ('retail', 'VEVOR & Pro Retail'),
      ('temu_tiktok', 'Temu / TikTok'),
      ('alibaba', 'Alibaba B2B'),
    ];

    final originChips = <(String, String)>[
      ('all', 'All (${allProducts.length})'),
      ('live', 'Your Live Links (${_firestoreProducts.length})'),
      ('featured', 'Featured'),
      ('missing_photo', 'Needs Photo'),
      if (visibleStarterCount > 0)
        ('demo', 'Demo Templates ($visibleStarterCount)'),
    ];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: PipeBuyerColors.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 240,
                      maxWidth: 420,
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText:
                            'Search affiliate links by title, brand, subcategory, ASIN...',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
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
                      width: 210,
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
                              child: Text(sub, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _catalogSubcategory = v ?? ''),
                      ),
                    ),
                  DropdownButton<String>(
                    value: _catalogCountryFilter,
                    items: [
                      const DropdownMenuItem(
                        value: 'ALL',
                        child: Text('All Countries'),
                      ),
                      const DropdownMenuItem(
                        value: 'GLOBAL',
                        child: Text('🌍 Worldwide Only'),
                      ),
                      ...PipeBuyerShopTaxonomy.countryOptions
                          .where((c) => c.code != 'ALL')
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.code,
                              child: Text('${c.flag} Ships to ${c.shortLabel}'),
                            ),
                          ),
                    ],
                    onChanged: (v) =>
                        setState(() => _catalogCountryFilter = v ?? 'ALL'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openProductEditor(),
                    style: FilledButton.styleFrom(
                      backgroundColor: PipeBuyerColors.orange,
                    ),
                    icon: const Icon(Icons.add_link_rounded, size: 18),
                    label: const Text('Add Affiliate Link'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openBulkSpreadsheetImporter,
                    icon: const Icon(Icons.upload_file_rounded, size: 17),
                    label: const Text('Import Spreadsheet (.CSV)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _exportCatalogCsv,
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...platformChips.map((entry) {
                      final selected = _catalogPlatformGroup == entry.$1;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            entry.$2,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          selected: selected,
                          selectedColor: PipeBuyerColors.orangeSoft,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) =>
                              setState(() => _catalogPlatformGroup = entry.$1),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    ...originChips.map((entry) {
                      final selected = _catalogOriginFilter == entry.$1;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(
                            entry.$2,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          selected: selected,
                          selectedColor: PipeBuyerColors.industrialBlue
                              .withValues(alpha: .14),
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => setState(
                            () => _catalogOriginFilter =
                                selected && entry.$1 != 'all'
                                    ? 'all'
                                    : entry.$1,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDemoStarterNoticeBanner(compact: true),
              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 42),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 42,
                          color: PipeBuyerColors.muted,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          allProducts.isEmpty
                              ? 'Your Store catalog is clean and ready for your first real product!'
                              : 'No affiliate links match this filter.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Paste any Amazon, AliExpress, Lazada, Shopee, Involve Asia, or partner link to auto-fill its photo, title & country.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: PipeBuyerColors.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _openProductEditor(),
                          icon: const Icon(Icons.add_link_rounded),
                          label: const Text('Add Affiliate Link'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filtered.map((item) {
                  final isLiveCustom = liveIds.contains(item.id.toLowerCase());
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AdminCatalogProductCard(
                      item: item,
                      isLiveCustom: isLiveCustom,
                      onTestLink: () => _testOpenAffiliateLink(item),
                      onToggleFeatured: () => _toggleProductStatus(
                        item,
                        nextFeatured: !item.featured,
                      ),
                      onToggleActive: (val) => _toggleProductStatus(
                        item,
                        nextStatus: val ? 'active' : 'paused',
                      ),
                      onEdit: () => _openProductEditor(existing: item),
                      onDelete: () => _confirmAndDeleteProduct(item),
                    ),
                  );
                }),
            ],
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
                  'Every platform below is built into Pipe Buyer\'s Smart Quick-Paste parser, automatic photo/title fetcher, and smart country geo-filter. Sign up for any program, paste shortlinks or product URLs into "Add Affiliate Link", and earn passive commissions on every qualifying click.',
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
                  Text(platform.bestFor, style: const TextStyle(fontSize: 13)),
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
                        onPressed: () => _openProductEditor(
                          initialSourceType: platform.sourceType,
                          initialVendorName: platform.name,
                        ),
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
                  style: TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 12.5,
                  ),
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
                const SizedBox(height: 8),
                TextField(
                  controller: _adminEmailsController,
                  decoration: const InputDecoration(
                    labelText:
                        'Vendor & Brand Portal Alert Emails (comma-separated)',
                    hintText: 'partnerships@pipebuyer.com, fleet@pipebuyer.com',
                    helperText:
                        'All active Administrators & Store Managers are notified automatically via push, in-app & email; add extra partnership inboxes here.',
                    prefixIcon: Icon(Icons.notifications_active_outlined),
                  ),
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
                    labelText:
                        'Canada Amazon Associate Tag (amazon.ca — optional w/ OneLink)',
                    hintText:
                        'Leave blank if Amazon OneLink is active on US Store ID',
                    helperText:
                        'Leave blank when Amazon OneLink is enabled on your US Store ID so OneLink auto-redirects Canadian buyers.',
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
                          labelText:
                              'eBay Partner Network 10-Digit Campaign ID',
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
                          labelText:
                              'Skimlinks / Sovrn Publisher ID (optional)',
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
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
    final pendingCount = _applications
        .where((a) => (a['status']?.toString() ?? 'pending') == 'pending')
        .length;
    final underReviewCount = _applications
        .where((a) => (a['status']?.toString() ?? '') == 'under_review')
        .length;
    final approvedCount = _applications
        .where((a) => (a['status']?.toString() ?? '') == 'approved')
        .length;
    final waitlistedCount = _applications
        .where((a) => (a['status']?.toString() ?? '') == 'waitlisted')
        .length;
    final declinedCount = _applications
        .where((a) => (a['status']?.toString() ?? '') == 'declined')
        .length;

    final query = _applicationQuery.trim().toLowerCase();
    final filtered = _applications.where((app) {
      final status = (app['status']?.toString() ?? 'pending').toLowerCase();
      if (_applicationStatusFilter != 'all' &&
          status != _applicationStatusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = <String>[
        app['companyName']?.toString() ?? '',
        app['contactName']?.toString() ?? '',
        app['contactTitle']?.toString() ?? '',
        app['email']?.toString() ?? '',
        app['headquartersLocation']?.toString() ?? '',
        app['id']?.toString() ?? '',
        if (app['brandsCarried'] is Iterable)
          ...(app['brandsCarried'] as Iterable).map((e) => e.toString()),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OEM, Brand & Distributor Listing Requests',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Review Caterpillar, Brandt Tractor, Milwaukee, Snap-on & authorized partner submissions. Approving creates a verified partner record and notifies the applicant.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: PipeBuyerColors.muted,
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: _reloadDashboard,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText:
                        'Search company, brand, contact, territory, or reference ID',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _applicationQuery = v),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <({String key, String label})>[
                    (
                      key: 'all',
                      label: 'All (${_applications.length})',
                    ),
                    (key: 'pending', label: 'Pending ($pendingCount)'),
                    (
                      key: 'under_review',
                      label: 'Under Review ($underReviewCount)',
                    ),
                    (
                      key: 'approved',
                      label: 'Approved ($approvedCount)',
                    ),
                    (
                      key: 'waitlisted',
                      label: 'Waitlisted ($waitlistedCount)',
                    ),
                    (
                      key: 'declined',
                      label: 'Declined ($declinedCount)',
                    ),
                  ].map((chip) {
                    final selected = _applicationStatusFilter == chip.key;
                    return ChoiceChip(
                      label: Text(chip.label),
                      selected: selected,
                      onSelected: (_) => setState(
                        () => _applicationStatusFilter = chip.key,
                      ),
                    );
                  }).toList(growable: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_applications.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No distributor, brand, or business vendor applications submitted yet.',
                  style: TextStyle(color: PipeBuyerColors.muted),
                ),
              ),
            ),
          )
        else if (filtered.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No partner requests match the current filter.',
                  style: TextStyle(color: PipeBuyerColors.muted),
                ),
              ),
            ),
          )
        else
          ...filtered.map((app) {
            final id = app['id']?.toString() ?? '';
            final companyName = app['companyName']?.toString() ?? 'Applicant';
            final status =
                (app['status']?.toString() ?? 'pending').toLowerCase();
            final trackCode = app['partnershipTrack']?.toString() ?? '';
            final trackLabel = PipeBuyerShopTaxonomy.vendorTrackLabel(
              trackCode,
            );
            final authLevel = app['authorizationLevel']?.toString() ?? '';
            final authLabel = authLevel.isNotEmpty
                ? PipeBuyerShopTaxonomy.vendorAuthLevelLabel(authLevel)
                : '';
            final contactName = app['contactName']?.toString() ?? '';
            final contactTitle = app['contactTitle']?.toString() ?? '';
            final email = app['email']?.toString() ?? '';
            final phone = app['phone']?.toString() ?? '';
            final hq = app['headquartersLocation']?.toString() ?? '';
            final websiteUrl = app['websiteUrl']?.toString() ?? '';
            final sampleCatalogUrl = app['sampleCatalogUrl']?.toString() ?? '';
            final brandsList = (app['brandsCarried'] is Iterable)
                ? (app['brandsCarried'] as Iterable)
                    .map((e) => e.toString())
                    .where((s) => s.isNotEmpty)
                    .toList(growable: false)
                : const <String>[];
            final rawCategories = (app['categories'] is Iterable)
                ? (app['categories'] as Iterable)
                    .map((e) => e.toString())
                    .where((s) => s.isNotEmpty)
                    .toList(growable: false)
                : const <String>[];
            final categoryLabels = rawCategories
                .map(PipeBuyerShopTaxonomy.vendorCategoryLabel)
                .join(', ');
            final placements = (app['requestedPlacements'] is Iterable)
                ? (app['requestedPlacements'] as Iterable)
                    .map(
                      (e) => PipeBuyerShopTaxonomy.vendorPlacementLabel(
                        e.toString(),
                      ),
                    )
                    .where((s) => s.isNotEmpty)
                    .toList(growable: false)
                : const <String>[];
            final regions = (app['fulfillmentRegions'] is Iterable)
                ? (app['fulfillmentRegions'] as Iterable)
                    .map((e) => e.toString())
                    .where((s) => s.isNotEmpty)
                    .join(', ')
                : '';
            final integrationCode =
                app['catalogIntegrationMethod']?.toString() ?? '';
            final integrationLabel = integrationCode.isNotEmpty
                ? PipeBuyerShopTaxonomy.vendorIntegrationLabel(integrationCode)
                : '';
            final estimatedSku = app['estimatedSkuCount']?.toString() ?? '';
            final affiliateDetails =
                app['affiliateProgramDetails']?.toString() ?? '';
            final catalogNotes = app['catalogNotes']?.toString() ?? '';
            final reviewNotes = app['reviewNotes']?.toString() ?? '';
            final notifSummary = app['notificationSummary'] is Map
                ? Map<String, dynamic>.from(app['notificationSummary'] as Map)
                : const <String, dynamic>{};
            final adminAlertsCount =
                (notifSummary['inAppNotifiedCount'] as num?)?.toInt() ?? 0;
            final emailAlertsCount =
                (notifSummary['adminEmailSentCount'] as num?)?.toInt() ?? 0;

            Color badgeBg;
            Color badgeFg;
            if (status == 'approved') {
              badgeBg = PipeBuyerColors.success.withValues(alpha: .15);
              badgeFg = PipeBuyerColors.success;
            } else if (status == 'declined') {
              badgeBg = PipeBuyerColors.danger.withValues(alpha: .12);
              badgeFg = PipeBuyerColors.danger;
            } else if (status == 'under_review') {
              badgeBg = PipeBuyerColors.industrialBlue.withValues(alpha: .14);
              badgeFg = PipeBuyerColors.industrialBlue;
            } else {
              badgeBg = PipeBuyerColors.orangeSoft;
              badgeFg = PipeBuyerColors.orange;
            }

            String? firstStoreCategory;
            for (final code in rawCategories) {
              if (PipeBuyerShopTaxonomy.categoryByCode(code) != null) {
                firstStoreCategory = code;
                break;
              }
            }
            firstStoreCategory ??= rawCategories.contains('heavy_equipment_oem')
                ? 'hydraulics_fleet_shop'
                : 'power_hand_tools';

            final initialSource = trackCode == 'industrial_distributor'
                ? PipeBuyerShopSourceType.distributorAffiliate
                : (trackCode == 'verified_business_vendor'
                    ? PipeBuyerShopSourceType.vendorCatalog
                    : PipeBuyerShopSourceType.brandPartner);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.domain_verification_outlined,
                                size: 20,
                                color: PipeBuyerColors.industrialBlue,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  companyName,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (id.isNotEmpty)
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                  ),
                                  label: Text(
                                    'Ref: ${id.length > 10 ? id.substring(0, 10) : id}',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: id),
                                    );
                                    if (!mounted) return;
                                    PipeFeedback.show(
                                      context,
                                      message:
                                          'Copied application ID $id to clipboard.',
                                      tone: PipeStatusTone.info,
                                    );
                                  },
                                ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status.replaceAll('_', ' ').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: badgeFg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          'Track: $trackLabel',
                          if (authLabel.isNotEmpty) authLabel,
                          if (regions.isNotEmpty) 'Regions: $regions',
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: PipeBuyerColors.industrialBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          'Contact: $contactName${contactTitle.isNotEmpty ? ' ($contactTitle)' : ''}',
                          if (email.isNotEmpty) email,
                          if (phone.isNotEmpty) phone,
                          if (hq.isNotEmpty) 'Territory/HQ: $hq',
                        ].join(' • '),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      if (websiteUrl.isNotEmpty ||
                          sampleCatalogUrl.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            if (websiteUrl.isNotEmpty)
                              InkWell(
                                onTap: PipeBuyerShopUrlBuilder.isSafeHttpsUrl(
                                  websiteUrl,
                                )
                                    ? () => launchUrl(
                                          Uri.parse(websiteUrl),
                                          mode: LaunchMode.externalApplication,
                                        )
                                    : null,
                                child: Text(
                                  'Website: $websiteUrl',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: PipeBuyerColors.industrialBlue,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (sampleCatalogUrl.isNotEmpty)
                              InkWell(
                                onTap: PipeBuyerShopUrlBuilder.isSafeHttpsUrl(
                                  sampleCatalogUrl,
                                )
                                    ? () => launchUrl(
                                          Uri.parse(sampleCatalogUrl),
                                          mode: LaunchMode.externalApplication,
                                        )
                                    : null,
                                child: Text(
                                  'Sample Inventory / Catalog: $sampleCatalogUrl',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: PipeBuyerColors.industrialBlue,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (brandsList.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Brands: ${brandsList.join(', ')}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      if (categoryLabels.isNotEmpty ||
                          estimatedSku.isNotEmpty ||
                          integrationLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            [
                              if (categoryLabels.isNotEmpty)
                                'Categories: $categoryLabels',
                              if (estimatedSku.isNotEmpty)
                                'Size: $estimatedSku',
                              if (integrationLabel.isNotEmpty)
                                'Onboarding: $integrationLabel',
                            ].join(' • '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: PipeBuyerColors.muted,
                            ),
                          ),
                        ),
                      if (placements.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: placements
                              .map(
                                (label) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PipeBuyerColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: PipeBuyerColors.line,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                      if (affiliateDetails.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Affiliate / Dealer Program: $affiliateDetails',
                            style: const TextStyle(
                              fontSize: 12,
                              color: PipeBuyerColors.slate,
                            ),
                          ),
                        ),
                      if (catalogNotes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            catalogNotes,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      if (adminAlertsCount > 0 || emailAlertsCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Admin Alerts Dispatched: $adminAlertsCount in-app/push${emailAlertsCount > 0 ? ' • $emailAlertsCount email(s)' : ''}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: PipeBuyerColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (reviewNotes.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: PipeBuyerColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: PipeBuyerColors.line),
                          ),
                          child: Text(
                            'Admin Decision Notes: $reviewNotes',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            key: Key('vendor_approve_$id'),
                            onPressed: status == 'approved'
                                ? null
                                : () => _reviewApplication(id, 'approved'),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Approve Partner'),
                          ),
                          FilledButton.tonalIcon(
                            key: Key('vendor_under_review_$id'),
                            onPressed: status == 'under_review'
                                ? null
                                : () => _reviewApplication(id, 'under_review'),
                            icon: const Icon(
                              Icons.manage_search_rounded,
                              size: 18,
                            ),
                            label: const Text('Under Review'),
                          ),
                          OutlinedButton.icon(
                            key: Key('vendor_dialog_$id'),
                            onPressed: () => _openReviewApplicationDialog(
                              app,
                              initialDecision:
                                  status == 'pending' ? 'approved' : status,
                            ),
                            icon: const Icon(
                              Icons.mark_email_read_outlined,
                              size: 17,
                            ),
                            label: const Text('Review & Message'),
                          ),
                          OutlinedButton.icon(
                            key: Key('vendor_add_product_$id'),
                            onPressed: () => _openProductEditor(
                              initialSourceType: initialSource,
                              initialVendorName: companyName,
                              initialSuggestedTitle: brandsList.isNotEmpty
                                  ? '${brandsList.first} '
                                  : '',
                              initialSuggestedUrl: sampleCatalogUrl.isNotEmpty
                                  ? sampleCatalogUrl
                                  : websiteUrl,
                              initialCategoryCode: firstStoreCategory,
                              initialSuggestionNotes: catalogNotes,
                            ),
                            icon: const Icon(Icons.add_link_rounded, size: 17),
                            label: const Text('+ Add Brand Product'),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                _reviewApplication(id, 'waitlisted'),
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
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRolesTab() {
    final activeStaff =
        _staff.where((s) => s['active'] == true).toList(growable: false);

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
                  roleTitle:
                      'Affiliate Product Contributor (affiliate_contributor)',
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

  Widget _buildSuggestionsTab() {
    final pendingCount = _suggestions.where((s) => s.isPending).length;
    final addedCount = _suggestions.where((s) => s.status == 'added').length;
    final dismissedCount =
        _suggestions.where((s) => s.status == 'dismissed').length;

    final filtered = _suggestions.where((s) {
      if (_suggestionStatusFilter == 'pending') return s.isPending;
      if (_suggestionStatusFilter == 'added') return s.status == 'added';
      if (_suggestionStatusFilter == 'dismissed') {
        return s.status == 'dismissed';
      }
      return true;
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: PipeBuyerColors.orange,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Shopper Product Suggestions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: _reloadDashboard,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Public visitors who click "Know a helpful product not listed? Let us know!" on the Storefront submit item requests here. Click "Find & Add to Store" to auto-search Amazon SKUs or parse their link with your Associate tag.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: PipeBuyerColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('All (${_suggestions.length})'),
                      selected: _suggestionStatusFilter == 'all',
                      onSelected: (_) =>
                          setState(() => _suggestionStatusFilter = 'all'),
                    ),
                    ChoiceChip(
                      label: Text('Pending ($pendingCount)'),
                      selected: _suggestionStatusFilter == 'pending',
                      onSelected: (_) =>
                          setState(() => _suggestionStatusFilter = 'pending'),
                    ),
                    ChoiceChip(
                      label: Text('Added ($addedCount)'),
                      selected: _suggestionStatusFilter == 'added',
                      onSelected: (_) =>
                          setState(() => _suggestionStatusFilter = 'added'),
                    ),
                    ChoiceChip(
                      label: Text('Dismissed ($dismissedCount)'),
                      selected: _suggestionStatusFilter == 'dismissed',
                      onSelected: (_) =>
                          setState(() => _suggestionStatusFilter = 'dismissed'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No shopper product suggestions in this view yet.',
                  style: TextStyle(color: PipeBuyerColors.muted),
                ),
              ),
            ),
          )
        else
          ...filtered.map((s) {
            final cat = PipeBuyerShopTaxonomy.categoryByCode(s.categoryCode);
            final statusColor = switch (s.status) {
              'added' => PipeBuyerColors.success,
              'dismissed' => PipeBuyerColors.muted,
              _ => PipeBuyerColors.orange,
            };
            final statusLabel = switch (s.status) {
              'added' => 'ADDED TO STORE',
              'dismissed' => 'DISMISSED',
              _ => 'PENDING REVIEW',
            };
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (cat != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: PipeBuyerColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              cat.shortLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (s.submitterName.isNotEmpty ||
                            s.contactEmail.isNotEmpty)
                          Text(
                            'Suggested by ${s.submitterName.isNotEmpty ? s.submitterName : s.contactEmail}${s.submitterName.isNotEmpty && s.contactEmail.isNotEmpty ? " (${s.contactEmail})" : ""}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: PipeBuyerColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.productName,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (s.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        s.notes,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PipeBuyerColors.slate,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (s.productUrl.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap:
                            PipeBuyerShopUrlBuilder.isSafeHttpsUrl(s.productUrl)
                                ? () => launchUrl(
                                      Uri.parse(s.productUrl),
                                      mode: LaunchMode.externalApplication,
                                    )
                                : null,
                        child: Text(
                          s.productUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: PipeBuyerColors.industrialBlue,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: Key('suggestion_add_${s.id}'),
                          onPressed: () => _convertSuggestionToProduct(s),
                          icon: const Icon(Icons.add_link_rounded, size: 17),
                          label: const Text('Find & Add to Store'),
                        ),
                        if (s.status != 'dismissed')
                          OutlinedButton.icon(
                            key: Key('suggestion_dismiss_${s.id}'),
                            onPressed: () =>
                                _updateSuggestionStatus(s, 'dismissed'),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Dismiss'),
                          ),
                        if (s.status != 'pending')
                          TextButton(
                            onPressed: () =>
                                _updateSuggestionStatus(s, 'pending'),
                            child: const Text('Reopen'),
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
                style: DefaultTextStyle.of(context)
                    .style
                    .copyWith(fontSize: 12.5, height: 1.35),
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

class _AffiliateQuickLaunchSpec {
  const _AffiliateQuickLaunchSpec({
    required this.title,
    required this.regions,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.sourceType,
    required this.vendorName,
  });

  final String title;
  final String regions;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final PipeBuyerShopSourceType sourceType;
  final String vendorName;
}

class _AdminCatalogProductCard extends StatelessWidget {
  const _AdminCatalogProductCard({
    required this.item,
    required this.isLiveCustom,
    required this.onTestLink,
    required this.onToggleFeatured,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final PipeBuyerShopProduct item;
  final bool isLiveCustom;
  final VoidCallback onTestLink;
  final VoidCallback onToggleFeatured;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final active = item.status == 'active';
    final hasPhoto = item.imageUrl.trim().isNotEmpty;
    final lowerUrl = item.destinationUrl.toLowerCase();
    final isSearchUrl =
        lowerUrl.contains('/s?k=') || lowerUrl.contains('ar_mt=search_page');
    final countries = item.effectiveEligibleCountries;
    final isRestrictedNonNorthAmerica = !countries.contains('GLOBAL') &&
        !countries.contains('US') &&
        !countries.contains('CA');

    final fallbackThumb = Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
            child: SvgPicture.asset(
              item.effectiveIconAsset,
              fit: BoxFit.contain,
              placeholderBuilder: (_) => Icon(
                item.category.icon,
                size: 32,
                color: item.category.accentColor,
              ),
            ),
          ),
        ),
        Positioned(
          left: 4,
          right: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: PipeBuyerColors.ink.withValues(alpha: .78),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'NO PHOTO',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLiveCustom
              ? PipeBuyerColors.industrialBlue.withValues(alpha: .32)
              : PipeBuyerColors.line,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 14,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onTestLink,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PipeBuyerColors.line),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasPhoto
                          ? CachedNetworkImage(
                              imageUrl: item.imageUrl.trim(),
                              fit: BoxFit.contain,
                              placeholder: (_, __) => fallbackThumb,
                              errorWidget: (_, __, ___) => fallbackThumb,
                            )
                          : fallbackThumb,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _SmallStatusPill(
                              label: active ? 'LIVE' : 'PAUSED',
                              bg: active
                                  ? const Color(0xFFDCFCE7)
                                  : PipeBuyerColors.surfaceMuted,
                              fg: active
                                  ? const Color(0xFF166534)
                                  : PipeBuyerColors.muted,
                            ),
                            _SmallStatusPill(
                              label: isLiveCustom
                                  ? 'YOUR LIVE LINK'
                                  : 'DEMO TEMPLATE',
                              bg: isLiveCustom
                                  ? PipeBuyerColors.industrialBlue.withValues(
                                      alpha: .12,
                                    )
                                  : const Color(0xFFFEF3C7),
                              fg: isLiveCustom
                                  ? PipeBuyerColors.industrialBlue
                                  : const Color(0xFF92400E),
                            ),
                            _SmallStatusPill(
                              label: item.sourceType.label,
                              bg: PipeBuyerColors.orangeSoft,
                              fg: PipeBuyerColors.orangePressed,
                            ),
                            _SmallStatusPill(
                              label: item.shippingSummaryLabel,
                              bg: isRestrictedNonNorthAmerica
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFE0F2FE),
                              fg: isRestrictedNonNorthAmerica
                                  ? const Color(0xFF92400E)
                                  : const Color(0xFF0369A1),
                            ),
                            if (isSearchUrl)
                              const _SmallStatusPill(
                                label: 'Search URL (Not Direct SKU)',
                                bg: Color(0xFFF1F5F9),
                                fg: PipeBuyerColors.slate,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: onTestLink,
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.brand} • ${item.category.shortLabel}${item.subcategory.isNotEmpty ? ' › ${item.subcategory}' : ''}${item.priceDisplay.isNotEmpty ? ' • ${item.priceDisplay}' : ''} • Clicks: ${item.clickCount}${item.asin.isNotEmpty ? ' • ASIN: ${item.asin}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: PipeBuyerColors.slate,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: onTestLink,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.open_in_new_rounded,
                                size: 13,
                                color: PipeBuyerColors.industrialBlue,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  item.destinationHost.isNotEmpty
                                      ? '${item.destinationHost} — ${item.destinationUrl}'
                                      : item.destinationUrl,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: PipeBuyerColors.industrialBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onTestLink,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text(
                    'Test Buy Link',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: item.featured
                      ? 'Featured on Home & Top of Store'
                      : 'Mark as Featured',
                  onPressed: onToggleFeatured,
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
                  onChanged: onToggleActive,
                ),
                IconButton(
                  tooltip: 'Edit Affiliate Link',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Remove Affiliate Link',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: PipeBuyerColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallStatusPill extends StatelessWidget {
  const _SmallStatusPill({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: fg),
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
    this.initialSourceType,
    this.initialVendorName,
    this.initialSuggestedTitle,
    this.initialSuggestedUrl,
    this.initialCategoryCode,
    this.initialSuggestionNotes,
  });

  final PipeBuyerShopClient client;
  final PipeBuyerShopSettings settings;
  final PipeBuyerShopProduct? existing;
  final PipeBuyerShopSourceType? initialSourceType;
  final String? initialVendorName;
  final String? initialSuggestedTitle;
  final String? initialSuggestedUrl;
  final String? initialCategoryCode;
  final String? initialSuggestionNotes;

  @override
  State<PipeBuyerAffiliateLinkEditorDialog> createState() =>
      _PipeBuyerAffiliateLinkEditorDialogState();
}

class _PipeBuyerAffiliateLinkEditorDialogState
    extends State<PipeBuyerAffiliateLinkEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quickPasteController;
  late final TextEditingController _amazonSearchController;
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
  late List<String> _eligibleCountries;
  late bool _featured;
  bool _saving = false;
  bool _fetchingMetadata = false;
  bool _searchingAmazon = false;
  String _amazonSearchEmptyNote = '';
  List<PipeBuyerAmazonSearchCandidate> _searchCandidates =
      const <PipeBuyerAmazonSearchCandidate>[];
  Timer? _metadataDebounce;
  PipeBuyerParsedAffiliateSubmission? _parsedPreview;

  static const List<(PipeBuyerShopSourceType, String, String)>
      _platformPresets = <(PipeBuyerShopSourceType, String, String)>[
    (
      PipeBuyerShopSourceType.amazonAffiliate,
      'Amazon',
      'Paste Amazon SiteStripe link (amzn.to / link.amazon), product URL (/dp/...), share text, or 10-char ASIN.',
    ),
    (
      PipeBuyerShopSourceType.aliexpressAffiliate,
      'AliExpress',
      'Paste AliExpress Portals shortlink (s.click.aliexpress.com) or aliexpress.com/item/... URL (ships worldwide).',
    ),
    (
      PipeBuyerShopSourceType.lazadaAffiliate,
      'Lazada',
      'Paste Lazada LazAffiliate link (s.lazada.com.ph / .sg / .com.my) or Lazada item URL — country auto-detects.',
    ),
    (
      PipeBuyerShopSourceType.shopeeAffiliate,
      'Shopee',
      'Paste Shopee Affiliate link (shope.ee / s.shopee.ph) or Shopee item URL — orderable country auto-detects.',
    ),
    (
      PipeBuyerShopSourceType.affiliateNetwork,
      'Involve Asia',
      'Paste Involve Asia (invol.co), Impact, CJ, ShareASale, Awin, or Rakuten tracking link.',
    ),
    (
      PipeBuyerShopSourceType.ebayPartner,
      'eBay',
      'Paste eBay Partner Network shortlink (ebay.us) or ebay.com/itm/... product URL.',
    ),
    (
      PipeBuyerShopSourceType.hardwareProRetail,
      'VEVOR / Retail',
      'Paste VEVOR, Home Depot, Tractor Supply, Northern Tool, Harbor Freight, or Grainger affiliate link.',
    ),
    (
      PipeBuyerShopSourceType.temuAffiliate,
      'Temu',
      'Paste Temu Affiliate link (temu.to or temu.com) — global workshop & tool deals.',
    ),
    (
      PipeBuyerShopSourceType.tiktokShopAffiliate,
      'TikTok Shop',
      'Paste TikTok Shop product or showcase link (vt.tiktok.com / tiktok.com).',
    ),
    (
      PipeBuyerShopSourceType.alibabaB2b,
      'Alibaba B2B',
      'Paste Alibaba or DHgate wholesale pipe, valve, flange, or machinery affiliate link.',
    ),
  ];

  String _defaultSubcategoryFor(String categoryCode) {
    final subs = PipeBuyerShopTaxonomy.subcategoriesForCategory(categoryCode);
    return subs.isNotEmpty ? subs.first : '';
  }

  String _defaultVendorForSource(PipeBuyerShopSourceType source) {
    return switch (source) {
      PipeBuyerShopSourceType.amazonAffiliate => 'Amazon',
      PipeBuyerShopSourceType.aliexpressAffiliate => 'AliExpress',
      PipeBuyerShopSourceType.lazadaAffiliate => 'Lazada',
      PipeBuyerShopSourceType.shopeeAffiliate => 'Shopee',
      PipeBuyerShopSourceType.ebayPartner => 'eBay',
      PipeBuyerShopSourceType.walmartAffiliate => 'Walmart',
      PipeBuyerShopSourceType.temuAffiliate => 'Temu',
      PipeBuyerShopSourceType.tiktokShopAffiliate => 'TikTok Shop',
      PipeBuyerShopSourceType.alibabaB2b => 'Alibaba',
      PipeBuyerShopSourceType.hardwareProRetail => 'VEVOR',
      PipeBuyerShopSourceType.affiliateNetwork => 'Involve Asia Partner',
      _ => 'Partner Store',
    };
  }

  List<String> _defaultCountriesForSource(PipeBuyerShopSourceType source) {
    return PipeBuyerShopUrlBuilder.inferEligibleCountries(
      '',
      sourceType: source,
    );
  }

  String get _activePlatformHelperText {
    for (final preset in _platformPresets) {
      if (preset.$1 == _sourceType) return preset.$3;
    }
    return 'Paste any HTTPS affiliate link or partner product URL — photo, title, and orderable countries auto-fill.';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final initialSource = e?.sourceType ??
        widget.initialSourceType ??
        PipeBuyerShopSourceType.amazonAffiliate;
    final initialVendor = e?.vendorName ??
        widget.initialVendorName ??
        _defaultVendorForSource(initialSource);

    final suggestedTitle = (widget.initialSuggestedTitle ?? '').trim();
    final suggestedUrl = (widget.initialSuggestedUrl ?? '').trim();
    final suggestedNotes = (widget.initialSuggestionNotes ?? '').trim();
    final validInitialCat = widget.initialCategoryCode != null &&
            PipeBuyerShopTaxonomy.categoryByCode(widget.initialCategoryCode!) !=
                null
        ? widget.initialCategoryCode!
        : 'power_hand_tools';

    _quickPasteController = TextEditingController(
      text: e?.destinationUrl ?? suggestedUrl,
    );
    _amazonSearchController = TextEditingController(
      text: (e != null &&
              e.sourceType == PipeBuyerShopSourceType.amazonAffiliate &&
              e.asin.isEmpty)
          ? e.title
          : (e == null ? suggestedTitle : ''),
    );
    _titleController = TextEditingController(text: e?.title ?? suggestedTitle);
    _brandController = TextEditingController(text: e?.brand ?? '');
    _vendorController = TextEditingController(text: initialVendor);
    _asinController = TextEditingController(text: e?.asin ?? '');
    _urlController = TextEditingController(
      text: e?.destinationUrl ?? suggestedUrl,
    );
    _imageUrlController = TextEditingController(text: e?.imageUrl ?? '');
    _priceController = TextEditingController(text: e?.priceDisplay ?? '');
    _badgeController = TextEditingController(text: e?.badgeText ?? '');
    _descriptionController = TextEditingController(
      text: e?.description ?? suggestedNotes,
    );
    _highlightsController = TextEditingController(
      text: e?.highlights.join('\n') ?? '',
    );
    _categoryCode = e?.categoryCode ?? validInitialCat;
    _subcategory = (e?.subcategory.trim().isNotEmpty ?? false)
        ? e!.subcategory.trim()
        : _defaultSubcategoryFor(_categoryCode);
    _sourceType = initialSource;
    _eligibleCountries = e != null
        ? List<String>.from(e.effectiveEligibleCountries)
        : List<String>.from(_defaultCountriesForSource(initialSource));
    _featured = e?.featured ?? false;
    if (_urlController.text.isNotEmpty) {
      _parsedPreview = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
        _urlController.text,
        widget.settings,
      );
    }
    if (e == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (suggestedUrl.isNotEmpty) {
          _applySmartPaste(suggestedUrl);
        } else if (suggestedTitle.length >= 2 &&
            _sourceType == PipeBuyerShopSourceType.amazonAffiliate) {
          _runAmazonProductSearch(suggestedTitle);
        }
      });
    }
  }

  @override
  void dispose() {
    _metadataDebounce?.cancel();
    _quickPasteController.dispose();
    _amazonSearchController.dispose();
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

  void _selectPlatformPreset(
    PipeBuyerShopSourceType source,
    String vendorLabel,
  ) {
    setState(() {
      _sourceType = source;
      if (_urlController.text.trim().isEmpty) {
        _vendorController.text = _defaultVendorForSource(source);
        _eligibleCountries = List<String>.from(
          _defaultCountriesForSource(source),
        );
      }
    });
  }

  void _toggleEligibleCountry(String code) {
    final upper = code.trim().toUpperCase();
    setState(() {
      if (upper == 'GLOBAL') {
        _eligibleCountries = <String>['GLOBAL'];
        return;
      }
      final next = _eligibleCountries.where((c) => c != 'GLOBAL').toSet();
      if (next.contains(upper)) {
        next.remove(upper);
      } else {
        next.add(upper);
      }
      _eligibleCountries =
          next.isEmpty ? <String>['GLOBAL'] : next.toList(growable: false);
    });
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
      if (parsed.eligibleCountries.isNotEmpty) {
        _eligibleCountries = List<String>.from(parsed.eligibleCountries);
      }

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
        final validSubs = PipeBuyerShopTaxonomy.subcategoriesForCategory(
          _categoryCode,
        );
        if (parsed.suggestedSubcategory.isNotEmpty &&
            validSubs.contains(parsed.suggestedSubcategory)) {
          _subcategory = parsed.suggestedSubcategory;
        } else if (!validSubs.contains(_subcategory)) {
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

    if (parsed != null) {
      _scheduleRemoteMetadataFetch(raw);
    }
  }

  void _scheduleRemoteMetadataFetch(String raw) {
    _metadataDebounce?.cancel();
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    _metadataDebounce = Timer(const Duration(milliseconds: 380), () {
      _fetchLiveMetadata(trimmed);
    });
  }

  Future<void> _fetchLiveMetadata([String? rawOverride]) async {
    final target = (rawOverride ??
            (_quickPasteController.text.trim().isNotEmpty
                ? _quickPasteController.text.trim()
                : _urlController.text.trim()))
        .trim();
    if (target.isEmpty || !mounted) return;
    setState(() => _fetchingMetadata = true);
    final remote = await widget.client.fetchRemoteAffiliatePreview(target);
    if (!mounted) return;
    setState(() {
      _fetchingMetadata = false;
      if (remote == null) return;
      _parsedPreview = remote;

      if (remote.canonicalProductUrl.isNotEmpty &&
          (_urlController.text.trim().isEmpty ||
              remote.isShortLink ||
              _urlController.text.toLowerCase().contains('/s?k=') ||
              _urlController.text.toLowerCase().contains('ar_mt=search_page') ||
              _urlController.text.toLowerCase().contains('link.amazon'))) {
        _urlController.text = remote.canonicalProductUrl;
      } else if (remote.destinationUrl.isNotEmpty &&
          _urlController.text.trim().isEmpty) {
        _urlController.text = remote.destinationUrl;
      }
      if (remote.searchCandidates.isNotEmpty) {
        _searchCandidates = remote.searchCandidates;
        _amazonSearchEmptyNote = '';
      }
      _sourceType = remote.sourceType;
      if (remote.suggestedVendorName.isNotEmpty) {
        _vendorController.text = remote.suggestedVendorName;
      }
      if (remote.asin.isNotEmpty) {
        _asinController.text = remote.asin;
      }
      if (remote.imageUrl.isNotEmpty &&
          _imageUrlController.text.trim().isEmpty) {
        _imageUrlController.text = remote.imageUrl;
      }
      final currentTitle = _titleController.text.trim();
      final looksPlaceholderTitle = currentTitle.isEmpty ||
          currentTitle.contains('Product Selection') ||
          currentTitle.startsWith('Amazon Item ');
      if (remote.suggestedTitle.isNotEmpty && looksPlaceholderTitle) {
        _titleController.text = remote.suggestedTitle;
      }
      final currentBrand = _brandController.text.trim();
      if (remote.suggestedBrand.isNotEmpty &&
          (currentBrand.isEmpty ||
              currentBrand == 'Industrial Select' ||
              currentBrand == 'Partner Brand')) {
        _brandController.text = remote.suggestedBrand;
      }
      if (remote.suggestedPriceDisplay.isNotEmpty &&
          _priceController.text.trim().isEmpty) {
        _priceController.text = remote.suggestedPriceDisplay;
      }
      if (widget.existing == null && remote.suggestedCategoryCode.isNotEmpty) {
        _categoryCode = remote.suggestedCategoryCode;
        final validSubs = PipeBuyerShopTaxonomy.subcategoriesForCategory(
          _categoryCode,
        );
        if (remote.suggestedSubcategory.isNotEmpty &&
            validSubs.contains(remote.suggestedSubcategory)) {
          _subcategory = remote.suggestedSubcategory;
        } else if (!validSubs.contains(_subcategory)) {
          _subcategory = _defaultSubcategoryFor(_categoryCode);
        }
      }
      if (remote.suggestedHighlights.isNotEmpty &&
          _highlightsController.text.trim().isEmpty) {
        _highlightsController.text = remote.suggestedHighlights.join('\n');
      }
      if (remote.eligibleCountries.isNotEmpty) {
        _eligibleCountries = List<String>.from(remote.eligibleCountries);
      }
      if (_descriptionController.text.trim().isEmpty &&
          _titleController.text.trim().isNotEmpty) {
        final cat = PipeBuyerShopTaxonomy.categoryByCode(_categoryCode);
        _descriptionController.text =
            'Field-proven ${cat?.shortLabel.toLowerCase() ?? "industrial"} gear selected for Pipe Buyer contractors, fabricators, and field crews.';
      }
    });
  }

  Future<void> _runAmazonProductSearch([String? queryOverride]) async {
    final query = (queryOverride ?? _amazonSearchController.text).trim();
    if (query.length < 2 || !mounted) {
      PipeFeedback.show(
        context,
        message: 'Enter a tool name, brand, or model number to search Amazon.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    setState(() {
      _searchingAmazon = true;
      _amazonSearchEmptyNote = '';
    });
    final results = await widget.client.searchAmazonAffiliateProducts(
      query,
      settings: widget.settings,
    );
    if (!mounted) return;
    setState(() {
      _searchingAmazon = false;
      _searchCandidates = results;
      _amazonSearchEmptyNote = results.isEmpty
          ? 'No direct Amazon SKU matched "$query". Try a model number (e.g., RIDGID 31110 or Milwaukee 2767-20) or paste the /dp/ product URL directly.'
          : '';
    });
  }

  void _selectAmazonCandidate(PipeBuyerAmazonSearchCandidate candidate) {
    final baseUrl = candidate.destinationUrl.trim().isNotEmpty
        ? candidate.destinationUrl.trim()
        : 'https://www.amazon.com/dp/${candidate.asin}?linkCode=ll1';
    final draft = PipeBuyerShopProduct(
      id: widget.existing?.id ?? 'draft_candidate',
      title: candidate.title,
      brand: candidate.brand,
      vendorName: 'Amazon',
      sourceType: PipeBuyerShopSourceType.amazonAffiliate,
      categoryCode: candidate.categoryCode,
      subcategory: candidate.subcategory,
      asin: candidate.asin,
      destinationUrl: baseUrl,
      imageUrl: candidate.imageUrl,
      priceDisplay: candidate.priceDisplay,
      eligibleCountries: const <String>['US', 'CA'],
    );
    final monetizedUrl = PipeBuyerShopUrlBuilder.buildMonetizedUrl(
      draft,
      widget.settings,
      regionCode: 'US',
    );
    final finalUrl = monetizedUrl.isNotEmpty ? monetizedUrl : baseUrl;
    final parsed = PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
      finalUrl,
      widget.settings,
    );

    setState(() {
      _sourceType = PipeBuyerShopSourceType.amazonAffiliate;
      _vendorController.text = 'Amazon';
      _asinController.text = candidate.asin;
      _urlController.text = finalUrl;
      _quickPasteController.text = finalUrl;
      if (candidate.imageUrl.isNotEmpty) {
        _imageUrlController.text = candidate.imageUrl;
      }
      if (candidate.title.isNotEmpty) {
        _titleController.text = candidate.title;
      }
      if (candidate.brand.isNotEmpty) {
        _brandController.text = candidate.brand;
      }
      if (candidate.priceDisplay.isNotEmpty) {
        _priceController.text = candidate.priceDisplay;
      }
      _categoryCode = candidate.categoryCode;
      final validSubs = PipeBuyerShopTaxonomy.subcategoriesForCategory(
        _categoryCode,
      );
      _subcategory = validSubs.contains(candidate.subcategory)
          ? candidate.subcategory
          : _defaultSubcategoryFor(_categoryCode);
      _eligibleCountries = const <String>['US', 'CA'];
      _parsedPreview = parsed;
      _searchCandidates = const <PipeBuyerAmazonSearchCandidate>[];
      _amazonSearchEmptyNote = '';
      if (_descriptionController.text.trim().isEmpty &&
          _titleController.text.trim().isNotEmpty) {
        final cat = PipeBuyerShopTaxonomy.categoryByCode(_categoryCode);
        _descriptionController.text =
            'Field-proven ${cat?.shortLabel.toLowerCase() ?? "industrial"} gear selected for Pipe Buyer contractors, fabricators, and field crews.';
      }
    });
    _scheduleRemoteMetadataFetch(finalUrl);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    _quickPasteController.text = text;
    _applySmartPaste(text);
  }

  Future<void> _pasteImageFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    setState(() {
      _imageUrlController.text = text;
    });
  }

  Future<void> _testDraftLink() async {
    final url = _urlController.text.trim().isNotEmpty
        ? _urlController.text.trim()
        : (_asinController.text.trim().length == 10
            ? 'https://www.amazon.com/dp/${_asinController.text.trim()}'
            : '');
    if (url.isEmpty) {
      PipeFeedback.show(
        context,
        message: 'Paste an affiliate link first to test it.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    final draft = PipeBuyerShopProduct(
      id: widget.existing?.id ?? 'draft_preview',
      title: _titleController.text.trim().isEmpty
          ? 'Preview Item'
          : _titleController.text.trim(),
      brand: _brandController.text.trim().isEmpty
          ? 'Industrial Select'
          : _brandController.text.trim(),
      vendorName: _vendorController.text.trim(),
      sourceType: _sourceType,
      categoryCode: _categoryCode,
      destinationUrl: url,
      asin: _asinController.text.trim(),
      eligibleCountries: _eligibleCountries,
    );
    final opened = await widget.client.openProductAffiliateLink(
      product: draft,
      settings: widget.settings,
      regionCode: 'US',
      placement: 'editor_test',
    );
    if (!mounted) return;
    if (!opened) {
      PipeFeedback.show(
        context,
        message: 'Could not open preview URL ($url).',
        tone: PipeStatusTone.warning,
      );
    }
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
        'eligibleCountries': _eligibleCountries,
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
    final imagePreviewUrl = _imageUrlController.text.trim();
    final isWorldwide =
        _eligibleCountries.isEmpty || _eligibleCountries.contains('GLOBAL');
    final isNonNorthAmericaOnly = !isWorldwide &&
        !_eligibleCountries.contains('US') &&
        !_eligibleCountries.contains('CA');

    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Add Multi-Platform Affiliate Product'
            : 'Edit Store Affiliate Product',
      ),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // STEP 1: Platform Quick Selector & 1-Step Link Paste
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: PipeBuyerColors.orange.withValues(alpha: .35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                color: PipeBuyerColors.orangePressed,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                '1. Choose Platform & Paste Affiliate Link',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: _pasteFromClipboard,
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(
                                  Icons.content_paste_rounded,
                                  size: 15,
                                ),
                                label: const Text(
                                  'Paste Clipboard',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _fetchingMetadata
                                    ? null
                                    : () => _fetchLiveMetadata(),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.white,
                                ),
                                icon: _fetchingMetadata
                                    ? const SizedBox(
                                        width: 13,
                                        height: 13,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.auto_fix_high_rounded,
                                        size: 15,
                                      ),
                                label: Text(
                                  _fetchingMetadata
                                      ? 'Fetching Photo...'
                                      : 'Auto-Fill Photo & Info',
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _platformPresets.map((preset) {
                          final selected = _sourceType == preset.$1;
                          return ChoiceChip(
                            label: Text(
                              preset.$2,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                              ),
                            ),
                            selected: selected,
                            selectedColor: PipeBuyerColors.orangeSoft,
                            backgroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) =>
                                _selectPlatformPreset(preset.$1, preset.$2),
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _activePlatformHelperText,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: PipeBuyerColors.slate,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('affiliate_quick_paste_field'),
                        controller: _quickPasteController,
                        decoration: const InputDecoration(
                          labelText:
                              'Paste Affiliate Link, Shortlink, Share Text, or ASIN',
                          hintText:
                              'https://amzn.to/... • https://s.click.aliexpress.com/... • https://shope.ee/... • https://s.lazada...',
                          prefixIcon: Icon(Icons.add_link_rounded),
                          fillColor: Colors.white,
                        ),
                        onChanged: _applySmartPaste,
                      ),
                      if (_sourceType ==
                          PipeBuyerShopSourceType.amazonAffiliate) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: PipeBuyerColors.industrialBlue.withValues(
                                alpha: .28,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.manage_search_rounded,
                                    size: 17,
                                    color: PipeBuyerColors.industrialBlue,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'SiteStripe Product Finder (Auto-Build Direct /dp/ Link + Photo w/ Tag ${widget.settings.amazonAssociateTagUs.isNotEmpty ? widget.settings.amazonAssociateTagUs : "pipebuyer-20"})',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: PipeBuyerColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      key: const Key(
                                        'amazon_product_finder_field',
                                      ),
                                      controller: _amazonSearchController,
                                      textInputAction: TextInputAction.search,
                                      onSubmitted: _runAmazonProductSearch,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText:
                                            'Search Amazon by Tool Name, Brand, or Model #',
                                        hintText:
                                            'e.g., RIDGID 31110 36 pipe wrench, Milwaukee 2767-20, Lincoln Viking 3350',
                                        prefixIcon: Icon(
                                          Icons.search_rounded,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.tonalIcon(
                                    key: const Key(
                                      'amazon_product_finder_button',
                                    ),
                                    onPressed: _searchingAmazon
                                        ? null
                                        : () => _runAmazonProductSearch(),
                                    icon: _searchingAmazon
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.travel_explore_rounded,
                                            size: 16,
                                          ),
                                    label: Text(
                                      _searchingAmazon
                                          ? 'Searching...'
                                          : 'Find SKU',
                                    ),
                                  ),
                                ],
                              ),
                              if (_amazonSearchEmptyNote.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _amazonSearchEmptyNote,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: PipeBuyerColors.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (preview != null &&
                          (preview.isSearchPageLink ||
                              preview.complianceWarnings.isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: PipeBuyerColors.warning.withValues(
                                alpha: .45,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 17,
                                color: PipeBuyerColors.warning,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  preview.complianceWarnings.isNotEmpty
                                      ? preview.complianceWarnings.first
                                      : 'Amazon search URL detected (/s?k=...). Select the exact product SKU below so buyers open the real product page instead of competitor search ads.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: PipeBuyerColors.ink,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_searchCandidates.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Matching Amazon SKUs — Click "Select SKU" to Auto-Fill Direct Link, Photo & Category:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: PipeBuyerColors.industrialBlue,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ..._searchCandidates.map((cand) {
                          final catObj = PipeBuyerShopTaxonomy.categoryByCode(
                            cand.categoryCode,
                          );
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: PipeBuyerColors.line),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: PipeBuyerColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: cand.imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: cand.imageUrl,
                                          fit: BoxFit.contain,
                                          placeholder: (_, __) => const Icon(
                                            Icons.image_outlined,
                                            size: 20,
                                            color: PipeBuyerColors.muted,
                                          ),
                                          errorWidget: (_, __, ___) =>
                                              const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 20,
                                            color: PipeBuyerColors.muted,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.inventory_2_outlined,
                                          size: 20,
                                          color: PipeBuyerColors.muted,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cand.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'ASIN: ${cand.asin}${cand.priceDisplay.isNotEmpty ? " • ${cand.priceDisplay}" : ""} • ${catObj?.shortLabel ?? cand.categoryCode}${cand.subcategory.isNotEmpty ? " › ${cand.subcategory}" : ""}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: PipeBuyerColors.muted,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonalIcon(
                                  onPressed: () => _selectAmazonCandidate(cand),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'Select SKU',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
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
                            if (preview.isSearchPageLink)
                              const _ComplianceBadge(
                                ok: false,
                                label: 'Search URL — Pick Direct SKU',
                              ),
                            _ComplianceBadge(
                              ok: !isNonNorthAmericaOnly,
                              label: isWorldwide
                                  ? 'Ships: Worldwide'
                                  : 'Ships: ${_eligibleCountries.join(", ")}',
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // STEP 2: Visual Product Photo Preview & Core Product Details
                const Text(
                  '2. Product Photo & Storefront Card Details',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PipeBuyerColors.line),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: imagePreviewUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imagePreviewUrl,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  color: PipeBuyerColors.muted,
                                ),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: PipeBuyerColors.muted,
                                ),
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: PipeBuyerColors.muted,
                                  size: 28,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Photo Preview',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: PipeBuyerColors.muted,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _imageUrlController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Product Photo HTTPS URL',
                              hintText:
                                  'Auto-filled from product link, or paste image address',
                              suffixIcon: IconButton(
                                tooltip: 'Paste Image URL from Clipboard',
                                onPressed: _pasteImageFromClipboard,
                                icon: const Icon(
                                  Icons.content_paste_rounded,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tip: Product photos load automatically for most links. If a site blocks bots, right-click the product photo -> "Copy image address" and click paste.',
                            style: TextStyle(
                              fontSize: 11,
                              color: PipeBuyerColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Product Title *',
                  ),
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
                          labelText: 'Brand (e.g., Milwaukee, RIDGID, INGCO)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _vendorController,
                        decoration: const InputDecoration(
                          labelText: 'Sold By / Platform',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _categoryCode,
                        decoration: const InputDecoration(
                          labelText: 'Store Category',
                        ),
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
                              final subs = PipeBuyerShopTaxonomy
                                  .subcategoriesForCategory(
                                v,
                              );
                              if (!subs.contains(_subcategory)) {
                                _subcategory = _defaultSubcategoryFor(v);
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final subs = <String>{
                            ...PipeBuyerShopTaxonomy.subcategoriesForCategory(
                              _categoryCode,
                            ),
                            if (_subcategory.trim().isNotEmpty)
                              _subcategory.trim(),
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
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: 'Destination Affiliate HTTPS URL *',
                          hintText: 'https://www.amazon.com/dp/B077H7JP1D',
                        ),
                        validator: (v) {
                          final trimmed = v?.trim() ?? '';
                          if (trimmed.isEmpty &&
                              _asinController.text.trim().length == 10) {
                            return null;
                          }
                          if (!PipeBuyerShopUrlBuilder.isSafeHttpsUrl(
                            trimmed,
                          )) {
                            return 'Enter a valid HTTPS affiliate or partner URL.';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          final parsed =
                              PipeBuyerShopUrlBuilder.parseAffiliateSubmission(
                            val,
                            widget.settings,
                          );
                          setState(() {
                            _parsedPreview = parsed;
                            if (parsed != null &&
                                parsed.eligibleCountries.isNotEmpty) {
                              _eligibleCountries = List<String>.from(
                                parsed.eligibleCountries,
                              );
                            }
                          });
                          if (parsed != null &&
                              parsed.asin.isNotEmpty &&
                              _asinController.text.isEmpty) {
                            _asinController.text = parsed.asin;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price Note (optional)',
                          hintText: 'e.g., USD 129.00',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // STEP 3: Smart Country / Orderable Region Geo-Filtering
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PipeBuyerColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.public_rounded,
                            size: 17,
                            color: PipeBuyerColors.industrialBlue,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '3. Orderable Countries (Smart Storefront Geo-Filter)',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Shoppers only see items that can actually be ordered in their selected country (for example, Lazada PH / Shopee PH items only appear for Philippines shoppers, while AliExpress items show worldwide).',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: PipeBuyerColors.muted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          FilterChip(
                            label: const Text(
                              '🌍 Worldwide (All Countries)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            selected: isWorldwide,
                            selectedColor: const Color(0xFFDCFCE7),
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => _toggleEligibleCountry('GLOBAL'),
                          ),
                          ...PipeBuyerShopTaxonomy.countryOptions
                              .where((c) => c.code != 'ALL')
                              .map((country) {
                            final selected = !isWorldwide &&
                                _eligibleCountries.contains(country.code);
                            return FilterChip(
                              label: Text(
                                '${country.flag} ${country.code}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                              tooltip: country.label,
                              selected: selected,
                              selectedColor: PipeBuyerColors.orangeSoft,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) =>
                                  _toggleEligibleCountry(country.code),
                            );
                          }),
                        ],
                      ),
                      if (isNonNorthAmericaOnly) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: PipeBuyerColors.warning.withValues(
                                alpha: .40,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: PipeBuyerColors.warning,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'Regional Store Detected (${_eligibleCountries.join(", ")}): This product will show for shoppers in ${_eligibleCountries.join(", ")} and stay automatically hidden for US & Canada shoppers who cannot check out on ${_vendorController.text}. For US/CA/Global buyers, add an Amazon or AliExpress link!',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: PipeBuyerColors.ink,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Feature on Home & Top of Store',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  value: _featured,
                  onChanged: (v) => setState(() => _featured = v),
                ),
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Optional Details (Channel Override, ASIN, Badge, Specs & Field Notes)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: PipeBuyerColors.industrialBlue,
                      ),
                    ),
                    children: [
                      const SizedBox(height: 6),
                      DropdownButtonFormField<PipeBuyerShopSourceType>(
                        key: ValueKey<String>('source_${_sourceType.code}'),
                        isExpanded: true,
                        initialValue: _sourceType,
                        decoration: const InputDecoration(
                          labelText: 'Partner Channel',
                        ),
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
                          labelText: 'Field Use Commentary (optional)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _highlightsController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Key Specs (optional, one per line)',
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
        OutlinedButton.icon(
          onPressed: _saving ? null : _testDraftLink,
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Test Buy Link'),
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
  const _ComplianceBadge({required this.ok, required this.label});

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
                          (msg) =>
                              Text(msg, style: const TextStyle(fontSize: 11.5)),
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

class _VendorApplicationReviewDialog extends StatefulWidget {
  const _VendorApplicationReviewDialog({
    required this.app,
    required this.initialDecision,
  });

  final Map<String, dynamic> app;
  final String initialDecision;

  @override
  State<_VendorApplicationReviewDialog> createState() =>
      _VendorApplicationReviewDialogState();
}

class _VendorApplicationReviewDialogState
    extends State<_VendorApplicationReviewDialog> {
  late final TextEditingController _notesController;
  late String _selectedDecision;
  bool _sendNotification = true;

  @override
  void initState() {
    super.initState();
    _selectedDecision = widget.initialDecision;
    _notesController = TextEditingController(
      text: widget.app['reviewNotes']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.app['companyName']?.toString() ?? 'Partner';
    final contact = widget.app['contactName']?.toString() ?? 'applicant';
    final email = widget.app['email']?.toString() ?? '';

    return AlertDialog(
      title: Text('Review $company'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedDecision,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Decision Status',
                  prefixIcon: Icon(Icons.fact_check_outlined),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: 'under_review',
                    child: Text('Under Admin Review'),
                  ),
                  DropdownMenuItem(
                    value: 'approved',
                    child: Text('Approved Partner'),
                  ),
                  DropdownMenuItem(
                    value: 'waitlisted',
                    child: Text('Waitlisted'),
                  ),
                  DropdownMenuItem(
                    value: 'declined',
                    child: Text('Declined'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedDecision = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message / Onboarding Notes to Partner',
                  hintText:
                      'e.g., Approved for Storefront & Heavy Equipment catalog onboarding. Reply with CSV/XML feed.',
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _sendNotification,
                onChanged: (val) =>
                    setState(() => _sendNotification = val ?? true),
                title: Text(
                  'Email & notify $contact ($email)',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop((
            decision: _selectedDecision,
            notes: _notesController.text.trim(),
            notifyApplicant: _sendNotification,
          )),
          icon: const Icon(Icons.send_rounded, size: 17),
          label: const Text('Save Decision'),
        ),
      ],
    );
  }
}
