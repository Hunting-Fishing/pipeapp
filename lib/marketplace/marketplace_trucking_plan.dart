import 'package:flutter/material.dart';

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
}

class MarketplaceTruckingPlanSelector extends StatelessWidget {
  const MarketplaceTruckingPlanSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.dispatchEnabled = true,
    this.highlightMissing = false,
  });

  final MarketplaceTruckingPlan? value;
  final ValueChanged<MarketplaceTruckingPlan> onChanged;
  final bool dispatchEnabled;
  final bool highlightMissing;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: highlightMissing ? const EdgeInsets.all(10) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color:
              highlightMissing ? const Color(0xFFFFF4E5) : Colors.transparent,
          border: highlightMissing
              ? Border.all(color: const Color(0xFFE87900), width: 1.5)
              : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.local_shipping_outlined, size: 20),
              SizedBox(width: 7),
              Text('Trucking plan',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              Text(' *', style: TextStyle(color: Colors.red)),
            ]),
            const SizedBox(height: 3),
            const Text(
                'Choose how transportation should be handled with this offer.',
                style: TextStyle(fontSize: 11, color: Color(0xFF66758A))),
            const SizedBox(height: 8),
            ...MarketplaceTruckingPlan.values
                .where((plan) =>
                    dispatchEnabled ||
                    plan != MarketplaceTruckingPlan.requestDispatch)
                .map((plan) {
              final selected = value == plan;
              final color =
                  selected ? const Color(0xFF0878E8) : const Color(0xFFD8E0E9);
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Material(
                  color: selected
                      ? const Color(0xFFEAF4FD)
                      : const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: color, width: selected ? 1.6 : 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onChanged(plan),
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Row(children: [
                        Icon(plan.icon,
                            color: selected
                                ? const Color(0xFF0878E8)
                                : const Color(0xFF66758A)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(plan.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              Text(plan.description,
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF66758A))),
                            ],
                          ),
                        ),
                        Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: selected
                                ? const Color(0xFF0878E8)
                                : const Color(0xFF9AA7B5)),
                      ]),
                    ),
                  ),
                ),
              );
            }),
            if (value == null && highlightMissing)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text('Required: select a trucking plan.',
                    style: TextStyle(
                        color: Color(0xFF8A4300),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
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
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        color: const Color(0xFFEAF4FD),
        elevation: 0,
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFFB8D9F8)),
            borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                CircleAvatar(
                    backgroundColor: Color(0xFF0878E8),
                    foregroundColor: Colors.white,
                    child: Icon(Icons.local_shipping_outlined)),
                SizedBox(width: 10),
                Expanded(
                    child: Text('Trucking & Dispatch',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900))),
              ]),
              const SizedBox(height: 8),
              Text(
                  auction
                      ? 'Check route, weight and carrier pricing before bidding. Trucking quotes stay separate from your auction bid.'
                      : 'Estimate the load and route, then let professional Dispatch providers bid on the trucking job.',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF53657A))),
              const SizedBox(height: 10),
              FilledButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.route_outlined),
                  label: Text(auction
                      ? 'Plan trucking before bidding'
                      : 'Request carrier quotes'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46))),
            ],
          ),
        ),
      );
}

class MarketplaceDeliveryLocationSelector extends StatelessWidget {
  const MarketplaceDeliveryLocationSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.highlightMissing = false,
  });

  final MarketplaceLocation? value;
  final ValueChanged<MarketplaceLocation> onChanged;
  final bool highlightMissing;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (value != null) ...[
            ListingLocationMap(point: value!.point, approximate: false),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.location_on_outlined, color: Color(0xFF0878E8)),
              const SizedBox(width: 7),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Destination: ${value!.publicName}',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    if (value!.address.trim().isNotEmpty)
                      Text('Site / address: ${value!.address}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF66758A))),
                    if (value!.nearestTown.trim().isNotEmpty)
                      Text('Nearest recognized town: ${value!.nearestTown}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF66758A))),
                    Text(
                        '${value!.point.latitude.toStringAsFixed(5)}, ${value!.point.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF66758A)))
                  ]))
            ]),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
              onPressed: () async {
                final selected = await MarketplaceLocationPicker.showDelivery(
                    context, value);
                if (selected != null) onChanged(selected);
              },
              icon: Icon(value == null
                  ? Icons.add_location_alt_outlined
                  : Icons.edit_location_alt_outlined),
              label: Text(value == null
                  ? 'Choose delivery destination on map *'
                  : 'Change delivery destination'),
              style: OutlinedButton.styleFrom(
                  backgroundColor: highlightMissing && value == null
                      ? const Color(0xFFFFF4E5)
                      : null,
                  foregroundColor: highlightMissing && value == null
                      ? const Color(0xFF8A4300)
                      : null,
                  side: highlightMissing && value == null
                      ? const BorderSide(color: Color(0xFFE87900), width: 1.5)
                      : null,
                  minimumSize: const Size.fromHeight(50),
                  alignment: Alignment.centerLeft)),
          if (value == null)
            Padding(
                padding: EdgeInsets.only(left: 12, top: 5),
                child: Text(
                    highlightMissing
                        ? 'Required: choose the Dispatch delivery destination.'
                        : 'Search an address, small community or landmark, position the pin, then identify the nearest well-known town.',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: highlightMissing
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: highlightMissing
                            ? const Color(0xFF8A4300)
                            : const Color(0xFF66758A))))
        ],
      );
}
