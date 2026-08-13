import 'dart:async';

import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';

class MarketplaceOfferRequirements {
  const MarketplaceOfferRequirements({
    required this.offeredUnitPrice,
    required this.requestedQuantity,
    required this.hasTruckingPlan,
    required this.requestsDispatch,
    required this.hasDispatchDestination,
    required this.hasTruckingDate,
  });

  final num offeredUnitPrice;
  final int requestedQuantity;
  final bool hasTruckingPlan;
  final bool requestsDispatch;
  final bool hasDispatchDestination;
  final bool hasTruckingDate;

  List<String> get missing {
    final items = <String>[];
    if (requestedQuantity <= 0) items.add('quantity requested');
    if (offeredUnitPrice <= 0) items.add('offer price');
    if (!hasTruckingPlan) items.add('trucking plan');
    if (requestsDispatch && !hasDispatchDestination) {
      items.add('delivery destination');
    }
    if (requestsDispatch && !hasTruckingDate) {
      items.add('trucking / pickup date');
    }
    return items;
  }

  bool get complete => missing.isEmpty;

  String get guidance => missing.isEmpty
      ? 'All required offer details are complete.'
      : 'Still required: ${missing.join(', ')}.';
}

class MarketplaceOfferSubmitButton extends StatelessWidget {
  const MarketplaceOfferSubmitButton({
    required this.requirements,
    required this.onComplete,
    super.key,
  });

  final MarketplaceOfferRequirements requirements;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: requirements.complete
              ? const Color(0xFF0F52BA)
              : const Color(0xFFE87900),
          foregroundColor: Colors.white,
        ),
        onPressed: () {
          if (!requirements.complete) {
            showMarketplaceOfferGuidanceToast(context, requirements.guidance);
            return;
          }
          onComplete();
        },
        child: const Text('Submit offer'),
      );
}

void showMarketplaceOfferGuidanceToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 24,
      right: 24,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          elevation: 10,
          borderRadius: BorderRadius.circular(12),
          child: PipeStatusSurface(
            tone: PipeStatusTone.warning,
            title: 'Offer not submitted',
            message: message,
            liveRegion: true,
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Timer(const Duration(seconds: 4), () {
    if (entry.mounted) entry.remove();
  });
}
