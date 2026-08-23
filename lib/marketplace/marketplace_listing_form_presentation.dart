import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

class MarketplaceListingGuide {
  const MarketplaceListingGuide({
    required this.title,
    required this.summary,
    required this.recommendedFacts,
  });

  final String title;
  final String summary;
  final List<String> recommendedFacts;
}

MarketplaceListingGuide marketplaceListingGuideFor(
  String? category,
  String? productType,
) {
  if (category == 'Pipe, Tubing & Materials' ||
      const {
        'Drill Pipe',
        'Casing',
        'Tubing',
        'Line Pipe',
        'OCTG',
        'Sucker Rod',
      }.contains(productType)) {
    return const MarketplaceListingGuide(
      title: 'Pipe & tubular details buyers compare first',
      summary:
          'Lead with the specifications a field buyer needs to compare lots without opening every description.',
      recommendedFacts: [
        'Nominal size / OD',
        'Type, grade or wall',
        'Quantity / joints',
        'Condition / band',
        'Inspection status',
        'Pickup location',
      ],
    );
  }

  switch (category) {
    case 'Heavy Equipment':
      return const MarketplaceListingGuide(
        title: 'Heavy equipment identity',
        summary:
            'Year, make/model, usage and serial information make the listing easier to evaluate and search.',
        recommendedFacts: [
          'Year',
          'Make / model',
          'Machine hours',
          'Serial / PIN',
          'Operating status',
          'Attachments',
        ],
      );
    case 'Transport & Hauling':
      return const MarketplaceListingGuide(
        title: 'Truck & trailer identity',
        summary:
            'Capture the core fleet facts before describing configuration, service history and included equipment.',
        recommendedFacts: [
          'Year',
          'Make / model',
          'VIN / serial',
          'Hours if applicable',
          'Operating status',
          'Configuration',
        ],
      );
    case 'Oil & Gas Equipment':
    case 'Oilfield & Drilling':
    case 'Site Support':
      return const MarketplaceListingGuide(
        title: 'Industrial equipment identity',
        summary:
            'Manufacturer, model, serial information and service condition should be visible before long-form notes.',
        recommendedFacts: [
          'Make / model',
          'Year if known',
          'Serial number',
          'Runtime / hours',
          'Operating status',
          'Included equipment',
        ],
      );
    case 'Tanks & Containers':
      return const MarketplaceListingGuide(
        title: 'Tank & container details',
        summary:
            'Give buyers enough information to assess suitability before requesting inspection or transport details.',
        recommendedFacts: [
          'Capacity / size',
          'Manufacturer',
          'Previous service',
          'Condition',
          'Inspection status',
          'Pickup location',
        ],
      );
    case 'Portable Buildings':
      return const MarketplaceListingGuide(
        title: 'Portable building details',
        summary:
            'Keep the headline facts compact; put floor plan, utility and transport notes in the description.',
        recommendedFacts: [
          'Dimensions',
          'Layout / rooms',
          'Utilities',
          'Condition',
          'Included equipment',
          'Pickup location',
        ],
      );
    case 'Farm & Ranch Products':
      return const MarketplaceListingGuide(
        title: 'Fabricated product details',
        summary:
            'Dimensions, material, quantity and finish are the fastest way for buyers to compare fabricated inventory.',
        recommendedFacts: [
          'Dimensions',
          'Material / pipe used',
          'Quantity',
          'Finish',
          'Condition',
          'Pickup location',
        ],
      );
    case 'Site & Property':
      return const MarketplaceListingGuide(
        title: 'Property & rights details',
        summary:
            'Use structured land, building, title and operating fields so buyers can screen the opportunity before due diligence.',
        recommendedFacts: [
          'Offering / interest',
          'Land area',
          'Building area',
          'Zoning / use',
          'Location',
          'Supporting records',
        ],
      );
    default:
      return const MarketplaceListingGuide(
        title: 'Listing facts buyers compare first',
        summary:
            'Use structured facts for identity, quantity, condition and location; reserve the description for context and exceptions.',
        recommendedFacts: [
          'Product type',
          'Make / model',
          'Quantity',
          'Condition',
          'Inspection',
          'Location',
        ],
      );
  }
}

class MarketplaceListingPlacementSelector extends StatelessWidget {
  const MarketplaceListingPlacementSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.timedBuyingEnabled,
    required this.wantedEnabled,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final bool timedBuyingEnabled;
  final bool wantedEnabled;

