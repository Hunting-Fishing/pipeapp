import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_dispatch_request_service_page.dart';
import 'pipebuyer_contact_center_dashboard.dart';
import 'pipebuyer_country_flag_icon.dart';
import 'pipebuyer_list_services_page.dart';
import 'pipebuyer_site_footer.dart';
import 'pipebuyer_yellow_pages_client.dart';
import 'pipebuyer_yellow_pages_taxonomy.dart';

enum YellowPagesViewMode { grid, lines }

class PipeBuyerYellowPagesDirectoryPage extends StatefulWidget {
  const PipeBuyerYellowPagesDirectoryPage({
    super.key,
    this.initialQuery = '',
    this.initialCategoryCode = '',
    this.initialContinentCode = '',
    this.initialCountryCode = '',
    this.initialViewMode = YellowPagesViewMode.grid,
    this.client,
  });

  final String initialQuery;
  final String initialCategoryCode;
  final String initialContinentCode;
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
  Timer? _debounce;

  // View & Grid density state
  YellowPagesViewMode _viewMode = YellowPagesViewMode.grid;
  int?
      _manualGridColumns; // null => responsive Auto (4-6 on desktop, 1-3 on mobile/tablet)

  // Unified Filter & Sort state
  String _continentCode = '';
  String _countryCode = '';
  String _regionCode = '';
  String _city = '';
  String _cityCountryCode = '';
  String _cityRegionCode = '';
  String _categoryCode = '';
  String _basin = '';
  String _certification = '';
  String _tierFilter = '';
  String _startsWith = '';
  String _sortBy = 'priority';
  bool _emergency24x7 = false;
  bool _paidOnly = false;
  bool _hasTollFree = false;

  // Results & live database facet counts state
  bool _loading = false;
  bool _canAccessContactCenter = false;
  String? _error;
  int _totalMatched = 0;
  String? _nextCursor;
  List<String> _expandedCategories = const <String>[];
  List<Map<String, dynamic>> _entries = const <Map<String, dynamic>>[];
  PipeBuyerYellowPagesDirectoryCounts _directoryCounts =
      PipeBuyerYellowPagesDirectoryCounts.empty;

