import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/data/bounded_firestore_query.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_dispatch_service_taxonomy.dart';
import 'marketplace_dispatch_directory_actions.dart';
import 'marketplace_location_picker.dart';

class DispatchDirectoryEntry {
  const DispatchDirectoryEntry({
    required this.id,
    required this.operatingName,
    required this.description,
    required this.website,
    required this.businessTypeCode,
    required this.serviceCodes,
    required this.serviceAreaLabel,
    required this.availabilityCode,
    required this.emergencyCallout,
    required this.remoteSiteCapable,
    required this.homeBaseLabel,
    required this.homeBasePoint,
  });

  factory DispatchDirectoryEntry.fromDirectoryProjection(
    String id,
    Map<String, dynamic> data,
  ) {
    final publicLocation = _map(data['publicLocation']);
    final serviceCodes = data['serviceCodes'] is Iterable
        ? (data['serviceCodes'] as Iterable)
            .map((value) => '$value'.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
        : <String>[];
    serviceCodes.sort();
    final point = data['mapPoint'];

    return DispatchDirectoryEntry(
      id: id,
      operatingName: _firstText([data['companyName'], data['operatingName']]),
      description: '${data['publicSummary'] ?? ''}'.trim(),
      website: '${data['website'] ?? ''}'.trim(),
      businessTypeCode: '${data['businessType'] ?? ''}'.trim(),
      serviceCodes: serviceCodes,
      serviceAreaLabel: '${data['serviceAreaSummary'] ?? ''}'.trim(),
      availabilityCode: '${data['availability'] ?? ''}'.trim(),
      emergencyCallout: data['emergencyCallout'] == true,
      remoteSiteCapable: data['remoteSiteCapable'] == true,
      homeBaseLabel: '${publicLocation['label'] ?? ''}'.trim(),
      homeBasePoint: point is GeoPoint ? point : null,
    );
  }

  factory DispatchDirectoryEntry.fromPublicBusinessProfile(
    String id,
    Map<String, dynamic> data,
  ) {
    final dispatch = _map(data['dispatchProfile']);
    final serviceCodes = dispatch['serviceCodes'] is Iterable
        ? (dispatch['serviceCodes'] as Iterable)
            .map((value) => '$value'.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
        : <String>[];
    serviceCodes.sort();

    final home = _map(dispatch['homeLocation']);
    final point = home['point'];

    return DispatchDirectoryEntry(
      id: id,
      operatingName: _firstText([
        dispatch['operatingName'],
        data['publicName'],
      ]),
      description: _firstText([
        dispatch['description'],
        data['description'],
      ]),
      website: _firstText([
        dispatch['website'],
        data['website'],
      ]),
      businessTypeCode: '${dispatch['businessType'] ?? ''}'.trim(),
      serviceCodes: serviceCodes,
      serviceAreaLabel: _firstText([
        dispatch['serviceAreaLabel'],
        data['serviceAreaLabel'],
      ]),
      availabilityCode: '${dispatch['availability'] ?? ''}'.trim(),
      emergencyCallout: dispatch['emergencyCallout'] == true,
      remoteSiteCapable: dispatch['remoteSiteCapable'] == true,
      homeBaseLabel: '${home['label'] ?? ''}'.trim(),
      homeBasePoint: point is GeoPoint ? point : null,
    );
  }

  final String id;
  final String operatingName;
  final String description;
  final String website;
  final String businessTypeCode;
  final List<String> serviceCodes;
  final String serviceAreaLabel;
  final String availabilityCode;
  final bool emergencyCallout;
  final bool remoteSiteCapable;
  final String homeBaseLabel;
  final GeoPoint? homeBasePoint;

  bool get isDirectoryReady =>
      operatingName.isNotEmpty &&
      serviceCodes.isNotEmpty &&
      serviceAreaLabel.isNotEmpty;

  bool matches(DispatchDirectoryFilters filters) {
    if (filters.serviceCode.isNotEmpty &&
        !serviceCodes.contains(filters.serviceCode)) {
      return false;
    }
    if (filters.availabilityCode.isNotEmpty &&
        availabilityCode != filters.availabilityCode) {
      return false;
    }
    if (filters.businessTypeCode.isNotEmpty &&
        businessTypeCode != filters.businessTypeCode) {
      return false;
    }
    if (filters.emergencyOnly && !emergencyCallout) return false;
    if (filters.remoteOnly && !remoteSiteCapable) return false;

    final query = filters.searchText.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystack = <String>[
      operatingName,
      description,
      serviceAreaLabel,
      homeBaseLabel,
      ...serviceCodes.map(_serviceLabel),
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = '${value ?? ''}'.trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}

class DispatchDirectoryFilters {
  const DispatchDirectoryFilters({
    this.searchText = '',
    this.serviceCode = '',
    this.availabilityCode = '',
    this.businessTypeCode = '',
    this.emergencyOnly = false,
    this.remoteOnly = false,
  });

  final String searchText;
  final String serviceCode;
  final String availabilityCode;
  final String businessTypeCode;
  final bool emergencyOnly;
  final bool remoteOnly;

  bool get hasActiveFilters =>
      searchText.trim().isNotEmpty ||
      serviceCode.isNotEmpty ||
      availabilityCode.isNotEmpty ||
      businessTypeCode.isNotEmpty ||
      emergencyOnly ||
      remoteOnly;

  DispatchDirectoryFilters copyWith({
    String? searchText,
    String? serviceCode,
    String? availabilityCode,
    String? businessTypeCode,
    bool? emergencyOnly,
    bool? remoteOnly,
  }) =>
      DispatchDirectoryFilters(
        searchText: searchText ?? this.searchText,
        serviceCode: serviceCode ?? this.serviceCode,
        availabilityCode: availabilityCode ?? this.availabilityCode,
        businessTypeCode: businessTypeCode ?? this.businessTypeCode,
        emergencyOnly: emergencyOnly ?? this.emergencyOnly,
        remoteOnly: remoteOnly ?? this.remoteOnly,
      );
}

enum DispatchDirectoryViewMode { list, map }

class DispatchDirectoryPageData {
  const DispatchDirectoryPageData({
    required this.entries,
    required this.cursor,
    required this.hasMore,
  });

  final List<DispatchDirectoryEntry> entries;
  final QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;

  DispatchDirectoryPageData append(DispatchDirectoryPageData nextPage) {
    final entriesById = <String, DispatchDirectoryEntry>{
      for (final entry in entries) entry.id: entry,
      for (final entry in nextPage.entries) entry.id: entry,
    };
    final mergedEntries = entriesById.values.toList()
      ..sort((left, right) => left.operatingName
          .toLowerCase()
          .compareTo(right.operatingName.toLowerCase()));
    return DispatchDirectoryPageData(
      entries: mergedEntries,
      cursor: nextPage.cursor,
      hasMore: nextPage.hasMore,
    );
  }
}

class MarketplaceDispatchDirectoryRepository {
  MarketplaceDispatchDirectoryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<DispatchDirectoryPageData> loadPage({
    DispatchDirectoryFilters filters = const DispatchDirectoryFilters(),
    QueryDocumentSnapshot<Map<String, dynamic>>? after,
    int pageSize = 60,
  }) async {
    Query<Map<String, dynamic>> query =
        _firestore.collection('dispatch_directory_entries');
    final searchTerms = filters.searchText
        .trim()
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((value) => value.length >= 2)
        .toList();

    if (filters.serviceCode.isNotEmpty) {
      query = query.where('serviceCodes', arrayContains: filters.serviceCode);
    } else if (searchTerms.isNotEmpty) {
      query = query.where('searchTokens', arrayContains: searchTerms.first);
    } else if (filters.availabilityCode.isNotEmpty) {
      query = query.where('availability', isEqualTo: filters.availabilityCode);
    } else if (filters.businessTypeCode.isNotEmpty) {
      query = query.where('businessType', isEqualTo: filters.businessTypeCode);
    }

    final page = await loadFirestoreDocumentPage(
      query,
      after: after,
      pageSize: pageSize,
    );
    final entries = page.documents
        .map(
          (document) => DispatchDirectoryEntry.fromDirectoryProjection(
            document.id,
            document.data(),
          ),
        )
        .where((entry) => entry.isDirectoryReady && entry.matches(filters))
        .toList()
      ..sort((left, right) => left.operatingName
          .toLowerCase()
          .compareTo(right.operatingName.toLowerCase()));
    return DispatchDirectoryPageData(
      entries: entries,
      cursor: page.cursor,
      hasMore: page.hasMore,
    );
  }
}

class MarketplaceDispatchDirectoryPage extends StatefulWidget {
  const MarketplaceDispatchDirectoryPage({
    super.key,
    this.repository,
    this.seedEntries,
    this.legacyProviderTools,
  });

  final MarketplaceDispatchDirectoryRepository? repository;
  final List<DispatchDirectoryEntry>? seedEntries;
  final Widget? legacyProviderTools;

  @override
  State<MarketplaceDispatchDirectoryPage> createState() =>
      _MarketplaceDispatchDirectoryPageState();
}

class _MarketplaceDispatchDirectoryPageState
    extends State<MarketplaceDispatchDirectoryPage> {
  MarketplaceDispatchDirectoryRepository? _repository;
  late Future<DispatchDirectoryPageData> _loadFuture;
  DispatchDirectoryPageData? _lastSuccessfulData;
  Timer? _filterDebounce;
  int _loadGeneration = 0;
  final TextEditingController _search = TextEditingController();
  DispatchDirectoryFilters _filters = const DispatchDirectoryFilters();
  bool _loadingMore = false;
  String? _loadMoreError;
  DispatchDirectoryViewMode _viewMode = DispatchDirectoryViewMode.list;
  String? _selectedMapEntryId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _loadFuture = _load();
  }

  Future<DispatchDirectoryPageData> _load() {
    final generation = ++_loadGeneration;
    final seed = widget.seedEntries;
    final Future<DispatchDirectoryPageData> request;
    if (seed != null) {
      request = Future.value(
        DispatchDirectoryPageData(
          entries: seed,
          cursor: null,
          hasMore: false,
        ),
      );
    } else {
      final repository =
          _repository ??= MarketplaceDispatchDirectoryRepository();
      request = repository.loadPage(filters: _filters);
    }
    return request.then((data) {
      if (generation == _loadGeneration) {
        _lastSuccessfulData = data;
      }
      return data;
    });
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    _filterDebounce?.cancel();
    final nextLoad = _load();
    setState(() {
      _loadMoreError = null;
      _loadingMore = false;
      _loadFuture = nextLoad;
    });
  }

  Future<void> _loadMore() async {
    final current = _lastSuccessfulData;
    if (_loadingMore ||
        widget.seedEntries != null ||
        current == null ||
        !current.hasMore ||
        current.cursor == null) {
      return;
    }

    final generation = _loadGeneration;
    final repository =
        _repository ??= MarketplaceDispatchDirectoryRepository();
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });

    try {
      final nextPage = await repository.loadPage(
        filters: _filters,
        after: current.cursor,
      );
      if (!mounted || generation != _loadGeneration) return;
      final merged = current.append(nextPage);
      setState(() {
        _lastSuccessfulData = merged;
        _loadFuture = Future.value(merged);
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError =
            'Could not load more companies. The companies already shown were kept.';
      });
    }
  }

  void _setFilters(DispatchDirectoryFilters value) {
    setState(() {
      _filters = value;
      _loadGeneration++;
      _loadMoreError = null;
      _loadingMore = false;
    });
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final nextLoad = _load();
      setState(() {
        _loadFuture = nextLoad;
      });
    });
  }

  void _clearFilters() {
    _search.clear();
    _setFilters(const DispatchDirectoryFilters());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DispatchDirectoryPageData>(
      future: _loadFuture,
      initialData: _lastSuccessfulData,
      builder: (context, snapshot) {
        final retainedData = snapshot.data ?? _lastSuccessfulData;
        if (snapshot.connectionState == ConnectionState.waiting &&
            retainedData == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && retainedData == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 42),
                  const SizedBox(height: 10),
                  const Text(
                    'Directory could not be loaded.',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check the connection and retry. Only the bounded server-owned Directory projection is read by this view.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Retry directory'),
                  ),
                ],
              ),
            ),
          );
        }

        final allEntries =
            retainedData?.entries ?? const <DispatchDirectoryEntry>[];
        final filtered = allEntries
            .where((entry) => entry.matches(_filters))
            .toList(growable: false);
        final mappedEntries = filtered
            .where((entry) => entry.homeBasePoint != null)
            .toList(growable: false);

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
          children: [
            const PipeBuyerPageHeader(
              eyebrow: 'PIPE BUYER SERVICE DIRECTORY',
              title: 'Find industrial service companies',
              subtitle:
                  'Search structured provider profiles by service, operating area and availability. Results come from the server-owned Dispatch Directory projection, which excludes private contacts, exact addresses, credentials and account-only data.',
              icon: Icons.business_outlined,
            ),
            const SizedBox(height: 14),
            _DirectoryFilterCard(
              searchController: _search,
              filters: _filters,
              onChanged: _setFilters,
              onClear: _clearFilters,
            ),
            if (snapshot.connectionState == ConnectionState.waiting &&
                retainedData != null) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Updating Directory results...',
                    style: TextStyle(
                      color: PipeBuyerColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
            if (snapshot.hasError && retainedData != null) ...[
              const SizedBox(height: 8),
              _DirectoryRefreshWarning(onRetry: _reload),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtered.length} ${filtered.length == 1 ? 'company' : 'companies'} shown',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                SegmentedButton<DispatchDirectoryViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: DispatchDirectoryViewMode.list,
                      icon: Icon(Icons.view_list_outlined),
                      label: Text('List'),
                    ),
                    ButtonSegment(
                      value: DispatchDirectoryViewMode.map,
                      icon: Icon(Icons.map_outlined),
                      label: Text('Map'),
                    ),
                  ],
                  selected: {_viewMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) return;
                    setState(() => _viewMode = selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (allEntries.isEmpty)
              const _DirectoryEmptyState(
                title: 'No companies are listed yet',
                message:
                    'Active, Directory-ready provider profiles will appear here after the server projection publishes them.',
              )
            else if (filtered.isEmpty)
              _DirectoryEmptyState(
                title: 'No companies match these filters',
                message:
                    'Clear one or more filters or search a broader service or location.',
                action: _filters.hasActiveFilters
                    ? OutlinedButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Clear filters'),
                      )
                    : null,
              )
            else if (_viewMode == DispatchDirectoryViewMode.list)
              ...filtered.map(
                (entry) => _DirectoryCompanyCard(
                  entry: entry,
                  remoteDataEnabled: widget.seedEntries == null,
                ),
              )
            else
              _DirectoryMapView(
                entries: mappedEntries,
                selectedEntryId: _selectedMapEntryId,
                remoteDataEnabled: widget.seedEntries == null,
                onSelected: (entryId) {
                  setState(() => _selectedMapEntryId = entryId);
                },
                onShowList: () {
                  setState(() => _viewMode = DispatchDirectoryViewMode.list);
                },
              ),
            if (retainedData?.hasMore == true &&
                widget.seedEntries == null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: _loadingMore
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_outlined),
                  label: Text(
                    _loadingMore
                        ? 'Loading more companies…'
                        : 'Load more companies',
                  ),
                ),
              ),
              if (_loadMoreError != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.sync_problem_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _loadMoreError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ],
            if (widget.legacyProviderTools != null) ...[
              const SizedBox(height: 20),
              const PipeBuyerPageHeader(
                eyebrow: 'CURRENT PROVIDER TOOLS',
                title: 'Pilot and escort equipment',
                subtitle:
                    'Existing provider equipment remains available while the full Directory map and company detail workflow are added.',
                icon: Icons.assistant_direction_outlined,
              ),
              const SizedBox(height: 10),
              widget.legacyProviderTools!,
            ],
          ],
        );
      },
    );
  }
}