  @override
  Widget build(BuildContext context) {
    final options = <_PlacementOption>[
      const _PlacementOption(
        value: 'Marketplace',
        label: 'Marketplace',
        description: 'Sell, rent or request a quote',
        icon: Icons.storefront_outlined,
      ),
      _PlacementOption(
        value: 'Timed Buying',
        label: 'Timed Buying',
        description: 'Accept timed offers until a closing time',
        icon: Icons.timer_outlined,
        enabled: timedBuyingEnabled,
      ),
      _PlacementOption(
        value: 'Wanted',
        label: 'Wanted Ad',
        description: 'Tell suppliers what you need',
        icon: Icons.campaign_outlined,
        enabled: wantedEnabled,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 430
                ? 2
                : 1;
        const gap = 9.0;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final option in options)
              SizedBox(
                width: width,
                child: _PlacementCard(
                  option: option,
                  selected: selected == option.value,
                  onTap: option.enabled ? () => onChanged(option.value) : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlacementOption {
  const _PlacementOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
    this.enabled = true,
  });

  final String value;
  final String label;
  final String description;
  final IconData icon;
  final bool enabled;
}

class _PlacementCard extends StatelessWidget {
  const _PlacementCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PlacementOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final border = selected ? PipeBuyerColors.orange : const Color(0xFFDDE3EA);
    final background = selected
        ? PipeBuyerColors.orangeSoft
        : enabled
            ? Colors.white
            : const Color(0xFFF4F6F8);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 78),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: selected ? 1.6 : 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? PipeBuyerColors.orange
                        : PipeBuyerColors.industrialBlue.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    option.icon,
                    size: 18,
                    color: selected
                        ? Colors.white
                        : enabled
                            ? PipeBuyerColors.industrialBlue
                            : PipeBuyerColors.muted,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.label,
                              style: TextStyle(
                                color: enabled
                                    ? PipeBuyerColors.ink
                                    : PipeBuyerColors.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 17,
                              color: PipeBuyerColors.orange,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        enabled
                            ? option.description
                            : 'Temporarily unavailable',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PipeBuyerColors.muted,
                          fontSize: 10.5,
                          height: 1.2,
                        ),
                      ),
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
}

class MarketplaceListingFormSectionHeader extends StatelessWidget {
  const MarketplaceListingFormSectionHeader({
    super.key,
    required this.step,
    required this.title,
    required this.description,
    required this.icon,
  });

  final int step;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 7, bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PipeBuyerColors.ink,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 17, color: PipeBuyerColors.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: PipeBuyerColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: PipeBuyerColors.muted,
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class MarketplaceListingCategoryGuide extends StatelessWidget {
  const MarketplaceListingCategoryGuide({
    super.key,
    required this.category,
    required this.productType,
  });

  final String? category;
  final String? productType;

  @override
  Widget build(BuildContext context) {
    final guide = marketplaceListingGuideFor(category, productType);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE7F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 18,
                color: PipeBuyerColors.industrialBlue,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  guide.title,
                  style: const TextStyle(
                    color: PipeBuyerColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            guide.summary,
            style: const TextStyle(
              color: PipeBuyerColors.muted,
              fontSize: 10.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final fact in guide.recommendedFacts)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFDDE3EA)),
                  ),
                  child: Text(
                    fact,
                    style: const TextStyle(
                      color: PipeBuyerColors.graphite,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class MarketplaceListingResponsiveFields extends StatelessWidget {
  const MarketplaceListingResponsiveFields({
    super.key,
    required this.children,
    this.breakpoint = 680,
    this.spacing = 10,
  });

  final List<Widget> children;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < breakpoint || children.length <= 1) {
            return Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1) SizedBox(height: spacing),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                Expanded(child: children[i]),
                if (i != children.length - 1) SizedBox(width: spacing),
              ],
            ],
          );
        },
      );
}

class MarketplaceListingChecklistItem {
  const MarketplaceListingChecklistItem({
    required this.label,
    required this.complete,
  });

  final String label;
  final bool complete;
}

class MarketplaceListingPublishChecklist extends StatelessWidget {
  const MarketplaceListingPublishChecklist({
    super.key,
    required this.items,
    required this.destinationLabel,
  });

  final List<MarketplaceListingChecklistItem> items;
  final String destinationLabel;

  @override
  Widget build(BuildContext context) {
    final completed = items.where((item) => item.complete).length;
    final ready = items.isNotEmpty && completed == items.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ready ? const Color(0xFFF0FBF6) : const Color(0xFFFFFAF2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready ? const Color(0xFFB9E7D0) : const Color(0xFFF1D7A7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.verified_outlined : Icons.checklist_rounded,
                size: 19,
                color: ready ? PipeBuyerColors.success : PipeBuyerColors.orange,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  ready
                      ? 'Ready for $destinationLabel review'
                      : '$completed of ${items.length} core sections ready',
                  style: const TextStyle(
                    color: PipeBuyerColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final item in items)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.complete
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 15,
                      color: item.complete
                          ? PipeBuyerColors.success
                          : PipeBuyerColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: item.complete
                            ? PipeBuyerColors.graphite
                            : PipeBuyerColors.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
