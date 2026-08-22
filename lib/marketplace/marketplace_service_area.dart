import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'industrial_icon_assets.dart';
import 'marketplace_location_picker.dart';
import 'open_address_autocomplete.dart';

enum ServiceAreaMode { radius, places, regions }

class ServiceAreaPlace {
  const ServiceAreaPlace({
    required this.name,
    required this.point,
    this.region = '',
    this.country = '',
    this.countryCode = '',
    this.osmType = '',
    this.osmId = '',
    this.boundaryRings = const [],
  });

  final String name;
  final LatLng point;
  final String region;
  final String country;
  final String countryCode;
  final String osmType;
  final String osmId;
  final List<List<LatLng>> boundaryRings;

  Map<String, dynamic> toMap() => {
        'name': name,
        'point': GeoPoint(point.latitude, point.longitude),
        'region': region,
        'country': country,
        'countryCode': countryCode,
        'osmType': osmType,
        'osmId': osmId,
        // Firestore does not support arrays nested directly inside arrays.
        // Each polygon ring is therefore stored as an object containing its
        // point array.
        'boundaryRings': boundaryRings
            .map((ring) => {
                  'points': ring
                      .map((point) => GeoPoint(point.latitude, point.longitude))
                      .toList()
                })
            .toList(),
      };

  factory ServiceAreaPlace.fromMap(Map<String, dynamic> value) {
    final point = value['point'];
    return ServiceAreaPlace(
      name: '${value['name'] ?? ''}',
      point: point is GeoPoint
          ? LatLng(point.latitude, point.longitude)
          : const LatLng(55.1707, -118.7947),
      region: '${value['region'] ?? ''}',
      country: '${value['country'] ?? ''}',
      countryCode: '${value['countryCode'] ?? ''}',
      osmType: '${value['osmType'] ?? ''}',
      osmId: '${value['osmId'] ?? ''}',
      boundaryRings: (value['boundaryRings'] as List? ?? const [])
          .map((raw) {
            // Accept the current Firestore-safe object shape and the original
            // in-memory list shape for records created before this migration.
            final points = raw is Map ? raw['points'] : raw;
            return points is List ? points : const <dynamic>[];
          })
          .map((ring) => ring
              .whereType<GeoPoint>()
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList())
          .where((ring) => ring.length >= 3)
          .toList(),
    );
  }
}

class MarketplaceServiceArea {
  const MarketplaceServiceArea({
    required this.mode,
    required this.center,
    required this.centerLabel,
    this.radiusKm = 50,
    this.places = const [],
  });

  final ServiceAreaMode mode;
  final LatLng center;
  final String centerLabel;
  final double radiusKm;
  final List<ServiceAreaPlace> places;

  List<String> get countryCodes => places
      .map((place) => place.countryCode.toUpperCase())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

  List<String> get regionKeys => places
      .map((place) =>
          '${place.countryCode.toUpperCase()}:${place.region.toLowerCase()}')
      .where((value) => !value.endsWith(':'))
      .toSet()
      .toList();

  List<String> get placeKeys => places
      .map((place) =>
          '${place.countryCode.toUpperCase()}:${place.region.toLowerCase()}:${place.name.toLowerCase()}')
      .toSet()
      .toList();

  String get summary => switch (mode) {
        ServiceAreaMode.radius =>
          '$centerLabel and within ${radiusKm.round()} km',
        ServiceAreaMode.places => places.isEmpty
            ? 'Selected towns and communities'
            : places.map((e) => e.name).join(', '),
        ServiceAreaMode.regions => places.isEmpty
            ? 'Selected regions'
            : places.map((e) => e.name).join(', '),
      };

  Map<String, dynamic> toMap() => {
        'mode': mode.name,
        'center': GeoPoint(center.latitude, center.longitude),
        'centerLabel': centerLabel,
        'radiusKm': radiusKm,
        'places': places.map((place) => place.toMap()).toList(),
        'schemaVersion': 1,
      };

