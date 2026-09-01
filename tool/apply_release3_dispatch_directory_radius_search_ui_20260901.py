from pathlib import Path

DIRECTORY = Path('lib/marketplace/marketplace_dispatch_directory.dart')
PROJECTION_TEST = Path('test/marketplace_dispatch_directory_projection_query_test.dart')
WIDGET_TEST = Path('test/marketplace_dispatch_directory_test.dart')
DOC = Path('docs/DISPATCH_RELEASE3_DIRECTORY_RADIUS_SEARCH_UI.md')


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label} anchor mismatch: {count}')
    return text.replace(old, new, 1)


directory = DIRECTORY.read_text(encoding='utf-8')

directory = replace_once(
    directory,
    "import 'marketplace_dispatch_service_taxonomy.dart';\nimport 'marketplace_dispatch_directory_actions.dart';\nimport 'marketplace_location_picker.dart';\n",
    "import 'marketplace_command_client.dart';\nimport 'marketplace_dispatch_directory_actions.dart';\nimport 'marketplace_dispatch_service_taxonomy.dart';\nimport 'marketplace_location_picker.dart';\nimport 'open_address_autocomplete.dart';\n",
    'Directory imports',
)

directory = replace_once(
    directory,
    "    this.serviceAreaCenterLabel = '',\n    this.serviceAreaRadiusKm = 0,\n  });\n",
    "    this.serviceAreaCenterLabel = '',\n    this.serviceAreaRadiusKm = 0,\n    this.distanceKm,\n  });\n",
    'entry constructor',
)

directory = replace_once(
    directory,
    "    final point = data['mapPoint'];\n",
    "    final point = _geoPoint(data['mapPoint']);\n",
    'projection map point',
)

directory = replace_once(
    directory,
    "    final point = home['point'];\n",
    "    final point = _geoPoint(home['point']);\n",
    'legacy map point',
)

point_assignment = "      homeBasePoint: point is GeoPoint ? point : null,\n"
if directory.count(point_assignment) != 2:
    raise SystemExit(f'homeBasePoint anchor mismatch: {directory.count(point_assignment)}')
directory = directory.replace(point_assignment, "      homeBasePoint: point,\n")

directory = replace_once(
    directory,
    "      serviceAreaRadiusKm:\n          (publicServiceArea['radiusKm'] as num?)?.toDouble() ?? 0,\n    );\n",
    "      serviceAreaRadiusKm:\n          (publicServiceArea['radiusKm'] as num?)?.toDouble() ?? 0,\n      distanceKm: (data['distanceKm'] as num?)?.toDouble(),\n    );\n",
    'projection distance',
)

directory = replace_once(
    directory,
    "  final String serviceAreaCenterLabel;\n  final double serviceAreaRadiusKm;\n\n  bool get hasPublishedRadiusCoverage =>\n",
    "  final String serviceAreaCenterLabel;\n  final double serviceAreaRadiusKm;\n  final double? distanceKm;\n\n  bool get hasPublishedRadiusCoverage =>\n",
    'entry distance field',
)

directory = replace_once(
    directory,
    "  static Map<String, dynamic> _map(Object? value) {\n    if (value is Map<String, dynamic>) return value;\n    if (value is Map) {\n      return value.map((key, item) => MapEntry('$key', item));\n    }\n    return const <String, dynamic>{};\n  }\n\n  static String _firstText(Iterable<Object?> values) {\n",
    "  static Map<String, dynamic> _map(Object? value) {\n    if (value is Map<String, dynamic>) return value;\n    if (value is Map) {\n      return value.map((key, item) => MapEntry('$key', item));\n    }\n    return const <String, dynamic>{};\n  }\n\n  static GeoPoint? _geoPoint(Object? value) {\n    if (value is GeoPoint) return value;\n    final map = _map(value);\n    final latitude = double.tryParse(\n      '${map['latitude'] ?? map['lat'] ?? ''}',\n    );\n    final longitude = double.tryParse(\n      '${map['longitude'] ?? map['lng'] ?? ''}',\n    );\n    if (latitude == null ||\n        longitude == null ||\n        latitude < -90 ||\n        latitude > 90 ||\n        longitude < -180 ||\n        longitude > 180) {\n      return null;\n    }\n    return GeoPoint(latitude, longitude);\n  }\n\n  static String _firstText(Iterable<Object?> values) {\n",
    'GeoPoint parser',
)

