import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

class MarketplaceListingSpec {
  const MarketplaceListingSpec({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

String _listingSpecText(dynamic raw) {
  if (raw == null) return '';
  if (raw is Iterable) {
    return raw
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty && item != 'null')
        .join(', ');
  }
  final value = '$raw'.trim();
  return value == 'null' ? '' : value;
}

List<MarketplaceListingSpec> marketplaceListingSpecs(
  Map<String, dynamic> listing,
) {
  final specs = <MarketplaceListingSpec>[];
  void add(String label, dynamic raw, IconData icon) {
    final value = _listingSpecText(raw);
    if (value.isEmpty) return;
    specs.add(MarketplaceListingSpec(label: label, value: value, icon: icon));
  }

  // Put the same decision-making facts buyers look for on professional
  // industrial inventory sites first: identity, usage, condition and location.
  final brand = _listingSpecText(listing['brand']);
  final model = _listingSpecText(listing['model']);
  if (brand.isNotEmpty || model.isNotEmpty) {
    add(
      'Make / model',
      [brand, model].where((item) => item.isNotEmpty).join(' '),
      Icons.precision_manufacturing_outlined,
    );
  }
  add('Year', listing['modelYear'], Icons.calendar_today_outlined);
  if (listing['machineHours'] != null) {
    add(
      'Machine hours',
      '${_listingSpecText(listing['machineHours'])} hours',
      Icons.timer_outlined,
    );
  }
  add(
    'Serial number',
    listing['serialNumber'] ?? listing['vin'],
    Icons.confirmation_number_outlined,
  );
  add('Category', listing['category'], Icons.category_outlined);
  add('Item type', listing['productType'], Icons.inventory_2_outlined);
  add('Condition', listing['condition'], Icons.verified_outlined);
  add(
    'Location',
    listing['publicLocationName'] ??
        listing['nearestTown'] ??
        listing['locationLabel'] ??
        listing['city'],
    Icons.location_on_outlined,
  );

  if (listing['quantity'] != null) {
    final quantity = _listingSpecText(listing['quantity']);
    final basis = _listingSpecText(listing['priceBasis']);
    add(
      'Quantity',
      basis.isEmpty ? quantity : '$quantity • $basis',
      Icons.numbers_rounded,
    );
  }
  add('Pipe size', listing['pipeSize'], Icons.straighten_outlined);
  add('Pipe band', listing['pipeBand'], Icons.layers_outlined);
  add('Inspection', listing['inspectionStatus'], Icons.fact_check_outlined);
  add(
    'Operating status',
    listing['operatingStatus'],
    Icons.power_settings_new_outlined,
  );
  add('Engine', listing['engineDetails'], Icons.settings_outlined);
  add(
    'Maintenance history',
    listing['maintenanceHistory'],
    Icons.build_outlined,
  );
  add(
    'Included attachments',
    listing['attachments'],
    Icons.attachment_outlined,
  );
  return specs;
}

class MarketplaceListingSpecsGrid extends StatelessWidget {
  const MarketplaceListingSpecsGrid({
    super.key,
    required this.listing,
    this.title = 'Listing details',
    this.maxVisibleSpecs = 8,
  });

  final Map<String, dynamic> listing;
  final String title;
  final int maxVisibleSpecs;

  @override
  Widget build(BuildContext context) {
    final specs = marketplaceListingSpecs(listing);
    if (specs.isEmpty) return const SizedBox.shrink();
    final visibleCount = maxVisibleSpecs <= 0
        ? specs.length
        : maxVisibleSpecs.clamp(1, specs.length);
    final visible = specs.take(visibleCount).toList(growable: false);
    final remaining = specs.skip(visibleCount).toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.trim().isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: PipeBuyerColors.industrialBlue,
                ),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 9),
          ],
          _ListingSpecsWrap(specs: visible),
          if (remaining.isNotEmpty) ...[
            const SizedBox(height: 6),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4),
                dense: true,
                visualDensity: const VisualDensity(vertical: -3),
                leading: const Icon(Icons.tune_rounded, size: 18),
                title: Text(
                  'More specifications (${remaining.length})',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                children: [_ListingSpecsWrap(specs: remaining)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListingSpecsWrap extends StatelessWidget {
  const _ListingSpecsWrap({required this.specs});

  final List<MarketplaceListingSpec> specs;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          // The old detail page became one tall ListTile per fact. Two compact
          // columns now fit even inside the narrower desktop content rail,
          // while wider screens scale to three/four columns.
          final columns = constraints.maxWidth >= 960
              ? 4
              : constraints.maxWidth >= 650
                  ? 3
                  : constraints.maxWidth >= 330
                      ? 2
                      : 1;
          const gap = 7.0;
          final itemWidth =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final spec in specs)
                SizedBox(
                  width: itemWidth,
                  child: _ListingSpecTile(spec: spec),
                ),
            ],
          );
        },
      );
}

class _ListingSpecTile extends StatelessWidget {
  const _ListingSpecTile({required this.spec});

  final MarketplaceListingSpec spec;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: PipeBuyerColors.canvas,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFE4E8EE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: PipeBuyerColors.orangeSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                spec.icon,
                size: 15,
                color: PipeBuyerColors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PipeBuyerColors.muted,
                      fontSize: 9,
                      height: 1.1,
                      letterSpacing: .25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    spec.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PipeBuyerColors.ink,
                      fontSize: 12.5,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