  factory MarketplaceServiceArea.fromMap(Map<String, dynamic> value) {
    final center = value['center'];
    final modeName = '${value['mode'] ?? 'radius'}';
    return MarketplaceServiceArea(
      mode: ServiceAreaMode.values.firstWhere(
        (item) => item.name == modeName,
        orElse: () => ServiceAreaMode.radius,
      ),
      center: center is GeoPoint
          ? LatLng(center.latitude, center.longitude)
          : const LatLng(55.1707, -118.7947),
      centerLabel: '${value['centerLabel'] ?? ''}',
      radiusKm: (value['radiusKm'] as num?)?.toDouble() ?? 50,
      places: (value['places'] as List? ?? const [])
          .whereType<Map>()
          .map((item) =>
              ServiceAreaPlace.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

Map<String, dynamic> selectServiceAreaBoundaryCandidate({
  required Iterable<Map<String, dynamic>> candidates,
  required String requestedName,
  required ServiceAreaMode mode,
  String countryCode = '',
}) {
  final requested = _normalizeServiceAreaBoundaryText(requestedName);
  if (requested.isEmpty) return <String, dynamic>{};

  const settlementTypes = {
    'city',
    'town',
    'village',
    'hamlet',
    'locality',
    'municipality',
    'borough',
  };
  const broadTypes = {
    'country',
    'state',
    'province',
    'region',
    'district',
    'county',
  };
  const regionTypes = {
    'country',
    'state',
    'province',
    'region',
    'district',
    'county',
    'municipality',
    'administrative',
  };

  for (final item in candidates) {
    final geometry = item['geojson'];
    if (geometry is! Map ||
        !const ['Polygon', 'MultiPolygon'].contains(geometry['type'])) {
      continue;
    }

    final address = item['address'] is Map
        ? Map<String, dynamic>.from(item['address'] as Map)
        : const <String, dynamic>{};
    final namedetails = item['namedetails'] is Map
        ? Map<String, dynamic>.from(item['namedetails'] as Map)
        : const <String, dynamic>{};
    final extratags = item['extratags'] is Map
        ? Map<String, dynamic>.from(item['extratags'] as Map)
        : const <String, dynamic>{};
    final displayFirst =
        '${item['display_name'] ?? ''}'.split(',').first.trim();
    final names = <String>[
      '${item['name'] ?? ''}',
      '${namedetails['name'] ?? ''}',
      displayFirst,
      ...[
        'city',
        'town',
        'village',
        'hamlet',
        'locality',
        'municipality',
        'borough',
        'district',
        'county',
        'state',
        'province',
        'region',
        'country',
      ].map((key) => '${address[key] ?? ''}'),
    ].map(_normalizeServiceAreaBoundaryText).where((value) => value.isNotEmpty);
    if (!names.contains(requested)) continue;

    final addressType = '${item['addresstype'] ?? ''}'.trim().toLowerCase();
    if (mode == ServiceAreaMode.places) {
      if (broadTypes.contains(addressType)) continue;
      final settlementEvidence = settlementTypes.contains(addressType) ||
          const [
            'city',
            'town',
            'village',
            'hamlet',
            'locality',
            'municipality',
            'borough',
          ].any((key) =>
              _normalizeServiceAreaBoundaryText('${address[key] ?? ''}') ==
              requested);
      if (!settlementEvidence) continue;

      // Canadian incorporated municipalities are admin_level 8 in OSM.
      // Reject a broader regional-district boundary even if its address
      // hierarchy happens to mention the requested city.
      if (countryCode.trim().toUpperCase() == 'CA') {
        final adminLevel = '${extratags['admin_level'] ?? ''}'.trim();
        if (adminLevel.isNotEmpty && adminLevel != '8') continue;
      }
    } else {
      final regionEvidence = regionTypes.contains(addressType) ||
          const [
            'country',
            'state',
            'province',
            'region',
            'district',
            'county',
            'municipality',
          ].any((key) =>
              _normalizeServiceAreaBoundaryText('${address[key] ?? ''}') ==
              requested);
      if (!regionEvidence) continue;
    }

    return item;
  }
  return <String, dynamic>{};
}

String _normalizeServiceAreaBoundaryText(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

class MarketplaceServiceAreaPicker extends StatefulWidget {
  const MarketplaceServiceAreaPicker({super.key, this.initial});
  final MarketplaceServiceArea? initial;

  static Future<MarketplaceServiceArea?> show(
          BuildContext context, MarketplaceServiceArea? initial) =>
      Navigator.of(context).push<MarketplaceServiceArea>(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => MarketplaceServiceAreaPicker(initial: initial)));

  @override
  State<MarketplaceServiceAreaPicker> createState() =>
      _MarketplaceServiceAreaPickerState();
}

class _MarketplaceServiceAreaPickerState
    extends State<MarketplaceServiceAreaPicker> {
  final _mapController = MapController();
  late ServiceAreaMode _mode;
  late LatLng _center;
  late String _centerLabel;
  late double _radiusKm;
  late List<ServiceAreaPlace> _places;
  final _areaSearchFocus = FocusNode();
  int? _editingPlaceIndex;
  bool _loadingBoundary = false;
  int _areaSearchVersion = 0;
  final Map<ServiceAreaMode, List<ServiceAreaPlace>> _modePlaces = {
    ServiceAreaMode.places: <ServiceAreaPlace>[],
    ServiceAreaMode.regions: <ServiceAreaPlace>[],
  };

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _mode = initial?.mode ?? ServiceAreaMode.radius;
    _center = initial?.center ?? const LatLng(55.1707, -118.7947);
    _centerLabel = initial?.centerLabel ?? 'Grande Prairie, Alberta';
    _radiusKm = initial?.radiusKm ?? 50;
    _places = [...?initial?.places];
    if (_mode == ServiceAreaMode.places) {
      _places = _places.where((place) {
        final tag = _normalized(place.name);
        final regionOnly = _normalized('${place.region}, ${place.country}');
        return tag.isNotEmpty && tag != regionOnly;
      }).toList();
    }
    if (_mode != ServiceAreaMode.radius) {
      _modePlaces[_mode] = _places;
    }
  }

  @override
  void dispose() {
    _areaSearchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Service area'),
          actions: [
            IconButton(
              tooltip: 'Use my current location',
              onPressed: _useCurrentLocation,
              icon: const Icon(Icons.my_location_rounded),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final content = _buildControls(context);
              final map = _buildMapPanel(context, wide: wide);
              if (wide) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 430,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 22, 14, 30),
                            child: content,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 22, 22, 30),
                            child: map,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
                  content,
                  const SizedBox(height: 16),
                  map,
                ],
              );
            },
          ),
        ),
      );

  Widget _buildControls(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ServiceAreaHero(mode: _mode),
          const SizedBox(height: 16),
          Text(
            'Coverage method',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            'Define where you provide service. This controls marketplace discovery and service-area matching; it does not publish an exact private address.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: .64),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ServiceAreaMode>(
            showSelectedIcon: true,
            segments: const [
              ButtonSegment(
                value: ServiceAreaMode.radius,
                icon: Icon(Icons.radar_rounded),
                label: Text('Radius'),
              ),
              ButtonSegment(
                value: ServiceAreaMode.places,
                icon: Icon(Icons.location_city_outlined),
                label: Text('Towns'),
              ),
              ButtonSegment(
                value: ServiceAreaMode.regions,
                icon: Icon(Icons.map_outlined),
                label: Text('Regions'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() {
              if (_mode != ServiceAreaMode.radius) {
                _modePlaces[_mode] = _places;
              }
              _mode = value.first;
              if (_mode != ServiceAreaMode.radius) {
                _places = _modePlaces[_mode] ?? <ServiceAreaPlace>[];
              }
              _editingPlaceIndex = null;
              _areaSearchVersion++;
            }),
          ),
          const SizedBox(height: 16),
          if (_mode == ServiceAreaMode.radius) ...[
            OpenAddressAutocomplete(
              label: 'Service-area centre',
              hint: 'Search a city, town, yard community, or operating area',
              onSelected: _selected,
            ),
            const SizedBox(height: 13),
            _RadiusControlCard(
              centerLabel: _centerLabel,
              radiusKm: _radiusKm,
              onChanged: (value) => setState(() => _radiusKm = value),
            ),
          ] else ...[
            _SelectedAreasHeader(
              mode: _mode,
              count: _places.length,
              onAdd: () {
                setState(() {
                  _editingPlaceIndex = null;
                  _areaSearchVersion++;
                });
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _areaSearchFocus.requestFocus());
              },
            ),
            if (_loadingBoundary) ...[
              const SizedBox(height: 10),
              const _BoundaryLoadingCard(),
            ],
            const SizedBox(height: 10),
            OpenAddressAutocomplete(
              key: ValueKey('${_mode.name}-$_areaSearchVersion'),
              focusNode: _areaSearchFocus,
              label: _mode == ServiceAreaMode.places
                  ? 'Add a town or municipality'
                  : 'Add a province, state, region, or country',
              searchType: _mode == ServiceAreaMode.places
                  ? OpenAddressSearchType.settlement
                  : OpenAddressSearchType.administrative,
              onSelected: _selected,
            ),
            const SizedBox(height: 10),
            Text(
              _editingPlaceIndex == null
                  ? 'Search and select another area to expand your mapped coverage.'
                  : 'Editing ${_places[_editingPlaceIndex!].name}. You can drag its orange pin or tap the map to correct the reference point.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .62),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 10),
            if (_places.isEmpty)
              _EmptyCoverageCard(mode: _mode)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _places
                    .map(
                      (place) => InputChip(
                        selected: _editingPlaceIndex == _places.indexOf(place),
                        selectedColor: PipeBuyerColors.orangeSoft,
                        side: BorderSide(
                          color: _editingPlaceIndex == _places.indexOf(place)
                              ? PipeBuyerColors.orange
                              : Theme.of(context).dividerColor,
                        ),
                        label: Text(place.name),
                        avatar: const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: PipeBuyerColors.orangePressed,
                        ),
                        onPressed: () => setState(
                          () => _editingPlaceIndex = _places.indexOf(place),
                        ),
                        onDeleted: () => setState(() {
                          final removed = _places.indexOf(place);
                          _places.remove(place);
                          if (_editingPlaceIndex == removed) {
                            _editingPlaceIndex = null;
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
          ],
          const SizedBox(height: 16),
          _CoverageSummaryCard(
            mode: _mode,
            centerLabel: _centerLabel,
            radiusKm: _radiusKm,
            places: _places,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Use this service area'),
          ),
        ],
      );

  Widget _buildMapPanel(BuildContext context, {required bool wide}) =>
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 22,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const IndustrialAssetIcon(
                      label: 'Service area map',
                      assetPath: IndustrialIconAssets.routeMap,
                      size: 38,
                      borderRadius: 9,
                      fallback: Icon(
                        Icons.map_outlined,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coverage map',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          _mode == ServiceAreaMode.radius
                              ? 'Drag the orange pin or adjust the service radius.'
                              : 'Selected boundaries and reference pins are shown below.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: .60),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Use my current location',
                    onPressed: _useCurrentLocation,
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: wide ? 500 : 330,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _mode == ServiceAreaMode.radius ? 7 : 5,
                        onTap: (_, point) => _mapTapped(point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: pipeBuyerTileUrl,
                          userAgentPackageName: 'ca.pipebuyer.marketplace',
                        ),
                        if (_mode == ServiceAreaMode.radius)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: _center,
                                radius: _radiusKm * 1000,
                                useRadiusInMeter: true,
                                color: PipeBuyerColors.orange
                                    .withValues(alpha: .13),
                                borderColor: PipeBuyerColors.orange,
                                borderStrokeWidth: 2.5,
                              ),
                            ],
                          ),
                        if (_mode != ServiceAreaMode.radius)
                          PolygonLayer(
                            polygons: _places
                                .expand((place) => place.boundaryRings)
                                .map(
                                  (ring) => Polygon(
                                    points: ring,
                                    color: _mode == ServiceAreaMode.places
                                        ? PipeBuyerColors.success
                                            .withValues(alpha: .14)
                                        : PipeBuyerColors.industrialBlue
                                            .withValues(alpha: .13),
                                    borderColor: _mode == ServiceAreaMode.places
                                        ? PipeBuyerColors.success
                                        : PipeBuyerColors.industrialBlue,
                                    borderStrokeWidth: 2.25,
                                  ),
                                )
                                .toList(),
                          ),
                        DragMarkers(
                          markers: (_mode == ServiceAreaMode.radius
                                  ? [
                                      ServiceAreaPlace(
                                        name: _centerLabel,
                                        point: _center,
                                      ),
                                    ]
                                  : _places)
                              .map(
                                (place) => DragMarker(
                                  point: place.point,
                                  size: const Size(48, 48),
                                  builder: (_, __, isDragging) =>
                                      _ServiceAreaMapPin(
                                    active: isDragging ||
                                        (_mode != ServiceAreaMode.radius &&
                                            _editingPlaceIndex ==
                                                _places.indexOf(place)),
                                  ),
                                  onTap: (_) {
                                    if (_mode != ServiceAreaMode.radius) {
                                      setState(() => _editingPlaceIndex =
                                          _places.indexOf(place));
                                    }
                                  },
                                  onDragEnd: (_, point) =>
                                      _draggedPlace(place, point),
                                  scrollMapNearEdge: true,
                                ),
                              )
                              .toList(),
                        ),
                        const SimpleAttributionWidget(
                          source: Text('© OpenStreetMap contributors'),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _MapModeBadge(mode: _mode),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: .52),
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.privacy_tip_outlined,
                    color: PipeBuyerColors.industrialBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Service coverage is used for discovery and matching. A service-area map does not publish a private yard, home, or exact business address.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  void _selected(OpenAddress address) async {
    final selectedAreaName = _mode == ServiceAreaMode.places
        ? _settlementName(address)
        : _regionName(address);
    final name = [
      selectedAreaName,
      if (address.region.isNotEmpty &&
          _normalized(address.region) != _normalized(selectedAreaName))
        address.region,
      address.country,
    ].where((value) => value.isNotEmpty).toSet().join(', ');
    var place = ServiceAreaPlace(
      name: name.isEmpty ? address.label : name,
      point: address.point,
      region: address.region,
      country: address.country,
      countryCode: address.countryCode,
      osmType: address.osmType,
      osmId: address.osmId,
    );
    if (_mode == ServiceAreaMode.radius) {
      setState(() {
        _center = address.point;
        _centerLabel = name.isEmpty ? address.label : name;
        _places = [place];
      });
      _mapController.move(address.point, 8);
      return;
    }
    if (_mode == ServiceAreaMode.regions || _mode == ServiceAreaMode.places) {
      setState(() => _loadingBoundary = true);
      final boundary = await _loadBoundary(address);
      place = ServiceAreaPlace(
        name: place.name,
        point: place.point,
        region: place.region,
        country: place.country,
        countryCode: place.countryCode,
        osmType: place.osmType,
        osmId: place.osmId,
        boundaryRings: boundary,
      );
      if (!mounted) return;
      setState(() => _loadingBoundary = false);
      if (_mode == ServiceAreaMode.regions && boundary.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'An official administrative boundary was not available for this region result, so it was not added. Choose another region result with a mapped boundary.',
          ),
        ));
        return;
      }
      if (_mode == ServiceAreaMode.places && boundary.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'An official municipality boundary was not available. Only the town reference point will be saved; a surrounding district will not be substituted.',
          ),
        ));
      }
    }
    if (_places.any((item) => item.name == place.name)) return;
    setState(() => _places.add(place));
    if (place.boundaryRings.isNotEmpty) {
      _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(
              place.boundaryRings.expand((ring) => ring).toList()),
          padding: const EdgeInsets.all(24)));
    } else {
      _mapController.move(
          address.point, _mode == ServiceAreaMode.places ? 8 : 5);
    }
  }

  void _mapTapped(LatLng point) {
    setState(() {
      _center = point;
      if (_mode == ServiceAreaMode.radius) {
        _centerLabel = 'Manually positioned service centre';
        return;
      }
      final index = _editingPlaceIndex;
      if (index != null && index >= 0 && index < _places.length) {
        final current = _places[index];
        _places[index] = ServiceAreaPlace(
          name: current.name,
          point: point,
          region: current.region,
          country: current.country,
          countryCode: current.countryCode,
          osmType: current.osmType,
          osmId: current.osmId,
          boundaryRings: current.boundaryRings,
        );
      }
    });
  }

  void _draggedPlace(ServiceAreaPlace place, LatLng point) {
    setState(() {
      if (_mode == ServiceAreaMode.radius) {
        _center = point;
        _centerLabel = 'Manually positioned service centre';
        if (_places.isNotEmpty) {
          final current = _places.first;
          _places[0] = ServiceAreaPlace(
              name: current.name,
              point: point,
              region: current.region,
              country: current.country,
              countryCode: current.countryCode,
              osmType: current.osmType,
              osmId: current.osmId,
              boundaryRings: current.boundaryRings);
        }
        return;
      }
      final index = _places.indexOf(place);
      if (index < 0) return;
      _editingPlaceIndex = index;
      _places[index] = ServiceAreaPlace(
          name: place.name,
          point: point,
          region: place.region,
          country: place.country,
          countryCode: place.countryCode,
          osmType: place.osmType,
          osmId: place.osmId,
          boundaryRings: place.boundaryRings);
    });
  }

  Future<List<List<LatLng>>> _loadBoundary(OpenAddress address) async {
    try {
      final directRelation =
          _isRelationOsmType(address.osmType) && address.osmId.isNotEmpty;
      final requestedName = _mode == ServiceAreaMode.places
          ? _settlementName(address)
          : _regionName(address);
      final common = <String, String>{
        'format': 'jsonv2',
        'addressdetails': '1',
        'extratags': '1',
        'namedetails': '1',
        'polygon_geojson': '1',
        'polygon_threshold':
            _mode == ServiceAreaMode.places ? '0.002' : '0.005',
        'limit': '8',
        'email': 'admin@pipebuyer.com',
      };

      Future<List<Map<String, dynamic>>> fetchCandidates(Uri uri) async {
        final response = await http.get(uri, headers: {
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) return const [];
        final decoded = jsonDecode(response.body);
        if (decoded is! List) return const [];
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }

      var candidates = <Map<String, dynamic>>[];
      if (directRelation) {
        candidates = await fetchCandidates(
          Uri.https('nominatim.openstreetmap.org', '/lookup', {
            ...common,
            'osm_ids': 'R${address.osmId}',
          }),
        );
      }

      var selected = selectServiceAreaBoundaryCandidate(
        candidates: candidates,
        requestedName: requestedName,
        mode: _mode,
        countryCode: address.countryCode,
      );

      if (selected.isEmpty) {
        final queryParts = <String>[
          requestedName,
          if (address.region.isNotEmpty &&
              _normalized(address.region) != _normalized(requestedName))
            address.region,
          address.country,
        ].where((part) => part.isNotEmpty).toSet().toList();
        final searchParameters = <String, String>{
          ...common,
          if (address.countryCode.isNotEmpty)
            'countrycodes': address.countryCode.toLowerCase(),
          if (_mode == ServiceAreaMode.places) 'city': requestedName,
          if (_mode == ServiceAreaMode.places && address.region.isNotEmpty)
            'state': address.region,
          if (_mode == ServiceAreaMode.places && address.country.isNotEmpty)
            'country': address.country,
          if (_mode == ServiceAreaMode.regions) 'q': queryParts.join(', '),
        };
        candidates = await fetchCandidates(
          Uri.https(
            'nominatim.openstreetmap.org',
            '/search',
            searchParameters,
          ),
        );
        selected = selectServiceAreaBoundaryCandidate(
          candidates: candidates,
          requestedName: requestedName,
          mode: _mode,
          countryCode: address.countryCode,
        );
      }

      final geometry = selected['geojson'] as Map<String, dynamic>?;
      if (geometry == null) return const [];
      final coordinates = geometry['coordinates'];
      final rings = <List<LatLng>>[];

      void addRing(dynamic raw) {
        if (raw is! List) return;
        final ring = raw
            .whereType<List>()
            .where((pair) => pair.length >= 2)
            .map((pair) => LatLng(
                  (pair[1] as num).toDouble(),
                  (pair[0] as num).toDouble(),
                ))
            .toList();
        if (ring.length >= 3) rings.add(ring);
      }

      if (geometry['type'] == 'Polygon' && coordinates is List) {
        if (coordinates.isNotEmpty) addRing(coordinates.first);
      } else if (geometry['type'] == 'MultiPolygon' && coordinates is List) {
        for (final polygon in coordinates.whereType<List>()) {
          if (polygon.isNotEmpty) addRing(polygon.first);
        }
      }
      return rings;
    } catch (_) {
      return const [];
    }
  }

  String _settlementName(OpenAddress address) {
    final city = address.city.trim();
    if (city.isNotEmpty && _normalized(city) != _normalized(address.region)) {
      return city;
    }
    final explicit = address.name.trim();
    if (explicit.isNotEmpty &&
        const {
          'city',
          'town',
          'village',
          'hamlet',
          'locality',
          'municipality',
          'borough',
        }.contains(address.placeType.toLowerCase()) &&
        _normalized(explicit) != _normalized(address.region)) {
      return explicit;
    }
    final firstLabel =
        address.label.split(',').first.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (firstLabel.isNotEmpty &&
        _normalized(firstLabel) != _normalized(address.region) &&
        _normalized(firstLabel) != _normalized(address.country)) {
      return firstLabel;
    }
    return city;
  }

  String _regionName(OpenAddress address) {
    final explicit = address.name.trim();
    if (explicit.isNotEmpty) return explicit;
    final region = address.region.trim();
    if (region.isNotEmpty) return region;
    return address.label.split(',').first.trim();
  }

  bool _isRelationOsmType(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'r' || normalized == 'relation';
  }

  String _normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  Future<void> _useCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission was not granted.');
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12)));
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _center = point;
        if (_mode == ServiceAreaMode.radius) {
          _centerLabel = 'Current device location';
        }
      });
      _mapController.move(point, 13);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not use device location: $error')));
      }
    }
  }

  void _save() {
    if (_mode != ServiceAreaMode.radius && _places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one service area.')));
      return;
    }
    Navigator.pop(
        context,
        MarketplaceServiceArea(
          mode: _mode,
          center: _center,
          centerLabel: _centerLabel,
          radiusKm: _radiusKm,
          places: _places,
        ));
  }
}