radius_data = r'''
class DispatchDirectoryRadiusSearchData {
  const DispatchDirectoryRadiusSearchData({
    required this.entries,
    required this.center,
    required this.radiusKm,
    required this.resultCount,
    required this.truncated,
  });

  factory DispatchDirectoryRadiusSearchData.fromCommandResult(
    Map<String, dynamic> data,
  ) {
    final entries = <DispatchDirectoryEntry>[];
    final rawResults = data['results'];
    if (rawResults is Iterable) {
      for (final raw in rawResults) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final id = '${item['id'] ?? ''}'.trim();
        if (id.isEmpty) continue;
        final entry = DispatchDirectoryEntry.fromDirectoryProjection(id, item);
        if (entry.isDirectoryReady) entries.add(entry);
      }
    }
    final centerPoint = DispatchDirectoryEntry._geoPoint(data['center']);
    return DispatchDirectoryRadiusSearchData(
      entries: entries,
      center: centerPoint == null
          ? null
          : LatLng(centerPoint.latitude, centerPoint.longitude),
      radiusKm: (data['radiusKm'] as num?)?.toDouble() ?? 0,
      resultCount: (data['resultCount'] as num?)?.toInt() ?? entries.length,
      truncated: data['truncated'] == true,
    );
  }

  final List<DispatchDirectoryEntry> entries;
  final LatLng? center;
  final double radiusKm;
  final int resultCount;
  final bool truncated;
}

'''
directory = replace_once(
    directory,
    "class MarketplaceDispatchDirectoryRepository {\n",
    radius_data + "class MarketplaceDispatchDirectoryRepository {\n",
    'radius search data class',
)

directory = replace_once(
    directory,
    "class MarketplaceDispatchDirectoryRepository {\n  MarketplaceDispatchDirectoryRepository({FirebaseFirestore? firestore})\n      : _firestore = firestore ?? FirebaseFirestore.instance;\n\n  final FirebaseFirestore _firestore;\n",
    "class MarketplaceDispatchDirectoryRepository {\n  MarketplaceDispatchDirectoryRepository({\n    FirebaseFirestore? firestore,\n    MarketplaceCommandClient? commandClient,\n  })  : _firestore = firestore,\n        _commands = commandClient ?? MarketplaceCommandClient();\n\n  FirebaseFirestore? _firestore;\n  final MarketplaceCommandClient _commands;\n\n  FirebaseFirestore get _resolvedFirestore =>\n      _firestore ??= FirebaseFirestore.instance;\n",
    'Directory repository constructor',
)

directory = replace_once(
    directory,
    "        _firestore.collection('dispatch_directory_entries');\n",
    "        _resolvedFirestore.collection('dispatch_directory_entries');\n",
    'resolved Firestore query',
)

repository_method = r'''

  Future<DispatchDirectoryRadiusSearchData> searchRadius({
    required LatLng center,
    required double radiusKm,
    int resultLimit = 60,
  }) async {
    final result = await _commands.execute('searchDispatchDirectoryRadius', {
      'latitude': center.latitude,
      'longitude': center.longitude,
      'radiusKm': radiusKm,
      'resultLimit': resultLimit,
    });
    return DispatchDirectoryRadiusSearchData.fromCommandResult(result);
  }
'''
directory = replace_once(
    directory,
    "  }\n}\n\nclass MarketplaceDispatchDirectoryPage extends StatefulWidget {\n",
    "  }" + repository_method + "\n}\n\nclass MarketplaceDispatchDirectoryPage extends StatefulWidget {\n",
    'repository radius method',
)

directory = replace_once(
    directory,
    "  DispatchDirectoryViewMode _viewMode = DispatchDirectoryViewMode.list;\n  String? _selectedMapEntryId;\n",
    "  DispatchDirectoryViewMode _viewMode = DispatchDirectoryViewMode.list;\n  String? _selectedMapEntryId;\n  OpenAddress? _radiusPlace;\n  double _radiusKm = 250;\n  DispatchDirectoryRadiusSearchData? _radiusSearchData;\n  bool _radiusSearchLoading = false;\n  String? _radiusSearchError;\n  String _activeRadiusLabel = '';\n  int _radiusSearchGeneration = 0;\n  int _radiusInputVersion = 0;\n",
    'radius state',
)

