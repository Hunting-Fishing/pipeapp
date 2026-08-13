import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import 'marketplace_location.dart';
import 'open_address_autocomplete.dart';

const pipeBuyerTileUrl = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

IconData _locationVisibilityIcon(LocationVisibility visibility) =>
    switch (visibility) {
      LocationVisibility.exact => Icons.location_on_outlined,
      LocationVisibility.approximate => Icons.radar,
      LocationVisibility.onRequest => Icons.lock_outline,
      LocationVisibility.hidden => Icons.visibility_off_outlined,
    };

class MarketplaceLocationPicker extends StatefulWidget {
  const MarketplaceLocationPicker(
      {super.key,
      this.initial,
      this.title = 'Listing location',
      this.delivery = false,
      this.community = false})
      : assert(!(delivery && community));

  final MarketplaceLocation? initial;
  final String title;
  final bool delivery;
  final bool community;

  static Future<MarketplaceLocation?> show(
          BuildContext context, MarketplaceLocation? initial,
          {String title = 'Listing location'}) =>
      Navigator.of(context).push<MarketplaceLocation>(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              MarketplaceLocationPicker(initial: initial, title: title)));

  static Future<MarketplaceLocation?> showDelivery(
          BuildContext context, MarketplaceLocation? initial) =>
      Navigator.of(context).push<MarketplaceLocation>(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => MarketplaceLocationPicker(
              initial: initial,
              title: 'Delivery destination',
              delivery: true)));

  static Future<MarketplaceLocation?> showCommunity(
          BuildContext context, MarketplaceLocation? initial) =>
      Navigator.of(context).push<MarketplaceLocation>(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => MarketplaceLocationPicker(
              initial: initial, title: 'Primary community', community: true)));

  @override
  State<MarketplaceLocationPicker> createState() =>
      _MarketplaceLocationPickerState();
}