class _ServiceAreaHero extends StatelessWidget {
  const _ServiceAreaHero({required this.mode});

  final ServiceAreaMode mode;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x21000000),
              blurRadius: 20,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const IndustrialAssetIcon(
                label: 'Service area coverage',
                assetPath: IndustrialIconAssets.routeMap,
                size: 66,
                borderRadius: 11,
                fallback: Icon(
                  Icons.route_outlined,
                  color: PipeBuyerColors.orange,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OPERATING COVERAGE',
                    style: TextStyle(
                      color: PipeBuyerColors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .75,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Where do you provide service?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1.18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    switch (mode) {
                      ServiceAreaMode.radius =>
                        'Set a practical operating radius around a community or yard area.',
                      ServiceAreaMode.places =>
                        'Choose specific towns and municipalities your operation serves.',
                      ServiceAreaMode.regions =>
                        'Define broader state, province, regional, or country coverage.',
                    },
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _RadiusControlCard extends StatelessWidget {
  const _RadiusControlCard({
    required this.centerLabel,
    required this.radiusKm,
    required this.onChanged,
  });

  final String centerLabel;
  final double radiusKm;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.orangeSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    color: PipeBuyerColors.orangePressed,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${radiusKm.round()} km service radius',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        centerLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: radiusKm,
              min: 5,
              max: 1000,
              divisions: 199,
              label: '${radiusKm.round()} km',
              activeColor: PipeBuyerColors.orange,
              onChanged: onChanged,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('5 km', style: TextStyle(fontSize: 10.5)),
                Text('1,000 km', style: TextStyle(fontSize: 10.5)),
              ],
            ),
          ],
        ),
      );
}