radius_methods = r'''
  Future<void> _searchRadius() async {
    final place = _radiusPlace;
    if (place == null || _radiusSearchLoading) {
      if (place == null) {
        setState(() => _radiusSearchError = 'Choose a town or place first.');
      }
      return;
    }
    final request = ++_radiusSearchGeneration;
    final repository =
        _repository ??= MarketplaceDispatchDirectoryRepository();
    setState(() {
      _radiusSearchLoading = true;
      _radiusSearchError = null;
    });
    try {
      final result = await repository.searchRadius(
        center: place.point,
        radiusKm: _radiusKm,
        resultLimit: 60,
      );
      if (!mounted || request != _radiusSearchGeneration) return;
      setState(() {
        _radiusSearchData = result;
        _activeRadiusLabel = _radiusPlaceLabel(place);
        _radiusSearchLoading = false;
        _radiusSearchError = null;
        _selectedMapEntryId = null;
      });
    } catch (error) {
      if (!mounted || request != _radiusSearchGeneration) return;
      setState(() {
        _radiusSearchLoading = false;
        _radiusSearchError = marketplaceCommandErrorMessage(
          error,
          fallback: 'Could not search this area. Check the connection and try again.',
        );
      });
    }
  }

  void _clearRadiusSearch() {
    _radiusSearchGeneration++;
    setState(() {
      _radiusPlace = null;
      _radiusSearchData = null;
      _radiusSearchLoading = false;
      _radiusSearchError = null;
      _activeRadiusLabel = '';
      _selectedMapEntryId = null;
      _radiusInputVersion++;
    });
    _reload();
  }

  String _radiusPlaceLabel(OpenAddress place) {
    final primary = place.name.trim().isNotEmpty
        ? place.name.trim()
        : place.city.trim().isNotEmpty
            ? place.city.trim()
            : place.label.trim();
    return <String>[
      primary,
      place.region.trim(),
      place.country.trim(),
    ].where((value) => value.isNotEmpty).toSet().join(', ');
  }

'''
directory = replace_once(
    directory,
    "  void _setFilters(DispatchDirectoryFilters value) {\n",
    radius_methods + "  void _setFilters(DispatchDirectoryFilters value) {\n",
    'radius state methods',
)

directory = replace_once(
    directory,
    "  void _setFilters(DispatchDirectoryFilters value) {\n    setState(() {\n",
    "  void _setFilters(DispatchDirectoryFilters value) {\n    if (_radiusSearchData != null) {\n      setState(() {\n        _filters = value;\n        _loadMoreError = null;\n      });\n      return;\n    }\n    setState(() {\n",
    'local filters during radius mode',
)

directory = replace_once(
    directory,
    "        final allEntries =\n            retainedData?.entries ?? const <DispatchDirectoryEntry>[];\n",
    "        final radiusSearchData = _radiusSearchData;\n        final allEntries = radiusSearchData?.entries ??\n            retainedData?.entries ??\n            const <DispatchDirectoryEntry>[];\n",
    'radius result data source',
)

directory = replace_once(
    directory,
    "            const SizedBox(height: 14),\n            _DirectoryFilterCard(\n",
    "            const SizedBox(height: 14),\n            _DirectoryRadiusSearchCard(\n              key: const ValueKey('directory-radius-search-card'),\n              selectedPlace: _radiusPlace,\n              radiusKm: _radiusKm,\n              loading: _radiusSearchLoading,\n              error: _radiusSearchError,\n              activeData: radiusSearchData,\n              activeLabel: _activeRadiusLabel,\n              inputVersion: _radiusInputVersion,\n              onPlaceSelected: (place) {\n                setState(() {\n                  _radiusPlace = place;\n                  _radiusSearchError = null;\n                });\n              },\n              onPlaceChanged: (_) {\n                if (_radiusPlace == null) return;\n                setState(() => _radiusPlace = null);\n              },\n              onRadiusChanged: (value) {\n                setState(() => _radiusKm = value);\n              },\n              onSearch: _searchRadius,\n              onClear: _clearRadiusSearch,\n            ),\n            const SizedBox(height: 14),\n            _DirectoryFilterCard(\n",
    'radius search card placement',
)

