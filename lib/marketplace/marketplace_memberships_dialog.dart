import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_dispatch_subscription_panel.dart';
import 'marketplace_subscription_artwork.dart';

class MarketplaceMembershipsDialog extends StatelessWidget {
  const MarketplaceMembershipsDialog({
    super.key,
    required this.onVipDetails,
  });

  final VoidCallback onVipDetails;

  void _openVip(BuildContext context) {
    Navigator.of(context).pop();
    scheduleMicrotask(onVipDetails);
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 820),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Memberships & upgrades',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage Pipe Buyer VIP access and Dispatch membership in one place.',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101721),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: PipeBuyerColors.orange.withValues(alpha: .55),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const artwork = SizedBox(
                        width: 180,
                        child: MarketplaceSubscriptionArtwork(
                          planTitle: 'VIP Membership',
                          fallbackLabel: 'Pipe, Tubing & Materials',
                          height: 120,
                        ),
                      );
                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VIP MEMBERSHIP',
                            style: TextStyle(
                              color: Color(0xFFFFC44D),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .9,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Marketplace priority access',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            '24-hour early listing access, priority alerts and the VIP marketplace experience.',
                            style: TextStyle(color: Colors.white70, height: 1.35),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => _openVip(context),
                            icon: const Icon(Icons.workspace_premium_outlined),
                            label: const Text('View VIP details'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFC44D),
                            ),
                          ),
                        ],
                      );
                      if (constraints.maxWidth >= 620) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            artwork,
                            const SizedBox(width: 16),
                            Expanded(child: details),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          artwork,
                          const SizedBox(height: 10),
                          details,
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      color: PipeBuyerColors.industrialBlue,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dispatch membership',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose Monthly or Yearly. Pipe Buyer will reuse an existing Checkout instead of creating duplicate subscriptions.',
                ),
                const SizedBox(height: 12),
                const MarketplaceDispatchSubscriptionPanel(),
              ],
            ),
          ),
        ),
      );
}