class _MarketplaceLocationPickerState extends State<MarketplaceLocationPicker> {
  final _mapController = MapController();
  late LatLng _point;
  late LocationVisibility _visibility;
  late final TextEditingController _address;
  late final TextEditingController _town;
  late final TextEditingController _publicName;
  late final TextEditingController _notes;
  late final TextEditingController _region;
  late final TextEditingController _postalCode;
  late final TextEditingController _country;
  Timer? _reverseDebounce;
  int _reverseRequest = 0;
  bool _reverseLoading = false;
  String? _reverseStatus;
  String _lastAutoPublicName = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _point = initial?.point ?? const LatLng(55.1707, -118.7947);
    _visibility = widget.delivery
        ? LocationVisibility.exact
        : widget.community
            ? LocationVisibility.approximate
            : initial?.visibility ?? LocationVisibility.approximate;
    _address = TextEditingController(text: initial?.address);
    _town = TextEditingController(text: initial?.nearestTown);
    _publicName = TextEditingController(
        text: initial?.publicName ??
            (widget.delivery || widget.community
                ? ''
                : 'Grande Prairie area, AB'));
    _notes = TextEditingController(text: initial?.accessNotes);
    _region = TextEditingController(text: initial?.region ?? 'Alberta');
    _postalCode = TextEditingController(text: initial?.postalCode);
    _country = TextEditingController(text: initial?.country ?? 'Canada');
  }

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    _address.dispose();
    _town.dispose();
    _publicName.dispose();
    _notes.dispose();
    _region.dispose();
    _postalCode.dispose();
    _country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
                tooltip: 'Use my current location',
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location)),
            TextButton(
                onPressed: _save,
                child: const Text('SAVE',
                    style: TextStyle(fontWeight: FontWeight.w800)))
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(
              widget.community
                  ? 'Choose your primary community or operating area'
                  : widget.delivery
                      ? 'Drop the pin at the delivery destination'
                      : 'Drop the pin at the real pickup location',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(widget.community
              ? 'The exact pin is stored privately. Only a broad area is used for local search and nearby results.'
              : widget.delivery
                  ? 'The exact destination is stored privately with your offer and trucking request.'
                  : 'The exact pin is stored privately unless you choose to publish it.'),
          const SizedBox(height: 14),
          if (widget.delivery) ...[
            const Card(
                color: Color(0xFFF3F5F8),
                elevation: 0,
                child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rural destination example',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          SizedBox(height: 5),
                          Text(
                              'Site or area: Tomslake rural property\nNearest recognized town: Dawson Creek, BC\nDestination label: Tomslake Farm — south gate',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF66758A))),
                          SizedBox(height: 5),
                          Text(
                              'Use the closest town that a driver can easily recognize, even when the destination is in a smaller community.',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF66758A)))
                        ]))),
            const SizedBox(height: 10),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 310,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _point,
                  initialZoom: 10,
                  onTap: (_, point) => _pinMoved(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: pipeBuyerTileUrl,
                    userAgentPackageName: 'ca.pipebuyer.marketplace',
                  ),
                  DragMarkers(markers: [
                    DragMarker(
                        point: _point,
                        size: const Size(48, 48),
                        builder: (_, __, isDragging) => Icon(Icons.location_pin,
                            size: isDragging ? 52 : 46,
                            color: const Color(0xFFFF5A00)),
                        onDragEnd: (_, point) => _pinMoved(point),
                        scrollMapNearEdge: true)
                  ]),
                  const SimpleAttributionWidget(
                      source: Text('© OpenStreetMap contributors')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Drag the orange pin to correct the exact location.',
              style: TextStyle(fontWeight: FontWeight.w700)),
          if (_reverseLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 5),
            const Row(children: [
              Icon(Icons.travel_explore_outlined,
                  size: 18, color: Color(0xFF0878E8)),
              SizedBox(width: 7),
              Expanded(
                  child: Text('Finding the nearest address and community…',
                      style: TextStyle(fontSize: 11, color: Color(0xFF66758A))))
            ])
          ] else if (_reverseStatus != null) ...[
            const SizedBox(height: 7),
            Row(children: [
              const Icon(Icons.auto_awesome_outlined,
                  size: 18, color: Color(0xFF0878E8)),
              const SizedBox(width: 7),
              Expanded(
                  child: Text(_reverseStatus!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF66758A))))
            ])
          ],
          const SizedBox(height: 10),
          OpenAddressAutocomplete(
              initialValue: _address.text,
              label: widget.community
                  ? 'Search city, town, municipality or operating area'
                  : widget.delivery
                      ? 'Search destination, landmark or nearest town'
                      : 'Find an address or place',
              hint: widget.community
                  ? 'Try Grande Prairie, Alberta or a nearby municipality'
                  : widget.delivery
                      ? 'Try Tomslake, Dawson Creek, a yard, farm, landmark or postal code'
                      : 'Start typing a street, town, lease or postal code',
              onSelected: (address) {
                setState(() {
                  _point = address.point;
                  _reverseStatus =
                      'Address selected. Drag the pin for a more precise site location.';
                });
                _mapController.move(address.point, 15);
                _applyAddress(address);
              }),
          const SizedBox(height: 10),
          TextField(
              controller: _address,
              decoration: InputDecoration(
                  labelText: widget.community
                      ? 'Selected place or address (private)'
                      : widget.delivery
                          ? 'Delivery address, yard, farm or site name'
                          : 'Street, rural route, LSD or site name',
                  hintText: widget.community
                      ? 'Optional street, rural area, or landmark'
                      : widget.delivery
                          ? 'e.g. Tomslake property, CJSM Yard or Lease 12-34'
                          : 'e.g. 25 km west on Highway 43',
                  helperText: widget.community
                      ? 'This detail and the exact pin stay private.'
                      : widget.delivery
                          ? 'Describe the actual site—not only the nearest town.'
                          : null,
                  prefixIcon: const Icon(Icons.edit_location_alt_outlined))),
          const SizedBox(height: 10),
          TextField(
              controller: _town,
              decoration: InputDecoration(
                  labelText: widget.community
                      ? 'City, town or municipality *'
                      : widget.delivery
                          ? 'Nearest recognized town *'
                          : 'Nearest recognized town',
                  hintText: widget.community
                      ? 'e.g. Grande Prairie'
                      : widget.delivery
                          ? 'e.g. Dawson Creek, British Columbia'
                          : 'e.g. Grande Prairie, Alberta',
                  helperText: widget.community
                      ? 'Used to organize local marketplace and nearby search results.'
                      : widget.delivery
                          ? 'For a rural Tomslake destination, Dawson Creek may be the nearest well-known service town.'
                          : null)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: _region,
                    decoration: const InputDecoration(
                        labelText: 'Province / state',
                        hintText: 'e.g. British Columbia'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: _postalCode,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Postal / ZIP code',
                        hintText: 'e.g. V1G 4H8'))),
          ]),
          const SizedBox(height: 10),
          TextField(
              controller: _country,
              decoration: const InputDecoration(
                  labelText: 'Country', hintText: 'e.g. Canada')),
          const SizedBox(height: 10),
          TextField(
              controller: _publicName,
              decoration: InputDecoration(
                  labelText: widget.community
                      ? 'Public community label *'
                      : widget.delivery
                          ? 'Destination label *'
                          : 'Public location label',
                  hintText: widget.community
                      ? 'e.g. Grande Prairie, Alberta'
                      : widget.delivery
                          ? 'e.g. Tomslake Farm — south gate'
                          : 'e.g. 25 km west of Grande Prairie',
                  helperText: widget.community
                      ? 'Shown on your seller profile; the exact pin remains private.'
                      : widget.delivery
                          ? 'Use a short name the buyer, seller and driver will recognize.'
                          : null)),
          const SizedBox(height: 14),
          if (widget.delivery)
            const Card(
                color: Color(0xFFEAF4FD),
                child: ListTile(
                    leading: Icon(Icons.lock_outline, color: Color(0xFF0878E8)),
                    title: Text('Private Dispatch destination'),
                    subtitle: Text(
                        'The exact pin is shared only with offer participants and the selected trucking provider.')))
          else if (widget.community)
            const Card(
                color: Color(0xFFEAF4FD),
                child: ListTile(
                    leading: Icon(Icons.radar, color: Color(0xFF0878E8)),
                    title: Text('Broad-area profile location'),
                    subtitle: Text(
                        'Pipe Buyer stores the exact pin privately and publishes only an approximate area for discovery.')))
          else ...[
            const Text('Who can see this location?',
                style: TextStyle(fontWeight: FontWeight.w800)),
            RadioGroup<LocationVisibility>(
              groupValue: _visibility,
              onChanged: (next) {
                if (next != null) setState(() => _visibility = next);
              },
              child: Column(
                children: LocationVisibility.values
                    .map((value) => RadioListTile<LocationVisibility>(
                          contentPadding: EdgeInsets.zero,
                          value: value,
                          secondary: Icon(_locationVisibilityIcon(value)),
                          title: Text(value.label),
                          subtitle: value == LocationVisibility.approximate
                              ? const Text(
                                  'Recommended for rural yards and remote sites')
                              : value == LocationVisibility.onRequest
                                  ? const Text(
                                      'Buyer must contact the seller for directions')
                                  : null,
                        ))
                    .toList(),
              ),
            ),
          ],
          TextField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: widget.community
                      ? 'Private community notes'
                      : widget.delivery
                          ? 'Private delivery instructions'
                          : 'Private access instructions',
                  hintText: widget.community
                      ? 'Optional notes for your own records'
                      : widget.delivery
                          ? 'Gate, yard contact, unloading or appointment details'
                          : 'Gate, lease road, appointment or loading details')),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(widget.community
                  ? 'Use this primary community'
                  : widget.delivery
                      ? 'Use this destination'
                      : 'Use this location')),
        ]),
      );

  void _save() {
    if ((widget.delivery || widget.community) && _town.text.trim().isEmpty) {
      PipeFeedback.show(
        context,
        message: widget.community
            ? 'Select or enter the city, town, or municipality for this profile.'
            : 'Enter the nearest recognized town so drivers can orient the route.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    if (_publicName.text.trim().isEmpty) {
      PipeFeedback.show(
        context,
        message: widget.community
            ? 'Enter a public community label, such as Grande Prairie, Alberta.'
            : widget.delivery
                ? 'Enter a destination label drivers can recognize.'
                : 'Enter a public location label.',
        tone: PipeStatusTone.warning,
      );
      return;
    }
    Navigator.pop(
        context,
        MarketplaceLocation(
          point: _point,
          visibility: widget.delivery
              ? LocationVisibility.exact
              : widget.community
                  ? LocationVisibility.approximate
                  : _visibility,
          publicName: _publicName.text,
          address: _address.text,
          nearestTown: _town.text,
          accessNotes: _notes.text,
          region: _region.text,
          postalCode: _postalCode.text,
          country: _country.text,
        ));
  }

  void _pinMoved(LatLng point, {bool immediate = false}) {
    setState(() {
      _point = point;
      _reverseStatus = null;
    });
    _reverseDebounce?.cancel();
    if (immediate) {
      _reverseGeocode(point);
    } else {
      _reverseDebounce = Timer(
          const Duration(milliseconds: 450), () => _reverseGeocode(point));
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    final request = ++_reverseRequest;
    if (mounted) setState(() => _reverseLoading = true);
    try {
      final address = await reverseOpenAddress(point);
      if (!mounted || request != _reverseRequest) return;
      if (address == null) {
        setState(() {
          _reverseLoading = false;
          _reverseStatus =
              'Pin saved. No nearby mapped address was found; enter the rural details below.';
        });
        return;
      }
      _applyAddress(address);
      setState(() {
        _reverseLoading = false;
        _reverseStatus = address.city.isEmpty
            ? 'Nearest mapped address added. Please confirm the nearest recognized town.'
            : 'Address and nearest community updated from the pin. Please confirm the details.';
      });
    } catch (_) {
      if (!mounted || request != _reverseRequest) return;
      setState(() {
        _reverseLoading = false;
        _reverseStatus =
            'Pin saved. Automatic address lookup was unavailable; enter the details below.';
      });
    }
  }

  void _applyAddress(OpenAddress address) {
    _address.text = address.label;
    _town.text = address.city;
    _region.text = address.region;
    _postalCode.text = address.postalCode;
    _country.text = address.country;
    final firstLabelPart = address.label.split(',').firstOrNull?.trim() ?? '';
    final townRegion = [address.city, address.region]
        .where((part) => part.isNotEmpty)
        .join(', ');
    final nextAutoLabel = widget.delivery && firstLabelPart.isNotEmpty
        ? firstLabelPart
        : townRegion;
    if (_publicName.text.trim().isEmpty ||
        _publicName.text.trim() == _lastAutoPublicName) {
      _publicName.text = nextAutoLabel;
      _lastAutoPublicName = nextAutoLabel;
    }
  }

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
      _pinMoved(point, immediate: true);
      _mapController.move(point, 15);
    } catch (error) {
      if (mounted) {
        final denied = error is StateError;
        PipeFeedback.show(
          context,
          message: denied
              ? 'Location access was not granted. Search for the community or place instead.'
              : 'Your device location could not be loaded. Search for the community or place instead.',
          tone: PipeStatusTone.warning,
        );
      }
    }
  }
}