directory = replace_once(
    directory,
    "            if (snapshot.connectionState == ConnectionState.waiting &&\n                retainedData != null) ...[\n",
    "            if (radiusSearchData == null &&\n                snapshot.connectionState == ConnectionState.waiting &&\n                retainedData != null) ...[\n",
    'suppress normal refresh while radius active',
)

directory = replace_once(
    directory,
    "            if (snapshot.hasError && retainedData != null) ...[\n",
    "            if (radiusSearchData == null &&\n                snapshot.hasError &&\n                retainedData != null) ...[\n",
    'suppress normal error while radius active',
)

directory = replace_once(
    directory,
    "                    '${filtered.length} ${filtered.length == 1 ? 'company' : 'companies'} shown',\n",
    "                    radiusSearchData == null\n                        ? '${filtered.length} ${filtered.length == 1 ? 'company' : 'companies'} shown'\n                        : '${filtered.length} ${filtered.length == 1 ? 'company' : 'companies'} shown within ${_directoryDistance(radiusSearchData.radiusKm)} km',\n",
    'radius result count label',
)

directory = replace_once(
    directory,
    "            if (allEntries.isEmpty)\n              const _DirectoryEmptyState(\n                title: 'No companies are listed yet',\n                message:\n                    'Active, Directory-ready provider profiles will appear here after the server projection publishes them.',\n              )\n",
    "            if (allEntries.isEmpty)\n              _DirectoryEmptyState(\n                title: radiusSearchData == null\n                    ? 'No companies are listed yet'\n                    : 'No companies found in this area',\n                message: radiusSearchData == null\n                    ? 'Active, Directory-ready provider profiles will appear here after the server projection publishes them.'\n                    : 'Try a larger distance or choose another town or place.',\n                action: radiusSearchData == null\n                    ? null\n                    : OutlinedButton.icon(\n                        onPressed: _clearRadiusSearch,\n                        icon: const Icon(Icons.edit_location_alt_outlined),\n                        label: const Text('Change area'),\n                      ),\n              )\n",
    'radius empty state',
)

directory = replace_once(
    directory,
    "              _DirectoryMapView(\n                entries: mappedEntries,\n                selectedEntryId: _selectedMapEntryId,\n",
    "              _DirectoryMapView(\n                entries: mappedEntries,\n                selectedEntryId: _selectedMapEntryId,\n                searchCenter: radiusSearchData?.center,\n                searchRadiusKm: radiusSearchData?.radiusKm,\n",
    'radius map arguments',
)

directory = replace_once(
    directory,
    "            if (retainedData?.hasMore == true &&\n                widget.seedEntries == null) ...[\n",
    "            if (radiusSearchData == null &&\n                retainedData?.hasMore == true &&\n                widget.seedEntries == null) ...[\n",
    'disable pagination for radius results',
)

directory = replace_once(
    directory,
    "    required this.entries,\n    required this.selectedEntryId,\n    required this.remoteDataEnabled,\n",
    "    required this.entries,\n    required this.selectedEntryId,\n    required this.searchCenter,\n    required this.searchRadiusKm,\n    required this.remoteDataEnabled,\n",
    'map constructor radius fields',
)

directory = replace_once(
    directory,
    "  final List<DispatchDirectoryEntry> entries;\n  final String? selectedEntryId;\n  final bool remoteDataEnabled;\n",
    "  final List<DispatchDirectoryEntry> entries;\n  final String? selectedEntryId;\n  final LatLng? searchCenter;\n  final double? searchRadiusKm;\n  final bool remoteDataEnabled;\n",
    'map radius fields',
)

