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

List<MarketplaceListingSpec> marketplaceListingSpecs(
  Map<String, dynamic> listing,
) {
  final specs = <MarketplaceListingSpec>[];
  void add(String label, dynamic raw, IconData icon) {
    final value = '${raw ?? ''}'.trim();
    if (value.isEmpty || value == 'null') return;
    specs.add(MarketplaceListingSpec(label: label, value: value, icon: icon));
  }

  add('Product type', listing['productType'], Icons.inventory_2_outlined);
  if (listing['quantity'] != null) {
    final basis = '${listing['priceBasis'] ?? ''}'.toLowerCase();
    final unit = basis.contains('joint')
        ? 'joints'
        : basis.contains('piece') || basis.contains('each')
            ? 'pieces'
            : 'units';
    add('Available quantity', '${listing['quantity']} $unit', Icons.numbers_rounded);
  }
  add('Inspection', listing['inspectionStatus'], Icons.fact_check_outlined);
  add('Condition', listing['condition'], Icons.verified_outlined);
  add('Size', listing['pipeSize'], Icons.straighten_outlined);
  final brand = '${listing['brand'] ?? ''}'.trim();
  final model = '${listing['model'] ?? ''}'.trim();
  if (brand.isNotEmpty || model.isNotEmpty) {
    add('Make / model', [brand, model].where((item) => item.isNotEmpty).join(' '),
        Icons.precision_manufacturing_outlined);
  }
  add('Year', listing['modelYear'], Icons.calendar_today_outlined);
  add('Operating status', listing['operatingStatus'], Icons.settings_outlined);
  return specs;
}

class MarketplaceListingSpecsGrid extends StatelessWidget {
  const MarketplaceListingSpecsGrid({
    super.key,
    required this.listing,
    this.title = 'Listing details',
  });

  final Map<String, dynamic> listing;
  final String title;

  @override
  Widget build(BuildContext context) {
    final specs = marketplaceListingSpecs(listing);
    if (specs.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: PipeBuyerColors.industrialBlue,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 860
                  ? 3
                  : constraints.maxWidth >= 520
                      ? 2
                      : 1;
              final gap = 8.0;
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
          ),
        ],
      ),
    );
  }
}

class _ListingSpecTile extends StatelessWidget {
  const _ListingSpecTile({required this.spec});

  final MarketplaceListingSpec spec;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: PipeBuyerColors.canvas,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE4E8EE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: PipeBuyerColors.industrialBlue.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                spec.icon,
                size: 18,
                color: PipeBuyerColors.industrialBlue,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.label,
                    style: const TextStyle(
                      color: PipeBuyerColors.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PipeBuyerColors.ink,
                      fontSize: 13,
                      height: 1.2,
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