class _DirectoryMapView extends StatelessWidget {
  const _DirectoryMapView({
    required this.entries,
    required this.selectedEntryId,
    required this.remoteDataEnabled,
    required this.onSelected,
    required this.onShowList,
  });

  final List<DispatchDirectoryEntry> entries;
  final String? selectedEntryId;
  final bool remoteDataEnabled;
  final ValueChanged<String> onSelected;
  final VoidCallback onShowList;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _DirectoryEmptyState(
        title: 'No mapped companies in these results',
        message:
            'These companies do not currently publish an approximate Directory map location. Their list profiles remain available.',
        action: OutlinedButton.icon(
          onPressed: onShowList,
          icon: const Icon(Icons.view_list_outlined),
          label: const Text('Show list'),
        ),
      );
    }

    DispatchDirectoryEntry? selectedEntry;
    for (final entry in entries) {
      if (entry.id == selectedEntryId) {
        selectedEntry = entry;
        break;
      }
    }

    final mapIdentity = entries.map((entry) {
      final point = entry.homeBasePoint!;
      return '${entry.id}:${point.latitude.toStringAsFixed(3)}:${point.longitude.toStringAsFixed(3)}';
    }).join('|');

    return PipeBuyerSectionCard(
      title: 'Map results',
      subtitle:
          'Pins use approximate public locations from the Dispatch Directory projection. They are for discovery, not routing to a private yard or residence.',
      leading: const Icon(Icons.map_outlined, color: PipeBuyerColors.orange),
      trailing: PipeBuyerStatusBadge(
        label: '${entries.length} mapped',
        icon: Icons.location_on_outlined,
        tone: PipeBuyerStatusTone.info,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 380,
              child: FlutterMap(
                key: ValueKey('dispatch-directory-map-$mapIdentity'),
                options: MapOptions(
                  initialCenter: _mapCenter(),
                  initialZoom: _mapZoom(),
                  minZoom: 2,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: pipeBuyerTileUrl,
                    userAgentPackageName: 'ca.pipebuyer.marketplace',
                  ),
                  MarkerLayer(
                    markers: entries.map((entry) {
                      final point = entry.homeBasePoint!;
                      final selected = entry.id == selectedEntryId;
                      return Marker(
                        point: LatLng(point.latitude, point.longitude),
                        width: 48,
                        height: 48,
                        child: Tooltip(
                          message: entry.homeBaseLabel.isEmpty
                              ? entry.operatingName
                              : '${entry.operatingName}\n${entry.homeBaseLabel}',
                          child: Semantics(
                            button: true,
                            label: 'Show ${entry.operatingName} from map',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelected(entry.id),
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: selected ? 42 : 36,
                                  height: selected ? 42 : 36,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? PipeBuyerColors.orange
                                        : PipeBuyerColors.ink,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: selected ? 3 : 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x26000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.business_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                  const SimpleAttributionWidget(
                    source: Text('© OpenStreetMap contributors'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                size: 18,
                color: PipeBuyerColors.industrialBlue,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Approximate public locations only. Confirm the service area and exact meeting or job location directly with the company.',
                  style: TextStyle(fontSize: 12, height: 1.35),
                ),
              ),
            ],
          ),
          if (selectedEntry != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Selected company',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            _DirectoryCompanyCard(
              entry: selectedEntry,
              remoteDataEnabled: remoteDataEnabled,
            ),
          ],
        ],
      ),
    );
  }

  LatLng _mapCenter() {
    var latitude = 0.0;
    var longitude = 0.0;
    for (final entry in entries) {
      final point = entry.homeBasePoint!;
      latitude += point.latitude;
      longitude += point.longitude;
    }
    return LatLng(latitude / entries.length, longitude / entries.length);
  }

  double _mapZoom() {
    if (entries.length == 1) return 8.5;
    var minLatitude = entries.first.homeBasePoint!.latitude;
    var maxLatitude = minLatitude;
    var minLongitude = entries.first.homeBasePoint!.longitude;
    var maxLongitude = minLongitude;
    for (final entry in entries.skip(1)) {
      final point = entry.homeBasePoint!;
      if (point.latitude < minLatitude) minLatitude = point.latitude;
      if (point.latitude > maxLatitude) maxLatitude = point.latitude;
      if (point.longitude < minLongitude) minLongitude = point.longitude;
      if (point.longitude > maxLongitude) maxLongitude = point.longitude;
    }
    final latitudeSpan = maxLatitude - minLatitude;
    final longitudeSpan = maxLongitude - minLongitude;
    final span = latitudeSpan > longitudeSpan ? latitudeSpan : longitudeSpan;
    if (span > 40) return 2.5;
    if (span > 20) return 3.5;
    if (span > 10) return 4.5;
    if (span > 5) return 5.5;
    if (span > 2) return 6.5;
    if (span > 1) return 7.5;
    if (span > .5) return 8.5;
    return 9.5;
  }
}

class _DirectoryFilterCard extends StatelessWidget {
  const _DirectoryFilterCard({
    required this.searchController,
    required this.filters,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final DispatchDirectoryFilters filters;
  final ValueChanged<DispatchDirectoryFilters> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return PipeBuyerSectionCard(
      title: 'Search & filters',
      subtitle:
          'Start with the service you need, then narrow by availability or business type.',
      leading: const Icon(Icons.tune_outlined, color: PipeBuyerColors.orange),
      trailing: filters.hasActiveFilters
          ? TextButton(onPressed: onClear, child: const Text('Clear'))
          : null,
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: (value) =>
                onChanged(filters.copyWith(searchText: value)),
            decoration: const InputDecoration(
              labelText: 'Search company, service or area',
              prefixIcon: Icon(Icons.search_outlined),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;

              final service = _DirectoryInlineSelect(
                id: 'directory-service-filter',
                label: 'Service',
                value: filters.serviceCode,
                options: [
                  const _DirectoryInlineSelectOption(
                    value: '',
                    label: 'All services',
                  ),
                  ...DispatchServiceTaxonomy.services.map(
                    (service) => _DirectoryInlineSelectOption(
                      value: service.code,
                      label: service.label,
                    ),
                  ),
                ],
                onChanged: (value) => onChanged(
                  filters.copyWith(serviceCode: value),
                ),
              );

              final availability = _DirectoryInlineSelect(
                id: 'directory-availability-filter',
                label: 'Availability',
                value: filters.availabilityCode,
                options: const [
                  _DirectoryInlineSelectOption(
                    value: '',
                    label: 'Any availability',
                  ),
                  _DirectoryInlineSelectOption(
                    value: 'available_now',
                    label: 'Available now',
                  ),
                  _DirectoryInlineSelectOption(
                    value: 'available_today',
                    label: 'Available today',
                  ),
                  _DirectoryInlineSelectOption(
                    value: 'available_this_week',
                    label: 'Available this week',
                  ),
                  _DirectoryInlineSelectOption(
                    value: 'unavailable',
                    label: 'Unavailable',
                  ),
                ],
                onChanged: (value) => onChanged(
                  filters.copyWith(availabilityCode: value),
                ),
              );

              final businessType = _DirectoryInlineSelect(
                id: 'directory-business-type-filter',
                label: 'Business type',
                value: filters.businessTypeCode,
                options: const [
                  _DirectoryInlineSelectOption(
                    value: '',
                    label: 'All business types',
                  ),
                  _DirectoryInlineSelectOption(
                    value: 'owner_operator',
                    label: 'Owner / operator',
                  ),
                  _DirectoryInlineSelectOption(
                    value: 'sole_proprietorship',
                    label: 'Sole proprietorship',
                  ),
                  _DirectoryInlineSelectOption(
                    value: 'partnership',
                    label: 'Partnership',
                  ),
                  _DirectoryInlineSelectOption(
                    value: 'corporation',
                    label: 'Corporation / company',
                  ),
                  _DirectoryInlineSelectOption(
                    value: 'other',
                    label: 'Other',
                  ),
                ],
                onChanged: (value) => onChanged(
                  filters.copyWith(businessTypeCode: value),
                ),
              );

              if (!wide) {
                return Column(
                  children: [
                    service,
                    const SizedBox(height: 10),
                    availability,
                    const SizedBox(height: 10),
                    businessType,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: service),
                  const SizedBox(width: 10),
                  Expanded(child: availability),
                  const SizedBox(width: 10),
                  Expanded(child: businessType),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Emergency callout'),
                selected: filters.emergencyOnly,
                onSelected: (value) =>
                    onChanged(filters.copyWith(emergencyOnly: value)),
              ),
              FilterChip(
                label: const Text('Remote-site capable'),
                selected: filters.remoteOnly,
                onSelected: (value) =>
                    onChanged(filters.copyWith(remoteOnly: value)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectoryInlineSelectOption {
  const _DirectoryInlineSelectOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

class _DirectoryInlineSelect extends StatefulWidget {
  const _DirectoryInlineSelect({
    required this.id,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String id;
  final String label;
  final String value;
  final List<_DirectoryInlineSelectOption> options;
  final ValueChanged<String> onChanged;

  @override
  State<_DirectoryInlineSelect> createState() => _DirectoryInlineSelectState();
}

class _DirectoryInlineSelectState extends State<_DirectoryInlineSelect> {
  bool _expanded = false;

  _DirectoryInlineSelectOption get _selected {
    for (final option in widget.options) {
      if (option.value == widget.value) return option;
    }
    return widget.options.first;
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  void _choose(String value) {
    setState(() => _expanded = false);

    // Close the same-tree selector first. Applying parent filter state on the
    // next frame avoids pointer/geometry churn while the option is handling
    // its mouse event.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          key: ValueKey('${widget.id}-button'),
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              suffixIcon: Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              ),
            ),
            child: Text(
              selected.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: widget.options.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Theme.of(context).dividerColor),
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final isSelected = option.value == widget.value;

                return GestureDetector(
                  key: ValueKey(
                    '${widget.id}-option-${option.value}',
                  ),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _choose(option.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(option.label)),
                        if (isSelected)
                          const Icon(
                            Icons.check,
                            size: 18,
                            color: PipeBuyerColors.orange,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _DirectoryCompanyCard extends StatelessWidget {
  const _DirectoryCompanyCard({
    required this.entry,
    required this.remoteDataEnabled,
  });

  final DispatchDirectoryEntry entry;
  final bool remoteDataEnabled;

  @override
  Widget build(BuildContext context) {
    final services = entry.serviceCodes.take(5).map(_serviceLabel).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PipeBuyerSectionCard(
        title: entry.operatingName,
        subtitle: entry.serviceAreaLabel,
        leading: const Icon(
          Icons.business_center_outlined,
          color: PipeBuyerColors.industrialBlue,
        ),
        trailing: _AvailabilityBadge(code: entry.availabilityCode),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.description.isNotEmpty) ...[
              Text(
                entry.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                ...services.map((label) => Chip(label: Text(label))),
                if (entry.emergencyCallout)
                  const Chip(
                    avatar: Icon(Icons.bolt_outlined, size: 18),
                    label: Text('Emergency callout'),
                  ),
                if (entry.remoteSiteCapable)
                  const Chip(
                    avatar: Icon(Icons.terrain_outlined, size: 18),
                    label: Text('Remote-site capable'),
                  ),
              ],
            ),
            if (entry.homeBaseLabel.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Approximate home base: ${entry.homeBaseLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            MarketplaceDispatchDirectoryBusinessActions(
              providerUid: entry.id,
              operatingName: entry.operatingName,
              serviceCodes: entry.serviceCodes,
              remoteDataEnabled: remoteDataEnabled,
            ),
            const SizedBox(height: 8),
            const Text(
              'Provider-supplied profile information. Verification badges are not shown in this Directory foundation.',
              style: TextStyle(color: PipeBuyerColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final label = switch (code) {
      'available_now' => 'AVAILABLE NOW',
      'available_today' => 'TODAY',
      'available_this_week' => 'THIS WEEK',
      'unavailable' => 'UNAVAILABLE',
      _ => 'AVAILABILITY UNKNOWN',
    };
    final tone = switch (code) {
      'available_now' || 'available_today' => PipeBuyerStatusTone.success,
      'available_this_week' => PipeBuyerStatusTone.info,
      'unavailable' => PipeBuyerStatusTone.neutral,
      _ => PipeBuyerStatusTone.neutral,
    };
    return PipeBuyerStatusBadge(
      label: label,
      icon: Icons.schedule_outlined,
      tone: tone,
    );
  }
}

class _DirectoryRefreshWarning extends StatelessWidget {
  const _DirectoryRefreshWarning({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD2A8)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.sync_problem_outlined,
              color: PipeBuyerColors.orange,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Could not refresh these filters. Showing the last loaded Directory results.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _DirectoryEmptyState extends StatelessWidget {
  const _DirectoryEmptyState({
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => PipeBuyerSectionCard(
        title: title,
        subtitle: message,
        leading: const Icon(Icons.search_off_outlined),
        child: action ?? const SizedBox.shrink(),
      );
}

String _serviceLabel(String code) {
  for (final service in DispatchServiceTaxonomy.services) {
    if (service.code == code) return service.label;
  }
  return code;
}