directory = replace_once(
    directory,
    "    final mapIdentity = entries.map((entry) {\n      final point = entry.homeBasePoint!;\n      return '${entry.id}:${point.latitude.toStringAsFixed(3)}:${point.longitude.toStringAsFixed(3)}';\n    }).join('|');\n",
    "    final mapIdentity = entries.map((entry) {\n      final point = entry.homeBasePoint!;\n      return '${entry.id}:${point.latitude.toStringAsFixed(3)}:${point.longitude.toStringAsFixed(3)}';\n    }).join('|');\n    final searchIdentity = searchCenter == null || searchRadiusKm == null\n        ? ''\n        : ':search:${searchCenter!.latitude.toStringAsFixed(3)}:${searchCenter!.longitude.toStringAsFixed(3)}:${searchRadiusKm!.toStringAsFixed(1)}';\n",
    'map search identity',
)

directory = replace_once(
    directory,
    "                key: ValueKey('dispatch-directory-map-$mapIdentity'),\n",
    "                key: ValueKey(\n                  'dispatch-directory-map-$mapIdentity$searchIdentity',\n                ),\n",
    'map key radius identity',
)

directory = replace_once(
    directory,
    "                  initialCenter: _mapCenter(),\n                  initialZoom: _mapZoom(),\n",
    "                  initialCenter: searchCenter ?? _mapCenter(),\n                  initialZoom: _mapZoom(),\n",
    'map search center',
)

directory = replace_once(
    directory,
    "                  if (radiusEntry != null)\n                    CircleLayer(\n",
    "                  if (searchCenter != null &&\n                      searchRadiusKm != null &&\n                      searchRadiusKm! > 0)\n                    CircleLayer(\n                      circles: [\n                        CircleMarker(\n                          point: searchCenter!,\n                          radius: searchRadiusKm! * 1000,\n                          useRadiusInMeter: true,\n                          color: PipeBuyerColors.industrialBlue\n                              .withValues(alpha: .07),\n                          borderColor: PipeBuyerColors.industrialBlue\n                              .withValues(alpha: .78),\n                          borderStrokeWidth: 2,\n                        ),\n                      ],\n                    ),\n                  if (radiusEntry != null)\n                    CircleLayer(\n",
    'map search circle',
)

directory = replace_once(
    directory,
    "  double _mapZoom() {\n    if (entries.length == 1) return 8.5;\n",
    "  double _mapZoom() {\n    final radius = searchRadiusKm;\n    if (searchCenter != null && radius != null && radius > 0) {\n      if (radius >= 1000) return 4;\n      if (radius >= 500) return 5;\n      if (radius >= 250) return 6;\n      if (radius >= 100) return 7;\n      return 8;\n    }\n    if (entries.length == 1) return 8.5;\n",
    'map radius zoom',
)

radius_card = r'''
String _directoryDistance(double value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);

class _DirectoryRadiusSearchCard extends StatelessWidget {
  const _DirectoryRadiusSearchCard({
    super.key,
    required this.selectedPlace,
    required this.radiusKm,
    required this.loading,
    required this.error,
    required this.activeData,
    required this.activeLabel,
    required this.inputVersion,
    required this.onPlaceSelected,
    required this.onPlaceChanged,
    required this.onRadiusChanged,
    required this.onSearch,
    required this.onClear,
  });

  final OpenAddress? selectedPlace;
  final double radiusKm;
  final bool loading;
  final String? error;
  final DispatchDirectoryRadiusSearchData? activeData;
  final String activeLabel;
  final int inputVersion;
  final ValueChanged<OpenAddress> onPlaceSelected;
  final ValueChanged<String> onPlaceChanged;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final active = activeData;
    if (active != null) {
      return PipeBuyerSectionCard(
        title: 'Search near a place',
        subtitle:
            'Geographic results use approximate public Directory points—not private yards, homes, or exact provider addresses.',
        leading: const Icon(Icons.radar_outlined, color: PipeBuyerColors.orange),
        trailing: TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
          label: const Text('Change area'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_searching_outlined,
                  size: 20,
                  color: PipeBuyerColors.industrialBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$activeLabel · within ${_directoryDistance(active.radiusKm)} km',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '${active.resultCount} ${active.resultCount == 1 ? 'company' : 'companies'} returned by the bounded server search. Existing service and availability filters can narrow these results.',
              style: const TextStyle(height: 1.35),
            ),
            if (active.truncated) ...[
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'More companies may be available in this area. Reduce the distance for a more complete result before relying on additional filters.',
                        style: TextStyle(fontSize: 12, height: 1.35),
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

    const distances = <double>[50, 100, 250, 500, 1000];
    return PipeBuyerSectionCard(
      title: 'Search near a place',
      subtitle:
          'Choose a town or place and a distance. This finds companies whose approximate public Directory point is nearby.',
      leading: const Icon(Icons.radar_outlined, color: PipeBuyerColors.orange),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OpenAddressAutocomplete(
            key: ValueKey('directory-radius-place-$inputVersion'),
            initialValue: selectedPlace?.label ?? '',
            label: 'Town or place',
            hint: 'Try Grande Prairie, Fort St. John, Midland or another town',
            searchType: OpenAddressSearchType.settlement,
            enabled: !loading,
            onChanged: onPlaceChanged,
            onSelected: onPlaceSelected,
          ),
          if (selectedPlace != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 17,
                  color: PipeBuyerColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    selectedPlace!.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Distance',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: distances
                .map(
                  (distance) => ChoiceChip(
                    key: ValueKey(
                      'directory-radius-distance-${distance.round()}',
                    ),
                    label: Text('${distance.round()} km'),
                    selected: radiusKm == distance,
                    onSelected: loading
                        ? null
                        : (_) => onRadiusChanged(distance),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('directory-radius-search-button'),
            onPressed: selectedPlace == null || loading ? null : onSearch,
            icon: loading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_outlined),
            label: Text(loading ? 'Searching this area…' : 'Search this area'),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'This is a discovery search. Confirm service coverage, the exact job location, route, permits, availability, and travel charges directly with the company.',
            style: TextStyle(fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

'''
directory = replace_once(
    directory,
    "class _DirectoryFilterCard extends StatelessWidget {\n",
    radius_card + "class _DirectoryFilterCard extends StatelessWidget {\n",
    'radius search card class',
)

