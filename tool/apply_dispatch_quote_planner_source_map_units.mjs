import fs from 'node:fs';

const dashboardPath = 'lib/marketplace/marketplace_dispatch_dashboard.dart';
const planPath = 'docs/DISPATCH_NETWORK_MASTER_PLAN.md';

function normalize(value) {
  return value.replace(/\r\n/g, '\n');
}

function replaceOne(source, pattern, replacement, label) {
  const matches = [...source.matchAll(pattern)];
  if (matches.length !== 1) {
    throw new Error(`Expected exactly one ${label} target, found ${matches.length}. Stop instead of guessing.`);
  }
  return source.replace(pattern, replacement);
}

let source = normalize(fs.readFileSync(dashboardPath, 'utf8'));

const appliedMarkers = [
  'class _DispatchUnitRequirementDraft',
  'MarketplaceLocation? originLocation;',
  "collection('public_listings')",
  'MarketplaceLocationPicker.showDelivery(',
  "'requestedUnits': unitRequirements",
  "'requirementsVersion': 1",
];

if (!appliedMarkers.every((marker) => source.includes(marker))) {
  if (!source.includes("import 'marketplace_location.dart';")) {
    source = replaceOne(
      source,
      /import 'marketplace_location_picker\.dart';\n/,
      "import 'marketplace_location_picker.dart';\nimport 'marketplace_location.dart';\n",
      'MarketplaceLocation import',
    );
  }

  if (!source.includes('class _DispatchUnitRequirementDraft')) {
    const models = `const _dispatchQuoteUnitTypes = <String, String>{
  'hauling_tractor': 'Hauling tractor / power unit',
  'pilot_truck': 'Pilot / escort truck',
  'hotshot_unit': 'Hotshot unit',
  'winch_tractor': 'Winch tractor',
  'lowboy_trailer': 'Lowboy trailer',
  'flatbed_trailer': 'Flatbed trailer',
  'step_deck_trailer': 'Step-deck trailer',
  'picker_crane_truck': 'Picker / crane truck',
  'service_truck': 'Service truck',
  'crane_unit': 'Crane unit',
  'loader': 'Loader',
  'grader': 'Grader',
  'excavator': 'Excavator',
  'custom_equipment': 'Other / custom equipment',
};

class _DispatchUnitRequirementDraft {
  _DispatchUnitRequirementDraft({
    required this.typeCode,
    int minQuantity = 1,
    int maxQuantity = 1,
  })  : minController = TextEditingController(text: '$minQuantity'),
        maxController = TextEditingController(text: '$maxQuantity');

  factory _DispatchUnitRequirementDraft.fromMap(Map<String, dynamic> data) {
    final type = '${data['unitTypeCode'] ?? 'hauling_tractor'}';
    final min = (data['minQuantity'] as num? ?? 1).toInt();
    final max = (data['maxQuantity'] as num? ?? min).toInt();
    return _DispatchUnitRequirementDraft(
      typeCode: _dispatchQuoteUnitTypes.containsKey(type)
          ? type
          : 'custom_equipment',
      minQuantity: min < 1 ? 1 : min,
      maxQuantity: max < min ? min : max,
    );
  }

  String typeCode;
  final TextEditingController minController;
  final TextEditingController maxController;

  int? get minQuantity => int.tryParse(minController.text.trim());
  int? get maxQuantity => int.tryParse(maxController.text.trim());

  String? validate() {
    final min = minQuantity;
    final max = maxQuantity;
    if (min == null || max == null) return 'Enter whole-number unit quantities.';
    if (min < 1) return 'Minimum units must be at least 1.';
    if (max < min) return 'Maximum units must be greater than or equal to minimum units.';
    if (max > 999) return 'Maximum units cannot exceed 999 in one requirement row.';
    return null;
  }

  Map<String, dynamic> toMap() => {
        'unitTypeCode': typeCode,
        'unitTypeLabel': _dispatchQuoteUnitTypes[typeCode] ?? 'Other equipment',
        'minQuantity': minQuantity ?? 1,
        'maxQuantity': maxQuantity ?? minQuantity ?? 1,
      };

  void dispose() {
    minController.dispose();
    maxController.dispose();
  }
}

`;
    source = replaceOne(
      source,
      /class _DispatchQuoteDialog extends StatefulWidget \{/,
      `${models}class _DispatchQuoteDialog extends StatefulWidget {`,
      'Dispatch quote model insertion',
    );
  }

  if (!source.includes('MarketplaceLocation? originLocation;')) {
    source = replaceOne(
      source,
      /  bool manual = false;\n/,
      `  bool manual = false;
  String sourceMode = 'standalone';
  String? selectedListingId;
  String selectedListingTitle = '';
  MarketplaceLocation? originLocation;
  MarketplaceLocation? destinationLocation;
  late final List<_DispatchUnitRequirementDraft> unitRequirements;
`,
      'Dispatch quote state fields',
    );
  }

  if (!source.includes("widget.template['requestedUnits']")) {
    const restore = `    };
    sourceMode = '${widget.template['sourceType'] ?? 'standalone'}' == 'listing'
        ? 'listing'
        : 'standalone';
    selectedListingId = '${widget.template['listingId'] ?? ''}'.trim();
    if (selectedListingId!.isEmpty) selectedListingId = null;
    selectedListingTitle = '${widget.template['listingTitle'] ?? ''}'.trim();
    originLocation = marketplaceLocationFromOfferDelivery(
      widget.template['originLocation'],
    );
    destinationLocation = marketplaceLocationFromOfferDelivery(
      widget.template['destinationLocation'],
    );
    final savedUnits = widget.template['requestedUnits'];
    unitRequirements = [];
    if (savedUnits is List) {
      for (final value in savedUnits) {
        if (value is Map) {
          unitRequirements.add(
            _DispatchUnitRequirementDraft.fromMap(
              Map<String, dynamic>.from(value),
            ),
          );
        }
      }
    }
    if (unitRequirements.isEmpty) {
      unitRequirements.add(
        _DispatchUnitRequirementDraft(typeCode: 'hauling_tractor'),
      );
    }
`;
    source = replaceOne(
      source,
      /    \};\n    for \(final controller in c\.values\) \{/,
      `${restore}    for (final controller in c.values) {`,
      'Dispatch quote template restoration',
    );
  }

  if (!source.includes('for (final requirement in unitRequirements)')) {
    source = replaceOne(
      source,
      /    for \(final controller in c\.values\) \{\n      controller\.removeListener\(_refresh\);\n      controller\.dispose\(\);\n    \}\n    super\.dispose\(\);/,
      `    for (final controller in c.values) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    for (final requirement in unitRequirements) {
      requirement.dispose();
    }
    super.dispose();`,
      'Dispatch quote dispose hook',
    );
  }

  if (!source.includes("title: 'Job source & route'")) {
    const laneReplacement = `_QuoteSection(
                      title: 'Job source & route',
                      icon: Icons.route_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _field('name', 'Saved quote / lane name'),
                          const SizedBox(height: 4),
                          _dispatchSourceSelector(),
                          const SizedBox(height: 14),
                          _dispatchRouteLocations(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _QuoteSection(
                      title: 'Route & load'`;
    source = replaceOne(
      source,
      /_QuoteSection\(\n\s+title: 'Lane identity',[\s\S]*?\n\s+\),\n\s+const SizedBox\(height: 12\),\n\s+_QuoteSection\(\n\s+title: 'Route & load'/,
      laneReplacement,
      'Lane identity section',
    );
  }

  if (!source.includes("title: 'Required job units'")) {
    source = replaceOne(
      source,
      /                    _QuoteSection\(\n                      title: 'Pilot vehicles',/,
      `                    _QuoteSection(
                      title: 'Required job units',
                      icon: Icons.format_list_numbered_rounded,
                      child: _requestedUnitsEditor(),
                    ),
                    const SizedBox(height: 12),
                    _QuoteSection(
                      title: 'Pilot vehicles',`,
      'Required job units section',
    );
  }

  if (!source.includes('Widget _dispatchSourceSelector()')) {
    const helpers = `  Widget _dispatchSourceSelector() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Start from',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'listing',
                icon: Icon(Icons.inventory_2_outlined),
                label: Text('Select Marketplace listing'),
              ),
              ButtonSegment<String>(
                value: 'standalone',
                icon: Icon(Icons.add_location_alt_outlined),
                label: Text('Custom / standalone job'),
              ),
            ],
            selected: {sourceMode},
            onSelectionChanged: (next) {
              final value = next.first;
              setState(() {
                sourceMode = value;
                if (value == 'standalone') {
                  selectedListingId = null;
                  selectedListingTitle = '';
                }
              });
            },
          ),
          if (sourceMode == 'listing') ...[
            const SizedBox(height: 10),
            _listingSelector(),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Use this for your own future work, a customer request, or any job that does not have a Pipe Buyer listing yet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      );

  Widget _listingSelector() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('public_listings')
            .where('status', isEqualTo: 'active')
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return const Text(
              'Marketplace listings could not be loaded. Choose Custom / standalone job or try again.',
            );
          }
          final docs = [...?snapshot.data?.docs]
            ..sort((left, right) =>
                '${left.data()['title'] ?? ''}'.compareTo(
                  '${right.data()['title'] ?? ''}',
                ));
          final selectedValue = docs.any((doc) => doc.id == selectedListingId)
              ? selectedListingId
              : null;
          return DropdownButtonFormField<String>(
            value: selectedValue,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Marketplace listing',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
            items: docs
                .map(
                  (doc) => DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(
                      '${doc.data()['title'] ?? 'Untitled listing'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (listingId) {
              if (listingId == null) return;
              final doc = docs.firstWhere((item) => item.id == listingId);
              _applyListing(doc.id, doc.data());
            },
          );
        },
      );

  void _applyListing(String listingId, Map<String, dynamic> listing) {
    final title = '${listing['title'] ?? 'Selected listing'}'.trim();
    final pickupLabel = '${listing['publicLocationName'] ?? listing['nearestTown'] ?? ''}'.trim();
    final point = listing['publicGeoPoint'];
    MarketplaceLocation? nextOrigin;
    if (point is GeoPoint) {
      nextOrigin = MarketplaceLocation(
        point: LatLng(point.latitude, point.longitude),
        visibility: LocationVisibility.approximate,
        publicName: pickupLabel.isEmpty ? 'Listing pickup area' : pickupLabel,
        nearestTown: '${listing['nearestTown'] ?? ''}'.trim(),
        region: '${listing['region'] ?? ''}'.trim(),
        country: '${listing['country'] ?? ''}'.trim(),
      );
    }
    setState(() {
      selectedListingId = listingId;
      selectedListingTitle = title;
      originLocation = nextOrigin;
    });
    if (c['name']!.text.trim().isEmpty) {
      c['name']!.text = '$title dispatch plan';
    }
    if (pickupLabel.isNotEmpty) c['origin']!.text = pickupLabel;
  }

  Widget _dispatchRouteLocations() => LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 620;
          final origin = _routeLocationCard(
            title: 'Origin / pickup',
            value: originLocation,
            buttonLabel: originLocation == null
                ? 'Select origin on map *'
                : 'Change origin on map',
            icon: Icons.trip_origin_rounded,
            onPressed: _pickOrigin,
          );
          final destination = _routeLocationCard(
            title: 'Destination',
            value: destinationLocation,
            buttonLabel: destinationLocation == null
                ? 'Select destination on map *'
                : 'Change destination on map',
            icon: Icons.flag_outlined,
            onPressed: _pickDestination,
          );
          if (stack) {
            return Column(
              children: [origin, const SizedBox(height: 10), destination],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: origin),
              const SizedBox(width: 10),
              Expanded(child: destination),
            ],
          );
        },
      );

  Widget _routeLocationCard({
    required String title,
    required MarketplaceLocation? value,
    required String buttonLabel,
    required IconData icon,
    required VoidCallback onPressed,
  }) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: PipeBuyerColors.orangePressed),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            if (value != null) ...[
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 130,
                  child: ListingLocationMap(
                    point: value.point,
                    approximate: false,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value.publicName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (value.nearestTown.trim().isNotEmpty)
                Text(
                  value.nearestTown,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.map_outlined),
              label: Text(buttonLabel),
            ),
          ],
        ),
      );

  Future<void> _pickOrigin() async {
    final selected = await MarketplaceLocationPicker.show(
      context,
      originLocation,
      title: 'Dispatch origin / pickup',
    );
    if (selected == null || !mounted) return;
    setState(() => originLocation = selected);
    c['origin']!.text = selected.publicName.trim().isEmpty
        ? selected.nearestTown.trim()
        : selected.publicName.trim();
  }

  Future<void> _pickDestination() async {
    final selected = await MarketplaceLocationPicker.showDelivery(
      context,
      destinationLocation,
    );
    if (selected == null || !mounted) return;
    setState(() => destinationLocation = selected);
    c['destination']!.text = selected.publicName.trim().isEmpty
        ? selected.nearestTown.trim()
        : selected.publicName.trim();
  }

  Widget _requestedUnitsEditor() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add every equipment class the job may require. Use the same minimum and maximum for an exact quantity, or a range such as 2-4 pilot trucks.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < unitRequirements.length; index++) ...[
            _unitRequirementRow(index),
            const SizedBox(height: 9),
          ],
          OutlinedButton.icon(
            onPressed: () => setState(
              () => unitRequirements.add(
                _DispatchUnitRequirementDraft(typeCode: 'hauling_tractor'),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add another unit type'),
          ),
        ],
      );

  Widget _unitRequirementRow(int index) {
    final requirement = unitRequirements[index];
    final error = requirement.validate();
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: error == null
              ? Theme.of(context).dividerColor
              : Theme.of(context).colorScheme.error,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final type = DropdownButtonFormField<String>(
            value: requirement.typeCode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Unit / equipment type'),
            items: _dispatchQuoteUnitTypes.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => requirement.typeCode = value);
            },
          );
          final min = TextField(
            controller: requirement.minController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minimum units'),
            onChanged: (_) => setState(() {}),
          );
          final max = TextField(
            controller: requirement.maxController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Maximum units'),
            onChanged: (_) => setState(() {}),
          );
          final remove = IconButton(
            tooltip: 'Remove unit requirement',
            onPressed: unitRequirements.length <= 1
                ? null
                : () {
                    final removed = unitRequirements.removeAt(index);
                    removed.dispose();
                    setState(() {});
                  },
            icon: const Icon(Icons.delete_outline),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                type,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: min),
                    const SizedBox(width: 8),
                    Expanded(child: max),
                    remove,
                  ],
                ),
              ] else
                Row(
                  children: [
                    Expanded(flex: 4, child: type),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: min),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: max),
                    remove,
                  ],
                ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String? _unitRequirementsError() {
    for (final requirement in unitRequirements) {
      final error = requirement.validate();
      if (error != null) return error;
    }
    return null;
  }

  Map<String, dynamic> _quoteLocationData(MarketplaceLocation value) => {
        'point': value.exactGeoPoint,
        'label': value.publicName.trim(),
        'address': value.address.trim(),
        'nearestTown': value.nearestTown.trim(),
        'region': value.region.trim(),
        'postalCode': value.postalCode.trim(),
        'country': value.country.trim(),
        'accessNotes': value.accessNotes.trim(),
      };

`;
    source = replaceOne(
      source,
      /  Widget _field\(String key, String label\) => Padding\(/,
      `${helpers}  Widget _field(String key, String label) => Padding(`,
      'Dispatch quote helper insertion',
    );
  }

  if (!source.includes('Select both origin and destination on the map.')) {
    source = replaceOne(
      source,
      /  Future<void> _save\(\) async \{\n/,
      `  Future<void> _save() async {
    if (sourceMode == 'listing' && selectedListingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a Marketplace listing or switch to Custom / standalone job.')),
      );
      return;
    }
    if (originLocation == null || destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both origin and destination on the map.')),
      );
      return;
    }
    final unitError = _unitRequirementsError();
    if (unitError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(unitError)),
      );
      return;
    }
`,
      'Dispatch quote save validation',
    );
  }

  if (!source.includes("'requestedUnits': unitRequirements")) {
    source = replaceOne(
      source,
      /      'manual': manual,\n      'formulaVersion': 1/,
      `      'sourceType': sourceMode,
      'listingId': sourceMode == 'listing' ? selectedListingId : null,
      'listingTitle': sourceMode == 'listing' ? selectedListingTitle : '',
      'originLocation': _quoteLocationData(originLocation!),
      'destinationLocation': _quoteLocationData(destinationLocation!),
      'requestedUnits': unitRequirements
          .map((requirement) => requirement.toMap())
          .toList(growable: false),
      'requirementsVersion': 1,
      'manual': manual,
      'formulaVersion': 1`,
      'Dispatch quote saved payload',
    );
  }

  for (const marker of appliedMarkers) {
    if (!source.includes(marker)) {
      throw new Error(`Dispatch quote planner marker missing after repair: ${marker}`);
    }
  }

  fs.writeFileSync(dashboardPath, source, 'utf8');
  console.log('Dispatch quote planner source/map/multi-unit repair applied.');
} else {
  console.log('Dispatch quote planner source/map/multi-unit repair already applied.');
}

let plan = normalize(fs.readFileSync(planPath, 'utf8'));
if (!plan.includes('Select Marketplace listing')) {
  plan = replaceOne(
    plan,
    /\*\*Last updated:\*\* 2026-08-17/,
    '**Last updated:** 2026-08-18',
    'Dispatch plan date',
  );
  plan = replaceOne(
    plan,
    /    requirements\{\}\n    requestedCompanyIds\[\]\?/,
    `    requirements{}
    requestedUnits[]
    requestedCompanyIds[]?`,
    'Phase 5 requested-units model',
  );
  plan = replaceOne(
    plan,
    /Required request sources:\n\n```text\nlisting\nstandalone\ndirectory_direct\n```/,
    `Required request sources:

\`\`\`text
listing
standalone
directory_direct
\`\`\`

Request composition requirements locked during the existing quote-planner foundation correction:

- **Select Marketplace listing** or **Custom / standalone job** at the start;
- mapped origin and destination using the existing Pipe Buyer open-map location picker;
- listing source may prefill the public pickup area but the user can refine the pickup pin;
- standalone source requires no listing and can be saved as a reusable preset;
- \`requestedUnits[]\` stores multiple equipment classes with \`minQuantity\` / \`maxQuantity\` ranges, for example 2-4 pilot trucks plus 1-12 hauling tractors;
- these requirements do not award Phase 5 points before the Phase 3/4 gates are green.`,
    'Phase 5 request-source requirements',
  );
  fs.writeFileSync(planPath, plan, 'utf8');
  console.log('Dispatch master plan updated with source/map/multi-unit requirements.');
} else {
  console.log('Dispatch master plan already contains source/map/multi-unit requirements.');
}
