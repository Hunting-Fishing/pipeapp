import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'industrial_icon_assets.dart';
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
              initial: initial,
              title: 'Primary community',
              community: true)));

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
              final wide = constraints.maxWidth >= 1000;
              if (wide) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 470,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 22, 14, 34),
                            child: _buildForm(context),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 22, 22, 34),
                            child: _buildMapCard(context, tall: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _LocationHero(
                    delivery: widget.delivery,
                    community: widget.community,
                  ),
                  const SizedBox(height: 14),
                  _buildMapCard(context, tall: false),
                  const SizedBox(height: 16),
                  _buildForm(context, includeHero: false),
                ],
              );
            },
          ),
        ),
      );

  Widget _buildForm(BuildContext context, {bool includeHero = true}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (includeHero) ...[
            _LocationHero(
              delivery: widget.delivery,
              community: widget.community,
            ),
            const SizedBox(height: 16),
          ],
          if (widget.delivery) ...[
            const _RuralDestinationTip(),
            const SizedBox(height: 12),
          ],
          _SectionLabel(
            icon: Icons.travel_explore_outlined,
            title: widget.community
                ? 'Find your community'
                : widget.delivery
                    ? 'Find the destination'
                    : 'Find the pickup location',
            subtitle: widget.community
                ? 'Search a city, town, municipality, or operating area.'
                : 'Search first, then drag the pin if the mapped point needs correction.',
          ),
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
            },
          ),
          if (_reverseLoading) ...[
            const SizedBox(height: 9),
            const _ReverseLookupState(loading: true),
          ] else if (_reverseStatus != null) ...[
            const SizedBox(height: 9),
            _ReverseLookupState(message: _reverseStatus!),
          ],
          const SizedBox(height: 16),
          _SectionLabel(
            icon: Icons.edit_location_alt_outlined,
            title: 'Location details',
            subtitle: widget.community
                ? 'Exact details stay private; the broad community label is public.'
                : widget.delivery
                    ? 'Use recognizable site and town information for the parties and carrier.'
                    : 'Add enough information to identify the site while respecting your visibility choice.',
          ),
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
              prefixIcon: const Icon(Icons.pin_drop_outlined),
            ),
          ),
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
                      ? 'For a rural destination, use the nearest well-known service town.'
                      : null,
              prefixIcon: const Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 420;
              final region = TextField(
                controller: _region,
                decoration: const InputDecoration(
                  labelText: 'Province / state',
                  hintText: 'e.g. British Columbia',
                ),
              );
              final postal = TextField(
                controller: _postalCode,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Postal / ZIP code',
                  hintText: 'e.g. V1G 4H8',
                ),
              );
              if (stack) {
                return Column(
                  children: [
                    region,
                    const SizedBox(height: 10),
                    postal,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: region),
                  const SizedBox(width: 10),
                  Expanded(child: postal),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _country,
            decoration: const InputDecoration(
              labelText: 'Country',
              hintText: 'e.g. Canada',
              prefixIcon: Icon(Icons.public_outlined),
            ),
          ),
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
                      : null,
              prefixIcon: const Icon(Icons.label_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.delivery)
            const _PrivacyInfoCard(
              icon: Icons.lock_outline,
              title: 'Private Dispatch destination',
              message:
                  'The exact pin is shared only with offer participants and the selected trucking provider.',
              tone: PipeBuyerColors.industrialBlue,
            )
          else if (widget.community)
            const _PrivacyInfoCard(
              icon: Icons.radar,
              title: 'Broad-area profile location',
              message:
                  'Pipe Buyer stores the exact pin privately and publishes only an approximate area for discovery.',
              tone: PipeBuyerColors.industrialBlue,
            )
          else
            _VisibilitySelector(
              value: _visibility,
              onChanged: (next) => setState(() => _visibility = next),
            ),
          const SizedBox(height: 14),
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
                      : 'Gate, lease road, appointment or loading details',
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(widget.community
                ? 'Use this primary community'
                : widget.delivery
                    ? 'Use this destination'
                    : 'Use this location'),
          ),
        ],
      );

  Widget _buildMapCard(BuildContext context, {required bool tall}) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 13, 10, 11),
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
                      label: 'Marketplace location map',
                      assetPath: IndustrialIconAssets.locationPin,
                      size: 38,
                      borderRadius: 9,
                      fallback: Icon(
                        Icons.location_on_outlined,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.community
                              ? 'Private reference pin'
                              : widget.delivery
                                  ? 'Delivery destination map'
                                  : 'Pickup location map',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Drag the orange pin or tap the map to correct the location.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
              height: tall ? 520 : 320,
              child: Stack(
                children: [
                  Positioned.fill(
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
                        DragMarkers(
                          markers: [
                            DragMarker(
                              point: _point,
                              size: const Size(52, 52),
                              builder: (_, __, isDragging) =>
                                  _PremiumLocationPin(active: isDragging),
                              onDragEnd: (_, point) => _pinMoved(point),
                              scrollMapNearEdge: true,
                            ),
                          ],
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
                    child: _MapPrivacyBadge(
                      label: widget.delivery
                          ? 'PRIVATE DESTINATION'
                          : widget.community
                              ? 'PRIVATE PIN • PUBLIC AREA'
                              : _visibility.label.toUpperCase(),
                      icon: widget.delivery || widget.community
                          ? Icons.lock_outline
                          : _locationVisibilityIcon(_visibility),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: .48),
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.privacy_tip_outlined,
                    size: 18,
                    color: PipeBuyerColors.industrialBlue,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      widget.community
                          ? 'The exact reference pin stays private; buyers see only the broad marketplace area.'
                          : widget.delivery
                              ? 'This exact destination is private to the transaction and selected carrier.'
                              : 'The public map follows the visibility option you choose below.',
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

  void _save() {
    if ((widget.delivery || widget.community) &&
        _town.text.trim().isEmpty) {
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

class _LocationHero extends StatelessWidget {
  const _LocationHero({required this.delivery, required this.community});

  final bool delivery;
  final bool community;

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
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: IndustrialAssetIcon(
                label: delivery
                    ? 'Delivery destination'
                    : community
                        ? 'Primary community'
                        : 'Listing location',
                assetPath: delivery
                    ? IndustrialIconAssets.routeMap
                    : IndustrialIconAssets.locationPin,
                size: 66,
                borderRadius: 11,
                fallback: const Icon(
                  Icons.location_on_outlined,
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
                  Text(
                    delivery
                        ? 'TRANSACTION LOGISTICS'
                        : community
                            ? 'MARKETPLACE DISCOVERY'
                            : 'LISTING LOCATION',
                    style: const TextStyle(
                      color: PipeBuyerColors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .72,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    community
                        ? 'Choose your primary community'
                        : delivery
                            ? 'Confirm the delivery destination'
                            : 'Confirm the pickup location',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1.18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    community
                        ? 'The exact reference pin stays private; only a broad area is used for local discovery.'
                        : delivery
                            ? 'Store the exact route destination privately for the offer and selected trucking provider.'
                            : 'Store the real site privately and choose how much location detail buyers can see.',
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

class _RuralDestinationTip extends StatelessWidget {
  const _RuralDestinationTip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              color: PipeBuyerColors.orangePressed,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rural destination example',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Site: Tomslake rural property\nNearest recognized town: Dawson Creek, BC\nDestination label: Tomslake Farm — south gate',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Use the closest town a driver can easily recognize even when the destination is in a smaller community.',
                    style: TextStyle(fontSize: 11.5, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PipeBuyerColors.orangeSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: PipeBuyerColors.orangePressed, size: 20),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .60),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _ReverseLookupState extends StatelessWidget {
  const _ReverseLookupState({this.loading = false, this.message});

  final bool loading;
  final String? message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: PipeBuyerColors.industrialBlue.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: PipeBuyerColors.industrialBlue.withValues(alpha: .16),
          ),
        ),
        child: Row(
          children: [
            if (loading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: PipeBuyerColors.industrialBlue,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loading
                    ? 'Finding the nearest address and community…'
                    : message ?? '',
                style: const TextStyle(fontSize: 11.5, height: 1.35),
              ),
            ),
          ],
        ),
      );
}

class _PrivacyInfoCard extends StatelessWidget {
  const _PrivacyInfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: tone.withValues(alpha: .20)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tone),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(message, style: const TextStyle(fontSize: 12.5, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _VisibilitySelector extends StatelessWidget {
  const _VisibilitySelector({required this.value, required this.onChanged});

  final LocationVisibility value;
  final ValueChanged<LocationVisibility> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Who can see this location?',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          RadioGroup<LocationVisibility>(
            groupValue: value,
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
            child: Column(
              children: LocationVisibility.values
                  .map(
                    (visibility) => Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      decoration: BoxDecoration(
                        color: value == visibility
                            ? PipeBuyerColors.orangeSoft
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: value == visibility
                              ? PipeBuyerColors.orange.withValues(alpha: .55)
                              : Theme.of(context).dividerColor,
                        ),
                      ),
                      child: RadioListTile<LocationVisibility>(
                        value: visibility,
                        secondary: Icon(
                          _locationVisibilityIcon(visibility),
                          color: value == visibility
                              ? PipeBuyerColors.orangePressed
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .58),
                        ),
                        title: Text(
                          visibility.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: visibility == LocationVisibility.approximate
                            ? const Text(
                                'Recommended for rural yards and remote sites')
                            : visibility == LocationVisibility.onRequest
                                ? const Text(
                                    'Buyer must contact the seller for directions')
                                : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
}

class _PremiumLocationPin extends StatelessWidget {
  const _PremiumLocationPin({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: active ? 50 : 46,
        height: active ? 50 : 46,
        decoration: BoxDecoration(
          color: PipeBuyerColors.ink,
          shape: BoxShape.circle,
          border: Border.all(
            color: PipeBuyerColors.orange,
            width: active ? 3 : 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3B000000),
              blurRadius: 9,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.location_on_rounded,
          color: PipeBuyerColors.orange,
          size: 27,
        ),
      );
}

class _MapPrivacyBadge extends StatelessWidget {
  const _MapPrivacyBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xE811151A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: PipeBuyerColors.orange, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .3,
              ),
            ),
          ],
        ),
      );
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
        appBar: AppBar(
          title: const Text('Listings map'),
          actions: [
            IconButton(
              tooltip: 'Refresh map listings',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: _listings,
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? const [];
            final mapped = docs
                .map((doc) {
                  final data = doc.data();
                  if (data['locationVisibility'] != 'exact' &&
                      data['locationVisibility'] != 'approximate') {
                    return null;
                  }
                  final point = data['publicGeoPoint'];
                  if (point is! GeoPoint) return null;
                  return _MappedListing(
                    title: '${data['title'] ?? 'Listing'}',
                    location: '${data['publicLocationName'] ?? ''}',
                    approximate: data['locationVisibility'] == 'approximate',
                    point: LatLng(point.latitude, point.longitude),
                  );
                })
                .whereType<_MappedListing>()
                .toList();
            final markers = mapped
                .map(
                  (item) => Marker(
                    point: item.point,
                    width: 52,
                    height: 52,
                    child: Tooltip(
                      message: '${item.title}\n${item.location}',
                      child: _MarketplaceMapMarker(
                        approximate: item.approximate,
                      ),
                    ),
                  ),
                )
                .toList();

            return Stack(
              children: [
                FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(54.3, -117.2),
                    initialZoom: 5.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: pipeBuyerTileUrl,
                      userAgentPackageName: 'ca.pipebuyer.marketplace',
                    ),
                    MarkerLayer(markers: markers),
                    const SimpleAttributionWidget(
                      source: Text('© OpenStreetMap contributors'),
                    ),
                  ],
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  top: 14,
                  child: _MapDiscoveryHeader(
                    count: markers.length,
                    loading:
                        snapshot.connectionState == ConnectionState.waiting,
                    error: snapshot.hasError,
                    onRefresh: _refresh,
                  ),
                ),
                if (snapshot.hasError)
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: _MapNoticeCard(
                      icon: Icons.cloud_off_outlined,
                      title: 'Map listings could not be loaded',
                      message: 'Check your connection and try again.',
                      action: FilledButton.tonalIcon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ),
                  )
                else if (snapshot.hasData && markers.isEmpty)
                  const Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: _MapNoticeCard(
                      icon: Icons.map_outlined,
                      title: 'No public map listings yet',
                      message:
                          'Hidden and request-only locations never appear on the public Listings Map.',
                    ),
                  )
                else if (snapshot.hasData &&
                    snapshot.data!.docs.length == _mapResultLimit)
                  const Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: _MapNoticeCard(
                      icon: Icons.filter_alt_outlined,
                      title: 'Showing the newest mapped inventory',
                      message:
                          'Mapped locations come from the 200 newest active listings. Use Browse filters to narrow your search.',
                    ),
                  ),
              ],
            );
          },
        ),
      );
}

class _MappedListing {
  const _MappedListing({
    required this.title,
    required this.location,
    required this.approximate,
    required this.point,
  });

  final String title;
  final String location;
  final bool approximate;
  final LatLng point;
}

class _MarketplaceMapMarker extends StatelessWidget {
  const _MarketplaceMapMarker({required this.approximate});

  final bool approximate;

  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: PipeBuyerColors.ink,
          shape: BoxShape.circle,
          border: Border.all(
            color: approximate
                ? PipeBuyerColors.industrialBlue
                : PipeBuyerColors.orange,
            width: 2.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3A000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          approximate ? Icons.radar_rounded : Icons.location_on_rounded,
          color: approximate
              ? PipeBuyerColors.industrialBlue
              : PipeBuyerColors.orange,
          size: 25,
        ),
      );
}

class _MapDiscoveryHeader extends StatelessWidget {
  const _MapDiscoveryHeader({
    required this.count,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final int count;
  final bool loading;
  final bool error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: const Color(0xED11151A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.orange.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.travel_explore_outlined,
                    color: PipeBuyerColors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NORTH AMERICA INVENTORY MAP',
                        style: TextStyle(
                          color: PipeBuyerColors.orange,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        error
                            ? 'Map inventory unavailable'
                            : loading
                                ? 'Loading mapped inventory…'
                                : '$count public mapped ${count == 1 ? 'listing' : 'listings'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'Exact and approximate public locations only • private locations stay hidden',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(11),
                    child: SizedBox.square(
                      dimension: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PipeBuyerColors.orange,
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Refresh mapped inventory',
                    onPressed: onRefresh,
                    color: Colors.white,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _MapNoticeCard extends StatelessWidget {
  const _MapNoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PipeBuyerColors.orangeSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: PipeBuyerColors.orangePressed),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(message,
                            style: const TextStyle(fontSize: 12.5, height: 1.35)),
                        if (action != null) ...[
                          const SizedBox(height: 9),
                          action!,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class ListingLocationMap extends StatelessWidget {
  const ListingLocationMap(
      {super.key, required this.point, required this.approximate});
  final LatLng point;
  final bool approximate;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: SizedBox(
          height: 210,
          child: Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: approximate ? 9 : 13,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: pipeBuyerTileUrl,
                      userAgentPackageName: 'ca.pipebuyer.marketplace',
                    ),
                    if (approximate)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: point,
                            radius: 5000,
                            useRadiusInMeter: true,
                            color: PipeBuyerColors.industrialBlue
                                .withValues(alpha: .12),
                            borderColor: PipeBuyerColors.industrialBlue,
                            borderStrokeWidth: 2.25,
                          ),
                        ],
                      )
                    else
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 48,
                            height: 48,
                            child: const _MarketplaceMapMarker(
                              approximate: false,
                            ),
                          ),
                        ],
                      ),
                    const SimpleAttributionWidget(
                      source: Text('© OpenStreetMap contributors'),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                top: 10,
                child: _MapPrivacyBadge(
                  label: approximate ? 'APPROXIMATE AREA' : 'PUBLIC PIN',
                  icon: approximate ? Icons.radar_rounded : Icons.location_on,
                ),
              ),
            ],
          ),
        ),
      );
}
