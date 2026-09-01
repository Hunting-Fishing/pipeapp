from pathlib import Path

DIRECTORY = Path('lib/marketplace/marketplace_dispatch_directory.dart')
TEST = Path('test/marketplace_dispatch_directory_projection_query_test.dart')
DOC = Path('docs/DISPATCH_RELEASE3_DIRECTORY_RADIUS_COVERAGE.md')

source = DIRECTORY.read_text(encoding='utf-8')

old = """    required this.remoteSiteCapable,
    required this.homeBaseLabel,
    required this.homeBasePoint,
  });
"""
new = """    required this.remoteSiteCapable,
    required this.homeBaseLabel,
    required this.homeBasePoint,
    this.serviceAreaMode = '',
    this.serviceAreaCenterLabel = '',
    this.serviceAreaRadiusKm = 0,
  });
"""
if source.count(old) != 1:
    raise SystemExit(f'constructor anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """  ) {
    final publicLocation = _map(data['publicLocation']);
    final serviceCodes = data['serviceCodes'] is Iterable
"""
new = """  ) {
    final publicLocation = _map(data['publicLocation']);
    final publicServiceArea = _map(data['publicServiceArea']);
    final serviceCodes = data['serviceCodes'] is Iterable
"""
if source.count(old) != 1:
    raise SystemExit(f'projection geography anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """      remoteSiteCapable: data['remoteSiteCapable'] == true,
      homeBaseLabel: '${publicLocation['label'] ?? ''}'.trim(),
      homeBasePoint: point is GeoPoint ? point : null,
    );
"""
new = """      remoteSiteCapable: data['remoteSiteCapable'] == true,
      homeBaseLabel: '${publicLocation['label'] ?? ''}'.trim(),
      homeBasePoint: point is GeoPoint ? point : null,
      serviceAreaMode: '${publicServiceArea['mode'] ?? ''}'.trim(),
      serviceAreaCenterLabel:
          '${publicServiceArea['centerLabel'] ?? ''}'.trim(),
      serviceAreaRadiusKm:
          (publicServiceArea['radiusKm'] as num?)?.toDouble() ?? 0,
    );
"""
if source.count(old) != 1:
    raise SystemExit(f'projection constructor anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """    final home = _map(dispatch['homeLocation']);
    final point = home['point'];

    return DispatchDirectoryEntry(
"""
new = """    final home = _map(dispatch['homeLocation']);
    final serviceArea = _map(dispatch['serviceArea']);
    final point = home['point'];

    return DispatchDirectoryEntry(
"""
if source.count(old) != 1:
    raise SystemExit(f'legacy geography anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """      remoteSiteCapable: dispatch['remoteSiteCapable'] == true,
      homeBaseLabel: '${home['label'] ?? ''}'.trim(),
      homeBasePoint: point is GeoPoint ? point : null,
    );
"""
new = """      remoteSiteCapable: dispatch['remoteSiteCapable'] == true,
      homeBaseLabel: '${home['label'] ?? ''}'.trim(),
      homeBasePoint: point is GeoPoint ? point : null,
      serviceAreaMode: '${serviceArea['mode'] ?? ''}'.trim(),
      serviceAreaCenterLabel: '${serviceArea['centerLabel'] ?? ''}'.trim(),
      serviceAreaRadiusKm:
          (serviceArea['radiusKm'] as num?)?.toDouble() ?? 0,
    );
"""
if source.count(old) != 1:
    raise SystemExit(f'legacy constructor anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """  final bool remoteSiteCapable;
  final String homeBaseLabel;
  final GeoPoint? homeBasePoint;

  bool get isDirectoryReady =>
"""
new = """  final bool remoteSiteCapable;
  final String homeBaseLabel;
  final GeoPoint? homeBasePoint;
  final String serviceAreaMode;
  final String serviceAreaCenterLabel;
  final double serviceAreaRadiusKm;

  bool get hasPublishedRadiusCoverage =>
      serviceAreaMode == 'radius' &&
      serviceAreaRadiusKm > 0 &&
      homeBasePoint != null;

  bool get isDirectoryReady =>
