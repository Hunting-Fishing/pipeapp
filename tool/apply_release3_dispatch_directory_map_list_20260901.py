from pathlib import Path

DIRECTORY = Path('lib/marketplace/marketplace_dispatch_directory.dart')
TEST = Path('test/marketplace_dispatch_directory_projection_query_test.dart')
DOC = Path('docs/DISPATCH_RELEASE3_DIRECTORY_MAP_LIST.md')

source = DIRECTORY.read_text(encoding='utf-8')

old = """import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/data/bounded_firestore_query.dart';
"""
new = """import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/data/bounded_firestore_query.dart';
"""
if source.count(old) != 1:
    raise SystemExit(f'import anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """import 'marketplace_dispatch_service_taxonomy.dart';
import 'marketplace_dispatch_directory_actions.dart';
"""
new = """import 'marketplace_dispatch_service_taxonomy.dart';
import 'marketplace_dispatch_directory_actions.dart';
import 'marketplace_location_picker.dart';
"""
if source.count(old) != 1:
    raise SystemExit(f'local import anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """class DispatchDirectoryPageData {
"""
new = """enum DispatchDirectoryViewMode { list, map }

class DispatchDirectoryPageData {
"""
if source.count(old) != 1:
    raise SystemExit(f'view mode anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """  bool _loadingMore = false;
  String? _loadMoreError;
"""
new = """  bool _loadingMore = false;
  String? _loadMoreError;
  DispatchDirectoryViewMode _viewMode = DispatchDirectoryViewMode.list;
  String? _selectedMapEntryId;
"""
if source.count(old) != 1:
    raise SystemExit(f'state anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """        final filtered = allEntries
            .where((entry) => entry.matches(_filters))
            .toList(growable: false);

        return ListView(
"""
new = """        final filtered = allEntries
            .where((entry) => entry.matches(_filters))
            .toList(growable: false);
        final mappedEntries = filtered
            .where((entry) => entry.homeBasePoint != null)
            .toList(growable: false);

        return ListView(
"""
if source.count(old) != 1:
    raise SystemExit(f'filtered entries anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """            Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtered.length} ${filtered.length == 1 ? 'company' : 'companies'} shown',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const PipeBuyerStatusBadge(
                  label: 'LIST VIEW',
                  icon: Icons.view_list_outlined,
                  tone: PipeBuyerStatusTone.info,
                ),
              ],
            ),
"""
new = """            Row(
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
"""
if source.count(old) != 1:
    raise SystemExit(f'view switch anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """            else
              ...filtered.map(
                (entry) => _DirectoryCompanyCard(
                  entry: entry,
                  remoteDataEnabled: widget.seedEntries == null,
                ),
              ),
"""
new = """            else if (_viewMode == DispatchDirectoryViewMode.list)
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
"""
if source.count(old) != 1:
    raise SystemExit(f'list/map content anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

anchor = """class _DirectoryFilterCard extends StatelessWidget {
"""
map_view = r'''class _DirectoryMapView extends StatelessWidget {
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

'''
if source.count(anchor) != 1:
    raise SystemExit(f'map widget insertion anchor mismatch: {source.count(anchor)}')
source = source.replace(anchor, map_view + anchor, 1)
DIRECTORY.write_text(source, encoding='utf-8')

test = TEST.read_text(encoding='utf-8')
anchor = """  test('Directory filters preserve structured service and capability matching', () {
"""
insert = """  test('Directory map/list view uses the public approximate map projection', () {
    final source = File(
      'lib/marketplace/marketplace_dispatch_directory.dart',
    ).readAsStringSync();

    expect(source, contains("package:flutter_map/flutter_map.dart"));
    expect(source, contains('DispatchDirectoryViewMode.map'));
    expect(source, contains('entry.homeBasePoint != null'));
    expect(source, contains('urlTemplate: pipeBuyerTileUrl'));
    expect(source, contains('OpenStreetMap contributors'));
    expect(source, contains('Approximate public locations only.'));
    expect(source, contains('Selected company'));
  });

""" + anchor
if test.count(anchor) != 1:
    raise SystemExit(f'test insertion anchor mismatch: {test.count(anchor)}')
test = test.replace(anchor, insert, 1)
TEST.write_text(test, encoding='utf-8')

DOC.write_text("""# Release 3 — Dispatch Directory synchronized List / Map

## Date

2026-09-01

## Production baseline

This slice starts from verified production application SHA:

```text
f980358ca136202daca5617c94fa8fff7f3c64d0
```

Production verification for that baseline is GitHub Actions run `33509965140` with App Check enforced.

## User problem

The Directory can now page through companies, but discovery is list-only even though the server-owned public projection already publishes an approximate `mapPoint` when a provider has a public mappable location.

For non-technical users, the next useful step is a simple two-mode Directory: **List** or **Map**. Both modes must show the same filtered provider set and must not create a second location source.

## Bounded implementation

- Add a simple List / Map segmented control.
- Keep List as the default view.
- Build map pins only from filtered entries whose projected `homeBasePoint` came from the public Directory `mapPoint`.
- Use the existing `flutter_map` dependency and `pipeBuyerTileUrl`, which defaults to OpenStreetMap tiles.
- Keep OpenStreetMap attribution visible.
- Recompute map center/zoom from the currently mapped public results when the result set changes.
- Selecting a provider pin shows that same provider's existing Directory company card below the map.
- Pagination remains available in Map mode; newly loaded public companies automatically join the same filtered map data set.
- If no filtered providers publish a public map point, explain that clearly and offer a one-tap return to List.

## Privacy boundary

This slice does **not** read or publish a private yard, residence, exact address, credential, contact, Auth UID or moderation field. The map uses only the existing server-owned `dispatch_directory_entries.mapPoint` projection already parsed as `homeBasePoint`.

The UI explicitly states that map locations are approximate and are for provider discovery, not private-yard routing.

## Not in this slice

- Radius filtering.
- Device-location permission or "near me" behavior.
- Geocoding new provider coordinates.
- A new map vendor or paid map API.
- Changes to provider profile persistence or projection Functions.
- Changes to quote, messaging, Stripe, membership or Dispatch payment flows.

## Verification expectation

The release gate must pass repository analysis, focused Directory tests, full Flutter regression, release-contract tests, both Functions codebase validations and `git diff --check` before the durable files are committed.

## Next after this slice

After the synchronized List / Map experience is verified, evaluate geography/radius filtering using only public approximate locations and service-area data. Do not expose private home-base coordinates to implement radius search.
""", encoding='utf-8')
