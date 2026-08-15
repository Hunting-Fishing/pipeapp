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
      return 'assets/images/subscriptions/vip_subscription.webp';
    }
    if (normalized.contains('year')) {
      return 'assets/images/subscriptions/dispatch_yearly_subscription.webp';
    }
    return 'assets/images/subscriptions/dispatch_monthly_subscription.webp';
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            _assetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Center(
              child: IndustrialAssetIcon(
                label: fallbackLabel,
                size: height.clamp(90.0, 132.0).toDouble(),
                borderRadius: 12,
                fallback: const Icon(
                  Icons.workspace_premium_outlined,
                  size: 58,
                ),
              ),
            ),
          ),
        ),
      );
}
