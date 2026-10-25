import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_dispatch_request_service_page.dart';
import 'pipebuyer_contact_center_dashboard.dart';
import 'pipebuyer_list_services_page.dart';
import 'pipebuyer_yellow_pages_client.dart';
import 'pipebuyer_yellow_pages_taxonomy.dart';

enum YellowPagesViewMode { grid, lines }

class PipeBuyerYellowPagesDirectoryPage extends StatefulWidget {
  const PipeBuyerYellowPagesDirectoryPage({
    super.key,
    this.initialQuery = '',
    this.initialCategoryCode = '',
    this.initialCountryCode = '',
    this.initialViewMode = YellowPagesViewMode.grid,
    this.client,
  });

  final String initialQuery;
  final String initialCategoryCode;
  final String initialCountryCode;
  final YellowPagesViewMode initialViewMode;
  final PipeBuyerYellowPagesClient? client;

  @override
  State<PipeBuyerYellowPagesDirectoryPage> createState() =>
      _PipeBuyerYellowPagesDirectoryPageState();
}

class _PipeBuyerYellowPagesDirectoryPageState
    extends State<PipeBuyerYellowPagesDirectoryPage> {
  late final PipeBuyerYellowPagesClient _client;
  late final TextEditingController _searchController;
  final TextEditingController _customCityController = TextEditingController();
  Timer? _debounce;

  // View & Grid density state
  YellowPagesViewMode _viewMode = YellowPagesViewMode.grid;
  int? _manualGridColumns; // null => responsive Auto (4-6 on desktop)
  bool _showAdvancedFilters = false;

  // Filter & Sort state
  String _countryCode = '';
  String _regionCode = '';
  String _city = '';
  String _categoryCode = '';
  String _basin = '';
  String _certification = '';
  String _tierFilter = '';
  String _startsWith = '';
  String _sortBy = 'priority';
  bool _emergency24x7 = false;
  bool _paidOnly = false;
  bool _hasTollFree = false;

  // Results state
  bool _loading = false;
  bool _canAccessContactCenter = false;
  String? _error;
  int _totalMatched = 0;
  String? _nextCursor;
  List<String> _expandedCategories = const <String>[];
  List<Map<String, dynamic>> _entries = const <Map<String, dynamic>>[];

  static const _quickSearchTags = <({String label, String query})>[
    (label: 'Hydrovac', query: 'Hydrovac'),
    (label: 'Winch & Heavy Haul', query: 'Winch Truck'),
    (label: 'OCTG & Pipe', query: 'OCTG'),
    (label: 'Mobile Welding', query: 'Welding'),
    (label: 'Frac & Wireline', query: 'Wireline'),
    (label: 'Cranes & Pickers', query: 'Picker Truck'),
    (label: 'Pipe Inspection / NDT', query: 'Pipe Inspection'),
    (label: 'Oilfield Rentals', query: 'Oilfield Rentals'),
  ];

  static const _alphabet = <String>[
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#',
  ];

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerYellowPagesClient();
    _viewMode = widget.initialViewMode;
    _searchController = TextEditingController(text: widget.initialQuery);
    _categoryCode = widget.initialCategoryCode;
    _countryCode = widget.initialCountryCode;
    _load(reset: true);
    _refreshStaffAccess();
  }

  Future<void> _refreshStaffAccess() async {
    try {
      final access = await _client.getAccess();
      if (!mounted) return;
      setState(() {
        _canAccessContactCenter = access.authorized || access.isAgent;
      });
    } catch (_) {
      // Public visitors do not have Contact Center access.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _customCityController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _countryCode.isNotEmpty ||
      _regionCode.isNotEmpty ||
      _city.isNotEmpty ||
      _categoryCode.isNotEmpty ||
      _basin.isNotEmpty ||
      _certification.isNotEmpty ||
      _tierFilter.isNotEmpty ||
      _startsWith.isNotEmpty ||
      _emergency24x7 ||
      _paidOnly ||
      _hasTollFree ||
      _sortBy != 'priority';

  int get _advancedFilterCount {
    var count = 0;
    if (_certification.isNotEmpty) count++;
    if (_tierFilter.isNotEmpty) count++;
    if (_startsWith.isNotEmpty) count++;
    if (_hasTollFree) count++;
    if (_sortBy != 'priority') count++;
    return count;
  }

  void _resetAllFilters() {
    _searchController.clear();
    _customCityController.clear();
    setState(() {
      _countryCode = '';
      _regionCode = '';
      _city = '';
      _categoryCode = '';
      _basin = '';
      _certification = '';
      _tierFilter = '';
      _startsWith = '';
      _sortBy = 'priority';
      _emergency24x7 = false;
      _paidOnly = false;
      _hasTollFree = false;
    });
    _load(reset: true);
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _load(reset: true);
    });
  }

  Future<void> _load({required bool reset}) async {
    if (_loading && !reset) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _entries = const <Map<String, dynamic>>[];
        _nextCursor = null;
      }
    });
    try {
      final offset = reset ? 0 : (int.tryParse(_nextCursor ?? '0') ?? 0);
      final page = await _client.searchPublic(
        query: _searchController.text.trim(),
        countryCode: _countryCode,
        regionCode: _regionCode,
        city: _city,
        categoryCode: _categoryCode,
        basin: _basin,
        certification: _certification,
        emergency24x7: _emergency24x7,
        paidOnly: _paidOnly,
        tierFilter: _tierFilter,
        hasTollFree: _hasTollFree,
        startsWith: _startsWith,
        sortBy: _sortBy,
        offset: offset,
        pageSize: 60, // LCM(4, 5, 6) = 60 so 4/5/6-col grids always fill complete rows
      );
      if (!mounted) return;
      setState(() {
        _entries = reset
            ? page.items
            : List<Map<String, dynamic>>.unmodifiable(
                <Map<String, dynamic>>[..._entries, ...page.items],
              );
        _totalMatched = page.totalMatched;
        _nextCursor = page.nextCursor;
        _expandedCategories = page.expandedCategories;
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

  int _resolveGridColumns(double width) {
    if (width >= 980 && _manualGridColumns != null) {
      return _manualGridColumns!.clamp(4, 6);
    }
    if (width >= 1740) return 6;
    if (width >= 1360) return 5;
    if (width >= 980) return 4;
    if (width >= 680) return 3;
    if (width >= 460) return 2;
    return 1;
  }

  Future<void> _openListServices({Map<String, dynamic>? claimEntry}) async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PipeBuyerListServicesPage(
          claimedCompanyId: claimEntry?['companyId']?.toString() ??
              claimEntry?['id']?.toString(),
          initialCompanyName: '${claimEntry?['companyName'] ?? ''}',
          initialCity: '${claimEntry?['city'] ?? ''}',
          initialCountryCode: '${claimEntry?['countryCode'] ?? 'CA'}',
          initialRegionCode: '${claimEntry?['regionCode'] ?? 'AB'}',
          initialPhone: '${claimEntry?['publicPhone'] ?? ''}',
        ),
      ),
    );
    if (submitted == true && mounted) {
      _load(reset: true);
    }
  }

  void _openContactCenter() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PipeBuyerContactCenterDashboard(),
      ),
    );
  }

  void _openDispatchRequest() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const MarketplaceDispatchRequestServicePage(),
      ),
    );
  }

  Future<void> _openAllCategoriesModal() async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => _AllCategoriesPickerDialog(selectedCode: _categoryCode),
    );
    if (chosen == null || !mounted) return;
    setState(() => _categoryCode = chosen == '__all__' ? '' : chosen);
    _load(reset: true);
  }

  Future<void> _openCustomCityDialog() async {
    _customCityController.text = _city;
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Filter by City or Oilfield Area',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: _customCityController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Nisku, Midland, Grande Prairie, Williston...',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text('Clear City'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_customCityController.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (entered == null || !mounted) return;
    setState(() => _city = entered);
    _load(reset: true);
  }

  void _showCompanyDetailsModal(Map<String, dynamic> entry) {
    final companyId = '${entry['companyId'] ?? entry['id'] ?? ''}'.trim();
    if (companyId.isNotEmpty) {
      _client.recordLeadInteraction(
        companyId: companyId,
        interactionType: 'profile_view',
      );
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: _CompanyDetailSheet(
          entry: entry,
          client: _client,
          onClaimOrUpgrade: () {
            Navigator.of(ctx).pop();
            _openListServices(claimEntry: entry);
          },
          onRequestDispatch: () {
            Navigator.of(ctx).pop();
            _openDispatchRequest();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regions =
        PipeBuyerYellowPagesTaxonomy.regionsForCountry(_countryCode);
    final hubs = PipeBuyerYellowPagesTaxonomy.hubsForLocation(
      countryCode: _countryCode,
      regionCode: _regionCode,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        leading: !Navigator.of(context).canPop() &&
                GoRouter.maybeOf(context) != null
            ? IconButton(
                tooltip: 'Back to Pipe Buyer',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => GoRouter.of(context).go('/'),
              )
            : null,
        title: const Text(
          'SEARCH FOR SERVICES • YELLOW PAGES',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: FilledButton.icon(
              onPressed: () => _openListServices(),
              icon: const Icon(Icons.workspace_premium_outlined, size: 18),
              label: const Text('List Services'),
            ),
          ),
          if (_canAccessContactCenter)
            IconButton(
              tooltip: 'Staff & Admin Contact Center',
              onPressed: _openContactCenter,
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          IconButton(
            tooltip: 'Refresh directory',
            onPressed: _loading ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1960),
          child: Column(
            children: [
              _EnhancedFilterDeck(
                controller: _searchController,
                countryCode: _countryCode,
                regionCode: _regionCode,
                city: _city,
                categoryCode: _categoryCode,
                basin: _basin,
                certification: _certification,
                tierFilter: _tierFilter,
                startsWith: _startsWith,
                sortBy: _sortBy,
                emergency24x7: _emergency24x7,
                paidOnly: _paidOnly,
                hasTollFree: _hasTollFree,
                showAdvanced: _showAdvancedFilters,
                advancedFilterCount: _advancedFilterCount,
                regions: regions,
                hubs: hubs,
                quickTags: _quickSearchTags,
                alphabet: _alphabet,
                onSearchChanged: _onSearchChanged,
                onApplyQuickTag: (q) {
                  _searchController.text = q;
                  _load(reset: true);
                },
                onClearSearch: () {
                  _searchController.clear();
                  setState(() {});
                  _load(reset: true);
                },
                onCountryChanged: (code) {
                  setState(() {
                    _countryCode = code;
                    _regionCode = '';
                    _city = '';
                  });
                  _load(reset: true);
                },
                onRegionChanged: (code) {
                  setState(() {
                    _regionCode = code;
                    _city = '';
                  });
                  _load(reset: true);
                },
                onCityChanged: (value) {
                  if (value == '__custom__') {
                    _openCustomCityDialog();
                    return;
                  }
                  setState(() => _city = value);
                  _load(reset: true);
                },
                onBasinChanged: (value) {
                  setState(() => _basin = value);
                  _load(reset: true);
                },
                onCertificationChanged: (value) {
                  setState(() => _certification = value);
                  _load(reset: true);
                },
                onTierFilterChanged: (value) {
                  setState(() {
                    _tierFilter = value;
                    if (value == 'paid_only') {
                      _paidOnly = true;
                    } else if (_paidOnly && value.isEmpty) {
                      _paidOnly = false;
                    }
                  });
                  _load(reset: true);
                },
                onSortChanged: (value) {
                  setState(() => _sortBy = value);
                  _load(reset: true);
                },
                onStartsWithChanged: (letter) {
                  setState(
                    () => _startsWith = _startsWith == letter ? '' : letter,
                  );
                  _load(reset: true);
                },
                onEmergencyChanged: (v) {
                  setState(() => _emergency24x7 = v);
                  _load(reset: true);
                },
                onPaidOnlyChanged: (v) {
                  setState(() {
                    _paidOnly = v;
                    if (!v && _tierFilter == 'paid_only') _tierFilter = '';
                  });
                  _load(reset: true);
                },
                onTollFreeChanged: (v) {
                  setState(() => _hasTollFree = v);
                  _load(reset: true);
                },
                onToggleAdvanced: () => setState(
                  () => _showAdvancedFilters = !_showAdvancedFilters,
                ),
                onBrowseAllCategories: _openAllCategoriesModal,
                onListServices: () => _openListServices(),
              ),
              // Horizontal 24-Category Strip with tree-shake-safe icons
              Container(
                color: Colors.white,
                height: 46,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  scrollDirection: Axis.horizontal,
                  itemCount:
                      PipeBuyerYellowPagesTaxonomy.categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text(
                          'All Categories (24)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        selected: _categoryCode.isEmpty,
                        onSelected: (_) {
                          setState(() => _categoryCode = '');
                          _load(reset: true);
                        },
                      );
                    }
                    final cat =
                        PipeBuyerYellowPagesTaxonomy.categories[index - 1];
                    final selected = _categoryCode == cat.code;
                    return ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        PipeBuyerYellowPagesTaxonomy.iconForCategory(cat.code),
                        size: 15,
                        color: selected
                            ? PipeBuyerColors.orange
                            : PipeBuyerColors.slate,
                      ),
                      label: Text(
                        cat.shortLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      selected: selected,
                      onSelected: (isSelected) {
                        setState(
                          () => _categoryCode = isSelected ? cat.code : '',
                        );
                        _load(reset: true);
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              // Results Toolbar: Count + Active Filter Breadcrumbs + View Mode & 4-6 Grid Density Switcher
              LayoutBuilder(
                builder: (context, barConstraints) {
                  final wideToolbar = barConstraints.maxWidth >= 980;
                  final autoCols = _resolveGridColumns(barConstraints.maxWidth);
                  return Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                              Icons.verified_outlined,
                              size: 16,
                              color: PipeBuyerColors.industrialBlue,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${_formatCount(_totalMatched)} verified service provider${_totalMatched == 1 ? '' : 's'}'
                                '${_expandedCategories.isNotEmpty ? ' • Smart-matched categories' : ' • Featured -> Pro -> Verified'}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (_hasActiveFilters) ...[
                              const SizedBox(width: 10),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                onPressed: _resetAllFilters,
                                icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
                                label: const Text(
                                  'Reset Filters',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_viewMode == YellowPagesViewMode.grid &&
                                wideToolbar)
                              _GridDensitySelector(
                                manualColumns: _manualGridColumns,
                                resolvedAutoColumns: autoCols,
                                onChanged: (cols) =>
                                    setState(() => _manualGridColumns = cols),
                              ),
                            _ViewModeSwitcher(
                              mode: _viewMode,
                              onChanged: (mode) =>
                                  setState(() => _viewMode = mode),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (_hasActiveFilters)
                _ActiveFilterBreadcrumbStrip(
                  countryCode: _countryCode,
                  regionCode: _regionCode,
                  city: _city,
                  categoryCode: _categoryCode,
                  basin: _basin,
                  certification: _certification,
                  tierFilter: _tierFilter,
                  startsWith: _startsWith,
                  emergency24x7: _emergency24x7,
                  paidOnly: _paidOnly,
                  hasTollFree: _hasTollFree,
                  onClearCountry: () {
                    setState(() {
                      _countryCode = '';
                      _regionCode = '';
                      _city = '';
                    });
                    _load(reset: true);
                  },
                  onClearRegion: () {
                    setState(() {
                      _regionCode = '';
                      _city = '';
                    });
                    _load(reset: true);
                  },
                  onClearCity: () {
                    setState(() => _city = '');
                    _load(reset: true);
                  },
                  onClearCategory: () {
                    setState(() => _categoryCode = '');
                    _load(reset: true);
                  },
                  onClearBasin: () {
                    setState(() => _basin = '');
                    _load(reset: true);
                  },
                  onClearCertification: () {
                    setState(() => _certification = '');
                    _load(reset: true);
                  },
                  onClearTier: () {
                    setState(() {
                      _tierFilter = '';
                      _paidOnly = false;
                    });
                    _load(reset: true);
                  },
                  onClearStartsWith: () {
                    setState(() => _startsWith = '');
                    _load(reset: true);
                  },
                  onClearEmergency: () {
                    setState(() => _emergency24x7 = false);
                    _load(reset: true);
                  },
                  onClearTollFree: () {
                    setState(() => _hasTollFree = false);
                    _load(reset: true);
                  },
                ),
              const Divider(height: 1),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.error_outline,
                        color: PipeBuyerColors.danger,
                      ),
                      title: Text(_error!),
                      trailing: TextButton(
                        onPressed: () => _load(reset: true),
                        child: const Text('Retry'),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _loading && _entries.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                        ? _EmptyDirectoryState(
                            hasFilters: _hasActiveFilters,
                            onResetFilters: _resetAllFilters,
                            onListServices: () => _openListServices(),
                            onRequestDispatch: _openDispatchRequest,
                          )
                        : LayoutBuilder(
                            builder: (context, viewport) {
                              if (_viewMode == YellowPagesViewMode.lines) {
                                return _LinesDirectoryView(
                                  entries: _entries,
                                  width: viewport.maxWidth,
                                  hasMore: _nextCursor != null,
                                  loading: _loading,
                                  client: _client,
                                  onLoadMore: () => _load(reset: false),
                                  onSelectCompany: _showCompanyDetailsModal,
                                  onClaimOrUpgrade: (entry) =>
                                      _openListServices(claimEntry: entry),
                                  onRequestDispatch: _openDispatchRequest,
                                );
                              }
                              final cols =
                                  _resolveGridColumns(viewport.maxWidth);
                              return CustomScrollView(
                                slivers: [
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      12,
                                      14,
                                      18,
                                    ),
                                    sliver: SliverGrid(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: cols,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        mainAxisExtent: cols >= 5 ? 236 : 242,
                                      ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final entry = _entries[index];
                                          return _GridCompanyCard(
                                            entry: entry,
                                            compact: cols >= 5,
                                            client: _client,
                                            onOpenDetails: () =>
                                                _showCompanyDetailsModal(entry),
                                            onClaimOrUpgrade: () =>
                                                _openListServices(
                                              claimEntry: entry,
                                            ),
                                            onRequestDispatch:
                                                _openDispatchRequest,
                                          );
                                        },
                                        childCount: _entries.length,
                                      ),
                                    ),
                                  ),
                                  if (_nextCursor != null)
                                    SliverToBoxAdapter(
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                            bottom: 32,
                                          ),
                                          child: FilledButton.tonalIcon(
                                            onPressed: _loading
                                                ? null
                                                : () => _load(reset: false),
                                            icon: const Icon(Icons.expand_more),
                                            label: Text(
                                              _loading
                                                  ? 'Loading more providers...'
                                                  : 'Load 60 more providers (${_entries.length} of ${_formatCount(_totalMatched)} shown)',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _EnhancedFilterDeck extends StatelessWidget {
  const _EnhancedFilterDeck({
    required this.controller,
    required this.countryCode,
    required this.regionCode,
    required this.city,
    required this.categoryCode,
    required this.basin,
    required this.certification,
    required this.tierFilter,
    required this.startsWith,
    required this.sortBy,
    required this.emergency24x7,
    required this.paidOnly,
    required this.hasTollFree,
    required this.showAdvanced,
    required this.advancedFilterCount,
    required this.regions,
    required this.hubs,
    required this.quickTags,
    required this.alphabet,
    required this.onSearchChanged,
    required this.onApplyQuickTag,
    required this.onClearSearch,
    required this.onCountryChanged,
    required this.onRegionChanged,
    required this.onCityChanged,
    required this.onBasinChanged,
    required this.onCertificationChanged,
    required this.onTierFilterChanged,
    required this.onSortChanged,
    required this.onStartsWithChanged,
    required this.onEmergencyChanged,
    required this.onPaidOnlyChanged,
    required this.onTollFreeChanged,
    required this.onToggleAdvanced,
    required this.onBrowseAllCategories,
    required this.onListServices,
  });

  final TextEditingController controller;
  final String countryCode;
  final String regionCode;
  final String city;
  final String categoryCode;
  final String basin;
  final String certification;
  final String tierFilter;
  final String startsWith;
  final String sortBy;
  final bool emergency24x7;
  final bool paidOnly;
  final bool hasTollFree;
  final bool showAdvanced;
  final int advancedFilterCount;
  final List<YellowPagesRegionOption> regions;
  final List<({String city, String regionCode, String countryCode})> hubs;
  final List<({String label, String query})> quickTags;
  final List<String> alphabet;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onApplyQuickTag;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onBasinChanged;
  final ValueChanged<String> onCertificationChanged;
  final ValueChanged<String> onTierFilterChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onStartsWithChanged;
  final ValueChanged<bool> onEmergencyChanged;
  final ValueChanged<bool> onPaidOnlyChanged;
  final ValueChanged<bool> onTollFreeChanged;
  final VoidCallback onToggleAdvanced;
  final VoidCallback onBrowseAllCategories;
  final VoidCallback onListServices;

  @override
  Widget build(BuildContext context) {
    final cityInHubs = hubs.any((h) => h.city == city);
    final selectedCat = PipeBuyerYellowPagesTaxonomy.byCode(categoryCode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0E1B2E),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: PipeBuyerColors.orange,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PipeBuyer North America Oil & Gas Service Directory (Canada & USA)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onListServices,
                icon: const Icon(Icons.campaign_outlined, size: 17),
                label: const Text(
                  r'Advertise / Claim Listing (from $24/mo) →',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Search Bar + Quick Oilfield Slang Chips on wide screens
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 42,
                      child: TextField(
                        controller: controller,
                        onChanged: onSearchChanged,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText:
                              'Search company, phone, city or service: Hydrovac, Winch Truck, OCTG, Welding, Nisku, Midland TX...',
                          hintStyle: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF334155),
                            size: 20,
                          ),
                          suffixIcon: controller.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: onClearSearch,
                                  icon: const Icon(Icons.clear, size: 18),
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (constraints.maxWidth >= 1150) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: quickTags.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, idx) {
                            final tag = quickTags[idx];
                            final active = controller.text.trim().toLowerCase() ==
                                tag.query.toLowerCase();
                            return ActionChip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: active
                                  ? PipeBuyerColors.orange
                                  : const Color(0xFF1B2E4B),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                              label: Text(
                                tag.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () =>
                                  onApplyQuickTag(active ? '' : tag.query),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          // Primary Filter Controls Wrap (100% visible without hidden horizontal scroll)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CountryPill(
                label: 'All North America',
                selected: countryCode.isEmpty,
                onTap: () => onCountryChanged(''),
              ),
              _CountryPill(
                label: 'Canada (CA)',
                selected: countryCode == 'CA',
                onTap: () => onCountryChanged('CA'),
              ),
              _CountryPill(
                label: 'USA (US)',
                selected: countryCode == 'US',
                onTap: () => onCountryChanged('US'),
              ),
              // Province / State Dropdown
              _DarkDropdownPill<String>(
                icon: Icons.map_outlined,
                active: regionCode.isNotEmpty,
                value: regions.any((r) => r.regionCode == regionCode)
                    ? regionCode
                    : '',
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All Provinces / States'),
                  ),
                  ...regions.map(
                    (r) => DropdownMenuItem(
                      value: r.regionCode,
                      child: Text('${r.regionCode} • ${r.name}'),
                    ),
                  ),
                ],
                onChanged: (v) => onRegionChanged(v ?? ''),
              ),
              // City / Oilfield Hub Dropdown
              _DarkDropdownPill<String>(
                icon: Icons.location_city_outlined,
                active: city.isNotEmpty,
                value: city.isEmpty
                    ? ''
                    : (cityInHubs ? city : '__selected_custom__'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All Cities / Hubs'),
                  ),
                  const DropdownMenuItem(
                    value: '__custom__',
                    child: Text('✎ Type Any City...'),
                  ),
                  if (city.isNotEmpty && !cityInHubs)
                    DropdownMenuItem(
                      value: '__selected_custom__',
                      child: Text('City: $city'),
                    ),
                  ...hubs.map(
                    (h) => DropdownMenuItem(
                      value: h.city,
                      child: Text('${h.city}, ${h.regionCode}'),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v == '__selected_custom__') {
                    onCityChanged('__custom__');
                  } else {
                    onCityChanged(v ?? '');
                  }
                },
              ),
              // Oil & Gas Basin Dropdown
              _DarkDropdownPill<String>(
                icon: Icons.layers_outlined,
                active: basin.isNotEmpty,
                value: PipeBuyerYellowPagesTaxonomy.basins.contains(basin)
                    ? basin
                    : '',
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All Basins'),
                  ),
                  ...PipeBuyerYellowPagesTaxonomy.basins.map(
                    (b) => DropdownMenuItem(value: b, child: Text(b)),
                  ),
                ],
                onChanged: (v) => onBasinChanged(v ?? ''),
              ),
              // All 24 Categories Grid Modal Trigger
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onBrowseAllCategories,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: selectedCat != null
                        ? PipeBuyerColors.orange
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.grid_view_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        selectedCat != null
                            ? selectedCat.shortLabel
                            : 'Browse 24 Categories',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              _DarkTogglePill(
                icon: Icons.bolt_rounded,
                label: '24/7 Emergency',
                selected: emergency24x7,
                onTap: () => onEmergencyChanged(!emergency24x7),
              ),
              _DarkTogglePill(
                icon: Icons.workspace_premium_outlined,
                label: 'Featured & Pro',
                selected: paidOnly,
                onTap: () => onPaidOnlyChanged(!paidOnly),
              ),
              // More Filters & A-Z Toggle
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onToggleAdvanced,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: showAdvanced || advancedFilterCount > 0
                        ? PipeBuyerColors.industrialBlue
                        : Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        advancedFilterCount > 0
                            ? 'More Filters ($advancedFilterCount)'
                            : 'More Filters & A–Z',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        showAdvanced
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Expandable Secondary Filter Drawer: Certifications, Tier, Sort, Toll-Free & A-Z Index
          if (showAdvanced) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Safety Certifications
                      _DarkDropdownPill<String>(
                        icon: Icons.verified_user_outlined,
                        active: certification.isNotEmpty,
                        value: PipeBuyerYellowPagesTaxonomy.certifications
                                .contains(certification)
                            ? certification
                            : '',
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('All Safety Certifications'),
                          ),
                          ...PipeBuyerYellowPagesTaxonomy.certifications.map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          ),
                        ],
                        onChanged: (v) => onCertificationChanged(v ?? ''),
                      ),
                      // Listing Tier Filter
                      _DarkDropdownPill<String>(
                        icon: Icons.stars_outlined,
                        active: tierFilter.isNotEmpty,
                        value: tierFilter,
                        items: const [
                          DropdownMenuItem(
                            value: '',
                            child: Text('All Listing Tiers'),
                          ),
                          DropdownMenuItem(
                            value: 'featured_only',
                            child: Text('Featured Partners (#1 Spotlight)'),
                          ),
                          DropdownMenuItem(
                            value: 'paid_only',
                            child: Text('Featured & Verified Pro'),
                          ),
                          DropdownMenuItem(
                            value: 'claimable_only',
                            child: Text('Unclaimed Businesses (Claimable)'),
                          ),
                        ],
                        onChanged: (v) => onTierFilterChanged(v ?? ''),
                      ),
                      // Sort Order
                      _DarkDropdownPill<String>(
                        icon: Icons.sort_rounded,
                        active: sortBy != 'priority',
                        value: sortBy,
                        items: const [
                          DropdownMenuItem(
                            value: 'priority',
                            child: Text('Sort: Priority Ranked'),
                          ),
                          DropdownMenuItem(
                            value: 'name_asc',
                            child: Text('Sort: Company Name (A–Z)'),
                          ),
                          DropdownMenuItem(
                            value: 'city_asc',
                            child: Text('Sort: City / Hub (A–Z)'),
                          ),
                          DropdownMenuItem(
                            value: 'region_asc',
                            child: Text('Sort: Country & Prov/State'),
                          ),
                        ],
                        onChanged: (v) => onSortChanged(v ?? 'priority'),
                      ),
                      _DarkTogglePill(
                        icon: Icons.support_agent_outlined,
                        label: 'Has Toll-Free (1-800)',
                        selected: hasTollFree,
                        onTap: () => onTollFreeChanged(!hasTollFree),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Yellow Pages A-Z Quick Jump Index
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text(
                            'A–Z INDEX:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        _AlphabetChip(
                          label: 'ALL',
                          selected: startsWith.isEmpty,
                          onTap: () => onStartsWithChanged(startsWith),
                        ),
                        ...alphabet.map(
                          (letter) => Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: _AlphabetChip(
                              label: letter,
                              selected: startsWith == letter,
                              onTap: () => onStartsWithChanged(letter),
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
        ],
      ),
    );
  }
}

class _DarkDropdownPill<T> extends StatelessWidget {
  const _DarkDropdownPill({
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.active = false,
  });

  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active
            ? PipeBuyerColors.orange.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? PipeBuyerColors.orange
              : Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isDense: true,
              dropdownColor: const Color(0xFF152642),
              iconEnabledColor: Colors.white,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              value: value,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkTogglePill extends StatelessWidget {
  const _DarkTogglePill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: selected
              ? PipeBuyerColors.orange
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? PipeBuyerColors.orange
                : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
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

class _AlphabetChip extends StatelessWidget {
  const _AlphabetChip({
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
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? PipeBuyerColors.orange
              : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CountryPill extends StatelessWidget {
  const _CountryPill({
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
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? PipeBuyerColors.orange
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? PipeBuyerColors.orange
                : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
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

class _ViewModeSwitcher extends StatelessWidget {
  const _ViewModeSwitcher({
    required this.mode,
    required this.onChanged,
  });

  final YellowPagesViewMode mode;
  final ValueChanged<YellowPagesViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeBtn(
            icon: Icons.grid_view_rounded,
            label: 'Grid View',
            selected: mode == YellowPagesViewMode.grid,
            onTap: () => onChanged(YellowPagesViewMode.grid),
          ),
          _ModeBtn(
            icon: Icons.view_headline_rounded,
            label: 'Lines View',
            selected: mode == YellowPagesViewMode.lines,
            onTap: () => onChanged(YellowPagesViewMode.lines),
          ),
        ],
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  const _ModeBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0E1B2E) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridDensitySelector extends StatelessWidget {
  const _GridDensitySelector({
    required this.manualColumns,
    required this.resolvedAutoColumns,
    required this.onChanged,
  });

  final int? manualColumns;
  final int resolvedAutoColumns;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <({String label, int? value})>[
      (
        label: manualColumns == null
            ? 'Auto ($resolvedAutoColumns/row)'
            : 'Auto',
        value: null,
      ),
      (label: '4/row', value: 4),
      (label: '5/row', value: 5),
      (label: '6/row', value: 6),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final selected = manualColumns == opt.value;
          return InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: () => onChanged(opt.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? PipeBuyerColors.orange : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                opt.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _ActiveFilterBreadcrumbStrip extends StatelessWidget {
  const _ActiveFilterBreadcrumbStrip({
    required this.countryCode,
    required this.regionCode,
    required this.city,
    required this.categoryCode,
    required this.basin,
    required this.certification,
    required this.tierFilter,
    required this.startsWith,
    required this.emergency24x7,
    required this.paidOnly,
    required this.hasTollFree,
    required this.onClearCountry,
    required this.onClearRegion,
    required this.onClearCity,
    required this.onClearCategory,
    required this.onClearBasin,
    required this.onClearCertification,
    required this.onClearTier,
    required this.onClearStartsWith,
    required this.onClearEmergency,
    required this.onClearTollFree,
  });

  final String countryCode;
  final String regionCode;
  final String city;
  final String categoryCode;
  final String basin;
  final String certification;
  final String tierFilter;
  final String startsWith;
  final bool emergency24x7;
  final bool paidOnly;
  final bool hasTollFree;

  final VoidCallback onClearCountry;
  final VoidCallback onClearRegion;
  final VoidCallback onClearCity;
  final VoidCallback onClearCategory;
  final VoidCallback onClearBasin;
  final VoidCallback onClearCertification;
  final VoidCallback onClearTier;
  final VoidCallback onClearStartsWith;
  final VoidCallback onClearEmergency;
  final VoidCallback onClearTollFree;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (countryCode.isNotEmpty)
        _RemovableFilterChip(
          label: countryCode == 'CA' ? 'Canada (CA)' : 'USA (US)',
          onDeleted: onClearCountry,
        ),
      if (regionCode.isNotEmpty)
        _RemovableFilterChip(label: 'Prov/State: $regionCode', onDeleted: onClearRegion),
      if (city.isNotEmpty)
        _RemovableFilterChip(label: 'City: $city', onDeleted: onClearCity),
      if (categoryCode.isNotEmpty)
        _RemovableFilterChip(
          label: PipeBuyerYellowPagesTaxonomy.byCode(categoryCode)?.shortLabel ??
              categoryCode,
          onDeleted: onClearCategory,
        ),
      if (basin.isNotEmpty)
        _RemovableFilterChip(label: 'Basin: $basin', onDeleted: onClearBasin),
      if (certification.isNotEmpty)
        _RemovableFilterChip(
          label: 'Cert: $certification',
          onDeleted: onClearCertification,
        ),
      if (tierFilter.isNotEmpty || paidOnly)
        _RemovableFilterChip(
          label: tierFilter == 'featured_only'
              ? 'Featured Partners'
              : tierFilter == 'claimable_only'
                  ? 'Unclaimed Only'
                  : 'Featured & Pro',
          onDeleted: onClearTier,
        ),
      if (startsWith.isNotEmpty)
        _RemovableFilterChip(
          label: 'Starts with "$startsWith"',
          onDeleted: onClearStartsWith,
        ),
      if (emergency24x7)
        _RemovableFilterChip(
          label: '24/7 Emergency',
          onDeleted: onClearEmergency,
        ),
      if (hasTollFree)
        _RemovableFilterChip(
          label: 'Toll-Free 1-800',
          onDeleted: onClearTollFree,
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: chips,
      ),
    );
  }
}

class _RemovableFilterChip extends StatelessWidget {
  const _RemovableFilterChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Colors.white,
      label: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
      onDeleted: onDeleted,
      deleteIconColor: const Color(0xFF64748B),
    );
  }
}

// ============================================================================
// 4–6 COLUMN RESPONSIVE GRID CARD
// ============================================================================
class _GridCompanyCard extends StatelessWidget {
  const _GridCompanyCard({
    required this.entry,
    required this.compact,
    required this.client,
    required this.onOpenDetails,
    required this.onClaimOrUpgrade,
    required this.onRequestDispatch,
  });

  final Map<String, dynamic> entry;
  final bool compact;
  final PipeBuyerYellowPagesClient client;
  final VoidCallback onOpenDetails;
  final VoidCallback onClaimOrUpgrade;
  final VoidCallback onRequestDispatch;

  @override
  Widget build(BuildContext context) {
    final companyId = '${entry['companyId'] ?? entry['id'] ?? ''}'.trim();
    final companyName = '${entry['companyName'] ?? 'Service Provider'}'.trim();
    final effectiveTier = '${entry['effectiveTier'] ?? 'free_verified'}';
    final isFeatured = effectiveTier == 'featured_platinum';
    final isPaid = isFeatured || effectiveTier == 'paid_verified';
    final claimable = entry['claimable'] == true || !isPaid;

    final city = '${entry['city'] ?? ''}'.trim();
    final region = '${entry['regionCode'] ?? ''}'.trim();
    final country = '${entry['countryCode'] ?? ''}'.trim();
    final locShort =
        [city, region].where((s) => s.isNotEmpty).join(', ');
    final regionCountryBadge =
        [region, country].where((s) => s.isNotEmpty).join(' • ');

    final phone = '${entry['publicPhone'] ?? ''}'.trim();
    final website = isPaid ? '${entry['website'] ?? ''}'.trim() : '';
    final emergency24x7 = entry['emergency24x7'] == true;

    final categories = _asStringList(entry['categories']);
    final services = _asStringList(entry['services']);
    final basins = _asStringList(entry['basins']);
    final allTags = <String>[
      ...categories,
      ...services.where((s) => !categories.contains(s)),
    ];
    final shownTags = allTags.take(2).toList(growable: false);
    final extraCount = allTags.length - shownTags.length;

    final borderColor = isFeatured
        ? PipeBuyerColors.orange
        : isPaid
            ? PipeBuyerColors.industrialBlue
            : const Color(0xFFD8E1EB);

    return Material(
      color: isFeatured ? const Color(0xFFFFFCF8) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetails,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isFeatured ? 2.0 : (isPaid ? 1.5 : 1.0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Accent Stripe
              Container(
                height: 3.5,
                color: isFeatured
                    ? PipeBuyerColors.orange
                    : isPaid
                        ? PipeBuyerColors.industrialBlue
                        : const Color(0xFF94A3B8),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 10 : 12,
                    8,
                    compact ? 10 : 12,
                    9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Tier Badge + 24/7 + Country/State Pill
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: [
                                if (isFeatured)
                                  const _TierBadge(
                                    label: 'FEATURED',
                                    color: PipeBuyerColors.orange,
                                  )
                                else if (isPaid)
                                  const _TierBadge(
                                    label: 'PRO',
                                    color: PipeBuyerColors.industrialBlue,
                                  )
                                else
                                  const _TierBadge(
                                    label: 'VERIFIED',
                                    color: Color(0xFF475569),
                                  ),
                                if (emergency24x7)
                                  const _TierBadge(
                                    label: '24/7',
                                    color: PipeBuyerColors.success,
                                  ),
                              ],
                            ),
                          ),
                          if (regionCountryBadge.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                regionCountryBadge,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Row 2: Company Name (2 lines max)
                      Text(
                        companyName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 13.5 : 14.2,
                          height: 1.18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Row 3: City + Basin
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              [
                                if (locShort.isNotEmpty) locShort,
                                if (basins.isNotEmpty) basins.first,
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      // Row 4: Compact Service Pills
                      if (shownTags.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            ...shownTags.map(
                              (tag) => Container(
                                constraints: const BoxConstraints(maxWidth: 165),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  tag,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                            if (extraCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '+$extraCount',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      const Spacer(),
                      const Divider(height: 10),
                      // Row 5: Pinned Bottom Action Bar (Call + Website/RFQ or Claim)
                      Row(
                        children: [
                          if (phone.isNotEmpty)
                            Expanded(
                              child: SizedBox(
                                height: 31,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isFeatured
                                        ? PipeBuyerColors.orange
                                        : const Color(0xFF0E1B2E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (companyId.isNotEmpty) {
                                      client.recordLeadInteraction(
                                        companyId: companyId,
                                        interactionType: 'call_click',
                                      );
                                    }
                                    launchUrl(Uri(scheme: 'tel', path: phone));
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.call, size: 13),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          phone,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            const Expanded(
                              child: Text(
                                'View profile',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: PipeBuyerColors.industrialBlue,
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          if (isPaid && website.isNotEmpty)
                            SizedBox(
                              width: 31,
                              height: 31,
                              child: IconButton.outlined(
                                padding: EdgeInsets.zero,
                                tooltip: 'Open Website',
                                onPressed: () {
                                  if (companyId.isNotEmpty) {
                                    client.recordLeadInteraction(
                                      companyId: companyId,
                                      interactionType: 'website_click',
                                    );
                                  }
                                  _launchWebsite(website);
                                },
                                icon: const Icon(Icons.language, size: 15),
                              ),
                            ),
                          if (isPaid)
                            SizedBox(
                              width: 31,
                              height: 31,
                              child: IconButton.outlined(
                                padding: EdgeInsets.zero,
                                tooltip: 'Request Service / RFQ',
                                onPressed: () {
                                  if (companyId.isNotEmpty) {
                                    client.recordLeadInteraction(
                                      companyId: companyId,
                                      interactionType: 'rfq_click',
                                    );
                                  }
                                  onRequestDispatch();
                                },
                                icon: const Icon(
                                  Icons.local_shipping_outlined,
                                  size: 15,
                                ),
                              ),
                            )
                          else if (claimable)
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: onClaimOrUpgrade,
                              child: Container(
                                height: 31,
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 7),
                                decoration: BoxDecoration(
                                  color: PipeBuyerColors.orange
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: PipeBuyerColors.orange
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: const Text(
                                  'Claim',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: PipeBuyerColors.orange,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HIGH-DENSITY LINES VIEW (YELLOW PAGES PHONEBOOK TABLE)
// ============================================================================
class _LinesDirectoryView extends StatelessWidget {
  const _LinesDirectoryView({
    required this.entries,
    required this.width,
    required this.hasMore,
    required this.loading,
    required this.client,
    required this.onLoadMore,
    required this.onSelectCompany,
    required this.onClaimOrUpgrade,
    required this.onRequestDispatch,
  });

  final List<Map<String, dynamic>> entries;
  final double width;
  final bool hasMore;
  final bool loading;
  final PipeBuyerYellowPagesClient client;
  final VoidCallback onLoadMore;
  final ValueChanged<Map<String, dynamic>> onSelectCompany;
  final ValueChanged<Map<String, dynamic>> onClaimOrUpgrade;
  final VoidCallback onRequestDispatch;

  @override
  Widget build(BuildContext context) {
    final wideTable = width >= 880;
    return Column(
      children: [
        if (wideTable)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    'TIER',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 25,
                  child: Text(
                    'COMPANY NAME',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 17,
                  child: Text(
                    'CITY & PROV / STATE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 14,
                  child: Text(
                    'BASIN',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 28,
                  child: Text(
                    'PRIMARY SERVICES & CATEGORIES',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(
                  width: 152,
                  child: Text(
                    'DIRECT PHONE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(
                  width: 116,
                  child: Text(
                    'ACTION',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: entries.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == entries.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.tonalIcon(
                      onPressed: loading ? null : onLoadMore,
                      icon: const Icon(Icons.expand_more),
                      label: Text(
                        loading
                            ? 'Loading...'
                            : 'Load 60 more lines (${entries.length} shown)',
                      ),
                    ),
                  ),
                );
              }
              final entry = entries[index];
              return _DirectoryLineRow(
                entry: entry,
                even: index.isEven,
                wideTable: wideTable,
                client: client,
                onTap: () => onSelectCompany(entry),
                onClaim: () => onClaimOrUpgrade(entry),
                onRequestDispatch: onRequestDispatch,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DirectoryLineRow extends StatelessWidget {
  const _DirectoryLineRow({
    required this.entry,
    required this.even,
    required this.wideTable,
    required this.client,
    required this.onTap,
    required this.onClaim,
    required this.onRequestDispatch,
  });

  final Map<String, dynamic> entry;
  final bool even;
  final bool wideTable;
  final PipeBuyerYellowPagesClient client;
  final VoidCallback onTap;
  final VoidCallback onClaim;
  final VoidCallback onRequestDispatch;

  @override
  Widget build(BuildContext context) {
    final companyId = '${entry['companyId'] ?? entry['id'] ?? ''}'.trim();
    final companyName = '${entry['companyName'] ?? 'Service Provider'}'.trim();
    final effectiveTier = '${entry['effectiveTier'] ?? 'free_verified'}';
    final isFeatured = effectiveTier == 'featured_platinum';
    final isPaid = isFeatured || effectiveTier == 'paid_verified';
    final emergency = entry['emergency24x7'] == true;

    final city = '${entry['city'] ?? ''}'.trim();
    final region = '${entry['regionCode'] ?? ''}'.trim();
    final country = '${entry['countryCode'] ?? ''}'.trim();
    final location =
        [city, region, country].where((s) => s.isNotEmpty).join(', ');

    final basins = _asStringList(entry['basins']);
    final categories = _asStringList(entry['categories']);
    final services = _asStringList(entry['services']);
    final serviceSummary =
        <String>[...categories, ...services].take(3).join(' • ');
    final phone = '${entry['publicPhone'] ?? ''}'.trim();

    final rowBg = isFeatured
        ? const Color(0xFFFFF8F1)
        : (even ? Colors.white : const Color(0xFFF8FAFC));

    if (!wideTable) {
      return Material(
        color: rowBg,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [location, if (serviceSummary.isNotEmpty) serviceSummary]
                            .join('  |  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      if (companyId.isNotEmpty) {
                        client.recordLeadInteraction(
                          companyId: companyId,
                          interactionType: 'call_click',
                        );
                      }
                      launchUrl(Uri(scheme: 'tel', path: phone));
                    },
                    icon: const Icon(Icons.call, size: 14),
                    label: Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: rowBg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isFeatured
                    ? PipeBuyerColors.orange
                    : isPaid
                        ? PipeBuyerColors.industrialBlue
                        : Colors.transparent,
                width: 3,
              ),
              bottom: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 89,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _TierBadge(
                    label: isFeatured
                        ? 'FEATURED'
                        : isPaid
                            ? 'PRO'
                            : (emergency ? '24/7' : 'VERIFIED'),
                    color: isFeatured
                        ? PipeBuyerColors.orange
                        : isPaid
                            ? PipeBuyerColors.industrialBlue
                            : (emergency
                                ? PipeBuyerColors.success
                                : const Color(0xFF475569)),
                  ),
                ),
              ),
              Expanded(
                flex: 25,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 17,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    basins.isNotEmpty ? basins.first : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 28,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    serviceSummary.isNotEmpty ? serviceSummary : 'Oilfield Services',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 152,
                child: phone.isNotEmpty
                    ? SizedBox(
                        height: 29,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: isFeatured
                                ? PipeBuyerColors.orange
                                : const Color(0xFF0E1B2E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () {
                            if (companyId.isNotEmpty) {
                              client.recordLeadInteraction(
                                companyId: companyId,
                                interactionType: 'call_click',
                              );
                            }
                            launchUrl(Uri(scheme: 'tel', path: phone));
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.call, size: 13),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const Text('—'),
              ),
              SizedBox(
                width: 116,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: isPaid
                      ? TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: onRequestDispatch,
                          icon: const Icon(Icons.local_shipping_outlined, size: 14),
                          label: const Text(
                            'RFQ',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                        )
                      : TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: PipeBuyerColors.orange,
                          ),
                          onPressed: onClaim,
                          child: const Text(
                            r'Claim ($24)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ALL 24 CATEGORIES VISUAL PICKER DIALOG
// ============================================================================
class _AllCategoriesPickerDialog extends StatelessWidget {
  const _AllCategoriesPickerDialog({required this.selectedCode});

  final String selectedCode;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.grid_view_rounded,
                    color: PipeBuyerColors.orange,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Select Oil & Gas Service Category (24 Sectors)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop('__all__'),
                    child: const Text('Show All Categories'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 720
                        ? 3
                        : (constraints.maxWidth >= 480 ? 2 : 1);
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisExtent: 82,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: PipeBuyerYellowPagesTaxonomy.categories.length,
                      itemBuilder: (context, idx) {
                        final cat =
                            PipeBuyerYellowPagesTaxonomy.categories[idx];
                        final active = cat.code == selectedCode;
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.of(context).pop(cat.code),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: active
                                  ? PipeBuyerColors.orange
                                      .withValues(alpha: 0.1)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: active
                                    ? PipeBuyerColors.orange
                                    : const Color(0xFFCBD5E1),
                                width: active ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  PipeBuyerYellowPagesTaxonomy.iconForCategory(
                                    cat.code,
                                  ),
                                  color: active
                                      ? PipeBuyerColors.orange
                                      : const Color(0xFF1E293B),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        cat.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        cat.sampleServices.take(2).join(' • '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FULL COMPANY QUICK-PROFILE BOTTOM SHEET
// ============================================================================
class _CompanyDetailSheet extends StatelessWidget {
  const _CompanyDetailSheet({
    required this.entry,
    required this.client,
    required this.onClaimOrUpgrade,
    required this.onRequestDispatch,
  });

  final Map<String, dynamic> entry;
  final PipeBuyerYellowPagesClient client;
  final VoidCallback onClaimOrUpgrade;
  final VoidCallback onRequestDispatch;

  @override
  Widget build(BuildContext context) {
    final companyId = '${entry['companyId'] ?? entry['id'] ?? ''}'.trim();
    final companyName = '${entry['companyName'] ?? 'Service Provider'}'.trim();
    final effectiveTier = '${entry['effectiveTier'] ?? 'free_verified'}';
    final isFeatured = effectiveTier == 'featured_platinum';
    final isPaid = isFeatured || effectiveTier == 'paid_verified';
    final claimable = entry['claimable'] == true || !isPaid;

    final city = '${entry['city'] ?? ''}'.trim();
    final region = '${entry['regionCode'] ?? ''}'.trim();
    final country = '${entry['countryCode'] ?? ''}'.trim();
    final location =
        [city, region, country].where((s) => s.isNotEmpty).join(', ');
    final phone = '${entry['publicPhone'] ?? ''}'.trim();
    final tollFree = '${entry['tollFreePhone'] ?? ''}'.trim();
    final email = '${entry['publicEmail'] ?? ''}'.trim();
    final website = isPaid ? '${entry['website'] ?? ''}'.trim() : '';
    final description = '${entry['description'] ?? ''}'.trim();
    final categories = _asStringList(entry['categories']);
    final services = _asStringList(entry['services']);
    final basins = _asStringList(entry['basins']);
    final certifications = _asStringList(entry['certifications']);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 30),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _TierBadge(
                  label: isFeatured
                      ? 'FEATURED PARTNER'
                      : isPaid
                          ? 'VERIFIED PRO'
                          : 'VERIFIED DIRECTORY',
                  color: isFeatured
                      ? PipeBuyerColors.orange
                      : isPaid
                          ? PipeBuyerColors.industrialBlue
                          : const Color(0xFF475569),
                ),
                if (entry['emergency24x7'] == true)
                  const _TierBadge(
                    label: '24/7 EMERGENCY CALLOUT',
                    color: PipeBuyerColors.success,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              companyName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                [location, if (basins.isNotEmpty) basins.join(' • ')]
                    .join('  |  '),
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(description, style: const TextStyle(height: 1.4)),
            ],
            if (categories.isNotEmpty || services.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Service Categories & Capabilities',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...categories.map(
                    (c) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  ...services
                      .where((s) => !categories.contains(s))
                      .map(
                        (s) => Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xFFF1F5F9),
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                ],
              ),
            ],
            if (certifications.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: certifications
                    .map(
                      (c) => _TierBadge(
                        label: '✓ $c',
                        color: PipeBuyerColors.success,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const Divider(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (phone.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () {
                      if (companyId.isNotEmpty) {
                        client.recordLeadInteraction(
                          companyId: companyId,
                          interactionType: 'call_click',
                        );
                      }
                      launchUrl(Uri(scheme: 'tel', path: phone));
                    },
                    icon: const Icon(Icons.call),
                    label: Text('Call $phone'),
                  ),
                if (isPaid && tollFree.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () =>
                        launchUrl(Uri(scheme: 'tel', path: tollFree)),
                    icon: const Icon(Icons.support_agent_outlined),
                    label: Text('Toll-Free: $tollFree'),
                  ),
                if (isPaid && email.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () =>
                        launchUrl(Uri(scheme: 'mailto', path: email)),
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email Dispatch'),
                  ),
                if (isPaid && website.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _launchWebsite(website),
                    icon: const Icon(Icons.language),
                    label: const Text('Visit Website'),
                  ),
                if (isPaid)
                  FilledButton.tonalIcon(
                    onPressed: onRequestDispatch,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Request Service / RFQ'),
                  ),
                if (claimable)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PipeBuyerColors.orange,
                      side: const BorderSide(color: PipeBuyerColors.orange),
                    ),
                    onPressed: onClaimOrUpgrade,
                    icon: const Icon(Icons.trending_up_rounded),
                    label: const Text(
                      r'Own this business? Claim & Upgrade (from $24/mo)',
                      style: TextStyle(fontWeight: FontWeight.w800),
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

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class _EmptyDirectoryState extends StatelessWidget {
  const _EmptyDirectoryState({
    required this.hasFilters,
    required this.onResetFilters,
    required this.onListServices,
    required this.onRequestDispatch,
  });

  final bool hasFilters;
  final VoidCallback onResetFilters;
  final VoidCallback onListServices;
  final VoidCallback onRequestDispatch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size: 54,
                    color: PipeBuyerColors.industrialBlue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasFilters
                        ? 'No verified providers matched these filters'
                        : 'North America Oil & Gas Service Directory',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasFilters
                        ? 'Broaden your region, basin, or service keyword, or post a live service request in Dispatch so nearby providers can quote directly.'
                        : 'Verified North American Oil & Gas service businesses appear here ranked by Priority Tier.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: PipeBuyerColors.muted),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      if (hasFilters)
                        OutlinedButton.icon(
                          onPressed: onResetFilters,
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('Reset Filters'),
                        ),
                      FilledButton.icon(
                        onPressed: onListServices,
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: const Text('List Services'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onRequestDispatch,
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: const Text('Post Dispatch Request'),
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
}

List<String> _asStringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

Future<void> _launchWebsite(String website) async {
  final value = website.trim();
  final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
