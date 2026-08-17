$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'pipebuyer_context.ps1')
Assert-PipeBuyerFormalBranch | Out-Null

function Normalize-Lf([string]$Text) {
  return $Text.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Replace-ExactlyOnce {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Before,
    [Parameter(Mandatory = $true)][string]$After,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $sourceLf = Normalize-Lf $Source
  $beforeLf = Normalize-Lf $Before
  $afterLf = Normalize-Lf $After

  if ($sourceLf.Contains($afterLf) -and -not $sourceLf.Contains($beforeLf)) {
    Write-Host "Already applied: $Label" -ForegroundColor DarkGray
    return $sourceLf
  }

  $count = ([regex]::Matches($sourceLf, [regex]::Escape($beforeLf))).Count
  if ($count -ne 1) {
    throw "STOP: Expected exactly one source target for '$Label', found $count. No guessing."
  }

  Write-Host "Applying: $Label" -ForegroundColor Green
  return $sourceLf.Replace($beforeLf, $afterLf)
}

$openAddressPath = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\open_address_autocomplete.dart'
$serviceAreaPath = Join-Path $script:PipeBuyerRepoRoot 'lib\marketplace\marketplace_service_area.dart'

foreach ($path in @($openAddressPath, $serviceAreaPath)) {
  if (-not (Test-Path -LiteralPath $path)) {
    throw "STOP: Required source file is missing: $path"
  }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $script:PipeBuyerRepoRoot "_local_backups\service-area-geocoder-$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item -LiteralPath $openAddressPath -Destination (Join-Path $backupDir 'open_address_autocomplete.dart')
Copy-Item -LiteralPath $serviceAreaPath -Destination (Join-Path $backupDir 'marketplace_service_area.dart')
Write-Host "Backup created: $backupDir" -ForegroundColor Green

$open = [System.IO.File]::ReadAllText($openAddressPath)

$open = Replace-ExactlyOnce $open @'
    required this.label,
    required this.point,
    this.street = '',
    this.city = '',
    this.region = '',
'@ @'
    required this.label,
    required this.point,
    this.name = '',
    this.street = '',
    this.city = '',
    this.district = '',
    this.region = '',
'@ 'preserve the selected Photon feature name and parent district separately'

$open = Replace-ExactlyOnce $open @'
  final String label;
  final LatLng point;
  final String street;
  final String city;
  final String region;
'@ @'
  final String label;
  final LatLng point;
  final String name;
  final String street;
  final String city;
  final String district;
  final String region;
'@ 'add semantic selected-name and district fields'

$open = Replace-ExactlyOnce $open @'
enum OpenAddressSearchType { all, settlement, administrative }
'@ @'
enum OpenAddressSearchType { all, settlement, administrative }

const _settlementPlaceTypes = {
  'city',
  'town',
  'village',
  'hamlet',
  'locality',
  'municipality',
  'borough',
};

const _administrativePlaceTypes = {
  'country',
  'state',
  'province',
  'region',
  'district',
  'county',
  'municipality',
};

bool openAddressMatchesSearchType(
  OpenAddress item,
  OpenAddressSearchType searchType,
) =>
    switch (searchType) {
      OpenAddressSearchType.all => true,
      OpenAddressSearchType.settlement =>
        _settlementPlaceTypes.contains(item.placeType.toLowerCase()),
      OpenAddressSearchType.administrative =>
        _administrativePlaceTypes.contains(item.placeType.toLowerCase()),
    };

List<OpenAddress> dedupeOpenAddressResults(Iterable<OpenAddress> items) {
  final byIdentity = <String, OpenAddress>{};
  for (final item in items) {
    final identityName = item.name.trim().isNotEmpty ? item.name : item.city;
    final key = [
      item.placeType,
      identityName,
      item.region,
      item.country,
    ].map(_normalizedOpenAddressPart).join('|');
    final current = byIdentity[key];
    if (current == null ||
        (!_isOsmRelation(current.osmType) && _isOsmRelation(item.osmType))) {
      byIdentity[key] = item;
    }
  }
  return byIdentity.values.toList(growable: false);
}

String _normalizedOpenAddressPart(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

bool _isOsmRelation(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'r' || normalized == 'relation';
}
'@ 'separate settlement searches from district/county administrative searches'

$open = Replace-ExactlyOnce $open @'
  return _openAddressFromFeature(
      Map<String, dynamic>.from(features.first as Map));
'@ @'
  return openAddressFromPhotonFeature(
      Map<String, dynamic>.from(features.first as Map));
'@ 'use testable Photon parser for reverse geocoding'

$open = Replace-ExactlyOnce $open @'
                        final secondary = [
                          address.city,
                          address.region,
                          address.country,
                        ].where((part) => part.isNotEmpty).toSet().join(', ');
'@ @'
                        final secondary = [
                          address.district,
                          address.region,
                          address.country,
                        ].where((part) => part.isNotEmpty).toSet().join(', ');
'@ 'show parent administrative context without calling it the selected town'

$open = Replace-ExactlyOnce $open @'
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
'@ @'
      final parsed = (data['features'] as List? ?? const [])
          .map((raw) => openAddressFromPhotonFeature(
                Map<String, dynamic>.from(raw as Map),
              ))
          .where((item) => item.label.isNotEmpty)
          .where((item) => openAddressMatchesSearchType(item, widget.searchType));
      final results = dedupeOpenAddressResults(parsed);
'@ 'filter towns as settlements only and deduplicate node/relation duplicates'

$open = Replace-ExactlyOnce $open @'
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
'@ @'
OpenAddress openAddressFromPhotonFeature(Map<String, dynamic> feature) {
  final properties =
      Map<String, dynamic>.from(feature['properties'] as Map? ?? const {});
  final geometry =
      Map<String, dynamic>.from(feature['geometry'] as Map? ?? const {});
  final coordinates = geometry['coordinates'] as List? ?? const [0, 0];
  String read(String key) => '${properties[key] ?? ''}'.trim();
  final featureName = read('name');
  final placeType = read('type').toLowerCase();
  final street = [read('housenumber'), read('street')]
      .where((value) => value.isNotEmpty)
      .join(' ');
  final explicitSettlement = [
    read('city'),
    read('town'),
    read('village'),
    read('hamlet'),
    read('locality'),
  ].firstWhere((value) => value.isNotEmpty, orElse: () => '');
  final settlement = explicitSettlement.isNotEmpty
      ? explicitSettlement
      : _settlementPlaceTypes.contains(placeType)
          ? featureName
          : '';
  final district = [read('district'), read('county')]
      .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  final parts = [
    street,
    featureName,
    settlement,
    district,
    read('state'),
    read('postcode'),
    read('country')
  ].where((value) => value.isNotEmpty).toSet().toList();
  return OpenAddress(
    label: parts.join(', '),
    point: LatLng(
        (coordinates[1] as num).toDouble(), (coordinates[0] as num).toDouble()),
    name: featureName,
    street: street,
    city: settlement,
    district: district,
    region: read('state'),
    postalCode: read('postcode'),
    country: read('country'),
    countryCode: read('countrycode').toUpperCase(),
    placeType: placeType,
    osmType: read('osm_type'),
    osmId: read('osm_id'),
  );
}
'@ 'never promote district or county names into the selected settlement field'

$service = [System.IO.File]::ReadAllText($serviceAreaPath)

$service = Replace-ExactlyOnce $service @'
}

class MarketplaceServiceAreaPicker extends StatefulWidget {
'@ @'
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
    final displayFirst = '${item['display_name'] ?? ''}'.split(',').first.trim();
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
'@ 'add strict town-versus-region boundary candidate classification'

$service = Replace-ExactlyOnce $service @'
  void _selected(OpenAddress address) async {
    final settlement = _settlementName(address);
    final name = [
      _mode == ServiceAreaMode.places ? settlement : address.region,
      if (_mode == ServiceAreaMode.places) address.region,
      address.country
    ].where((value) => value.isNotEmpty).toSet().join(', ');
'@ @'
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
'@ 'use the selected feature name instead of its parent region as the service-area identity'

$service = Replace-ExactlyOnce $service @'
      if (_mode == ServiceAreaMode.places && boundary.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'An official municipality boundary was not available. The town pin is still saved and can be adjusted.')));
      }
'@ @'
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
'@ 'never silently save a region as a bare pin or substitute a broader district for a town'

$oldBoundary = @'
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
'@

$newBoundary = @'
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
'@
$service = Replace-ExactlyOnce $service $oldBoundary $newBoundary 'resolve exact municipality/region boundary without broad-area substitution'

$service = Replace-ExactlyOnce $service @'
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
'@ @'
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
'@ 'keep selected town and selected region identities separate'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($openAddressPath, (Normalize-Lf $open), $utf8NoBom)
[System.IO.File]::WriteAllText($serviceAreaPath, (Normalize-Lf $service), $utf8NoBom)

Write-Host ''
Write-Host 'Service-area geocoder classification repair applied.' -ForegroundColor Green
Write-Host 'Source of truth remains the Dart files; this helper is only an idempotent guarded migration.' -ForegroundColor DarkGray