class _SelectedAreasHeader extends StatelessWidget {
  const _SelectedAreasHeader({
    required this.mode,
    required this.count,
    required this.onAdd,
  });

  final ServiceAreaMode mode;
  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode == ServiceAreaMode.places
                      ? 'Selected communities'
                      : 'Selected regions',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '$count ${count == 1 ? 'area' : 'areas'} mapped',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add area'),
          ),
        ],
      );
}

class _BoundaryLoadingCard extends StatelessWidget {
  const _BoundaryLoadingCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: PipeBuyerColors.industrialBlue.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: PipeBuyerColors.industrialBlue.withValues(alpha: .18),
          ),
        ),
        child: const Row(
          children: [
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Loading official map boundary…',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

class _EmptyCoverageCard extends StatelessWidget {
  const _EmptyCoverageCard({required this.mode});

  final ServiceAreaMode mode;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.add_location_alt_outlined,
              color: PipeBuyerColors.orangePressed,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mode == ServiceAreaMode.places
                    ? 'Search and add one or more towns or municipalities to show where you provide service.'
                    : 'Search and add one or more administrative regions to define your operating coverage.',
                style: const TextStyle(height: 1.35),
              ),
            ),
          ],
        ),
      );
}

class _CoverageSummaryCard extends StatelessWidget {
  const _CoverageSummaryCard({
    required this.mode,
    required this.centerLabel,
    required this.radiusKm,
    required this.places,
  });

