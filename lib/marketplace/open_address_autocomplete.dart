import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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

const settlementOpenAddressTypes = {
  'city',
  'town',
  'village',
  'hamlet',
  'locality',
  'municipality',
};

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
  return openAddressFromFeature(
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
  Widget build(BuildContext context) => Column(children: [
        TextFormField(
          controller: _controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autofillHints: const [AutofillHints.fullStreetAddress],
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : null,
          ),
          onChanged: (value) {
            widget.onChanged?.call(value);
            _changed(value);
          },
        ),
        if (_results.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 230),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 10)
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final address = _results[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(address.label, maxLines: 2),
                  subtitle: Text([address.city, address.region, address.country]
                      .where((part) => part.isNotEmpty)
                      .join(', ')),
                  onTap: () {
                    _controller.text = address.label;
                    setState(() => _results = const []);
                    widget.onSelected(address);
                  },
                );
              },
            ),
          ),
      ]);

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
              openAddressFromFeature(Map<String, dynamic>.from(raw as Map)))
          .where((item) => item.label.isNotEmpty)
          .where((item) => switch (widget.searchType) {
                OpenAddressSearchType.all => true,
                OpenAddressSearchType.settlement =>
                  settlementOpenAddressTypes.contains(item.placeType),
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

OpenAddress openAddressFromFeature(Map<String, dynamic> feature) {
  final properties =
      Map<String, dynamic>.from(feature['properties'] as Map? ?? const {});
  final geometry =
      Map<String, dynamic>.from(feature['geometry'] as Map? ?? const {});
  final coordinates = geometry['coordinates'] as List? ?? const [0, 0];
  String read(String key) => '${properties[key] ?? ''}'.trim();
  final placeType = read('type').toLowerCase();
  final featureName = read('name');
  final street = [read('housenumber'), read('street')]
      .where((value) => value.isNotEmpty)
      .join(' ');
  final community = [
    if (settlementOpenAddressTypes.contains(placeType)) featureName,
    read('city'),
    read('town'),
    read('village'),
    read('hamlet'),
    read('locality'),
    // District/county are useful fallbacks for rural addresses, but must not
    // replace the explicit name of a city or town result.
    read('district'),
    read('county'),
  ].firstWhere((value) => value.isNotEmpty, orElse: () => '');
  final parts = [
    street,
    featureName,
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
    placeType: placeType,
    osmType: read('osm_type'),
    osmId: read('osm_id'),
  );
}
