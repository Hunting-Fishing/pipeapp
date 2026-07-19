import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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
                icon: const Icon(Icons.my_location)),
            TextButton(onPressed: _save, child: const Text('SAVE'))
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('How far do you provide service?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
              'Choose a radius, individual communities, or entire administrative regions.'),
          const SizedBox(height: 14),
          SegmentedButton<ServiceAreaMode>(
            segments: const [
              ButtonSegment(
                  value: ServiceAreaMode.radius,
                  icon: Icon(Icons.radar),
                  label: Text('KM radius')),
              ButtonSegment(
                  value: ServiceAreaMode.places,
                  icon: Icon(Icons.location_city),
                  label: Text('Towns')),
              ButtonSegment(
                  value: ServiceAreaMode.regions,
                  icon: Icon(Icons.map_outlined),
                  label: Text('Regions')),
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
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 300,
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
                      userAgentPackageName: 'ca.pipebuyer.marketplace'),
                  if (_mode == ServiceAreaMode.radius)
                    CircleLayer(circles: [
                      CircleMarker(
                          point: _center,
                          radius: _radiusKm * 1000,
                          useRadiusInMeter: true,
                          color: const Color(0x332E7DFF),
                          borderColor: const Color(0xFF0878E8),
                          borderStrokeWidth: 2)
                    ]),
                  if (_mode != ServiceAreaMode.radius)
                    PolygonLayer(
                        polygons: _places
                            .expand((place) => place.boundaryRings)
                            .map((ring) => Polygon(
                                points: ring,
                                color: _mode == ServiceAreaMode.places
                                    ? const Color(0x3328A745)
                                    : const Color(0x332E7DFF),
                                borderColor: _mode == ServiceAreaMode.places
                                    ? const Color(0xFF28A745)
                                    : const Color(0xFF0878E8),
                                borderStrokeWidth: 2))
                            .toList()),
                  DragMarkers(
                      markers: (_mode == ServiceAreaMode.radius
                              ? [
                                  ServiceAreaPlace(
                                      name: _centerLabel, point: _center)
                                ]
                              : _places)
                          .map((place) => DragMarker(
                              point: place.point,
                              size: const Size(44, 44),
                              builder: (_, __, isDragging) => Icon(
                                  Icons.location_pin,
                                  size: isDragging ? 48 : 40,
                                  color: const Color(0xFFFF5A00)),
                              onTap: (_) {
                                if (_mode != ServiceAreaMode.radius) {
                                  setState(() => _editingPlaceIndex =
                                      _places.indexOf(place));
                                }
                              },
                              onDragEnd: (_, point) =>
                                  _draggedPlace(place, point),
                              scrollMapNearEdge: true))
                          .toList()),
                  const SimpleAttributionWidget(
                      source: Text('© OpenStreetMap contributors')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Every orange pin can be selected and dragged.',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_mode == ServiceAreaMode.radius)
            OpenAddressAutocomplete(
                label: 'Search service-area centre', onSelected: _selected),
          if (_mode == ServiceAreaMode.radius) ...[
            const SizedBox(height: 12),
            Text('Service distance: ${_radiusKm.round()} km',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            Slider(
                value: _radiusKm,
                min: 5,
                max: 1000,
                divisions: 199,
                label: '${_radiusKm.round()} km',
                onChanged: (value) => setState(() => _radiusKm = value)),
            Text('$_centerLabel • ${_radiusKm.round()} km radius'),
          ] else ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: Text(
                      _mode == ServiceAreaMode.places
                          ? 'Selected towns and municipalities'
                          : 'Selected administrative regions',
                      style: const TextStyle(fontWeight: FontWeight.w900))),
              OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _editingPlaceIndex = null;
                      _areaSearchVersion++;
                    });
                    WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _areaSearchFocus.requestFocus());
                  },
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add area'))
            ]),
            if (_loadingBoundary)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator()),
            OpenAddressAutocomplete(
                key: ValueKey('${_mode.name}-$_areaSearchVersion'),
                focusNode: _areaSearchFocus,
                label: _mode == ServiceAreaMode.places
                    ? 'Add a town or municipality to your coverage'
                    : 'Add a province, state, region or country to your coverage',
                searchType: _mode == ServiceAreaMode.places
                    ? OpenAddressSearchType.settlement
                    : OpenAddressSearchType.administrative,
                onSelected: _selected),
            const SizedBox(height: 8),
            Text(_editingPlaceIndex == null
                ? 'Search and select another area to expand your mapped coverage.'
                : 'Moving ${_places[_editingPlaceIndex!].name}. Tap the map to correct its pin.'),
            const SizedBox(height: 8),
            if (_places.isEmpty)
              const Text('Search and add one or more service areas.'),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _places
                  .map((place) => InputChip(
                      label: Text(place.name),
                      avatar: const Icon(Icons.location_on_outlined, size: 18),
                      onPressed: () => setState(
                          () => _editingPlaceIndex = _places.indexOf(place)),
                      onDeleted: () => setState(() {
                            final removed = _places.indexOf(place);
                            _places.remove(place);
                            if (_editingPlaceIndex == removed) {
                              _editingPlaceIndex = null;
                            }
                          })))
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Use this service area')),
        ]),
      );

  void _selected(OpenAddress address) async {
    final settlement = _settlementName(address);
    final name = [
      _mode == ServiceAreaMode.places ? settlement : address.region,
      if (_mode == ServiceAreaMode.places) address.region,
      address.country
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
      if (_mode == ServiceAreaMode.places && boundary.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'An official municipality boundary was not available. The town pin is still saved and can be adjusted.')));
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
      final directRelation = _mode == ServiceAreaMode.regions &&
          address.osmType.toUpperCase() == 'R' &&
          address.osmId.isNotEmpty;
      final requestedName = _mode == ServiceAreaMode.places
          ? _settlementName(address)
          : address.region;
      final uri = directRelation
          ? Uri.https('nominatim.openstreetmap.org', '/lookup', {
              'osm_ids': 'R${address.osmId}',
              'format': 'jsonv2',
              'polygon_geojson': '1',
              'polygon_threshold': '0.005',
              'email': 'admin@pipebuyer.com',
            })
          : Uri.https('nominatim.openstreetmap.org', '/search', {
              'q': [requestedName, address.region, address.country]
                  .where((part) => part.isNotEmpty)
                  .join(', '),
              'format': 'jsonv2',
              'addressdetails': '1',
              'polygon_geojson': '1',
              'polygon_threshold': '0.005',
              'limit': '8',
              'email': 'admin@pipebuyer.com',
            });
      final response = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const [];
      final results = jsonDecode(response.body) as List;
      if (results.isEmpty) return const [];
      final candidates = results
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item));
      final polygonCandidates = candidates.where((item) =>
          item['geojson'] is Map &&
          const ['Polygon', 'MultiPolygon']
              .contains((item['geojson'] as Map)['type']));
      final requested = _normalized(requestedName);
      final selected = polygonCandidates.firstWhere((item) {
        final display = _normalized('${item['display_name'] ?? ''}');
        final addressData = item['address'] is Map
            ? Map<String, dynamic>.from(item['address'] as Map)
            : const <String, dynamic>{};
        final names = [
          addressData['city'],
          addressData['town'],
          addressData['village'],
          addressData['municipality'],
          addressData['county'],
          addressData['name']
        ].map((value) => _normalized('${value ?? ''}'));
        return requested.isNotEmpty &&
            (display.startsWith(requested) || names.contains(requested));
      }, orElse: () => <String, dynamic>{});
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
                (pair[1] as num).toDouble(), (pair[0] as num).toDouble()))
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
    final firstLabel =
        address.label.split(',').first.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (firstLabel.isNotEmpty &&
        _normalized(firstLabel) != _normalized(address.region) &&
        _normalized(firstLabel) != _normalized(address.country)) {
      return firstLabel;
    }
    return city;
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