class MarketplaceMapSheet extends StatefulWidget {
  const MarketplaceMapSheet({super.key});

  @override
  State<MarketplaceMapSheet> createState() => _MarketplaceMapSheetState();
}

class _MarketplaceMapSheetState extends State<MarketplaceMapSheet> {
  static const _mapResultLimit = 200;
  late Future<QuerySnapshot<Map<String, dynamic>>> _listings;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _listings = FirebaseFirestore.instance
        .collection('public_listings')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(_mapResultLimit)
        .get();
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await _listings;
    } catch (_) {
      // FutureBuilder renders the actionable error state.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Listings map'), actions: [
        IconButton(
            tooltip: 'Refresh map listings',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh))
      ]),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: _listings,
          builder: (context, snapshot) {
            final markers = (snapshot.data?.docs ?? const [])
                .map((doc) {
                  final data = doc.data();
                  if (data['locationVisibility'] != 'exact' &&
                      data['locationVisibility'] != 'approximate') {
                    return null;
                  }
                  final point = data['publicGeoPoint'];
                  if (point is! GeoPoint) return null;
                  return Marker(
                      point: LatLng(point.latitude, point.longitude),
                      width: 48,
                      height: 48,
                      child: Tooltip(
                          message: '${data['title'] ?? 'Listing'}\n'
                              '${data['publicLocationName'] ?? ''}',
                          child: Icon(
                              data['locationVisibility'] == 'approximate'
                                  ? Icons.radio_button_checked
                                  : Icons.location_pin,
                              size: 42,
                              color: const Color(0xFFFF5A00))));
                })
                .whereType<Marker>()
                .toList();
            return Stack(children: [
              FlutterMap(
                options: const MapOptions(
                    initialCenter: LatLng(54.3, -117.2), initialZoom: 5.5),
                children: [
                  TileLayer(
                      urlTemplate: pipeBuyerTileUrl,
                      userAgentPackageName: 'ca.pipebuyer.marketplace'),
                  MarkerLayer(markers: markers),
                  const SimpleAttributionWidget(
                      source: Text('© OpenStreetMap contributors')),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator()),
              if (snapshot.hasError)
                Positioned(
                    left: 18,
                    right: 18,
                    top: 18,
                    child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(children: [
                              const Text('Map listings could not be loaded.',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              FilledButton.tonalIcon(
                                  onPressed: _refresh,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try again'))
                            ])))),
              if (snapshot.hasData && markers.isEmpty)
                Positioned(
                    left: 18,
                    right: 18,
                    top: 18,
                    child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                                'No public map listings yet. Hidden and request-only locations never appear here.'))))
              else if (snapshot.hasData &&
                  snapshot.data!.docs.length == _mapResultLimit)
                Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Text(
                                'Showing mapped locations from the 200 newest active listings. Use Browse filters to narrow your search.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12)))))
            ]);
          }));
}

