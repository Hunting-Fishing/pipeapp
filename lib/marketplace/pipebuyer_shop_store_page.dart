import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'pipebuyer_shop_client.dart';
import 'pipebuyer_shop_taxonomy.dart';
import 'pipebuyer_shop_vendor_apply_page.dart';

const Color _kShopeeOrange = Color(0xFFEE4D2D);
const Color _kShopeeOrangeDark = Color(0xFFD73211);
const Color _kStoreCanvas = Color(0xFFF5F5F7);

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
  static const List<String> _trendingKeywords = <String>[
    'Milwaukee M18',
    'Pipe Wrench',
    'Welding Helmet',
    'Grade 70 Chain',
    'H2S Monitor',
    'Transfer Pump',
    'Post Driver',
  ];

  static const List<(String label, String brand)> _featuredBrandPills =
      <(String, String)>[
    ('Milwaukee Tool Selection', 'Milwaukee'),
    ('RIDGID Pipe Tools', 'RIDGID'),
    ('Lincoln Electric', 'Lincoln Electric'),
    ('Miller Welding', 'Miller'),
    ('Fill-Rite Pumps', 'Fill-Rite'),
    ('Carhartt FR', 'Carhartt'),
  ];

  late PipeBuyerShopClient _client;
  late final TextEditingController _searchController;

  PipeBuyerShopSettings _settings = const PipeBuyerShopSettings();
  List<PipeBuyerShopProduct> _products =
      PipeBuyerShopClient.mergeWithStarterCatalog(
          const <PipeBuyerShopProduct>[]);
  Set<String> _savedIds = <String>{};

  late String _selectedCategoryCode;
  String _selectedSubcategory = '';
  late String _selectedBrand;
  PipeBuyerShopSourceType? _selectedSource;
  String _regionCode = 'US';
  String _sortBy = 'featured';
  bool _savedOnly = false;
  int _visibleLimit = 60;
  bool _loadingLive = true;

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
    if (oldWidget.client != widget.client) {
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

    final saved = await savedFuture;
    final region = await regionFuture;
    final snapshot = await catalogFuture;

    if (!mounted) return;
    setState(() {
      _savedIds = saved;
      _regionCode = region;
      _settings = snapshot.settings;
      _products = snapshot.products;
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
          ? 'Saved "${product.title}" to your Saved list.'
          : 'Removed from your Saved list.',
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
        message: 'Could not open store link on this device.',
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

  Future<void> _openProductSuggestionDialog({String initialName = ''}) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => PipeBuyerProductSuggestionDialog(
        client: _client,
        initialProductName: initialName,
        initialCategoryCode: _selectedCategoryCode.isNotEmpty
            ? _selectedCategoryCode
            : 'power_hand_tools',
      ),
    );
    if (submitted == true && mounted) {
      PipeFeedback.show(
        context,
        message:
            'Thank you! Your product suggestion has been sent to our Store team.',
        tone: PipeStatusTone.success,
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
      case 'price_asc':
        matched.sort((a, b) {
          final pa = a.numericPrice ?? double.infinity;
          final pb = b.numericPrice ?? double.infinity;
          final cmp = pa.compareTo(pb);
          if (cmp != 0) return cmp;
          return a.title.compareTo(b.title);
        });
      case 'price_desc':
        matched.sort((a, b) {
          final pa = a.numericPrice ?? -1;
          final pb = b.numericPrice ?? -1;
          final cmp = pb.compareTo(pa);
          if (cmp != 0) return cmp;
          return a.title.compareTo(b.title);
        });
      case 'brand':
        matched.sort((a, b) {
          final brandCmp = a.brand.compareTo(b.brand);
          if (brandCmp != 0) return brandCmp;
          return a.title.compareTo(b.title);
        });
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
      if (p.brand.trim().isEmpty) continue;
      counts[p.brand] = (counts[p.brand] ?? 0) + 1;
    }
    final brands = counts.keys.toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    return brands.take(12).toList(growable: false);
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

    if (!_settings.storeEnabled) {
      return Scaffold(
        backgroundColor: _kStoreCanvas,
        appBar: AppBar(
          backgroundColor: _kShopeeOrange,
          foregroundColor: Colors.white,
          title: const Text('Pipe Buyer Store'),
        ),
        body: Center(
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
                      'Pipe Buyer Store is refreshing inventory',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check back shortly for updated industrial tools, welding gear, and jobsite supplies.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PipeBuyerColors.muted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _openProductSuggestionDialog(),
                      icon: const Icon(Icons.lightbulb_outline_rounded),
                      label: const Text('Suggest a Product'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kStoreCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildShopeeHeader(context),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPromoBannerSection(context),
                        const SizedBox(height: 14),
                        _buildCategoriesGridCard(context),
                        const SizedBox(height: 14),
                        _buildSortAndFilterBar(
                          context,
                          resultCount: filtered.length,
                          hasActiveFilters: hasActiveFilters,
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          _buildEmptyResultsCard(context)
                        else ...[
                          _buildProductGrid(
                            context,
                            filtered
                                .take(_visibleLimit)
                                .toList(growable: false),
                          ),
                          if (filtered.length > _visibleLimit) ...[
                            const SizedBox(height: 18),
                            Center(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() => _visibleLimit += 60);
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.expand_more_rounded),
                                label: Text(
                                  'See More Products (${filtered.length - _visibleLimit} more)',
                                ),
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 22),
                        _buildSuggestProductBanner(context),
                        const SizedBox(height: 18),
                        _buildStoreFooter(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopeeHeader(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 760;
    final canPop = Navigator.of(context).canPop();
    final activeCountry =
        PipeBuyerShopTaxonomy.countryOptionByCode(_regionCode);
    final countryLabel = activeCountry != null
        ? '${activeCountry.flag} ${activeCountry.code == 'ALL' ? 'All Regions' : activeCountry.shortLabel}'
        : '🌍 $_regionCode';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            _kShopeeOrangeDark,
            _kShopeeOrange,
            Color(0xFFF9683A)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              isCompact ? 8 : 6,
              14,
              isCompact ? 10 : 10,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top utility strip (Country selector + Suggest Item + Saved + Seller Center)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _HeaderUtilityChip(
                          label: 'US Store (.com)',
                          selected: _regionCode == 'US',
                          onTap: () => _setRegion('US'),
                        ),
                        _HeaderUtilityChip(
                          label: 'Canada (.ca)',
                          selected: _regionCode == 'CA',
                          onTap: () => _setRegion('CA'),
                        ),
                        PopupMenuButton<String>(
                          key: const Key('shop_country_picker_button'),
                          tooltip: 'Select delivery country',
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
                                                fontWeight:
                                                    _regionCode == opt.code
                                                        ? FontWeight.w900
                                                        : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if (_regionCode == opt.code)
                                            const Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                              color: _kShopeeOrange,
                                            ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (_regionCode != 'US' && _regionCode != 'CA')
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Ship to: $countryLabel',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: (_regionCode != 'US' &&
                                              _regionCode != 'CA')
                                          ? _kShopeeOrangeDark
                                          : Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  size: 15,
                                  color: (_regionCode != 'US' &&
                                          _regionCode != 'CA')
                                      ? _kShopeeOrangeDark
                                      : Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        InkWell(
                          key: const Key('shop_suggest_product_top_button'),
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _openProductSuggestionDialog(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    isCompact
                                        ? 'Suggest an Item'
                                        : 'Know a helpful product not listed? Let us know!',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_settings.vendorApplicationsOpen && !isCompact)
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _openVendorApply(),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              child: Text(
                                'Sell on Store',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Main Shopee-style Brand + Wide Search Input + Wishlist Bar
                if (isCompact) ...[
                  Row(
                    children: [
                      if (canPop)
                        IconButton(
                          tooltip: 'Back',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      const Icon(
                        Icons.shopping_bag_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 7),
                      const Expanded(
                        child: Text(
                          'Pipe Buyer Store',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      _SavedHeartButton(
                        count: _savedIds.length,
                        selected: _savedOnly,
                        onTap: () => setState(() => _savedOnly = !_savedOnly),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildSearchBox(),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (canPop)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _clearAllFilters,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shopping_bag_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Pipe Buyer Store',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSearchBox(),
                            const SizedBox(height: 5),
                            SizedBox(
                              height: 18,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _trendingKeywords.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, i) {
                                  final kw = _trendingKeywords[i];
                                  return InkWell(
                                    onTap: () => setState(() {
                                      _searchController.text = kw;
                                    }),
                                    child: Text(
                                      kw,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: .92),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _SavedHeartButton(
                        count: _savedIds.length,
                        selected: _savedOnly,
                        onTap: () => setState(() => _savedOnly = !_savedOnly),
                      ),
                    ],
                  ),
                ],
                if (_loadingLive)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: PipeBuyerColors.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText:
                    'Search tools, pipe wrenches, welding hoods, rigging chains, PPE...',
                hintStyle: const TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: PipeBuyerColors.muted,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 34,
            width: 52,
            child: FilledButton(
              onPressed: () => setState(() {}),
              style: FilledButton.styleFrom(
                backgroundColor: _kShopeeOrange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Icon(Icons.search_rounded, size: 19),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBannerSection(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;

        final mainBanner = Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                Color(0xFF0F172A),
                Color(0xFF1E293B),
                Color(0xFF3B1D14),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _kShopeeOrange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'FIELD-PROVEN JOBSITE DEALS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Shop Pipefitting, Welding, Power Tools, Rigging & Safety Gear',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Top-rated industrial equipment & jobsite essentials from trusted trade brands.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .82),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _featuredBrandPills.map((entry) {
                  final isSelected =
                      _selectedBrand.toLowerCase() == entry.$2.toLowerCase();
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() {
                      _selectedBrand = isSelected ? '' : entry.$2;
                      _visibleLimit = 60;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _kShopeeOrange
                            : Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected
                              ? _kShopeeOrange
                              : Colors.white.withValues(alpha: .24),
                        ),
                      ),
                      child: Text(
                        entry.$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ],
          ),
        );

        final suggestCard = InkWell(
          key: const Key('shop_suggest_product_hero_card'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openProductSuggestionDialog(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFFF4EE), Color(0xFFFFE5D8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _kShopeeOrange.withValues(alpha: .35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _kShopeeOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Know a helpful product not listed?',
                        style: TextStyle(
                          color: PipeBuyerColors.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Let us know! Tap here to suggest tools or gear ->',
                        style: TextStyle(
                          color: _kShopeeOrangeDark,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        final topRatedCard = InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            _sortBy = 'featured';
            _selectedCategoryCode = '';
            _selectedSubcategory = '';
          }),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PipeBuyerColors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFD97706),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crew-Tested Top Picks',
                        style: TextStyle(
                          color: PipeBuyerColors.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Verified quality & fast doorstep delivery',
                        style: TextStyle(
                          color: PipeBuyerColors.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        if (!wide) {
          return Column(
            children: [
              mainBanner,
              const SizedBox(height: 8),
              suggestCard,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 7, child: mainBanner),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Expanded(child: topRatedCard),
                    const SizedBox(height: 8),
                    Expanded(child: suggestCard),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesGridCard(BuildContext context) {
    final countsByCat = <String, int>{};
    var totalCountryEligible = 0;
    for (final p in _products) {
      if (p.status == 'active' && p.shipsToCountry(_regionCode)) {
        totalCountryEligible += 1;
        countsByCat[p.categoryCode] = (countsByCat[p.categoryCode] ?? 0) + 1;
      }
    }

    final subcategories = _selectedCategoryCode.isEmpty
        ? const <String>[]
        : PipeBuyerShopTaxonomy.subcategoriesForCategory(_selectedCategoryCode);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PipeBuyerColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'CATEGORIES',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: PipeBuyerColors.muted,
                    ),
                  ),
                ),
                if (_selectedCategoryCode.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() {
                      _selectedCategoryCode = '';
                      _selectedSubcategory = '';
                    }),
                    child: const Text(
                      'View All Categories',
                      style: TextStyle(
                        color: _kShopeeOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileCount = PipeBuyerShopTaxonomy.categories.length + 1;
              final wide = constraints.maxWidth >= 920;
              final tileWidth = wide
                  ? constraints.maxWidth / tileCount
                  : (constraints.maxWidth /
                          (constraints.maxWidth >= 560 ? 5 : 3))
                      .clamp(98.0, 160.0);

              final tiles = <Widget>[
                _ShopeeCategoryTile(
                  width: tileWidth,
                  label: 'All Products',
                  count: totalCountryEligible,
                  icon: Icons.grid_view_rounded,
                  accentColor: _kShopeeOrange,
                  selected: _selectedCategoryCode.isEmpty,
                  onTap: () => setState(() {
                    _selectedCategoryCode = '';
                    _selectedSubcategory = '';
                    _visibleLimit = 60;
                  }),
                ),
                ...PipeBuyerShopTaxonomy.categories.map(
                  (cat) => _ShopeeCategoryTile(
                    width: tileWidth,
                    label: cat.shortLabel,
                    count: countsByCat[cat.code] ?? 0,
                    icon: cat.icon,
                    accentColor: cat.accentColor,
                    selected: _selectedCategoryCode == cat.code,
                    onTap: () => setState(() {
                      _selectedCategoryCode =
                          _selectedCategoryCode == cat.code ? '' : cat.code;
                      _selectedSubcategory = '';
                      _visibleLimit = 60;
                    }),
                  ),
                ),
              ];

              return Wrap(children: tiles);
            },
          ),
          if (subcategories.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: const Text(
                          'All Subcategories',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        selected: _selectedSubcategory.isEmpty,
                        selectedColor: const Color(0xFFFFEDE8),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) =>
                            setState(() => _selectedSubcategory = ''),
                      ),
                    ),
                    ...subcategories.map((sub) {
                      final active = _selectedSubcategory.toLowerCase() ==
                          sub.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            sub,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          selected: active,
                          selectedColor: const Color(0xFFFFEDE8),
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => setState(
                            () => _selectedSubcategory = active ? '' : sub,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSortAndFilterBar(
    BuildContext context, {
    required int resultCount,
    required bool hasActiveFilters,
  }) {
    final brands = _availableBrands;
    final hiddenByCountry = _hiddenByCountryCount;

    const sortTabs = <(String, String)>[
      ('featured', 'Top Picks'),
      ('popular', 'Popular'),
      ('price_asc', 'Price: Low to High'),
      ('price_desc', 'Price: High to Low'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PipeBuyerColors.line),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Sort by',
                style: TextStyle(
                  fontSize: 12.5,
                  color: PipeBuyerColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ...sortTabs.map((tab) {
                final active = _sortBy == tab.$1;
                return InkWell(
                  borderRadius: BorderRadius.circular(5),
                  onTap: () => setState(() => _sortBy = tab.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: active ? _kShopeeOrange : _kStoreCanvas,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      tab.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : PipeBuyerColors.ink,
                      ),
                    ),
                  ),
                );
              }),
              if (brands.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 185),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _kStoreCanvas,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: brands.any(
                          (b) =>
                              b.toLowerCase() == _selectedBrand.toLowerCase(),
                        )
                            ? brands.firstWhere(
                                (b) =>
                                    b.toLowerCase() ==
                                    _selectedBrand.toLowerCase(),
                              )
                            : '',
                        isDense: true,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PipeBuyerColors.ink,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text(
                              'All Brands',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...brands.map(
                            (b) => DropdownMenuItem(
                              value: b,
                              child: Text(
                                b,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedBrand = v ?? ''),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hiddenByCountry > 0)
                TextButton.icon(
                  onPressed: () => _setRegion('ALL'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: _kShopeeOrangeDark,
                  ),
                  icon: const Icon(Icons.public_rounded, size: 15),
                  label: Text(
                    '$hiddenByCountry regional item${hiddenByCountry == 1 ? '' : 's'} hidden for $_regionCode • Show All',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('Reset'),
                ),
              Text(
                '$resultCount product${resultCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: PipeBuyerColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResultsCard(BuildContext context) {
    final hiddenByCountry = _hiddenByCountryCount;
    final currentQuery = _searchController.text.trim();
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PipeBuyerColors.line),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.manage_search_rounded,
            size: 46,
            color: PipeBuyerColors.muted,
          ),
          const SizedBox(height: 10),
          Text(
            hiddenByCountry > 0
                ? 'No items ship to $_regionCode for those filters'
                : 'No products found matching your search',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            hiddenByCountry > 0
                ? '$hiddenByCountry item${hiddenByCountry == 1 ? '' : 's'} are available in other regional stores. Switch delivery country or view all regions below.'
                : 'Know a helpful product not listed? Let us know and our team can add it to the Store!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: PipeBuyerColors.muted),
          ),
          const SizedBox(height: 16),
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
                child: const Text('View All Products'),
              ),
              FilledButton.icon(
                onPressed: () =>
                    _openProductSuggestionDialog(initialName: currentQuery),
                style: FilledButton.styleFrom(backgroundColor: _kShopeeOrange),
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 17),
                label: Text(
                  currentQuery.isNotEmpty
                      ? 'Suggest "$currentQuery"'
                      : 'Suggest a Product',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(
    BuildContext context,
    List<PipeBuyerShopProduct> items,
  ) {
    final textScale = MediaQuery.textScalerOf(context).scale(10) / 10.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int columns;
        if (width >= 1160) {
          columns = 5;
        } else if (width >= 880) {
          columns = 4;
        } else if (width >= 600) {
          columns = 3;
        } else if (width >= 380 && textScale <= 1.15) {
          columns = 2;
        } else {
          columns = 1;
        }
        const gap = 10.0;
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
                onToggleSave: () => _toggleSave(product),
                onOpenDetails: () => _showProductDetailsSheet(context, product),
                onBuy: () =>
                    _buyOrOpenPartner(product, placement: 'store_grid'),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  Widget _buildSuggestProductBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kShopeeOrange.withValues(alpha: .30)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDE8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: _kShopeeOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Know a helpful product not listed? Let us know!',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: PipeBuyerColors.ink,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Share tools, welding supplies, rigging gear, or shop equipment your crew relies on and we will look into adding it.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: PipeBuyerColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          FilledButton.icon(
            key: const Key('shop_suggest_product_footer_button'),
            onPressed: () => _openProductSuggestionDialog(),
            style: FilledButton.styleFrom(
              backgroundColor: _kShopeeOrange,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Suggest a Product'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Text(
              _settings.disclosureText,
              style: const TextStyle(
                fontSize: 11,
                color: PipeBuyerColors.muted,
                height: 1.35,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _showDisclosureDialog(context),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Store Info',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
              if (_settings.vendorApplicationsOpen)
                TextButton(
                  onPressed: () => _openVendorApply(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Become a Seller',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDisclosureDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('About Pipe Buyer Store'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Orders open directly on Amazon or the verified retail storefront so you receive full manufacturer warranties, fast shipping, and buyer protection.',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 12),
              Text(
                _settings.disclosureText,
                style: const TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _settings.priceDisclaimerText,
                style: const TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                          color: const Color(0xFFFFEDE8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.brand,
                          style: const TextStyle(
                            color: _kShopeeOrangeDark,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          product.category.shortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PipeBuyerColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 230,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PipeBuyerColors.line),
                    ),
                    child: product.imageUrl.trim().isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrl.trim(),
                            fit: BoxFit.contain,
                            placeholder: (_, __) => Center(
                              child: SvgPicture.asset(
                                product.effectiveIconAsset,
                                height: 76,
                                fit: BoxFit.contain,
                              ),
                            ),
                            errorWidget: (_, __, ___) => Center(
                              child: SvgPicture.asset(
                                product.effectiveIconAsset,
                                height: 76,
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        : Center(
                            child: SvgPicture.asset(
                              product.effectiveIconAsset,
                              height: 76,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                  if (product.priceDisplay.isNotEmpty) ...[
                    Text(
                      product.priceDisplay,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _kShopeeOrange,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.28,
                    ),
                  ),
                  if (product.subcategory.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.subcategory,
                      style: const TextStyle(
                        color: PipeBuyerColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      product.description,
                      style: const TextStyle(fontSize: 13.5, height: 1.45),
                    ),
                  ],
                  if (product.highlights.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Product Specifications',
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
                              Icons.check_circle_rounded,
                              size: 16,
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
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kShopeeOrange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _buyOrOpenPartner(product, placement: 'store_detail');
                      },
                      icon: const Icon(Icons.shopping_cart_checkout_rounded),
                      label: Text(
                        product.sourceType ==
                                    PipeBuyerShopSourceType.amazonAffiliate &&
                                _regionCode == 'CA'
                            ? 'Buy on Amazon.ca'
                            : product.effectiveCtaLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class PipeBuyerProductSuggestionDialog extends StatefulWidget {
  const PipeBuyerProductSuggestionDialog({
    super.key,
    required this.client,
    this.initialProductName = '',
    this.initialCategoryCode = 'power_hand_tools',
  });

  final PipeBuyerShopClient client;
  final String initialProductName;
  final String initialCategoryCode;

  @override
  State<PipeBuyerProductSuggestionDialog> createState() =>
      _PipeBuyerProductSuggestionDialogState();
}

class _PipeBuyerProductSuggestionDialogState
    extends State<PipeBuyerProductSuggestionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _notesController;
  late final TextEditingController _submitterNameController;
  late final TextEditingController _emailController;
  late String _categoryCode;
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProductName);
    _urlController = TextEditingController();
    _notesController = TextEditingController();
    _submitterNameController = TextEditingController(
      text: widget.client.currentUserDisplayName,
    );
    _emailController = TextEditingController(
      text: widget.client.currentUserEmail,
    );
    _categoryCode =
        PipeBuyerShopTaxonomy.categoryByCode(widget.initialCategoryCode) != null
            ? widget.initialCategoryCode
            : 'power_hand_tools';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    _submitterNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await widget.client.submitProductSuggestion(
        productName: _nameController.text,
        productUrl: _urlController.text,
        categoryCode: _categoryCode,
        notes: _notesController.text,
        submitterName: _submitterNameController.text,
        contactEmail: _emailController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = err.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: _kShopeeOrange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Suggest a Helpful Product',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Know a helpful product, tool, or piece of gear not listed yet? Let us know and our Store team will review it!',
                  style: TextStyle(
                    fontSize: 13,
                    color: PipeBuyerColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('suggest_product_name_field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product / Tool Name & Brand *',
                    hintText: 'e.g., Klein Tools 935DAG Digital Angle Gauge',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 3) {
                      return 'Enter the product or tool name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categoryCode,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: PipeBuyerShopTaxonomy.categories
                      .map(
                        (cat) => DropdownMenuItem<String>(
                          value: cat.code,
                          child: Text(
                            cat.shortLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) {
                    if (v != null) setState(() => _categoryCode = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('suggest_product_url_field'),
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Product Link (Optional)',
                    hintText: 'https://www.amazon.com/... or brand website',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('suggest_product_notes_field'),
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Why do you recommend it? (Optional)',
                    hintText: 'Helpful notes, model number, or field use...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _submitterNameController,
                        decoration: const InputDecoration(
                          labelText: 'Your Name (Optional)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email (Optional)',
                        ),
                      ),
                    ),
                  ],
                ),
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
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('suggest_product_submit_button'),
          style: FilledButton.styleFrom(
            backgroundColor: _kShopeeOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: const Text('Send Suggestion'),
        ),
      ],
    );
  }
}

class _HeaderUtilityChip extends StatelessWidget {
  const _HeaderUtilityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _kShopeeOrangeDark : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SavedHeartButton extends StatelessWidget {
  const _SavedHeartButton({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 19,
              color: selected ? _kShopeeOrange : Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              'Saved ($count)',
              style: TextStyle(
                color: selected ? _kShopeeOrangeDark : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopeeCategoryTile extends StatelessWidget {
  const _ShopeeCategoryTile({
    required this.width,
    required this.label,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String label;
  final int count;
  final IconData icon;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF5F2) : Colors.white,
          border: Border(
            right: const BorderSide(color: Color(0xFFF1F5F9)),
            bottom: BorderSide(
              color: selected ? _kShopeeOrange : const Color(0xFFF1F5F9),
              width: selected ? 2.5 : 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? _kShopeeOrange.withValues(alpha: .14)
                    : accentColor.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 21,
                color: selected ? _kShopeeOrange : accentColor,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.2,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: selected ? _kShopeeOrangeDark : PipeBuyerColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count items',
              style: const TextStyle(
                fontSize: 10,
                color: PipeBuyerColors.muted,
                fontWeight: FontWeight.w600,
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
    required this.onToggleSave,
    required this.onOpenDetails,
    required this.onBuy,
  });

  final PipeBuyerShopProduct product;
  final String regionCode;
  final bool saved;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenDetails;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final fallbackArtwork = Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SvgPicture.asset(
          product.effectiveIconAsset,
          height: 68,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => Icon(
            product.category.icon,
            size: 40,
            color: product.category.accentColor,
          ),
        ),
      ),
    );

    final ctaText =
        product.sourceType == PipeBuyerShopSourceType.amazonAffiliate &&
                regionCode == 'CA'
            ? 'Amazon.ca'
            : product.effectiveCtaLabel;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpenDetails,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Clean white Shopee/Amazon square-feel product image showcase
              SizedBox(
                height: 176,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: product.imageUrl.trim().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: product.imageUrl.trim(),
                                fit: BoxFit.contain,
                                placeholder: (_, __) => fallbackArtwork,
                                errorWidget: (_, __, ___) => fallbackArtwork,
                              )
                            : fallbackArtwork,
                      ),
                    ),
                    if (product.featured || product.badgeText.trim().isNotEmpty)
                      Positioned(
                        left: 0,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: const BoxDecoration(
                            color: _kShopeeOrange,
                            borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                          child: Text(
                            product.badgeText.trim().isNotEmpty
                                ? product.badgeText.trim()
                                : 'Top Pick',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Material(
                        color: Colors.white.withValues(alpha: .9),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: saved ? 'Saved' : 'Save item',
                          visualDensity: VisualDensity.compact,
                          onPressed: onToggleSave,
                          icon: Icon(
                            saved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color:
                                saved ? _kShopeeOrange : PipeBuyerColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: PipeBuyerColors.ink,
                        height: 1.28,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${product.brand} • ${product.category.shortLabel}',
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
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            product.priceDisplay.isNotEmpty
                                ? product.priceDisplay
                                : 'View Price',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: _kShopeeOrange,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          '4.9',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: PipeBuyerColors.slate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: FilledButton(
                        onPressed: onBuy,
                        style: FilledButton.styleFrom(
                          backgroundColor: _kShopeeOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: Text(
                          ctaText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