directory = replace_once(
    directory,
    "                ...services.map((label) => Chip(label: Text(label))),\n",
    "                if (entry.distanceKm != null)\n                  Chip(\n                    avatar: const Icon(Icons.near_me_outlined, size: 18),\n                    label: Text(\n                      '${_directoryDistance(entry.distanceKm!)} km away',\n                    ),\n                  ),\n                ...services.map((label) => Chip(label: Text(label))),\n",
    'distance chip',
)

DIRECTORY.write_text(directory, encoding='utf-8')

projection_test = PROJECTION_TEST.read_text(encoding='utf-8')
projection_insert = r'''

  test('Directory parses bounded radius-search callable results', () {
    final result = DispatchDirectoryRadiusSearchData.fromCommandResult({
      'center': {'latitude': 55.17, 'longitude': -118.79},
      'radiusKm': 250,
      'resultCount': 1,
      'truncated': true,
      'results': [
        {
          'id': 'nearby-hotshot',
          'operatingName': 'Nearby Hotshot',
          'serviceCodes': ['transport_hotshot'],
          'serviceAreaSummary': 'Northern Alberta',
          'publicLocation': {'label': 'Grande Prairie, Alberta'},
          'mapPoint': {'latitude': 55.2, 'longitude': -118.8},
          'distanceKm': 12.3,
        },
      ],
    });

    expect(result.center?.latitude, closeTo(55.17, .001));
    expect(result.radiusKm, 250);
    expect(result.resultCount, 1);
    expect(result.truncated, isTrue);
    expect(result.entries.single.id, 'nearby-hotshot');
    expect(result.entries.single.homeBasePoint, isNotNull);
    expect(result.entries.single.distanceKm, 12.3);
  });
'''
projection_test = replace_once(
    projection_test,
    "\n  test('Directory page append deduplicates and keeps alphabetical order', () {\n",
    projection_insert + "\n  test('Directory page append deduplicates and keeps alphabetical order', () {\n",
    'radius callable parser test',
)
projection_test = replace_once(
    projection_test,
    "    expect(source, contains('Published service radius:'));\n  });\n",
    "    expect(source, contains('Published service radius:'));\n    expect(source, contains("""'searchDispatchDirectoryRadius'"""));\n    expect(source, contains('OpenAddressAutocomplete('));\n    expect(source, contains("""'Search this area'"""));\n    expect(source, contains("""'Change area'"""));\n    expect(source, contains('searchRadiusKm! * 1000'));\n    expect(source, contains('More companies may be available in this area.'));\n  });\n",
    'radius UI source contract',
)
PROJECTION_TEST.write_text(projection_test, encoding='utf-8')

widget_test = WIDGET_TEST.read_text(encoding='utf-8')
widget_insert = r'''

  testWidgets('directory exposes simple place and distance search controls', (
    tester,
  ) async {
    await _pumpSeededDirectory(tester);

    await _scrollDirectoryTo(tester, find.text('Search near a place'));
    expect(find.text('Search near a place'), findsOneWidget);
    expect(find.text('Town or place'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('directory-radius-distance-250')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('directory-radius-search-button')),
      findsOneWidget,
    );
    expect(find.text('Search this area'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
'''
widget_test = replace_once(
    widget_test,
    "\n  testWidgets('service selector exposes the structured Hotshot option', (\n",
    widget_insert + "\n  testWidgets('service selector exposes the structured Hotshot option', (\n",
    'radius search widget test',
)
WIDGET_TEST.write_text(widget_test, encoding='utf-8')

if DOC.exists():
    raise SystemExit('radius-search UI doc already exists')
DOC.write_text(r'''# Release 3 — Dispatch Directory radius search UI

## Date

2026-09-01

## Verified production baseline

```text
54e1a3c100d528eecdf4acdb4c7858644fb0576d
```

Protected production workflow `33519388582` / run #62 passed Firebase deployment, post-deploy Function parity, and responsive mobile/desktop visual acceptance with App Check enforced.

Evidence artifacts:

- Firebase release evidence: `9805447988`
- Visual acceptance evidence: `9805481206`

## User problem

The Directory has a correct server-owned radius-search callable, but ordinary users still need a simple way to choose a place and distance without understanding geohashes, Firestore query bounds, or map internals.

## Bounded UI implementation

- Add a visible `Search near a place` card above existing Directory filters.
- Use the existing OpenStreetMap/Photon place autocomplete and settlement results.
- Keep distance choices simple and oilfield-appropriate: 50, 100, 250, 500, and 1000 km.
- Require an explicit `Search this area` action so results never change unexpectedly while a user is still typing.
- Call only the protected `searchDispatchDirectoryRadius` backend and request its approved maximum of 60 bounded public results.
- Parse callable map points without changing the Firestore projection contract.
- Show returned `distanceKm` on company cards when available.
- Draw the selected search radius on the existing Directory map while preserving provider-declared coverage circles.
- Once a geographic search is active, collapse the control to a clear summary and `Change area` action. This prevents stale results while users edit search parameters.
- Keep existing service, availability, business type, emergency, and remote-site filters as local refinements of the bounded geographic result.
- Disable ordinary cursor pagination while radius-search results are active.

## Completeness rule

The server can return `truncated: true` when a bounded geohash range or result cap is saturated. The UI must then state that more companies may exist and ask the user to reduce the distance before relying on additional filters.

A truncated result must never be described as a complete list of every provider within the selected radius.

## Meaning of the search

`Search near a place` means the provider's **approximate public Directory point** is within the selected radius. It does not assert that every returned provider serves the exact job location, nor does it search private yards, homes, or precise carrier addresses.

Users must still confirm service coverage, exact job location, route, permits, availability, and travel charges directly with the company.

## Existing safety boundaries preserved

- No private carrier data is requested or displayed.
- No Firestore rules/schema changes.
- No direct unbounded Directory scan.
- No payment, subscription, listing, messaging, or provider persistence changes.
- The existing Directory list/map, provider actions, published provider radius visualization, and normal cursor browsing remain available.

## Verification gate

Before merge, this slice must pass:

- exact four-file durable mutation scope;
- `dart analyze lib test`;
- focused Dispatch Directory parser/widget tests;
- full Flutter regression;
- repository release-contract tests;
- both Firebase Functions codebase validations; and
- `git diff --check`.

## Permanent implementation rule

Do not replace the server-owned radius query with a client-side scan of loaded Directory pages. Geographic search results must come from `searchDispatchDirectoryRadius`; local filters may refine those returned results, and a truncated server response must remain visibly identified as incomplete.
''', encoding='utf-8')
