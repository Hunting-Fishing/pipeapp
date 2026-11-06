import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_account_security_page.dart';
import 'pipebuyer_shop_admin_page.dart';
import 'pipebuyer_shop_client.dart';
import 'pipebuyer_shop_taxonomy.dart';
import 'pipebuyer_shop_vendor_apply_page.dart';

class PipeBuyerShopStorePage extends StatefulWidget {
  const PipeBuyerShopStorePage({
    super.key,
    this.client,
    this.sessionOverride,
    this.initialQuery = '',
    this.initialCategoryCode = '',
    this.initialBrand = '',
    this.initialSourceCode = '',
  });

  final PipeBuyerShopClient? client;
  final Future<PipeBuyerShopRoleSession> Function()? sessionOverride;
  final String initialQuery;
  final String initialCategoryCode;
  final String initialBrand;
  final String initialSourceCode;

  @override
  State<PipeBuyerShopStorePage> createState() => _PipeBuyerShopStorePageState();
}

class _PipeBuyerShopStorePageState extends State<PipeBuyerShopStorePage> {
  late PipeBuyerShopClient _client;
  late final TextEditingController _searchController;

  PipeBuyerShopSettings _settings = const PipeBuyerShopSettings();
  List<PipeBuyerShopProduct> _products =
      PipeBuyerShopClient.mergeWithStarterCatalog(
          const <PipeBuyerShopProduct>[]);
  List<Map<String, dynamic>> _approvedVendors = const <Map<String, dynamic>>[];
  Set<String> _savedIds = <String>{};

  late String _selectedCategoryCode;
  String _selectedSubcategory = '';
  late String _selectedBrand;
  PipeBuyerShopSourceType? _selectedSource;
  String _regionCode = 'US';
  String _sortBy = 'featured';
  bool _savedOnly = false;
  int _visibleLimit = 60;
  PipeBuyerShopRoleSession _roleSession =
      const PipeBuyerShopRoleSession.signedOut();
  bool _loadingLive = true;