"""
if source.count(old) != 1:
    raise SystemExit(f'field anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """    final mapIdentity = entries.map((entry) {
      final point = entry.homeBasePoint!;
      return '${entry.id}:${point.latitude.toStringAsFixed(3)}:${point.longitude.toStringAsFixed(3)}';
    }).join('|');

    return PipeBuyerSectionCard(
"""
new = """    final radiusEntry = selectedEntry != null &&
            selectedEntry.hasPublishedRadiusCoverage
        ? selectedEntry
        : null;
    final radiusKm = radiusEntry?.serviceAreaRadiusKm ?? 0;
    final radiusText = radiusKm == radiusKm.roundToDouble()
        ? '${radiusKm.round()}'
        : radiusKm.toStringAsFixed(1);
    final radiusCenterLabel = radiusEntry == null
        ? ''
        : (radiusEntry.serviceAreaCenterLabel.isNotEmpty
            ? radiusEntry.serviceAreaCenterLabel
            : radiusEntry.homeBaseLabel);
    final mapIdentity = entries.map((entry) {
      final point = entry.homeBasePoint!;
      return '${entry.id}:${point.latitude.toStringAsFixed(3)}:${point.longitude.toStringAsFixed(3)}';
    }).join('|');

    return PipeBuyerSectionCard(
"""
if source.count(old) != 1:
    raise SystemExit(f'radius selection anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """                  MarkerLayer(
                    markers: entries.map((entry) {
"""
new = """                  if (radiusEntry != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(
                            radiusEntry.homeBasePoint!.latitude,
                            radiusEntry.homeBasePoint!.longitude,
                          ),
                          radius: radiusEntry.serviceAreaRadiusKm * 1000,
                          useRadiusInMeter: true,
                          color: PipeBuyerColors.orange.withValues(alpha: .11),
                          borderColor: PipeBuyerColors.orange,
                          borderStrokeWidth: 2.5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: entries.map((entry) {
"""
if source.count(old) != 1:
    raise SystemExit(f'circle layer anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

old = """          if (selectedEntry != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Selected company',
"""
new = """          if (radiusEntry != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PipeBuyerColors.orangeSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: PipeBuyerColors.orange.withValues(alpha: .45),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.radar_outlined,
                    color: PipeBuyerColors.orangePressed,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      radiusCenterLabel.isEmpty
                          ? 'Published service radius: within $radiusText km of this company’s approximate public service centre.'
                          : 'Published service radius: within $radiusText km of $radiusCenterLabel.',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Coverage is provider-declared and approximate. Confirm the exact job location, route, availability, permits, and travel charges directly with the company.',
              style: TextStyle(fontSize: 12, height: 1.35),
            ),
          ],
          if (selectedEntry != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Selected company',
"""
if source.count(old) != 1:
    raise SystemExit(f'coverage summary anchor mismatch: {source.count(old)}')
source = source.replace(old, new, 1)

DIRECTORY.write_text(source, encoding='utf-8')

test = TEST.read_text(encoding='utf-8')
old = """        'mapPoint': const GeoPoint(53.55, -113.49),
        'availability': 'available_now',
"""
new = """        'mapPoint': const GeoPoint(53.55, -113.49),
        'publicServiceArea': {
          'mode': 'radius',
          'centerLabel': 'Edmonton, Alberta',
          'radiusKm': 250,
        },
        'availability': 'available_now',
"""
if test.count(old) != 1:
    raise SystemExit(f'projection fixture anchor mismatch: {test.count(old)}')
test = test.replace(old, new, 1)

old = """    expect(entry.homeBasePoint, isNotNull);
    expect(entry.serviceCodes, contains('transport_lowboy'));
  });
"""
new = """    expect(entry.homeBasePoint, isNotNull);
    expect(entry.serviceCodes, contains('transport_lowboy'));
    expect(entry.serviceAreaMode, 'radius');
    expect(entry.serviceAreaCenterLabel, 'Edmonton, Alberta');
    expect(entry.serviceAreaRadiusKm, 250);
    expect(entry.hasPublishedRadiusCoverage, isTrue);
  });
"""
if test.count(old) != 1:
    raise SystemExit(f'projection expectation anchor mismatch: {test.count(old)}')
test = test.replace(old, new, 1)

old = """    expect(source, contains('Approximate public locations only.'));
    expect(source, contains('Selected company'));
  });
"""
new = """    expect(source, contains('Approximate public locations only.'));
    expect(source, contains('Selected company'));
    expect(source, contains('CircleLayer('));
    expect(source, contains('useRadiusInMeter: true'));
    expect(source, contains('serviceAreaRadiusKm * 1000'));
    expect(source, contains('Published service radius:'));
  });
"""
if test.count(old) != 1:
    raise SystemExit(f'map contract anchor mismatch: {test.count(old)}')
test = test.replace(old, new, 1)
TEST.write_text(test, encoding='utf-8')

DOC.write_text("""# Release 3 — Dispatch Directory published radius coverage

## Date

2026-09-01

## Verified production baseline

```text
5f3875cb57a0629c180e19db36c2b9c21b0ce6ea
```

Production workflow `33511679533` / run #60 passed Firebase deployment, post-deploy Function parity, and responsive mobile/desktop visual acceptance with App Check enforced.

Evidence artifacts:

- Firebase release evidence: `9802129019`
- Visual acceptance evidence: `9802162842`

## User problem

The Dispatch Directory now has synchronized List / Map discovery, but a point pin alone does not explain how far a radius-based provider says they operate.

A naive client-side "near me" radius filter would be misleading because a bounded Directory page is not the complete global provider set. This slice therefore visualizes existing provider-declared radius coverage without pretending that a partial client scan is a complete geographic search.

## Bounded implementation

- Parse only the existing server-owned `publicServiceArea.mode`, `publicServiceArea.centerLabel`, and `publicServiceArea.radiusKm` fields from `dispatch_directory_entries`.
- Preserve existing approximate public `mapPoint` as the radius centre shown to Directory users.
- When a mapped company is selected and its public service-area mode is `radius`, render its published radius as an OpenStreetMap circle.
- Show a plain-language summary such as `Published service radius: within 250 km of Edmonton, Alberta.`
- State clearly that coverage is provider-declared and approximate and that exact job location, routing, permits, availability, and travel charges must be confirmed directly.
- Keep List / Map filters, pagination, provider actions, and the existing privacy boundary unchanged.

## Privacy boundary

This slice does not add precise home, yard, residence, contact, credential, Auth UID, moderation, or private carrier fields to the Directory.

The coverage circle is centred on the same approximate public point already published by the server-owned Directory projection. It must not be described as an exact business location.

## Why true radius search is not in this slice

Firestore does not provide a native radial GeoPoint query. Filtering only the currently loaded client page by distance could silently omit valid companies on later pages and would create false confidence.

True radius search should be implemented as a separate bounded server/geohash design with explicit result limits, pagination semantics, and false-positive distance verification. Do not replace that design with an unbounded client collection scan.

## Verification gate

Before this slice may be merged, verification must pass:

- exact mutation scope;
- `dart analyze lib test`;
- focused Dispatch Directory tests;
- full Flutter regression;
- repository release-contract tests;
- both Firebase Functions codebase validations; and
- `git diff --check`.

## Permanent implementation rule

Radius coverage visualization and radius search are different concerns. A visible provider coverage circle may use the existing approximate public projection. A global "within X km" search must not be implemented by filtering only whatever Directory page happens to be loaded on the client.
""", encoding='utf-8')