  static const _alphabet = <String>[
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '#',
  ];

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PipeBuyerYellowPagesClient();
    _viewMode = widget.initialViewMode;
    _searchController = TextEditingController(text: widget.initialQuery);
    _categoryCode = widget.initialCategoryCode;
    _continentCode = widget.initialContinentCode;
    _countryCode = widget.initialCountryCode;
    _load(reset: true);
    _loadDirectoryCounts();
    _refreshStaffAccess();
  }

  Future<void> _loadDirectoryCounts() async {
    try {
      final counts = await _client.getDirectoryCounts();
      if (!mounted) return;
      setState(() {
        _directoryCounts = counts;
      });
    } catch (_) {
      // Directory still functions with static hub fallback if counts are unavailable.
    }
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
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _continentCode.isNotEmpty ||
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

  int get _moreFiltersCount {
    var count = 0;
    if (_basin.isNotEmpty) count++;
    if (_certification.isNotEmpty) count++;
    if (_tierFilter.isNotEmpty || _paidOnly) count++;
    if (_emergency24x7) count++;
    if (_hasTollFree) count++;
    return count;
  }

  void _resetAllFilters() {
    _searchController.clear();
    setState(() {
      _continentCode = '';
      _countryCode = '';
      _regionCode = '';
      _city = '';
      _cityCountryCode = '';
      _cityRegionCode = '';
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
      final effectiveCountryCode =
          _countryCode.isNotEmpty ? _countryCode : _cityCountryCode;
      final effectiveRegionCode =
          _regionCode.isNotEmpty ? _regionCode : _cityRegionCode;
      final page = await _client.searchPublic(
        query: _searchController.text.trim(),
        continentCode: _continentCode,
        countryCode: effectiveCountryCode,
        regionCode: effectiveRegionCode,
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
        pageSize:
            60, // LCM(4, 5, 6) = 60 so 4/5/6-col grids always fill complete rows
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
    if (width >= 480) return 2;
    return 1;
  }

  Future<void> _openListServices() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PipeBuyerListServicesPage(),
      ),
    );
    if (submitted == true && mounted) {
      _load(reset: true);
      _loadDirectoryCounts();
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

  Future<void> _openServicePicker() async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => _ServicePickerDialog(
        selectedCode: _categoryCode,
        counts: _directoryCounts,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _categoryCode = chosen == '__all__' ? '' : chosen);
    _load(reset: true);
  }

  Future<void> _openRegionPicker() async {
    final chosen = await showDialog<
        ({String continentCode, String countryCode, String regionCode})>(
      context: context,
      builder: (ctx) => _RegionPickerDialog(
        selectedContinentCode: _continentCode,
        selectedCountryCode: _countryCode,
        selectedRegionCode: _regionCode,
        counts: _directoryCounts,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _continentCode = chosen.continentCode;
      _countryCode = chosen.countryCode;
      _regionCode = chosen.regionCode;
      _cityCountryCode = '';
      _cityRegionCode = '';
      if (_city.isNotEmpty) {
        if (_directoryCounts.hasCounts) {
          final matchingTowns = _directoryCounts.townsForLocation(
            continentCode: _continentCode,
            countryCode: _countryCode,
            regionCode: _regionCode,
          );
          if (!matchingTowns.any(
            (t) => t.city.toLowerCase() == _city.toLowerCase(),
          )) {
            _city = '';
          }
        } else {
          final matchingHubs = PipeBuyerYellowPagesTaxonomy.hubsForLocation(
            continentCode: _continentCode,
            countryCode: _countryCode,
            regionCode: _regionCode,
          );
          if (matchingHubs.isNotEmpty &&
              !matchingHubs.any(
                (h) => h.city.toLowerCase() == _city.toLowerCase(),
              )) {
            _city = '';
          }
        }
      }
    });
    _load(reset: true);
  }

  Future<void> _openTownPicker() async {
    final List<YellowPagesTownCount> townOptions;
    if (_directoryCounts.hasCounts) {
      townOptions = _directoryCounts.townsForLocation(
        continentCode: _continentCode,
        countryCode: _countryCode,
        regionCode: _regionCode,
      );
    } else {
      final hubs = PipeBuyerYellowPagesTaxonomy.hubsForLocation(
        continentCode: _continentCode,
        countryCode: _countryCode,
        regionCode: _regionCode,
      );
      townOptions = hubs
          .map(
            (h) => YellowPagesTownCount(
              city: h.city,
              regionCode: h.regionCode,
              countryCode: h.countryCode,
            ),
          )
          .toList(growable: false);
    }
    final areaBusinessTotal = _directoryCounts.hasCounts
        ? _directoryCounts.countForLocation(
            continentCode: _continentCode,
            countryCode: _countryCode,
            regionCode: _regionCode,
          )
        : null;
    final chosen = await showDialog<
        ({String city, String? countryCode, String? regionCode})>(
      context: context,
      builder: (ctx) => _TownPickerDialog(
        selectedCity: _city,
        towns: townOptions,
        areaBusinessTotal: areaBusinessTotal,
        continentCode: _continentCode,
        countryCode: _countryCode,
        regionCode: _regionCode,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (chosen.city == '__all__' || chosen.city.trim().isEmpty) {
        _city = '';
        _cityCountryCode = '';
        _cityRegionCode = '';
      } else {
        _city = chosen.city.trim();
        _cityCountryCode = chosen.countryCode?.trim() ?? '';
        _cityRegionCode = chosen.regionCode?.trim() ?? '';
      }
    });
    _load(reset: true);
  }

  Future<void> _openAlphabeticalAndSortPicker() async {
    final chosen = await showDialog<({String startsWith, String sortBy})>(
      context: context,
      builder: (ctx) => _AlphabeticalAndSortDialog(
        selectedStartsWith: _startsWith,
        selectedSortBy: _sortBy,
        alphabet: _alphabet,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _startsWith = chosen.startsWith;
      _sortBy = chosen.sortBy;
    });
    _load(reset: true);
  }

  Future<void> _openMoreFiltersPicker() async {
    final chosen = await showDialog<_MoreFiltersResult>(
      context: context,
      builder: (ctx) => _MoreFiltersDialog(
        basin: _basin,
        certification: _certification,
        tierFilter: _tierFilter,
        emergency24x7: _emergency24x7,
        paidOnly: _paidOnly,
        hasTollFree: _hasTollFree,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _basin = chosen.basin;
      _certification = chosen.certification;
      _tierFilter = chosen.tierFilter;
      _emergency24x7 = chosen.emergency24x7;
      _paidOnly = chosen.paidOnly;
      _hasTollFree = chosen.hasTollFree;
    });
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactAppBar = screenWidth < 680;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        leading:
            !Navigator.of(context).canPop() && GoRouter.maybeOf(context) != null
                ? IconButton(
                    tooltip: 'Back to Pipe Buyer',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => GoRouter.of(context).go('/'),
                  )
                : null,
        title: Text(
          compactAppBar
              ? 'OILFIELD DIRECTORY'
              : 'PIPEBUYER OILFIELD DIRECTORY • SEARCH SERVICES',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            fontSize: compactAppBar ? 15 : 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                visualDensity: compactAppBar
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                padding: EdgeInsets.symmetric(
                  horizontal: compactAppBar ? 10 : 14,
                ),
              ),
              onPressed: _openListServices,
              icon: const Icon(Icons.workspace_premium_outlined, size: 17),
              label: Text(
                compactAppBar ? 'List' : 'List Services',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (_canAccessContactCenter)
            IconButton(
              tooltip: 'Directory Admin & Contact Center',
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
              // ONE Unified, Wrapping, Mobile-Responsive Filter Panel
              _UnifiedDirectoryFilterPanel(
                controller: _searchController,
                categoryCode: _categoryCode,
                continentCode: _continentCode,
                countryCode: _countryCode,
                regionCode: _regionCode,
                city: _city,
                cityCountryCode: _cityCountryCode,
                startsWith: _startsWith,
                sortBy: _sortBy,
                moreFiltersCount: _moreFiltersCount,
                hasActiveFilters: _hasActiveFilters,
                onSearchChanged: _onSearchChanged,
                onClearSearch: () {
                  _searchController.clear();
                  setState(() {});
                  _load(reset: true);
                },
                onTapService: _openServicePicker,
                onTapRegion: _openRegionPicker,
                onTapTown: _openTownPicker,
                onTapAlphabetical: _openAlphabeticalAndSortPicker,
                onTapMoreFilters: _openMoreFiltersPicker,
                onResetAll: _resetAllFilters,
                onListServices: _openListServices,
              ),
              // Active Filter Wrapping Strip (only shown when filters are active)
              if (_hasActiveFilters)
                _ActiveFilterBreadcrumbStrip(
                  continentCode: _continentCode,
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
                  onClearContinent: () {
                    setState(() {
                      _continentCode = '';
                      _countryCode = '';
                      _regionCode = '';
                    });
                    _load(reset: true);
                  },
                  onClearCountry: () {
                    setState(() {
                      _countryCode = '';
                      _regionCode = '';
                    });
                    _load(reset: true);
                  },
                  onClearRegion: () {
                    setState(() => _regionCode = '');
                    _load(reset: true);
                  },
                  onClearCity: () {
                    setState(() {
                      _city = '';
                      _cityCountryCode = '';
                      _cityRegionCode = '';
                    });
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
                  onClearSort: () {
                    setState(() => _sortBy = 'priority');
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
                  onResetAll: _resetAllFilters,
                ),
              // Results Toolbar: Count + Mobile-Responsive View Mode & Desktop 4-6 Grid Density Switcher
              LayoutBuilder(
                builder: (context, barConstraints) {
                  final wideToolbar = barConstraints.maxWidth >= 980;
                  final compactBar = barConstraints.maxWidth < 560;
                  final autoCols = _resolveGridColumns(barConstraints.maxWidth);
                  return Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: compactBar ? 12 : 14,
                      vertical: 8,
                    ),
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
                                compactBar
                                    ? '${_formatCount(_totalMatched)} verified providers'
                                    : '${_formatCount(_totalMatched)} verified service provider${_totalMatched == 1 ? '' : 's'}'
                                        '${_expandedCategories.isNotEmpty ? ' • Smart-matched categories' : ' • Featured -> Pro -> Verified'}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w800,
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
                              compact: compactBar,
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
                            onListServices: _openListServices,
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
                                  onRequestDispatch: _openDispatchRequest,
                                );
                              }
                              final cols =
                                  _resolveGridColumns(viewport.maxWidth);
                              return CustomScrollView(
                                slivers: [
                                  SliverPadding(
                                    padding: EdgeInsets.fromLTRB(
                                      cols == 1 ? 10 : 14,
                                      12,
                                      cols == 1 ? 10 : 14,
                                      18,
                                    ),
                                    sliver: SliverGrid(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: cols,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        mainAxisExtent: cols == 1
                                            ? 222
                                            : (cols >= 5 ? 236 : 244),
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
                                  const SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        14,
                                        12,
                                        14,
                                        28,
                                      ),
                                      child: PipeBuyerSiteFooter(
                                        currentSurface:
                                            PipeBuyerFooterSurface.directory,
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

// ============================================================================
// ONE UNIFIED, WRAPPING, MOBILE-RESPONSIVE FILTER PANEL
// ============================================================================
class _UnifiedDirectoryFilterPanel extends StatelessWidget {
  const _UnifiedDirectoryFilterPanel({
    required this.controller,
    required this.categoryCode,
    required this.continentCode,
    required this.countryCode,
    required this.regionCode,
    required this.city,
    this.cityCountryCode = '',
    required this.startsWith,
    required this.sortBy,
    required this.moreFiltersCount,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onTapService,
    required this.onTapRegion,
    required this.onTapTown,
    required this.onTapAlphabetical,
    required this.onTapMoreFilters,
    required this.onResetAll,
    required this.onListServices,
  });

  final TextEditingController controller;
  final String categoryCode;
  final String continentCode;
  final String countryCode;
  final String regionCode;
  final String city;
  final String cityCountryCode;
  final String startsWith;
  final String sortBy;
  final int moreFiltersCount;
  final bool hasActiveFilters;

  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onTapService;
  final VoidCallback onTapRegion;
  final VoidCallback onTapTown;
  final VoidCallback onTapAlphabetical;
  final VoidCallback onTapMoreFilters;
  final VoidCallback onResetAll;
  final VoidCallback onListServices;

  String _serviceValueLabel() {
    if (categoryCode.isEmpty) return 'All Services (24 Sectors)';
    final cat = PipeBuyerYellowPagesTaxonomy.byCode(categoryCode);
    return cat?.label ?? categoryCode;
  }

  String _regionValueLabel() {
    if (regionCode.isNotEmpty) {
      for (final r in PipeBuyerYellowPagesTaxonomy.regions) {
        if (r.regionCode == regionCode &&
            (countryCode.isEmpty || r.countryCode == countryCode)) {
          return '${r.name} (${r.regionCode}, ${r.countryCode})';
        }
      }
      return countryCode.isNotEmpty ? '$regionCode, $countryCode' : regionCode;
    }
    if (countryCode.isNotEmpty) {
      final country = PipeBuyerYellowPagesTaxonomy.countryByCode(countryCode);
      return country != null
          ? '${country.name} (${country.code})'
          : 'Country: $countryCode';
    }
    if (continentCode.isNotEmpty) {
      final cont = PipeBuyerYellowPagesTaxonomy.continentByCode(continentCode);
      return cont != null ? 'All ${cont.label}' : continentCode;
    }
    return 'All Global (Worldwide)';
  }

  String _townValueLabel() {
    if (city.isEmpty) return 'All Towns & Cities';
    return city;
  }

  Widget? _townFlagIcon() {
    if (city.isEmpty) return null;
    final resolvedCountry =
        countryCode.isNotEmpty ? countryCode : cityCountryCode;
    if (resolvedCountry.isNotEmpty) {
      return PipeBuyerCountryFlagIcon(
        countryCode: resolvedCountry,
        width: 19,
        height: 13,
      );
    }
    final q = city.trim().toLowerCase();
    for (final hub in PipeBuyerYellowPagesTaxonomy.oilfieldHubs) {
      if (hub.city.toLowerCase() == q) {
        return PipeBuyerCountryFlagIcon(
          countryCode: hub.countryCode,
          width: 19,
          height: 13,
        );
      }
    }
    return null;
  }

  String _alphabeticalValueLabel() {
    final sortLabel = switch (sortBy) {
      'name_asc' => 'A → Z',
      'name_desc' => 'Z → A',
      'city_asc' => 'By Town A → Z',
      'region_asc' => 'By Region',
      _ => 'Priority Ranked',
    };
    if (startsWith.isNotEmpty) {
      final letterLabel = startsWith == '#' ? '0–9' : '"$startsWith"';
      return 'Starts with $letterLabel • $sortLabel';
    }
    return sortBy == 'priority' ? 'All (A–Z) • Priority' : 'All • $sortLabel';
  }

  String _moreFiltersValueLabel() {
    if (moreFiltersCount == 0) return 'Basin, 24/7 & Safety Certs';
    return '$moreFiltersCount Active Filter${moreFiltersCount == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedCat = PipeBuyerYellowPagesTaxonomy.byCode(categoryCode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0E1B2E),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final showPromoLink = width >= 760;

          // Responsive wrapping column count for the unified filter dropdowns:
          // Desktop (>=1180): 5 per row
          // Tablet (740..1179): 3 per row
          // Phone (380..739): 2 per row
          // Very narrow (<380): 1 per row
          const spacing = 8.0;
          final filterCols = width >= 1180
              ? 5
              : width >= 740
                  ? 3
                  : width >= 380
                      ? 2
                      : 1;
          final itemWidth = (width - (spacing * (filterCols - 1))) / filterCols;

          return Column(
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
                  Expanded(
                    child: Text(
                      width < 560
                          ? 'PipeBuyer Global Oilfield Directory'
                          : 'PipeBuyer Oilfield Directory — Global Oil & Gas Services (Worldwide)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: width < 560 ? 13.5 : 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (showPromoLink)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amberAccent,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onListServices,
                      icon: const Icon(Icons.campaign_outlined, size: 17),
                      label: const Text(
                        r'List Your Business (from $24/mo) →',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Row 1: Full-Width Search Input
              SizedBox(
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
                    hintText: width < 560
                        ? 'Search company, phone, country, town, or service...'
                        : 'Search company name, phone, country, town/city, or service (e.g. Hydrovac, OCTG, Nisku, Midland, Aberdeen, Abu Dhabi)...',
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
              const SizedBox(height: 8),
              // Row 2: ONE Proper Unified Selectable Filter Area (Wraps cleanly across screen sizes)
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _FilterSelectBox(
                      label: 'FILTER BY SERVICE',
                      value: _serviceValueLabel(),
                      icon: selectedCat != null
                          ? PipeBuyerYellowPagesTaxonomy.iconForCategory(
                              selectedCat.code,
                            )
                          : Icons.handyman_outlined,
                      active: categoryCode.isNotEmpty,
                      onTap: onTapService,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _FilterSelectBox(
                      label: 'WORLD REGION & COUNTRY',
                      value: _regionValueLabel(),
                      icon: Icons.public_rounded,
                      leading: countryCode.isNotEmpty
                          ? PipeBuyerCountryFlagIcon(
                              countryCode: countryCode,
                              width: 20,
                              height: 14,
                            )
                          : null,
                      active: continentCode.isNotEmpty ||
                          countryCode.isNotEmpty ||
                          regionCode.isNotEmpty,
                      onTap: onTapRegion,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _FilterSelectBox(
                      label: 'FILTER BY TOWN / CITY',
                      value: _townValueLabel(),
                      icon: Icons.location_city_outlined,
                      leading: _townFlagIcon(),
                      active: city.isNotEmpty,
                      onTap: onTapTown,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _FilterSelectBox(
                      label: 'ALPHABETICAL & SORT',
                      value: _alphabeticalValueLabel(),
                      icon: Icons.sort_by_alpha_rounded,
                      active: startsWith.isNotEmpty || sortBy != 'priority',
                      onTap: onTapAlphabetical,
                    ),
                  ),
                  SizedBox(
                    width:
                        filterCols == 3 ? (itemWidth * 2 + spacing) : itemWidth,
                    child: _FilterSelectBox(
                      label: 'BASIN & OPTIONS',
                      value: _moreFiltersValueLabel(),
                      icon: Icons.tune_rounded,
                      active: moreFiltersCount > 0,
                      onTap: onTapMoreFilters,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterSelectBox extends StatelessWidget {
  const _FilterSelectBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.active,
    required this.onTap,
    this.leading,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? PipeBuyerColors.orange.withValues(alpha: 0.22)
          : const Color(0xFF172942),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? PipeBuyerColors.orange
                  : Colors.white.withValues(alpha: 0.18),
              width: active ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              leading ??
                  Icon(
                    icon,
                    size: 17,
                    color: active ? Colors.amberAccent : Colors.white70,
                  ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 0.45,
                        fontWeight: FontWeight.w900,
                        color: active ? Colors.amberAccent : Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewModeSwitcher extends StatelessWidget {
  const _ViewModeSwitcher({
    required this.mode,
    required this.onChanged,
    this.compact = false,
  });

  final YellowPagesViewMode mode;
  final ValueChanged<YellowPagesViewMode> onChanged;
  final bool compact;

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
            label: compact ? 'Grid' : 'Grid View',
            selected: mode == YellowPagesViewMode.grid,
            onTap: () => onChanged(YellowPagesViewMode.grid),
          ),
          _ModeBtn(
            icon: Icons.view_headline_rounded,
            label: compact ? 'Lines' : 'Lines View',
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
        label:
            manualColumns == null ? 'Auto ($resolvedAutoColumns/row)' : 'Auto',
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
    required this.continentCode,
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
    required this.onClearContinent,
    required this.onClearCountry,
    required this.onClearRegion,
    required this.onClearCity,
    required this.onClearCategory,
    required this.onClearBasin,
    required this.onClearCertification,
    required this.onClearTier,
    required this.onClearStartsWith,
    required this.onClearSort,
    required this.onClearEmergency,
    required this.onClearTollFree,
    required this.onResetAll,
  });

  final String continentCode;
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

  final VoidCallback onClearContinent;
  final VoidCallback onClearCountry;
  final VoidCallback onClearRegion;
  final VoidCallback onClearCity;
  final VoidCallback onClearCategory;
  final VoidCallback onClearBasin;
  final VoidCallback onClearCertification;
  final VoidCallback onClearTier;
  final VoidCallback onClearStartsWith;
  final VoidCallback onClearSort;
  final VoidCallback onClearEmergency;
  final VoidCallback onClearTollFree;
  final VoidCallback onResetAll;

  @override
  Widget build(BuildContext context) {
    final activeCountry =
        PipeBuyerYellowPagesTaxonomy.countryByCode(countryCode);
    final activeContinent =
        PipeBuyerYellowPagesTaxonomy.continentByCode(continentCode);

    final chips = <Widget>[
      if (categoryCode.isNotEmpty)
        _RemovableFilterChip(
          label:
              'Service: ${PipeBuyerYellowPagesTaxonomy.byCode(categoryCode)?.label ?? categoryCode}',
          onDeleted: onClearCategory,
        ),
      if (continentCode.isNotEmpty && countryCode.isEmpty)
        _RemovableFilterChip(
          label: 'Region: ${activeContinent?.label ?? continentCode}',
          onDeleted: onClearContinent,
        ),
      if (countryCode.isNotEmpty && regionCode.isEmpty)
        _RemovableFilterChip(
          avatar: PipeBuyerCountryFlagIcon(
            countryCode: countryCode,
            width: 16,
            height: 11,
          ),
          label: activeCountry != null
              ? '${activeCountry.name} (${activeCountry.code})'
              : countryCode,
          onDeleted: onClearCountry,
        ),
      if (regionCode.isNotEmpty)
        _RemovableFilterChip(
          avatar: countryCode.isNotEmpty
              ? PipeBuyerCountryFlagIcon(
                  countryCode: countryCode,
                  width: 16,
                  height: 11,
                )
              : null,
          label:
              'Region: $regionCode${countryCode.isNotEmpty ? ' ($countryCode)' : ''}',
          onDeleted: onClearRegion,
        ),
      if (city.isNotEmpty)
        _RemovableFilterChip(label: 'Town: $city', onDeleted: onClearCity),
      if (startsWith.isNotEmpty)
        _RemovableFilterChip(
          label: 'Starts with "${startsWith == '#' ? '0-9' : startsWith}"',
          onDeleted: onClearStartsWith,
        ),
      if (sortBy != 'priority')
        _RemovableFilterChip(
          label: switch (sortBy) {
            'name_asc' => 'Sort: A → Z',
            'name_desc' => 'Sort: Z → A',
            'city_asc' => 'Sort: By Town A → Z',
            _ => 'Sort: By Region',
          },
          onDeleted: onClearSort,
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
              : 'Featured & Pro',
          onDeleted: onClearTier,
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

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: onResetAll,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 15),
            label: const Text(
              'Clear All Filters',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemovableFilterChip extends StatelessWidget {
  const _RemovableFilterChip({
    required this.label,
    required this.onDeleted,
    this.avatar,
  });

  final String label;
  final VoidCallback onDeleted;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Colors.white,
      avatar: avatar,
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
// 1–6 COLUMN RESPONSIVE GRID CARD (NO CLAIM BUTTON, CLEAN WRAPPING TAGS)
// ============================================================================
class _GridCompanyCard extends StatelessWidget {
  const _GridCompanyCard({
    required this.entry,
    required this.compact,
    required this.client,
    required this.onOpenDetails,
    required this.onRequestDispatch,
  });

  final Map<String, dynamic> entry;
  final bool compact;
  final PipeBuyerYellowPagesClient client;
  final VoidCallback onOpenDetails;
  final VoidCallback onRequestDispatch;

  @override
  Widget build(BuildContext context) {
    final companyId = '${entry['companyId'] ?? entry['id'] ?? ''}'.trim();
    final companyName = '${entry['companyName'] ?? 'Service Provider'}'.trim();
    final effectiveTier = '${entry['effectiveTier'] ?? 'free_verified'}';
    final isFeatured = effectiveTier == 'featured_platinum';
    final isPaid = isFeatured || effectiveTier == 'paid_verified';

    final city = '${entry['city'] ?? ''}'.trim();
    final region = '${entry['regionCode'] ?? ''}'.trim();
    final country = '${entry['countryCode'] ?? ''}'.trim();
    final locShort = PipeBuyerYellowPagesTaxonomy.formatLocationLabel(
      city: city,
      regionCode: region,
      countryCode: country,
    );
    final regionCountryBadge =
        [region, country].where((s) => s.isNotEmpty).join(' • ');

    final phone = '${entry['publicPhone'] ?? ''}'.trim();
    final website = isPaid ? '${entry['website'] ?? ''}'.trim() : '';
    final emergency24x7 = entry['emergency24x7'] == true;

    final categories = _asStringList(entry['categories']);
    final services = _asStringList(entry['services']);
    final basins = _asStringList(entry['basins']);
    final formattedTags = <String>[];
    for (final raw in <String>[...categories, ...services]) {
      final clean = PipeBuyerYellowPagesTaxonomy.conciseCategoryLabel(raw);
      if (clean.isNotEmpty && !formattedTags.contains(clean)) {
        formattedTags.add(clean);
      }
    }
    final shownTags = formattedTags.take(2).toList(growable: false);
    final extraCount = formattedTags.length - shownTags.length;

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
                          if (regionCountryBadge.isNotEmpty ||
                              country.isNotEmpty) ...[
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (country.isNotEmpty) ...[
                                    PipeBuyerCountryFlagIcon(
                                      countryCode: country,
                                      width: 14,
                                      height: 9.5,
                                      borderRadius: 2,
                                    ),
                                    if (regionCountryBadge.isNotEmpty)
                                      const SizedBox(width: 4),
                                  ],
                                  if (regionCountryBadge.isNotEmpty)
                                    Text(
                                      regionCountryBadge,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                ],
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
                      // Row 3: Town + Basin
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
                      // Row 4: Clean Wrapping Service Pills (concise uncut category labels)
                      if (shownTags.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            ...shownTags.map(
                              (tag) => Container(
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
                      // Row 5: Full-Width Call Action Bar (+ Website/RFQ for Paid Pro/Featured)
                      Row(
                        children: [
                          if (phone.isNotEmpty)
                            Expanded(
                              child: SizedBox(
                                height: 32,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isFeatured
                                        ? PipeBuyerColors.orange
                                        : const Color(0xFF0E1B2E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
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
                                      const SizedBox(width: 5),
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
                              ),
                            )
                          else
                            const Expanded(
                              child: Text(
                                'View company details',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: PipeBuyerColors.industrialBlue,
                                ),
                              ),
                            ),
                          if (isPaid && website.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 32,
                              height: 32,
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
                          ],
                          if (isPaid) ...[
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 32,
                              height: 32,
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
                            ),
                          ],
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
// HIGH-DENSITY LINES VIEW (OILFIELD DIRECTORY TABLE + MOBILE LIST)
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
    required this.onRequestDispatch,
  });

  final List<Map<String, dynamic>> entries;
  final double width;
  final bool hasMore;
  final bool loading;
  final PipeBuyerYellowPagesClient client;
  final VoidCallback onLoadMore;
  final ValueChanged<Map<String, dynamic>> onSelectCompany;
  final VoidCallback onRequestDispatch;

  @override
  Widget build(BuildContext context) {
    final wideTable = width >= 840;
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
                  flex: 26,
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
                  flex: 19,
                  child: Text(
                    'TOWN & COUNTRY / REGION',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 15,
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
                  flex: 34,
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
                  width: 156,
                  child: Text(
                    'DIRECT PHONE',
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
            itemCount: entries.length + (hasMore ? 1 : 0) + 1,
            itemBuilder: (context, index) {
              final footerIndex = entries.length + (hasMore ? 1 : 0);
              if (index == footerIndex) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(14, 20, 14, 8),
                  child: PipeBuyerSiteFooter(
                    currentSurface: PipeBuyerFooterSurface.directory,
                  ),
                );
              }
              if (hasMore && index == entries.length) {
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
    required this.onRequestDispatch,
  });

  final Map<String, dynamic> entry;
  final bool even;
  final bool wideTable;
  final PipeBuyerYellowPagesClient client;
  final VoidCallback onTap;
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
    final location = PipeBuyerYellowPagesTaxonomy.formatLocationLabel(
      city: city,
      regionCode: region,
      countryCode: country,
      includeCountryForNorthAmerica: true,
    );

    final basins = _asStringList(entry['basins']);
    final categories = _asStringList(entry['categories']);
    final services = _asStringList(entry['services']);
    final serviceSummary = <String>[
      ...categories.map(PipeBuyerYellowPagesTaxonomy.conciseCategoryLabel),
      ...services.where((s) => !categories.contains(s)),
    ].take(3).join(' • ');
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TierBadge(
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (country.isNotEmpty) ...[
                      PipeBuyerCountryFlagIcon(
                        countryCode: country,
                        width: 15,
                        height: 10.5,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        [
                          location,
                          if (serviceSummary.isNotEmpty) serviceSummary
                        ].where((s) => s.isNotEmpty).join('  •  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
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
                        icon: const Icon(Icons.call, size: 13),
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
                flex: 26,
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
                flex: 19,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Row(
                    children: [
                      if (country.isNotEmpty) ...[
                        PipeBuyerCountryFlagIcon(
                          countryCode: country,
                          width: 16,
                          height: 11,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
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
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 15,
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
                flex: 34,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    serviceSummary.isNotEmpty
                        ? serviceSummary
                        : 'Oilfield Services',
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
                width: 156,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: phone.isNotEmpty
                      ? SizedBox(
                          height: 29,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: isFeatured
                                  ? PipeBuyerColors.orange
                                  : const Color(0xFF0E1B2E),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LIVE DATABASE BUSINESS COUNT BADGE (TOWNS, REGIONS, COUNTRIES & SECTORS)
// ============================================================================
class _DirectoryCountBadge extends StatelessWidget {
  const _DirectoryCountBadge({
    required this.count,
    this.suffix = '',
    this.compact = false,
    this.highlighted = false,
    this.mutedWhenZero = false,
  });

  final int count;
  final String suffix;
  final bool compact;
  final bool highlighted;
  final bool mutedWhenZero;

  static String formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isZero = count <= 0 && mutedWhenZero;
    final formatted = formatNumber(count);
    final text = suffix.isEmpty ? formatted : '$formatted $suffix';

    final bgColor = highlighted
        ? PipeBuyerColors.orange.withValues(alpha: 0.16)
        : isZero
            ? const Color(0xFFF8FAFC)
            : const Color(0xFFEFF6FF);
    final borderColor = highlighted
        ? PipeBuyerColors.orange.withValues(alpha: 0.45)
        : isZero
            ? const Color(0xFFE2E8F0)
            : const Color(0xFFBFDBFE);
    final textColor = highlighted
        ? const Color(0xFF9A3412)
        : isZero
            ? const Color(0xFF94A3B8)
            : const Color(0xFF1E3A8A);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 1.5 : 3,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 10.5 : 11.5,
          fontWeight: FontWeight.w800,
          color: textColor,
          height: 1.15,
        ),
      ),
    );
  }
}

// ============================================================================
// DIALOG 1: SEARCHABLE SERVICE / CATEGORY SELECTOR (FULL NAMES, NO CUTOFFS)
// ============================================================================
class _ServicePickerDialog extends StatefulWidget {
  const _ServicePickerDialog({
    required this.selectedCode,
    this.counts = PipeBuyerYellowPagesDirectoryCounts.empty,
  });

  final String selectedCode;
  final PipeBuyerYellowPagesDirectoryCounts counts;

  @override
  State<_ServicePickerDialog> createState() => _ServicePickerDialogState();
}

class _ServicePickerDialogState extends State<_ServicePickerDialog> {
  final TextEditingController _filterCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _filter.trim().toLowerCase();
    final filtered = PipeBuyerYellowPagesTaxonomy.categories.where((cat) {
      if (q.isEmpty) return true;
      return cat.label.toLowerCase().contains(q) ||
          cat.shortLabel.toLowerCase().contains(q) ||
          cat.sampleServices.any((s) => s.toLowerCase().contains(q));
    }).toList(growable: false);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.handyman_outlined,
                    color: PipeBuyerColors.orange,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Filter by Oilfield Service Category',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop('__all__'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('All Services'),
                        if (widget.counts.hasCounts) ...[
                          const SizedBox(width: 6),
                          _DirectoryCountBadge(
                            count: widget.counts.totalBusinesses,
                            compact: true,
                            highlighted: widget.selectedCode.isEmpty,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _filterCtrl,
                onChanged: (v) => setState(() => _filter = v),
                decoration: InputDecoration(
                  hintText:
                      'Search services (e.g. Towing, Hydrovac, Pipe & OCTG, Welding, Rigs)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _filter.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _filterCtrl.clear();
                            setState(() => _filter = '');
                          },
                          icon: const Icon(Icons.clear, size: 18),
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 680 ? 2 : 1;
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisExtent: 84,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final cat = filtered[idx];
                        final active = cat.code == widget.selectedCode;
                        final catCount = widget.counts.countForCategory(
                          cat.code,
                        );
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.of(context).pop(cat.code),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? PipeBuyerColors.orange
                                      .withValues(alpha: 0.10)
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
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        cat.sampleServices.take(3).join(' • '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.counts.hasCounts) ...[
                                  const SizedBox(width: 8),
                                  _DirectoryCountBadge(
                                    count: catCount,
                                    compact: true,
                                    highlighted: active,
                                    mutedWhenZero: true,
                                  ),
                                ],
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
// DIALOG 2: GLOBAL WORLD REGION, POPULAR QUICK-SEARCH & A–Z COUNTRY SELECTOR
// ============================================================================
class _RegionPickerDialog extends StatefulWidget {
  const _RegionPickerDialog({
    required this.selectedContinentCode,
    required this.selectedCountryCode,
    required this.selectedRegionCode,
    this.counts = PipeBuyerYellowPagesDirectoryCounts.empty,
  });

  final String selectedContinentCode;
  final String selectedCountryCode;
  final String selectedRegionCode;
  final PipeBuyerYellowPagesDirectoryCounts counts;

  @override
  State<_RegionPickerDialog> createState() => _RegionPickerDialogState();
}

class _RegionPickerDialogState extends State<_RegionPickerDialog> {
  String _filter = '';
  late String _activeContinent;
  String _expandedRegionCountryCode = '';

  List<YellowPagesRegionOption> _subRegionsForCountry(String countryCode) {
    final cc = countryCode.trim().toUpperCase();
    if (cc.isEmpty) return const <YellowPagesRegionOption>[];
    final base = PipeBuyerYellowPagesTaxonomy.regionsForCountry(cc);
    if (!widget.counts.hasCounts) return base;
    final known = base.map((r) => r.regionCode.toUpperCase()).toSet();
    final extras = <YellowPagesRegionOption>[];
    final prefix = '$cc:';
    for (final entry in widget.counts.byRegion.entries) {
      if (!entry.key.startsWith(prefix) || entry.value <= 0) continue;
      final rc = entry.key.substring(prefix.length).trim().toUpperCase();
      if (rc.isEmpty || rc == cc || known.contains(rc)) continue;
      known.add(rc);
      extras.add(
        YellowPagesRegionOption(
          countryCode: cc,
          regionCode: rc,
          name: rc,
        ),
      );
    }
    if (extras.isEmpty) return base;
    extras.sort((a, b) => a.name.compareTo(b.name));
    return <YellowPagesRegionOption>[...base, ...extras];
  }

  @override
  void initState() {
    super.initState();
    if (widget.selectedContinentCode.isNotEmpty) {
      _activeContinent = widget.selectedContinentCode;
    } else if (widget.selectedCountryCode.isNotEmpty) {
      final matched = PipeBuyerYellowPagesTaxonomy.countryByCode(
          widget.selectedCountryCode);
      _activeContinent = matched?.continentCode ?? '';
    } else {
      _activeContinent = '';
    }
    if (widget.selectedCountryCode.isNotEmpty &&
        _subRegionsForCountry(widget.selectedCountryCode).isNotEmpty) {
      _expandedRegionCountryCode = widget.selectedCountryCode;
    }
  }

  void _selectLocation({
    required String continentCode,
    required String countryCode,
    required String regionCode,
  }) {
    Navigator.of(context).pop((
      continentCode: continentCode,
      countryCode: countryCode,
      regionCode: regionCode,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final compactDialog = MediaQuery.sizeOf(context).width < 460;
    final hasCounts = widget.counts.hasCounts;
    final q = _filter.trim().toLowerCase();
    final activeContinentMeta =
        PipeBuyerYellowPagesTaxonomy.continentByCode(_activeContinent);
    final alphabeticalCountries =
        PipeBuyerYellowPagesTaxonomy.countriesForContinent(_activeContinent);
    final popularCountries =
        PipeBuyerYellowPagesTaxonomy.popularCountriesForContinent(
      _activeContinent,
    );

    final allowedCountryCodes =
        alphabeticalCountries.map((c) => c.code).toSet();

    final countriesWithSubRegions = alphabeticalCountries
        .where((c) => _subRegionsForCountry(c.code).isNotEmpty)
        .toList(growable: false);

    final subRegionsToDisplay = _expandedRegionCountryCode.isNotEmpty &&
            allowedCountryCodes.contains(_expandedRegionCountryCode)
        ? _subRegionsForCountry(_expandedRegionCountryCode)
        : const <YellowPagesRegionOption>[];

    // Search matches across all 197 countries + provinces/states
    final searchedCountries = q.isEmpty
        ? const <YellowPagesCountryOption>[]
        : PipeBuyerYellowPagesTaxonomy.countries.where((c) {
            return c.name.toLowerCase().contains(q) ||
                c.code.toLowerCase() == q;
          }).toList(growable: false);

    final searchedRegions = q.isEmpty
        ? const <YellowPagesRegionOption>[]
        : PipeBuyerYellowPagesTaxonomy.regions.where((r) {
            return r.name.toLowerCase().contains(q) ||
                r.regionCode.toLowerCase().contains(q) ||
                r.countryCode.toLowerCase() == q;
          }).toList(growable: false);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.public_rounded,
                    color: PipeBuyerColors.orange,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Filter by World Region, Country & State/Province',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // World Continent Tabs (Wraps cleanly on mobile & desktop)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'All Global',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        if (hasCounts) ...[
                          const SizedBox(width: 5),
                          _DirectoryCountBadge(
                            count: widget.counts.totalBusinesses,
                            compact: true,
                            highlighted: _activeContinent.isEmpty,
                          ),
                        ],
                      ],
                    ),
                    selected: _activeContinent.isEmpty,
                    onSelected: (_) => setState(() {
                      _activeContinent = '';
                      _expandedRegionCountryCode = '';
                    }),
                  ),
                  ...PipeBuyerYellowPagesTaxonomy.continents.map((cont) {
                    final selected = _activeContinent == cont.code;
                    return ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cont.shortLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          if (hasCounts) ...[
                            const SizedBox(width: 5),
                            _DirectoryCountBadge(
                              count: widget.counts.countForContinent(cont.code),
                              compact: true,
                              highlighted: selected,
                            ),
                          ],
                        ],
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _activeContinent = cont.code;
                        if (_expandedRegionCountryCode.isNotEmpty) {
                          final nextAllowed = PipeBuyerYellowPagesTaxonomy
                                  .countriesForContinent(cont.code)
                              .any((c) => c.code == _expandedRegionCountryCode);
                          if (!nextAllowed) {
                            _expandedRegionCountryCode = '';
                          }
                        }
                      }),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() => _filter = v),
                decoration: InputDecoration(
                  hintText:
                      'Search country, province, or state (e.g. Canada, Mexico, UAE, Norway, Alberta, Texas)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: q.isNotEmpty
                    ? ListView(
                        children: [
                          if (searchedCountries.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                'MATCHING COUNTRIES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            ...searchedCountries.map((c) {
                              final selected =
                                  widget.selectedCountryCode == c.code &&
                                      widget.selectedRegionCode.isEmpty;
                              final countryCount =
                                  widget.counts.countForCountry(c.code);
                              return ListTile(
                                dense: true,
                                selected: selected,
                                leading: PipeBuyerCountryFlagIcon(
                                  countryCode: c.code,
                                  width: 26,
                                  height: 18,
                                ),
                                title: Text(
                                  '${c.name} (${c.code})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(c.dialCode),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasCounts)
                                      _DirectoryCountBadge(
                                        count: countryCount,
                                        suffix: compactDialog
                                            ? ''
                                            : (countryCount == 1
                                                ? 'business'
                                                : 'businesses'),
                                        compact: compactDialog,
                                        highlighted: selected,
                                        mutedWhenZero: true,
                                      ),
                                    if (c.isPopularOilGas) ...[
                                      if (hasCounts) const SizedBox(width: 6),
                                      const _TierBadge(
                                        label: 'OIL & GAS',
                                        color: PipeBuyerColors.orange,
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () => _selectLocation(
                                  continentCode: c.continentCode,
                                  countryCode: c.code,
                                  regionCode: '',
                                ),
                              );
                            }),
                          ],
                          if (searchedRegions.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(top: 10, bottom: 6),
                              child: Text(
                                'MATCHING PROVINCES & STATES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            ...searchedRegions.map((r) {
                              final selected = widget.selectedRegionCode ==
                                      r.regionCode &&
                                  widget.selectedCountryCode == r.countryCode;
                              final regionCount = widget.counts.countForRegion(
                                r.countryCode,
                                r.regionCode,
                              );
                              return ListTile(
                                dense: true,
                                selected: selected,
                                leading: PipeBuyerCountryFlagIcon(
                                  countryCode: r.countryCode,
                                  width: 24,
                                  height: 16,
                                ),
                                title: Text(
                                  '${r.name} (${r.regionCode}, ${r.countryCode})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                trailing: hasCounts
                                    ? _DirectoryCountBadge(
                                        count: regionCount,
                                        suffix: compactDialog
                                            ? ''
                                            : (regionCount == 1
                                                ? 'business'
                                                : 'businesses'),
                                        compact: compactDialog,
                                        highlighted: selected,
                                        mutedWhenZero: true,
                                      )
                                    : null,
                                onTap: () => _selectLocation(
                                  continentCode: _activeContinent,
                                  countryCode: r.countryCode,
                                  regionCode: r.regionCode,
                                ),
                              );
                            }),
                          ],
                          if (searchedCountries.isEmpty &&
                              searchedRegions.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  'No matching country, province, or state found.',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              ),
                            ),
                        ],
                      )
                    : ListView(
                        children: [
                          // 1. Apply Entire World Region / Continent Row
                          ListTile(
                            dense: true,
                            tileColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            leading: const Icon(
                              Icons.language_rounded,
                              color: PipeBuyerColors.industrialBlue,
                            ),
                            title: Text(
                              _activeContinent.isEmpty
                                  ? 'Show All Global Countries (Worldwide • ${alphabeticalCountries.length} Countries)'
                                  : 'Show All ${activeContinentMeta?.label ?? _activeContinent} (${alphabeticalCountries.length} Countries)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasCounts) ...[
                                  _DirectoryCountBadge(
                                    count: widget.counts.countForContinent(
                                      _activeContinent,
                                    ),
                                    suffix: compactDialog ? '' : 'businesses',
                                    compact: compactDialog,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                ),
                              ],
                            ),
                            onTap: () => _selectLocation(
                              continentCode: _activeContinent,
                              countryCode: '',
                              regionCode: '',
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 2. Popular Oil & Gas Quick-Search Countries (Pinned at Top!)
                          if (popularCountries.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 15,
                                  color: PipeBuyerColors.orange,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _activeContinent.isEmpty
                                        ? 'POPULAR OIL & GAS COUNTRIES — QUICK SEARCH'
                                        : 'POPULAR ${activeContinentMeta?.shortLabel.toUpperCase() ?? ''} OIL & GAS — QUICK SEARCH',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.45,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: popularCountries.map((c) {
                                final isSelected =
                                    widget.selectedCountryCode == c.code &&
                                        widget.selectedRegionCode.isEmpty;
                                return ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: isSelected
                                      ? PipeBuyerColors.orange
                                          .withValues(alpha: 0.16)
                                      : const Color(0xFFFFF7ED),
                                  side: BorderSide(
                                    color: isSelected
                                        ? PipeBuyerColors.orange
                                        : const Color(0xFFFED7AA),
                                  ),
                                  avatar: PipeBuyerCountryFlagIcon(
                                    countryCode: c.code,
                                    width: 19,
                                    height: 13,
                                  ),
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (hasCounts) ...[
                                        const SizedBox(width: 5),
                                        _DirectoryCountBadge(
                                          count: widget.counts.countForCountry(
                                            c.code,
                                          ),
                                          compact: true,
                                          highlighted: isSelected,
                                        ),
                                      ],
                                    ],
                                  ),
                                  onPressed: () => _selectLocation(
                                    continentCode: _activeContinent,
                                    countryCode: c.code,
                                    regionCode: '',
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // 3. Optional Sub-Region / Province / State Drilldown
                          if (countriesWithSubRegions.isNotEmpty) ...[
                            const Text(
                              'DRILL DOWN BY PROVINCE / STATE / EMIRATE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.45,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: countriesWithSubRegions.map((c) {
                                final expanded =
                                    _expandedRegionCountryCode == c.code;
                                return ChoiceChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: PipeBuyerCountryFlagIcon(
                                    countryCode: c.code,
                                    width: 16,
                                    height: 11,
                                  ),
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${c.name} Regions',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (hasCounts) ...[
                                        const SizedBox(width: 5),
                                        _DirectoryCountBadge(
                                          count: widget.counts.countForCountry(
                                            c.code,
                                          ),
                                          compact: true,
                                          highlighted: expanded,
                                          mutedWhenZero: true,
                                        ),
                                      ],
                                    ],
                                  ),
                                  selected: expanded,
                                  onSelected: (_) => setState(() {
                                    _expandedRegionCountryCode =
                                        expanded ? '' : c.code;
                                  }),
                                );
                              }).toList(growable: false),
                            ),
                            if (subRegionsToDisplay.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: subRegionsToDisplay.map((r) {
                                    final selected =
                                        widget.selectedRegionCode ==
                                                r.regionCode &&
                                            widget.selectedCountryCode ==
                                                r.countryCode;
                                    return ActionChip(
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: selected
                                          ? PipeBuyerColors.industrialBlue
                                              .withValues(alpha: 0.14)
                                          : Colors.white,
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            r.name == r.regionCode
                                                ? r.regionCode
                                                : '${r.name} (${r.regionCode})',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (hasCounts) ...[
                                            const SizedBox(width: 5),
                                            _DirectoryCountBadge(
                                              count:
                                                  widget.counts.countForRegion(
                                                r.countryCode,
                                                r.regionCode,
                                              ),
                                              compact: true,
                                              highlighted: selected,
                                              mutedWhenZero: true,
                                            ),
                                          ],
                                        ],
                                      ),
                                      onPressed: () => _selectLocation(
                                        continentCode: _activeContinent,
                                        countryCode: r.countryCode,
                                        regionCode: r.regionCode,
                                      ),
                                    );
                                  }).toList(growable: false),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                          ],

                          // 4. Complete Alphabetical A–Z Country List (Every country in its alphabetical spot!)
                          Text(
                            _activeContinent.isEmpty
                                ? 'ALL COUNTRIES A–Z (${alphabeticalCountries.length} COUNTRIES)'
                                : '${activeContinentMeta?.label.toUpperCase() ?? _activeContinent.toUpperCase()} COUNTRIES A–Z (${alphabeticalCountries.length} COUNTRIES)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.45,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...alphabeticalCountries.map((c) {
                            final selected =
                                widget.selectedCountryCode == c.code &&
                                    widget.selectedRegionCode.isEmpty;
                            final hasSub =
                                _subRegionsForCountry(c.code).isNotEmpty;
                            final countryCount =
                                widget.counts.countForCountry(c.code);
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              selected: selected,
                              leading: PipeBuyerCountryFlagIcon(
                                countryCode: c.code,
                                width: 26,
                                height: 18,
                              ),
                              title: Text(
                                '${c.name} (${c.code})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                c.isPopularOilGas
                                    ? '${c.dialCode} • Popular Oil & Gas Market'
                                    : c.dialCode,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasCounts)
                                    _DirectoryCountBadge(
                                      count: countryCount,
                                      suffix: compactDialog
                                          ? ''
                                          : (countryCount == 1
                                              ? 'business'
                                              : 'businesses'),
                                      compact: compactDialog,
                                      highlighted: selected,
                                      mutedWhenZero: true,
                                    ),
                                  if (hasSub) ...[
                                    if (hasCounts) const SizedBox(width: 4),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      onPressed: () => setState(() {
                                        _expandedRegionCountryCode =
                                            _expandedRegionCountryCode == c.code
                                                ? ''
                                                : c.code;
                                      }),
                                      child: const Text(
                                        'States',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (selected) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.check_circle,
                                      color: PipeBuyerColors.orange,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () => _selectLocation(
                                continentCode: _activeContinent,
                                countryCode: c.code,
                                regionCode: '',
                              ),
                            );
                          }),
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

// ============================================================================
// DIALOG 3: SEARCHABLE TOWN / CITY INDEX SELECTOR WITH LIVE DATABASE COUNTS
// ============================================================================
enum _TownSortMode { alphabetical, mostBusinesses }

class _TownPickerDialog extends StatefulWidget {
  const _TownPickerDialog({
    required this.selectedCity,
    required this.towns,
    this.areaBusinessTotal,
    this.continentCode = '',
    required this.countryCode,
    required this.regionCode,
  });

  final String selectedCity;
  final List<YellowPagesTownCount> towns;
  final int? areaBusinessTotal;
  final String continentCode;
  final String countryCode;
  final String regionCode;

  @override
  State<_TownPickerDialog> createState() => _TownPickerDialogState();
}

class _TownPickerDialogState extends State<_TownPickerDialog> {
  late final TextEditingController _ctrl;
  String _query = '';
  _TownSortMode _sortMode = _TownSortMode.alphabetical;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _areaScopeLabel() {
    if (widget.regionCode.isNotEmpty) {
      for (final r in PipeBuyerYellowPagesTaxonomy.regions) {
        if (r.regionCode == widget.regionCode &&
            (widget.countryCode.isEmpty ||
                r.countryCode == widget.countryCode)) {
          return '${r.name} (${r.regionCode})';
        }
      }
      return widget.countryCode.isNotEmpty
          ? '${widget.regionCode}, ${widget.countryCode}'
          : widget.regionCode;
    }
    if (widget.countryCode.isNotEmpty) {
      return PipeBuyerYellowPagesTaxonomy.countryByCode(widget.countryCode)
              ?.name ??
          widget.countryCode;
    }
    if (widget.continentCode.isNotEmpty) {
      return PipeBuyerYellowPagesTaxonomy.continentByCode(widget.continentCode)
              ?.label ??
          widget.continentCode;
    }
    return 'Worldwide';
  }

  void _popAllTowns() {
    Navigator.of(context).pop((
      city: '__all__',
      countryCode: null as String?,
      regionCode: null as String?,
    ));
  }

  void _popCustomTown(String cityText) {
    Navigator.of(context).pop((
      city: cityText,
      countryCode: null as String?,
      regionCode: null as String?,
    ));
  }

  void _popTownOption(YellowPagesTownCount town) {
    Navigator.of(context).pop((
      city: town.city,
      countryCode: town.countryCode,
      regionCode: town.regionCode,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final compactDialog = MediaQuery.sizeOf(context).width < 460;
    final trimmed = _query.trim();
    final q = trimmed.toLowerCase();
    final hasTownCounts = widget.towns.any((t) => t.count != null);

    final filtered = widget.towns.where((t) {
      if (q.isEmpty) return true;
      return t.city.toLowerCase().contains(q) ||
          t.regionCode.toLowerCase().contains(q) ||
          t.countryCode.toLowerCase() == q;
    }).toList();

    if (_sortMode == _TownSortMode.mostBusinesses && hasTownCounts) {
      filtered.sort((a, b) {
        final cmp = (b.count ?? 0).compareTo(a.count ?? 0);
        if (cmp != 0) return cmp;
        return a.city.toLowerCase().compareTo(b.city.toLowerCase());
      });
    } else {
      filtered.sort(
        (a, b) => a.city.toLowerCase().compareTo(b.city.toLowerCase()),
      );
    }

    final exactMatch = widget.towns.any(
      (t) => t.city.toLowerCase() == q,
    );

    final int? summaryBusinesses = hasTownCounts
        ? (q.isEmpty && widget.areaBusinessTotal != null
            ? widget.areaBusinessTotal
            : filtered.fold<int>(0, (sum, t) => sum + (t.count ?? 0)))
        : null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_city_outlined,
                    color: PipeBuyerColors.orange,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Filter by Town / City',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _popAllTowns,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('All Towns'),
                        if (widget.areaBusinessTotal != null) ...[
                          const SizedBox(width: 6),
                          _DirectoryCountBadge(
                            count: widget.areaBusinessTotal!,
                            compact: true,
                            highlighted: widget.selectedCity.isEmpty,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (v) {
                  if (v.trim().isEmpty) {
                    _popAllTowns();
                  } else {
                    _popCustomTown(v.trim());
                  }
                },
                decoration: InputDecoration(
                  hintText:
                      'Search or type any town (e.g. Nisku, Midland, Aberdeen, Abu Dhabi, Villahermosa)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear, size: 18),
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Area Summary & Town Sort Mode Strip
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    summaryBusinesses != null
                        ? '${_areaScopeLabel()}: ${_DirectoryCountBadge.formatNumber(filtered.length)} town${filtered.length == 1 ? '' : 's'} • ${_DirectoryCountBadge.formatNumber(summaryBusinesses)} business${summaryBusinesses == 1 ? '' : 'es'} listed'
                        : '${_areaScopeLabel()}: ${_DirectoryCountBadge.formatNumber(filtered.length)} oilfield hubs',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF475569),
                    ),
                  ),
                  if (hasTownCounts)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text(
                            'A–Z',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          selected: _sortMode == _TownSortMode.alphabetical,
                          onSelected: (_) => setState(
                            () => _sortMode = _TownSortMode.alphabetical,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text(
                            'Most Listed',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          selected: _sortMode == _TownSortMode.mostBusinesses,
                          onSelected: (_) => setState(
                            () => _sortMode = _TownSortMode.mostBusinesses,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (trimmed.isNotEmpty && !exactMatch) ...[
                const SizedBox(height: 8),
                ListTile(
                  tileColor: PipeBuyerColors.orange.withValues(alpha: 0.10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  leading: const Icon(
                    Icons.place_outlined,
                    color: PipeBuyerColors.orange,
                  ),
                  title: Text(
                    'Filter by "$trimmed"',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text('Search any town or service area'),
                  onTap: () => _popCustomTown(trimmed),
                ),
              ],
              const SizedBox(height: 6),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No listed towns match your search.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final town = filtered[idx];
                          final selected = town.city.toLowerCase() ==
                              widget.selectedCity.toLowerCase();
                          final locationLabel = compactDialog
                              ? [town.regionCode, town.countryCode]
                                  .where((s) => s.isNotEmpty)
                                  .join(', ')
                              : [
                                  town.regionCode,
                                  PipeBuyerYellowPagesTaxonomy.countryByCode(
                                        town.countryCode,
                                      )?.name ??
                                      town.countryCode,
                                ].where((s) => s.isNotEmpty).join(', ');
                          return ListTile(
                            dense: true,
                            selected: selected,
                            leading: PipeBuyerCountryFlagIcon(
                              countryCode: town.countryCode,
                              width: 22,
                              height: 15,
                            ),
                            title: Text(
                              town.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (town.count != null) ...[
                                  _DirectoryCountBadge(
                                    count: town.count!,
                                    suffix: compactDialog
                                        ? ''
                                        : (town.count == 1
                                            ? 'business'
                                            : 'businesses'),
                                    compact: compactDialog,
                                    highlighted: selected,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  locationLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _popTownOption(town),
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
// DIALOG 4: ALPHABETICAL (A–Z) & SORT ORDER SELECTOR (WRAPPING GRID)
// ============================================================================
class _AlphabeticalAndSortDialog extends StatefulWidget {
  const _AlphabeticalAndSortDialog({
    required this.selectedStartsWith,
    required this.selectedSortBy,
    required this.alphabet,
  });

  final String selectedStartsWith;
  final String selectedSortBy;
  final List<String> alphabet;

  @override
  State<_AlphabeticalAndSortDialog> createState() =>
      _AlphabeticalAndSortDialogState();
}

class _AlphabeticalAndSortDialogState
    extends State<_AlphabeticalAndSortDialog> {
  late String _startsWith;
  late String _sortBy;

  @override
  void initState() {
    super.initState();
    _startsWith = widget.selectedStartsWith;
    _sortBy = widget.selectedSortBy;
  }

  @override
  Widget build(BuildContext context) {
    const sortOptions = <({String value, String label, String subtitle})>[
      (
        value: 'priority',
        label: 'Priority Ranked (Default)',
        subtitle: 'Featured Partners & Verified Pro first, then A–Z',
      ),
      (
        value: 'name_asc',
        label: 'Alphabetical (A → Z)',
        subtitle: 'Sort companies alphabetically from A to Z',
      ),
      (
        value: 'name_desc',
        label: 'Alphabetical (Z → A)',
        subtitle: 'Sort companies in reverse alphabetical order',
      ),
      (
        value: 'city_asc',
        label: 'By Town / City (A → Z)',
        subtitle: 'Group and sort companies by town name A to Z',
      ),
    ];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.sort_by_alpha_rounded,
                    color: PipeBuyerColors.orange,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Alphabetical Filter & Sort Order',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Filter by Company Starting Letter (Wraps A–Z)',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: const Text(
                      'ALL',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    selected: _startsWith.isEmpty,
                    onSelected: (_) => setState(() => _startsWith = ''),
                  ),
                  ...widget.alphabet.map((letter) {
                    final selected = _startsWith == letter;
                    return ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        letter == '#' ? '0–9' : letter,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      selected: selected,
                      onSelected: (_) {
                        Navigator.of(context).pop((
                          startsWith: selected ? '' : letter,
                          sortBy: _sortBy,
                        ));
                      },
                    );
                  }),
                ],
              ),
              const Divider(height: 26),
              const Text(
                'Sort Directory Results By',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...sortOptions.map((opt) {
                final selected = _sortBy == opt.value;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected
                        ? PipeBuyerColors.orange
                        : const Color(0xFF94A3B8),
                  ),
                  title: Text(
                    opt.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(opt.subtitle),
                  onTap: () => setState(() => _sortBy = opt.value),
                );
              }),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(
                      (startsWith: '', sortBy: 'priority'),
                    ),
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      (startsWith: _startsWith, sortBy: _sortBy),
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DIALOG 5: BASIN, 24/7 EMERGENCY & CERTIFICATIONS OPTIONS
// ============================================================================
class _MoreFiltersResult {
  const _MoreFiltersResult({
    required this.basin,
    required this.certification,
    required this.tierFilter,
    required this.emergency24x7,
    required this.paidOnly,
    required this.hasTollFree,
  });

  final String basin;
  final String certification;
  final String tierFilter;
  final bool emergency24x7;
  final bool paidOnly;
  final bool hasTollFree;
}

class _MoreFiltersDialog extends StatefulWidget {
  const _MoreFiltersDialog({
    required this.basin,
    required this.certification,
    required this.tierFilter,
    required this.emergency24x7,
    required this.paidOnly,
    required this.hasTollFree,
  });

  final String basin;
  final String certification;
  final String tierFilter;
  final bool emergency24x7;
  final bool paidOnly;
  final bool hasTollFree;

  @override
  State<_MoreFiltersDialog> createState() => _MoreFiltersDialogState();
}

class _MoreFiltersDialogState extends State<_MoreFiltersDialog> {
  late String _basin;
  late String _certification;
  late String _tierFilter;
  late bool _emergency24x7;
  late bool _paidOnly;
  late bool _hasTollFree;

  @override
  void initState() {
    super.initState();
    _basin = widget.basin;
    _certification = widget.certification;
    _tierFilter = widget.tierFilter;
    _emergency24x7 = widget.emergency24x7;
    _paidOnly = widget.paidOnly;
    _hasTollFree = widget.hasTollFree;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: PipeBuyerColors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Basin, Availability & Safety Filters',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue:
                    PipeBuyerYellowPagesTaxonomy.basins.contains(_basin)
                        ? _basin
                        : '',
                decoration: const InputDecoration(
                  labelText: 'Oil & Gas Basin',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('All Basins')),
                  ...PipeBuyerYellowPagesTaxonomy.basins.map(
                    (b) => DropdownMenuItem(value: b, child: Text(b)),
                  ),
                ],
                onChanged: (v) => setState(() => _basin = v ?? ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: PipeBuyerYellowPagesTaxonomy.certifications
                        .contains(_certification)
                    ? _certification
                    : '',
                decoration: const InputDecoration(
                  labelText: 'Safety & Industry Certification',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All Certifications'),
                  ),
                  ...PipeBuyerYellowPagesTaxonomy.certifications.map(
                    (c) => DropdownMenuItem(value: c, child: Text(c)),
                  ),
                ],
                onChanged: (v) => setState(() => _certification = v ?? ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: const {'', 'featured_only', 'paid_only'}
                        .contains(_tierFilter)
                    ? _tierFilter
                    : '',
                decoration: const InputDecoration(
                  labelText: 'Verification & Priority Tier',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: '',
                    child: Text('All Verified Providers'),
                  ),
                  DropdownMenuItem(
                    value: 'featured_only',
                    child: Text('Featured Partners (#1 Spotlight)'),
                  ),
                  DropdownMenuItem(
                    value: 'paid_only',
                    child: Text('Featured Partners & Verified Pro'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _tierFilter = v ?? '';
                  _paidOnly = _tierFilter == 'paid_only';
                }),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _emergency24x7,
                onChanged: (v) => setState(() => _emergency24x7 = v),
                title: const Text(
                  '24/7 Emergency Callout Available',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _hasTollFree,
                onChanged: (v) => setState(() => _hasTollFree = v),
                title: const Text(
                  'Has Toll-Free Dispatch Number (1-800)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(
                      const _MoreFiltersResult(
                        basin: '',
                        certification: '',
                        tierFilter: '',
                        emergency24x7: false,
                        paidOnly: false,
                        hasTollFree: false,
                      ),
                    ),
                    child: const Text('Reset Options'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _MoreFiltersResult(
                        basin: _basin,
                        certification: _certification,
                        tierFilter: _tierFilter,
                        emergency24x7: _emergency24x7,
                        paidOnly: _paidOnly,
                        hasTollFree: _hasTollFree,
                      ),
                    ),
                    child: const Text('Apply Options'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FULL COMPANY QUICK-PROFILE BOTTOM SHEET (NO PUBLIC CLAIM BUTTON)
// ============================================================================
class _CompanyDetailSheet extends StatelessWidget {
  const _CompanyDetailSheet({
    required this.entry,
    required this.client,
    required this.onRequestDispatch,
  });

  final Map<String, dynamic> entry;
  final PipeBuyerYellowPagesClient client;
  final VoidCallback onRequestDispatch;

  @override
  Widget build(BuildContext context) {
    final companyId = '${entry['companyId'] ?? entry['id'] ?? ''}'.trim();
    final companyName = '${entry['companyName'] ?? 'Service Provider'}'.trim();
    final effectiveTier = '${entry['effectiveTier'] ?? 'free_verified'}';
    final isFeatured = effectiveTier == 'featured_platinum';
    final isPaid = isFeatured || effectiveTier == 'paid_verified';

    final city = '${entry['city'] ?? ''}'.trim();
    final region = '${entry['regionCode'] ?? ''}'.trim();
    final country = '${entry['countryCode'] ?? ''}'.trim();
    final location = PipeBuyerYellowPagesTaxonomy.formatLocationLabel(
      city: city,
      regionCode: region,
      countryCode: country,
      includeCountryForNorthAmerica: true,
    );
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
              const SizedBox(height: 6),
              Row(
                children: [
                  if (country.isNotEmpty) ...[
                    PipeBuyerCountryFlagIcon(
                      countryCode: country,
                      width: 20,
                      height: 14,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      [location, if (basins.isNotEmpty) basins.join(' • ')]
                          .join('  |  '),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
                  ...services.where((s) => !categories.contains(s)).map(
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
                        : 'PipeBuyer Oilfield Directory',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasFilters
                        ? 'Broaden your town, country, region, or service filter, or post a live service request in Dispatch so nearby providers can quote directly.'
                        : 'Verified Global Oil & Gas service businesses across 197 countries appear here ranked by Priority Tier.',
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