  final ServiceAreaMode mode;
  final String centerLabel;
  final double radiusKm;
  final List<ServiceAreaPlace> places;

  @override
  Widget build(BuildContext context) {
    final headline = switch (mode) {
      ServiceAreaMode.radius => '${radiusKm.round()} km radius',
      ServiceAreaMode.places =>
        '${places.length} ${places.length == 1 ? 'community' : 'communities'}',
      ServiceAreaMode.regions =>
        '${places.length} ${places.length == 1 ? 'region' : 'regions'}',
    };
    final detail = switch (mode) {
      ServiceAreaMode.radius => centerLabel,
      ServiceAreaMode.places || ServiceAreaMode.regions => places.isEmpty
          ? 'No areas selected yet'
          : places.take(3).map((place) => place.name).join(' • ') +
              (places.length > 3 ? ' • +${places.length - 3} more' : ''),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PipeBuyerColors.success.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PipeBuyerColors.success.withValues(alpha: .20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PipeBuyerColors.success.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: PipeBuyerColors.success,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceAreaMapPin extends StatelessWidget {
  const _ServiceAreaMapPin({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: active ? 46 : 42,
        height: active ? 46 : 42,
        decoration: BoxDecoration(
          color: PipeBuyerColors.ink,
          shape: BoxShape.circle,
          border: Border.all(
            color: PipeBuyerColors.orange,
            width: active ? 3 : 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.location_on_rounded,
          color: PipeBuyerColors.orange,
          size: 25,
        ),
      );
}

class _MapModeBadge extends StatelessWidget {
  const _MapModeBadge({required this.mode});

  final ServiceAreaMode mode;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xE611151A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (mode) {
                ServiceAreaMode.radius => Icons.radar_rounded,
                ServiceAreaMode.places => Icons.location_city_outlined,
                ServiceAreaMode.regions => Icons.map_outlined,
              },
              color: PipeBuyerColors.orange,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              switch (mode) {
                ServiceAreaMode.radius => 'RADIUS COVERAGE',
                ServiceAreaMode.places => 'COMMUNITY COVERAGE',
                ServiceAreaMode.regions => 'REGIONAL COVERAGE',
              },
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .35,
              ),
            ),
          ],
        ),
      );
}
