import 'package:flutter/material.dart';

import 'industrial_icon_assets.dart';

class MarketplaceSubscriptionArtwork extends StatelessWidget {
  const MarketplaceSubscriptionArtwork({
    super.key,
    required this.planTitle,
    required this.fallbackLabel,
    this.height = 150,
  });

  final String planTitle;
  final String fallbackLabel;
  final double height;

  String get _assetPath {
    final normalized = planTitle.trim().toLowerCase();
    if (normalized.contains('vip')) {
      return 'assets/images/membership_vip_subscription.svg';
    }
    if (normalized.contains('year')) {
      return 'assets/images/membership_dispatch_yearly_subscription.svg';
    }
    return 'assets/images/membership_dispatch_monthly_subscription.svg';
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: Center(
          child: IndustrialAssetIcon(
            label: fallbackLabel,
            assetPath: _assetPath,
            size: height.clamp(96.0, 144.0).toDouble(),
            borderRadius: 16,
            fallback: const Icon(
              Icons.workspace_premium_outlined,
              size: 58,
            ),
          ),
        ),
      );
}
