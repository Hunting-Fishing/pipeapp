import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_location.dart';
import 'marketplace_location_picker.dart';

enum MarketplaceTruckingPlan {
  buyerArranged,
  requestDispatch,
  sellerPickup,
}

MarketplaceTruckingPlan? marketplaceTruckingPlanFromStorage(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized == 'not_specified') return null;
  for (final plan in MarketplaceTruckingPlan.values) {
    if (plan.storageValue == normalized) return plan;
  }
  return null;
}

extension MarketplaceTruckingPlanDetails on MarketplaceTruckingPlan {
  String get storageValue => switch (this) {
        MarketplaceTruckingPlan.buyerArranged => 'buyer_arranged',
        MarketplaceTruckingPlan.requestDispatch => 'request_dispatch',
        MarketplaceTruckingPlan.sellerPickup => 'seller_pickup',
      };

  String get label => switch (this) {
        MarketplaceTruckingPlan.buyerArranged => 'I have trucking arranged',
        MarketplaceTruckingPlan.requestDispatch =>
          'Request quotes through Dispatch',
        MarketplaceTruckingPlan.sellerPickup =>
          'Pickup or seller-arranged transport',
      };

  String get description => switch (this) {
        MarketplaceTruckingPlan.buyerArranged =>
          'I will use my own truck, carrier, or transportation.',
        MarketplaceTruckingPlan.requestDispatch =>
          'Prepare a Dispatch request for professional carrier bids.',
        MarketplaceTruckingPlan.sellerPickup =>
          'Transportation will be confirmed directly with the seller.',
      };

  IconData get icon => switch (this) {
        MarketplaceTruckingPlan.buyerArranged => Icons.local_shipping_outlined,
        MarketplaceTruckingPlan.requestDispatch => Icons.route_outlined,
        MarketplaceTruckingPlan.sellerPickup => Icons.handshake_outlined,
      };

  PipeBuyerStatusTone get tone => switch (this) {
        MarketplaceTruckingPlan.buyerArranged => PipeBuyerStatusTone.info,
        MarketplaceTruckingPlan.requestDispatch => PipeBuyerStatusTone.premium,
        MarketplaceTruckingPlan.sellerPickup => PipeBuyerStatusTone.success,
      };
}

class MarketplaceTruckingPlanSelector extends StatelessWidget {
  const MarketplaceTruckingPlanSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.dispatchEnabled = true,
  });

  final MarketplaceTruckingPlan? value;
  final ValueChanged<MarketplaceTruckingPlan> onChanged;
  final bool dispatchEnabled;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PipeBuyerColors.orangeSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: PipeBuyerColors.orangePressed,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Trucking plan',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Text(
                          ' *',
                          style: TextStyle(color: PipeBuyerColors.danger),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Choose how transportation should be handled with this offer.',
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
            ],
          ),
          const SizedBox(height: 10),
          ...MarketplaceTruckingPlan.values
              .where((plan) =>
                  dispatchEnabled ||
                  plan != MarketplaceTruckingPlan.requestDispatch)
              .map((plan) {
            final selected = value == plan;
            final accent = pipeBuyerToneColor(plan.tone);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected
                    ? accent.withValues(alpha: .07)
                    : Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: selected
                        ? accent.withValues(alpha: .62)
                        : Theme.of(context).dividerColor,
                    width: selected ? 1.6 : 1,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(plan),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(plan.icon, color: accent, size: 21),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                plan.description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(height: 1.35),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: selected
                              ? accent
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .34),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (value == null)
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 1),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 15,
                    color: PipeBuyerColors.danger,
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Select a trucking plan to continue.',
                      style: TextStyle(
                        color: PipeBuyerColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}

class MarketplaceDispatchQuoteCard extends StatelessWidget {
  const MarketplaceDispatchQuoteCard({
    super.key,
    required this.onPressed,
    this.auction = false,
  });

  final VoidCallback onPressed;
  final bool auction;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -26,
              bottom: -28,
              child: Icon(
                Icons.local_shipping_outlined,
                size: 120,
                color: Colors.white.withValues(alpha: .035),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 5, color: PipeBuyerColors.orange),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PipeBuyerStatusBadge(
                    label: 'PIPE BUYER DISPATCH',
                    icon: Icons.route_outlined,
                    tone: PipeBuyerStatusTone.premium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Trucking & Dispatch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    auction
                        ? 'Check route, weight and carrier pricing before bidding. Trucking quotes stay separate from your auction bid.'
                        : 'Estimate the load and route, then let professional Dispatch providers bid on the trucking job.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.route_outlined),
                    label: Text(auction
                        ? 'Plan trucking before bidding'
                        : 'Request carrier quotes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class MarketplaceDeliveryLocationSelector extends StatelessWidget {
  const MarketplaceDeliveryLocationSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MarketplaceLocation? value;
  final ValueChanged<MarketplaceLocation> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (value != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ListingLocationMap(
                point: value!.point,
                approximate: false,
              ),
            ),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PipeBuyerColors.industrialBlue.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      PipeBuyerColors.industrialBlue.withValues(alpha: .16),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color:
                          PipeBuyerColors.industrialBlue.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: PipeBuyerColors.industrialBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destination: ${value!.publicName}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (value!.address.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Site / address: ${value!.address}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (value!.nearestTown.trim().isNotEmpty)
                          Text(
                            'Nearest recognized town: ${value!.nearestTown}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const SizedBox(height: 3),
                        Text(
                          '${value!.point.latitude.toStringAsFixed(5)}, ${value!.point.longitude.toStringAsFixed(5)}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: .50),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
          ],
          OutlinedButton.icon(
            onPressed: () async {
              final selected =
                  await MarketplaceLocationPicker.showDelivery(context, value);
              if (selected != null) onChanged(selected);
            },
            icon: Icon(value == null
                ? Icons.add_location_alt_outlined
                : Icons.edit_location_alt_outlined),
            label: Text(value == null
                ? 'Choose delivery destination on map *'
                : 'Change delivery destination'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              alignment: Alignment.centerLeft,
            ),
          ),
          if (value == null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: Text(
                'Search an address, small community or landmark, position the pin, then identify the nearest well-known town.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .58),
                    ),
              ),
            ),
        ],
      );
}
