import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/design/pipe_buyer_theme.dart';

const pipeBuyerGeocoderUrl = String.fromEnvironment(
  'GEOCODER_URL',
  defaultValue: 'https://photon.komoot.io/api/',
);

class OpenAddress {
  const OpenAddress({
    required this.label,
    required this.point,
    this.street = '',
    this.city = '',
    this.region = '',
    this.postalCode = '',
    this.country = '',
    this.countryCode = '',
    this.placeType = '',
    this.osmType = '',
    this.osmId = '',
  });
  final String label;
  final LatLng point;
  final String street;
  final String city;
  final String region;
  final String postalCode;
  final String country;
  final String countryCode;
  final String placeType;
  final String osmType;
  final String osmId;
}

enum OpenAddressSearchType { all, settlement, administrative }

Future<OpenAddress?> reverseOpenAddress(LatLng point) async {
  final base = Uri.parse(pipeBuyerGeocoderUrl);
  final reverse = base.resolve('../reverse').replace(queryParameters: {
    'lat': point.latitude.toString(),
    'lon': point.longitude.toString(),
    'limit': '1',
    'lang': 'en',
    'radius': '15',
  });
  final response = await http.get(reverse, headers: {
    'Accept': 'application/json'
  }).timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) {
    throw StateError('Reverse geocoder unavailable');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final features = data['features'] as List? ?? const [];
  if (features.isEmpty) return null;
  return _openAddressFromFeature(
      Map<String, dynamic>.from(features.first as Map));
}

class OpenAddressAutocomplete extends StatefulWidget {
  const OpenAddressAutocomplete({
    super.key,
    required this.onSelected,
    this.initialValue = '',
    this.label = 'Search address or place',
    this.hint = 'Start typing a street, town, lease or postal code',
    this.searchType = OpenAddressSearchType.all,
    this.focusNode,
    this.enabled = true,
    this.onChanged,
    this.bias,
  });
  final String initialValue;
  final String label;
  final String hint;
  final ValueChanged<OpenAddress> onSelected;
  final OpenAddressSearchType searchType;
  final FocusNode? focusNode;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final LatLng? bias;

  @override
  State<OpenAddressAutocomplete> createState() =>
      _OpenAddressAutocompleteState();
}

class _OpenAddressAutocompleteState extends State<OpenAddressAutocomplete> {
  late final TextEditingController _controller;
  Timer? _debounce;
  int _request = 0;
  bool _loading = false;
  List<OpenAddress> _results = const [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant OpenAddressAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            autofillHints: const [AutofillHints.fullStreetAddress],
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              prefixIcon: const Icon(
                Icons.travel_explore_outlined,
                color: PipeBuyerColors.orangePressed,
              ),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear location search',
                          onPressed: !widget.enabled
                              ? null
                              : () {
                                  _controller.clear();
                                  widget.onChanged?.call('');
                                  setState(() => _results = const []);
                                },
                          icon: const Icon(Icons.close_rounded),
                        ),
            ),
            onChanged: (value) {
              setState(() {});
              widget.onChanged?.call(value);
              _changed(value);
            },
          ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.map_outlined,
                          size: 16,
                          color: PipeBuyerColors.orangePressed,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LOCATION RESULTS',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: PipeBuyerColors.orangePressed,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .65,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          '${_results.length}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 6),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 64,
                        color: Theme.of(context).dividerColor,
                      ),
                      itemBuilder: (_, index) {
                        final address = _results[index];
                        final secondary = [
                          address.city,
                          address.region,
                          address.country,
                        ].where((part) => part.isNotEmpty).toSet().join(', ');
                        return InkWell(
                          onTap: () {
                            _controller.text = address.label;
                            setState(() => _results = const []);
                            widget.onSelected(address);
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: PipeBuyerColors.orangeSoft,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(
                                    _placeTypeIcon(address.placeType),
                                    color: PipeBuyerColors.orangePressed,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        address.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          height: 1.25,
                                        ),
                                      ),
                                      if (secondary.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          secondary,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: .58),
                                              ),
                                        ),
                                      ],
                                      if (address.placeType.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            _placeTypeLabel(address.placeType),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Icon(
                                    Icons.north_west_rounded,
                                    size: 18,
                                    color: PipeBuyerColors.orange,
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
              ),
            ),
          ],
        ],
      );

  void _changed(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(query));
  }

  Future<void> _search(String query) async {
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final base = Uri.parse(pipeBuyerGeocoderUrl);
      final bias = widget.bias;
      final uri = base.replace(queryParameters: {
        ...base.queryParameters,
        'q': query.trim(),
        'limit': '6',
        'lang': 'en',
        if (bias != null) 'lat': bias.latitude.toString(),
        if (bias != null) 'lon': bias.longitude.toString(),
      });
      final response = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw StateError('Geocoder unavailable');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['features'] as List? ?? const [])
          .map((raw) =>
              _openAddressFromFeature(Map<String, dynamic>.from(raw as Map)))
          .where((item) => item.label.isNotEmpty)
          .where((item) => switch (widget.searchType) {
                OpenAddressSearchType.all => true,
                OpenAddressSearchType.settlement => const [
                    'city',
                    'town',
                    'village',
                    'hamlet',
                    'locality',
                    'district',
                    'county'
                  ].contains(item.placeType),
                OpenAddressSearchType.administrative => const [
                    'country',
                    'state',
                    'province',
                    'region',
                    'district',
                    'county'
                  ].contains(item.placeType),
              })
          .toList();
      if (mounted && request == _request) setState(() => _results = results);
    } catch (_) {
      if (mounted && request == _request) setState(() => _results = const []);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }
}

IconData _placeTypeIcon(String value) => switch (value.toLowerCase()) {
      'country' => Icons.public_outlined,
      'state' || 'province' || 'region' => Icons.map_outlined,
      'city' || 'town' || 'village' || 'hamlet' || 'locality' =>
        Icons.location_city_outlined,
      'district' || 'county' => Icons.hub_outlined,
      _ => Icons.location_on_outlined,
    };

String _placeTypeLabel(String value) {
  final normalized = value.trim().replaceAll('_', ' ');
  if (normalized.isEmpty) return 'Place';
  return normalized
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

OpenAddress _openAddressFromFeature(Map<String, dynamic> feature) {
  final properties =
      Map<String, dynamic>.from(feature['properties'] as Map? ?? const {});
  final geometry =
      Map<String, dynamic>.from(feature['geometry'] as Map? ?? const {});
  final coordinates = geometry['coordinates'] as List? ?? const [0, 0];
  String read(String key) => '${properties[key] ?? ''}'.trim();
  final street = [read('housenumber'), read('street')]
      .where((value) => value.isNotEmpty)
      .join(' ');
  final community = [
    read('city'),
    read('town'),
    read('village'),
    read('hamlet'),
    read('locality'),
    read('district'),
    read('county'),
  ].firstWhere((value) => value.isNotEmpty, orElse: () => '');
  final parts = [
    street,
    read('name'),
    community,
    read('state'),
    read('postcode'),
    read('country')
  ].where((value) => value.isNotEmpty).toSet().toList();
  return OpenAddress(
    label: parts.join(', '),
    point: LatLng(
        (coordinates[1] as num).toDouble(), (coordinates[0] as num).toDouble()),
    street: street,
    city: community,
    region: read('state'),
    postalCode: read('postcode'),
    country: read('country'),
    countryCode: read('countrycode').toUpperCase(),
    placeType: read('type'),
    osmType: read('osm_type'),
    osmId: read('osm_id'),
  );
}