class ListingLocationMap extends StatelessWidget {
  const ListingLocationMap(
      {super.key,
      required this.point,
      required this.approximate,
      this.height = 190,
      this.allowExpand = true});
  final LatLng point;
  final bool approximate;
  final double height;
  final bool allowExpand;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          child: Stack(children: [
            Positioned.fill(
              child: FlutterMap(
                options: MapOptions(
                    initialCenter: point,
                    initialZoom: approximate ? 9 : 13,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.all)),
                children: [
                  TileLayer(
                      urlTemplate: pipeBuyerTileUrl,
                      userAgentPackageName: 'ca.pipebuyer.marketplace'),
                  if (approximate)
                    CircleLayer(circles: [
                      CircleMarker(
                          point: point,
                          radius: 5000,
                          useRadiusInMeter: true,
                          color: const Color(0x332E7DFF),
                          borderColor: const Color(0xFF2E7DFF),
                          borderStrokeWidth: 2)
                    ])
                  else
                    MarkerLayer(markers: [
                      Marker(
                          point: point,
                          width: 44,
                          height: 44,
                          child: const Icon(Icons.location_pin,
                              size: 42, color: Color(0xFFFF5A00)))
                    ]),
                  const SimpleAttributionWidget(
                      source: Text('© OpenStreetMap contributors')),
                ],
              ),
            ),
            if (allowExpand)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: const Color(0xEFFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  elevation: 2,
                  child: IconButton(
                    tooltip: 'Open interactive location map',
                    onPressed: () => _showExpandedListingMap(
                      context,
                      point: point,
                      approximate: approximate,
                    ),
                    icon: const Icon(Icons.open_in_full_rounded),
                  ),
                ),
              ),
            Positioned(
              left: 8,
              top: 8,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xEFFFFFFF),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text(
                    'Drag or zoom map',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}

Future<void> _showExpandedListingMap(
  BuildContext context, {
  required LatLng point,
  required bool approximate,
}) =>
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: SafeArea(
          child: Column(children: [
            ListTile(
              leading: IconButton(
                tooltip: 'Close map',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
              title: Text(approximate
                  ? 'Approximate listing area'
                  : 'Listing location'),
              subtitle: const Text('Drag, pinch or scroll to explore the map.'),
            ),
            Expanded(
              child: ListingLocationMap(
                point: point,
                approximate: approximate,
                height: double.infinity,
                allowExpand: false,
              ),
            ),
          ]),
        ),
      ),
    );