  bool get _canManageLinks => _roleSession.canManageCatalog;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerShopClient();
    _searchController = TextEditingController(text: widget.initialQuery);
    _selectedCategoryCode =
        PipeBuyerShopTaxonomy.categoryByCode(widget.initialCategoryCode) != null
            ? widget.initialCategoryCode
            : '';
    _selectedBrand = widget.initialBrand.trim();
    if (widget.initialSourceCode.trim().isNotEmpty) {
      _selectedSource =
          PipeBuyerShopSourceType.fromCode(widget.initialSourceCode);
    }
    _hydrateStore();
  }

  @override
  void didUpdateWidget(covariant PipeBuyerShopStorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionOverride != widget.sessionOverride ||
        oldWidget.client != widget.client) {
      if (widget.client != null) {
        _client = widget.client!;
      }
      _hydrateStore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _hydrateStore() async {
    final savedFuture = _client.loadSavedProductIds();
    final regionFuture = _client.loadPreferredRegion();
    final catalogFuture = _client.loadStoreCatalog();
    Future<PipeBuyerShopRoleSession> sessionFuture =
        Future<PipeBuyerShopRoleSession>.value(
      const PipeBuyerShopRoleSession.signedOut(),
    );
    if (widget.sessionOverride != null) {
      sessionFuture = widget.sessionOverride!();
    } else if (Firebase.apps.isNotEmpty) {
      sessionFuture = _client
          .resolveShopRoleSession()
          .catchError((_) => const PipeBuyerShopRoleSession.signedOut());
    }

    final saved = await savedFuture;
    final region = await regionFuture;
    final snapshot = await catalogFuture;
    final roleSession = await sessionFuture;

    if (!mounted) return;
    setState(() {
      _savedIds = saved;
      _regionCode = region;
      _settings = snapshot.settings;
      _products = snapshot.products;
      _approvedVendors = snapshot.vendors;
      _roleSession = roleSession;
      _loadingLive = false;
    });
  }

  Future<void> _setRegion(String code) async {
    setState(() => _regionCode = code);
    await _client.savePreferredRegion(code);
  }

  Future<void> _toggleSave(PipeBuyerShopProduct product) async {
    final updated = await _client.toggleSavedProduct(product, _savedIds);
    if (!mounted) return;
    final savedNow = updated.contains(product.id);
    setState(() => _savedIds = updated);
    PipeFeedback.show(
      context,
      message: savedNow
          ? 'Saved "${product.title}" to your Shop list.'
          : 'Removed from your Saved Gear.',
      tone: PipeStatusTone.info,
    );
  }

  Future<void> _buyOrOpenPartner(
    PipeBuyerShopProduct product, {
    String placement = 'store_grid',
  }) async {
    final opened = await _client.openProductAffiliateLink(
      product: product,
      settings: _settings,
      regionCode: _regionCode,
      placement: placement,
    );
    if (!mounted) return;
    if (!opened) {
      PipeFeedback.show(
        context,
        message: 'Could not launch external partner link on this device.',
        tone: PipeStatusTone.warning,
      );
    }
  }

  Future<void> _openVendorApply({String initialBrand = ''}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PipeBuyerShopVendorApplyPage(
          client: _client,
          initialBrand: initialBrand,
        ),
      ),
    );
  }

  Future<void> _openAdminControl() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PipeBuyerShopAdminPage(
          client: _client,
          sessionOverride: widget.sessionOverride,
        ),
      ),
    );
    if (mounted) {
      await _hydrateStore();
    }
  }

  Future<void> _openMfaSecurity() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MarketplaceAccountSecurityPage(),
      ),
    );
    if (mounted) {
      await _hydrateStore();
    }
  }

  Future<void> _openInlineLinkEditor({PipeBuyerShopProduct? existing}) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => PipeBuyerAffiliateLinkEditorDialog(
        client: _client,
        settings: _settings,
        existing: existing,
      ),
    );
    if ((action == 'saved' || action == 'deleted') && mounted) {
      PipeFeedback.show(
        context,
        message: action == 'deleted'
            ? 'Affiliate link removed from the Store.'
            : existing == null
                ? 'Affiliate link added to the Store.'
                : 'Affiliate link updated.',
        tone: PipeStatusTone.success,
      );
      await _hydrateStore();
    }
  }

  Future<void> _confirmInlineRemove(PipeBuyerShopProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Affiliate Link?'),
        content: Text(
          'Remove "${product.title}" (${product.brand}) from the Pipe Buyer Store? '
          'Shoppers will immediately stop seeing this link.',
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
    );
    if (confirmed != true || !mounted) return;
    try {
      await _client.deleteProduct(
        productId: product.id,
        title: product.title,
      );
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'Removed "${product.title}" from the Store.',
        tone: PipeStatusTone.success,
      );
      await _hydrateStore();
    } catch (err) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'Failed to remove link: $err',
        tone: PipeStatusTone.error,
      );
    }
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategoryCode = '';
      _selectedSubcategory = '';
      _selectedBrand = '';
      _selectedSource = null;
      _savedOnly = false;
      _visibleLimit = 60;
    });
  }

  List<PipeBuyerShopProduct> get _productsMatchingNonCountryFilters {
    final query = _searchController.text.trim().toLowerCase();
    final terms =
        query.isEmpty ? const <String>[] : query.split(RegExp(r'\s+'));

    return _products.where((item) {
      if (item.status != 'active') return false;
      if (_savedOnly && !_savedIds.contains(item.id)) return false;
      if (_selectedCategoryCode.isNotEmpty &&
          item.categoryCode != _selectedCategoryCode) {
        return false;
      }
      if (_selectedSubcategory.isNotEmpty &&
          item.subcategory.toLowerCase() !=
              _selectedSubcategory.toLowerCase()) {
        return false;
      }
      if (_selectedSource != null && item.sourceType != _selectedSource) {
        return false;
      }
      if (_selectedBrand.isNotEmpty &&
          item.brand.toLowerCase() != _selectedBrand.toLowerCase()) {
        return false;
      }
      if (terms.isNotEmpty) {
        final haystack = [
          item.title,
          item.brand,
          item.vendorName,
          item.subcategory,
          item.description,
          item.category.label,
          ...item.highlights,
          ...item.tags,
        ].join(' ').toLowerCase();
        if (!terms.every(haystack.contains)) return false;
      }
      return true;
    }).toList(growable: false);
  }

  List<PipeBuyerShopProduct> get _filteredProducts {
    final matched = _productsMatchingNonCountryFilters
        .where((item) => item.shipsToCountry(_regionCode))
        .toList();

    switch (_sortBy) {
      case 'popular':
        matched.sort((a, b) {
          final clickCmp = b.clickCount.compareTo(a.clickCount);
          if (clickCmp != 0) return clickCmp;
          return a.priorityRank.compareTo(b.priorityRank);
        });
      case 'brand':
        matched.sort((a, b) {
          final brandCmp = a.brand.compareTo(b.brand);
          if (brandCmp != 0) return brandCmp;
          return a.title.compareTo(b.title);
        });
      case 'title':
        matched.sort((a, b) => a.title.compareTo(b.title));
      default:
        matched.sort((a, b) {
          if (a.featured != b.featured) return a.featured ? -1 : 1;
          final rankCmp = a.priorityRank.compareTo(b.priorityRank);
          if (rankCmp != 0) return rankCmp;
          return a.title.compareTo(b.title);
        });
    }
    return matched;
  }

  int get _hiddenByCountryCount {
    final withoutCountry = _productsMatchingNonCountryFilters;
    return withoutCountry
        .where((item) => !item.shipsToCountry(_regionCode))
        .length;
  }

  List<String> get _availableBrands {
    final counts = <String, int>{};
    for (final p in _products) {
      if (p.status != 'active' || !p.shipsToCountry(_regionCode)) continue;
      if (_selectedCategoryCode.isNotEmpty &&
          p.categoryCode != _selectedCategoryCode) {
        continue;
      }
      counts[p.brand] = (counts[p.brand] ?? 0) + 1;
    }
    final brands = counts.keys.toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    return brands.take(10).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final hasActiveFilters = _searchController.text.trim().isNotEmpty ||
        _selectedCategoryCode.isNotEmpty ||
        _selectedSubcategory.isNotEmpty ||
        _selectedBrand.isNotEmpty ||
        _selectedSource != null ||
        _savedOnly;

    return Scaffold(
      backgroundColor: PipeBuyerColors.canvas,
      appBar: AppBar(
        backgroundColor: PipeBuyerColors.ink,
        foregroundColor: Colors.white,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              color: PipeBuyerColors.orange,
              size: 21,
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Pipe Buyer Store',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_canManageLinks) ...[
            MediaQuery.sizeOf(context).width < 620
                ? IconButton(
                    tooltip: 'Add Affiliate Link',
                    onPressed: () => _openInlineLinkEditor(),
                    icon: const Icon(
                      Icons.add_link_rounded,
                      color: PipeBuyerColors.orange,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilledButton.icon(
                      onPressed: () => _openInlineLinkEditor(),
                      style: FilledButton.styleFrom(
                        backgroundColor: PipeBuyerColors.orange,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add_link_rounded, size: 17),
                      label: const Text(
                        'Add Affiliate Link',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
            MediaQuery.sizeOf(context).width < 620
                ? IconButton(
                    tooltip: 'Store Admin',
                    onPressed: _openAdminControl,
                    icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: PipeBuyerColors.orange,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: TextButton.icon(
                      onPressed: _openAdminControl,
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white),
                      icon: const Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 18,
                        color: PipeBuyerColors.orange,
                      ),
                      label: const Text('Store Admin'),
                    ),
                  ),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: MediaQuery.sizeOf(context).width < 420
                ? IconButton(
                    tooltip: 'Sell / Partner',
                    onPressed: () => _openVendorApply(),
                    icon: const Icon(
                      Icons.handshake_outlined,
                      color: PipeBuyerColors.orange,
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _openVendorApply(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: PipeBuyerColors.orange),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(
                      Icons.handshake_outlined,
                      size: 16,
                      color: PipeBuyerColors.orange,
                    ),
                    label: const Text(
                      'Sell / Partner',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
          ),
        ],
      ),
      body: !_settings.storeEnabled
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 46,
                          color: PipeBuyerColors.muted,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Pipe Buyer Store is being updated',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Check back shortly for updated industrial tools, welding gear, and partner deals.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: PipeBuyerColors.muted),
                        ),
                        if (_canManageLinks) ...[
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: _openAdminControl,
                            child: const Text('Open Store Admin'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
                  children: [
                    _buildStoreHero(context),
                    const SizedBox(height: 10),
                    _buildAffiliateDisclosureBanner(context),
                    if (_canManageLinks ||
                        _roleSession.reason == 'mfa_required') ...[
                      const SizedBox(height: 10),
                      _buildAdminQuickManageBar(context),
                    ],
                    const SizedBox(height: 16),
                    _buildPartnerSpotlights(context),
                    const SizedBox(height: 18),
                    _buildCategorySelector(context),
                    const SizedBox(height: 12),
                    _buildSubcategorySelector(context),
                    const SizedBox(height: 14),
                    _buildFilterAndSortToolbar(
                      context,
                      resultCount: filtered.length,
                      hasActiveFilters: hasActiveFilters,
                    ),
                    const SizedBox(height: 14),
                    if (filtered.isEmpty)
                      _buildEmptyResultsCard(context)
                    else ...[
                      _buildProductGrid(
                        context,
                        filtered.take(_visibleLimit).toList(growable: false),
                      ),
                      if (filtered.length > _visibleLimit) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _visibleLimit += 60);
                            },
                            icon: const Icon(Icons.expand_more_rounded),
                            label: Text(
                              'Show More Store Items (${filtered.length - _visibleLimit} remaining)',
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                    _buildVendorRecruitmentBanner(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAdminQuickManageBar(BuildContext context) {
    if (_roleSession.reason == 'mfa_required') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: PipeBuyerColors.warning.withValues(alpha: .45),
          ),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phonelink_lock_outlined,
                  size: 18,
                  color: PipeBuyerColors.warning,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Admin/Store role detected — complete 2-step verification (MFA) in Account Security to add or remove Store affiliate links.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: PipeBuyerColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: _openMfaSecurity,
              icon: const Icon(Icons.security_outlined, size: 16),
              label: const Text('Complete Account MFA'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PipeBuyerColors.industrialBlue.withValues(alpha: .35),
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
                Icons.verified_user_outlined,
                size: 18,
                color: PipeBuyerColors.industrialBlue,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${_roleSession.roleDisplayLabel}: Paste any Amazon, AliExpress, Lazada, Shopee or partner link to publish, or edit/remove below.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: PipeBuyerColors.ink,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _openInlineLinkEditor(),
                style: FilledButton.styleFrom(
                  backgroundColor: PipeBuyerColors.orange,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_link_rounded, size: 17),
                label: const Text('Quick-Add Amazon / Affiliate Link'),
              ),
              OutlinedButton.icon(
                onPressed: _openAdminControl,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 17,
                ),
                label: const Text('Store & Role Settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreHero(BuildContext context) {
    final activeCountry =
        PipeBuyerShopTaxonomy.countryOptionByCode(_regionCode);
    final countryLabel = activeCountry != null
        ? '${activeCountry.flag} ${activeCountry.code == 'ALL' ? 'All Regions' : activeCountry.shortLabel}'
        : '🌍 $_regionCode';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[PipeBuyerColors.ink, Color(0xFF1A2536)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PipeBuyerColors.orange.withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: PipeBuyerColors.orange.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'PIPE BUYER INDUSTRIAL SHOPPING & PARTNER STORE',
                  style: TextStyle(
                    color: PipeBuyerColors.orange,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _RegionChip(
                    label: 'US Store (.com)',
                    selected: _regionCode == 'US',
                    onTap: () => _setRegion('US'),
                  ),
                  _RegionChip(
                    label: 'Canada (.ca)',
                    selected: _regionCode == 'CA',
                    onTap: () => _setRegion('CA'),
                  ),
                  PopupMenuButton<String>(
                    key: const Key('shop_country_picker_button'),
                    tooltip: 'Select your delivery country',
                    onSelected: _setRegion,
                    itemBuilder: (context) =>
                        PipeBuyerShopTaxonomy.countryOptions
                            .map(
                              (opt) => PopupMenuItem<String>(
                                value: opt.code,
                                child: Row(
                                  children: [
                                    Text(opt.flag),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        opt.label,
                                        style: TextStyle(
                                          fontWeight: _regionCode == opt.code
                                              ? FontWeight.w900
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (_regionCode == opt.code)
                                      const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: PipeBuyerColors.orangePressed,
                                      ),
                                  ],
                                ),
                              ),
                            )
                            .toList(growable: false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (_regionCode != 'US' && _regionCode != 'CA')
                            ? PipeBuyerColors.orange
                            : Colors.white.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: (_regionCode != 'US' && _regionCode != 'CA')
                              ? PipeBuyerColors.orange
                              : Colors.white.withValues(alpha: .22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Deliver to: $countryLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _RegionChip(
                    label: 'Saved (${_savedIds.length})',
                    icon: _savedOnly
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    selected: _savedOnly,
                    onTap: () => setState(() => _savedOnly = !_savedOnly),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Shop Field-Proven Tools, Pipefitting, Welding, Rigging & PPE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Curated gear from Amazon Industrial, top trade brands like Milwaukee, RIDGID & Lincoln Electric, plus authorized distributors and verified vendors.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .80),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              color: PipeBuyerColors.ink,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText:
                  'Search Milwaukee M18, pipe wrenches, welding helmets, Grade 70 chains, H2S monitors...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: PipeBuyerColors.orangePressed,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
            ),
          ),
          if (_loadingLive)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: PipeBuyerColors.orange,
                backgroundColor: Colors.white12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAffiliateDisclosureBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PipeBuyerColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: PipeBuyerColors.orangePressed,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _settings.disclosureText,
              style: const TextStyle(
                fontSize: 11.5,
                color: PipeBuyerColors.slate,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _showDisclosureDialog(context),
            child: const Text(
              'Details',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showDisclosureDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Affiliate & Partner Store Disclosure'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _settings.disclosureText,
                style: const TextStyle(height: 1.45),
              ),
              const SizedBox(height: 12),
              Text(
                _settings.priceDisclaimerText,
                style: const TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Purchases open securely on Amazon or the verified partner/distributor website so you receive full manufacturer warranties, Prime shipping eligibility, and buyer protections.',
                style: TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerSpotlights(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'BRANDS, AFFILIATES & PARTNER STOREFRONTS',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: PipeBuyerColors.slate,
                ),
              ),
            ),
            if (_approvedVendors.isNotEmpty)
              Text(
                '${_approvedVendors.length} Verified Partner(s)',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: PipeBuyerColors.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: PipeBuyerShopTaxonomy.partnerSpotlights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final spot = PipeBuyerShopTaxonomy.partnerSpotlights[index];
              final isSelected = (spot.filterBrand != null &&
                      _selectedBrand.toLowerCase() ==
                          spot.filterBrand!.toLowerCase()) ||
                  (spot.filterSource != null &&
                      _selectedSource == spot.filterSource &&
                      _selectedBrand.isEmpty);

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  if (spot.opensVendorPortal) {
                    _openVendorApply();
                    return;
                  }
                  setState(() {
                    if (spot.filterBrand != null) {
                      _selectedBrand = isSelected ? '' : spot.filterBrand!;
                      _selectedSource = null;
                    } else if (spot.filterSource != null) {
                      _selectedSource = isSelected ? null : spot.filterSource;
                      _selectedBrand = '';
                    }
                  });
                },
                child: Container(
                  width: 268,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? spot.accentColor.withValues(alpha: .08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isSelected ? spot.accentColor : PipeBuyerColors.line,
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(spot.icon, size: 18, color: spot.accentColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              spot.channelLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: spot.accentColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: spot.accentColor.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              spot.statusLabel,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: spot.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        spot.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Expanded(
                        child: Text(
                          spot.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: PipeBuyerColors.muted,
                            height: 1.25,
                          ),
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

  Widget _buildCategorySelector(BuildContext context) {
    final countsByCat = <String, int>{};
    var totalCountryEligible = 0;
    for (final p in _products) {
      if (p.status == 'active' && p.shipsToCountry(_regionCode)) {
        totalCountryEligible += 1;
        countsByCat[p.categoryCode] = (countsByCat[p.categoryCode] ?? 0) + 1;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SHOP BY CATEGORY',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: PipeBuyerColors.slate,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CategoryFilterPill(
              label: 'All Categories',
              count: totalCountryEligible,
              icon: Icons.apps_rounded,
              selected: _selectedCategoryCode.isEmpty,
              onTap: () => setState(() {
                _selectedCategoryCode = '';
                _selectedSubcategory = '';
                _visibleLimit = 60;
              }),
            ),
            ...PipeBuyerShopTaxonomy.categories.map(
              (cat) => _CategoryFilterPill(
                label: cat.shortLabel,
                count: countsByCat[cat.code] ?? 0,
                icon: cat.icon,
                selected: _selectedCategoryCode == cat.code,
                onTap: () => setState(() {
                  _selectedCategoryCode =
                      _selectedCategoryCode == cat.code ? '' : cat.code;
                  _selectedSubcategory = '';
                  _visibleLimit = 60;
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubcategorySelector(BuildContext context) {
    final countsBySub = <String, int>{};
    for (final p in _products) {
      if (p.status != 'active' || !p.shipsToCountry(_regionCode)) continue;
      if (_selectedCategoryCode.isNotEmpty &&
          p.categoryCode != _selectedCategoryCode) {
        continue;
      }
      final sub = p.subcategory.trim();
      if (sub.isNotEmpty) {
        countsBySub[sub] = (countsBySub[sub] ?? 0) + 1;
      }
    }

    final List<String> subOptions;
    if (_selectedCategoryCode.isNotEmpty) {
      final official = PipeBuyerShopTaxonomy.subcategoriesForCategory(
        _selectedCategoryCode,
      );
      final merged = <String>[...official];
      for (final extra in countsBySub.keys) {
        if (!merged.any((m) => m.toLowerCase() == extra.toLowerCase())) {
          merged.add(extra);
        }
      }
      subOptions = merged;
    } else {
      final populated = countsBySub.keys.toList()
        ..sort((a, b) => (countsBySub[b] ?? 0).compareTo(countsBySub[a] ?? 0));
      subOptions = populated.take(12).toList(growable: false);
    }

    if (subOptions.isEmpty) return const SizedBox.shrink();

    final selectedCat =
        PipeBuyerShopTaxonomy.categoryByCode(_selectedCategoryCode);
    final heading = selectedCat != null
        ? '${selectedCat.shortLabel.toUpperCase()} SUBCATEGORIES'
        : 'POPULAR SUBCATEGORIES';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
            color: PipeBuyerColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text(
                'All Subcategories',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
              selected: _selectedSubcategory.isEmpty,
              selectedColor: PipeBuyerColors.orangeSoft,
              onSelected: (_) => setState(() {
                _selectedSubcategory = '';
                _visibleLimit = 60;
              }),
            ),
            ...subOptions.map((sub) {
              final active =
                  _selectedSubcategory.toLowerCase() == sub.toLowerCase();
              final count = countsBySub[sub] ?? 0;
              return ChoiceChip(
                label: Text(
                  count > 0 ? '$sub ($count)' : sub,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                selected: active,
                selectedColor: PipeBuyerColors.orangeSoft,
                onSelected: (_) => setState(() {
                  _selectedSubcategory = active ? '' : sub;
                  _visibleLimit = 60;
                }),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterAndSortToolbar(
    BuildContext context, {
    required int resultCount,
    required bool hasActiveFilters,
  }) {
    final brands = _availableBrands;
    final hiddenByCountry = _hiddenByCountryCount;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PipeBuyerColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '$resultCount item${resultCount == 1 ? '' : 's'} shown',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                  if (hiddenByCountry > 0)
                    TextButton(
                      onPressed: () => _setRegion('ALL'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.public_rounded, size: 15),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '$hiddenByCountry regional item${hiddenByCountry == 1 ? '' : 's'} hidden for $_regionCode • Show All Regions',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasActiveFilters)
                    TextButton.icon(
                      onPressed: _clearAllFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                      label: const Text('Reset filters'),
                    ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sort: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: PipeBuyerColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Flexible(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'featured',
                            child: Text('Featured Picks'),
                          ),
                          DropdownMenuItem(
                            value: 'popular',
                            child: Text('Most Popular'),
                          ),
                          DropdownMenuItem(
                            value: 'brand',
                            child: Text('Brand (A–Z)'),
                          ),
                          DropdownMenuItem(
                            value: 'title',
                            child: Text('Product Name (A–Z)'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _sortBy = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (brands.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: brands.map((brand) {
                final active =
                    _selectedBrand.toLowerCase() == brand.toLowerCase();
                return ChoiceChip(
                  label: Text(
                    brand,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  selected: active,
                  selectedColor: PipeBuyerColors.orangeSoft,
                  onSelected: (_) => setState(() {
                    _selectedBrand = active ? '' : brand;
                  }),
                );
              }).toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyResultsCard(BuildContext context) {
    final hiddenByCountry = _hiddenByCountryCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 44,
              color: PipeBuyerColors.muted,
            ),
            const SizedBox(height: 10),
            Text(
              hiddenByCountry > 0
                  ? 'No items ship to $_regionCode for those filters'
                  : 'No Store items match those filters',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              hiddenByCountry > 0
                  ? '$hiddenByCountry item${hiddenByCountry == 1 ? '' : 's'} are available in other regional stores. Switch delivery country or show all regions below.'
                  : 'Clear filters to browse all categories, or search directly on Amazon with Pipe Buyer support.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: PipeBuyerColors.muted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (hiddenByCountry > 0)
                  FilledButton.tonalIcon(
                    onPressed: () => _setRegion('ALL'),
                    icon: const Icon(Icons.public_rounded, size: 17),
                    label: const Text('Show All Regions'),
                  ),
                OutlinedButton(
                  onPressed: _clearAllFilters,
                  child: const Text('Show All Store Items'),
                ),
                if (_searchController.text.trim().isNotEmpty)
                  FilledButton.icon(
                    onPressed: () {
                      final q = Uri.encodeQueryComponent(
                        _searchController.text.trim(),
                      );
                      final dynamicSearch = PipeBuyerShopProduct(
                        id: 'amazon-search-fallback',
                        title: _searchController.text.trim(),
                        brand: 'Amazon',
                        vendorName: 'Amazon',
                        sourceType: PipeBuyerShopSourceType.amazonAffiliate,
                        categoryCode: 'power_hand_tools',
                        destinationUrl: 'https://www.amazon.com/s?k=$q',
                      );
                      _buyOrOpenPartner(dynamicSearch, placement: 'store_grid');
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: Text(
                      'Search "${_searchController.text.trim()}" on Amazon',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid(
    BuildContext context,
    List<PipeBuyerShopProduct> items,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1060
            ? 3
            : width >= 660
                ? 2
                : 1;
        const gap = 14.0;
        final cardWidth = (width - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((product) {
            final isSaved = _savedIds.contains(product.id);
            return SizedBox(
              width: cardWidth,
              child: _ShopProductCard(
                product: product,
                regionCode: _regionCode,
                saved: isSaved,
                canManageLinks: _canManageLinks,
                onToggleSave: () => _toggleSave(product),
                onOpenDetails: () => _showProductDetailsSheet(context, product),
                onBuy: () =>
                    _buyOrOpenPartner(product, placement: 'store_grid'),
                onEdit: _canManageLinks
                    ? () => _openInlineLinkEditor(existing: product)
                    : null,
                onRemove: _canManageLinks
                    ? () => _confirmInlineRemove(product)
                    : null,
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  void _showProductDetailsSheet(
    BuildContext context,
    PipeBuyerShopProduct product,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: PipeBuyerColors.orangeSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${product.brand} • ${product.sourceType.label}',
                          style: const TextStyle(
                            color: PipeBuyerColors.orangePressed,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Category: ${product.category.label}${product.subcategory.isNotEmpty ? ' • ${product.subcategory}' : ''}',
                    style: const TextStyle(
                      color: PipeBuyerColors.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      product.description,
                      style: const TextStyle(fontSize: 14, height: 1.45),
                    ),
                  ],
                  if (product.highlights.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Key Jobsite Specifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...product.highlights.map(
                      (spec) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
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
                              child: Text(
                                spec,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_settings.disclosureText} ${_settings.priceDisclaimerText}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: PipeBuyerColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _buyOrOpenPartner(product, placement: 'store_detail');
                      },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(
                        '${product.effectiveCtaLabel} (${_regionCode == 'CA' ? 'Canada' : 'US'})',
                      ),
                    ),
                  ),
                  if (_canManageLinks) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _openInlineLinkEditor(existing: product);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Edit Link'),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _confirmInlineRemove(product);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: PipeBuyerColors.danger,
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 17,
                          ),
                          label: const Text('Remove Link'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVendorRecruitmentBanner(BuildContext context) {
    if (!_settings.vendorApplicationsOpen) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: PipeBuyerColors.industrialBlue.withValues(alpha: .30),
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DISTRIBUTORS, BRANDS & INDUSTRIAL BUSINESSES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: PipeBuyerColors.industrialBlue,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Want to list Milwaukee, welding, rigging, PPE, or your business catalog in the Pipe Buyer Store?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'We onboard authorized industrial distributors, tool manufacturers, and verified businesses via affiliate feeds, partner storefronts, and direct vendor listings.',
                  style: TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _openVendorApply(),
            style: FilledButton.styleFrom(
              backgroundColor: PipeBuyerColors.industrialBlue,
            ),
            icon: const Icon(Icons.handshake_outlined),
            label: const Text('Apply as Vendor / Distributor'),
          ),
        ],
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? PipeBuyerColors.orange
              : Colors.white.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? PipeBuyerColors.orange
                : Colors.white.withValues(alpha: .22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterPill extends StatelessWidget {
  const _CategoryFilterPill({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? PipeBuyerColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? PipeBuyerColors.orange : PipeBuyerColors.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? PipeBuyerColors.orange : PipeBuyerColors.slate,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : PipeBuyerColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: .15)
                    : PipeBuyerColors.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : PipeBuyerColors.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopProductCard extends StatelessWidget {
  const _ShopProductCard({
    required this.product,
    required this.regionCode,
    required this.saved,
    this.canManageLinks = false,
    required this.onToggleSave,
    required this.onOpenDetails,
    required this.onBuy,
    this.onEdit,
    this.onRemove,
  });

  final PipeBuyerShopProduct product;
  final String regionCode;
  final bool saved;
  final bool canManageLinks;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenDetails;
  final VoidCallback onBuy;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final fallbackArtwork = Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SvgPicture.asset(
          product.effectiveIconAsset,
          height: 76,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => Icon(
            product.category.icon,
            size: 44,
            color: product.category.accentColor,
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PipeBuyerColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 142,
            decoration: const BoxDecoration(
              color: PipeBuyerColors.surfaceMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: product.imageUrl.trim().isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: product.imageUrl.trim(),
                            fit: BoxFit.contain,
                            placeholder: (_, __) => fallbackArtwork,
                            errorWidget: (_, __, ___) => fallbackArtwork,
                          ),
                        )
                      : fallbackArtwork,
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  right: 48,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: PipeBuyerColors.ink.withValues(alpha: .88),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          product.brand.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (product.badgeText.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: PipeBuyerColors.orange,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            product.badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Material(
                    color: Colors.white.withValues(alpha: .92),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: saved ? 'Saved in Shop' : 'Save item',
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggleSave,
                      icon: Icon(
                        saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 20,
                        color: saved
                            ? PipeBuyerColors.orangePressed
                            : PipeBuyerColors.slate,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.subcategory.trim().isNotEmpty
                            ? '${product.category.shortLabel.toUpperCase()} • ${product.subcategory}'
                            : product.category.shortLabel.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: product.category.accentColor,
                        ),
                      ),
                    ),
                    Text(
                      product.sourceType.label,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: PipeBuyerColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onOpenDetails,
                  child: Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                ),
                if (product.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: PipeBuyerColors.muted,
                      height: 1.32,
                    ),
                  ),
                ],
                if (product.highlights.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...product.highlights.take(2).map(
                        (spec) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: PipeBuyerColors.success,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  spec,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.sell_outlined,
                      size: 14,
                      color: product.priceDisplay.isNotEmpty
                          ? PipeBuyerColors.ink
                          : PipeBuyerColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        product.priceDisplay.isNotEmpty
                            ? '${product.priceDisplay} (verify live price)'
                            : 'Check live price & Prime delivery',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: product.priceDisplay.isNotEmpty
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: product.priceDisplay.isNotEmpty
                              ? PipeBuyerColors.ink
                              : PipeBuyerColors.slate,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  product.sourceType == PipeBuyerShopSourceType.amazonAffiliate
                      ? '#ad • Amazon Associate link • ${product.shippingSummaryLabel}'
                      : '#ad • ${product.vendorName.isNotEmpty ? product.vendorName : 'Partner'} • ${product.shippingSummaryLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: PipeBuyerColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: onOpenDetails,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(56, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text(
                        'Specs',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onBuy,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(
                          product.sourceType ==
                                      PipeBuyerShopSourceType.amazonAffiliate &&
                                  regionCode == 'CA'
                              ? 'Amazon.ca'
                              : product.effectiveCtaLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ),
                  ],
                ),
                if (canManageLinks && (onEdit != null || onRemove != null)) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (onEdit != null)
                        TextButton.icon(
                          onPressed: onEdit,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text(
                            'Edit Link',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      if (onRemove != null)
                        TextButton.icon(
                          onPressed: onRemove,
                          style: TextButton.styleFrom(
                            foregroundColor: PipeBuyerColors.danger,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 15,
                          ),
                          label: const Text(
                            'Remove Link',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
