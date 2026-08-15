import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

const marketplaceListingActiveDays = 30;
const marketplaceListingExpiryWarningDays = 3;

DateTime? marketplaceListingDate(dynamic value) {
  final parsed = switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    int milliseconds =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
    String text => DateTime.tryParse(text),
    _ => null,
  };
  return parsed;
}

@immutable
class MarketplaceListingLifecycle {
  const MarketplaceListingLifecycle({
    required this.status,
    required this.expiresAt,
    required this.renewalCount,
    required this.now,
  });

  factory MarketplaceListingLifecycle.fromMap(
    Map<String, dynamic> data, {
    DateTime? now,
  }) {
    return MarketplaceListingLifecycle(
      status: '${data['status'] ?? 'active'}'.trim().toLowerCase(),
      expiresAt: marketplaceListingDate(data['expiresAt']),
      renewalCount: (data['renewalCount'] as num?)?.toInt() ?? 0,
      now: now ?? DateTime.now(),
    );
  }

  final String status;
  final DateTime? expiresAt;
  final int renewalCount;
  final DateTime now;

  bool get expired =>
      status == 'expired' ||
      (expiresAt != null &&
          !expiresAt!.isAfter(now) &&
          const {'active', 'paused'}.contains(status));

  Duration? get remaining => expiresAt?.difference(now);

  bool get expiringSoon {
    final value = remaining;
    if (expired || value == null || value <= Duration.zero) return false;
    return value <= const Duration(days: marketplaceListingExpiryWarningDays);
  }

  int? get daysRemaining {
    final value = remaining;
    if (value == null) return null;
    if (value <= Duration.zero) return 0;
    return (value.inHours / 24).ceil();
  }

  String get ownerLabel {
    if (expired) return 'Expired — renew for another 30 days';
    final days = daysRemaining;
    if (days == null) return '30-day listing period';
    if (days == 0) return 'Expires today';
    if (days == 1) return '1 day remaining';
    return '$days days remaining';
  }
}

class MarketplaceListingLifecyclePill extends StatelessWidget {
  const MarketplaceListingLifecyclePill({
    super.key,
    required this.data,
    this.ownerView = false,
  });

  final Map<String, dynamic> data;
  final bool ownerView;

  @override
  Widget build(BuildContext context) {
    final lifecycle = MarketplaceListingLifecycle.fromMap(data);
    if (data['transactionType'] == 'Auction') return const SizedBox.shrink();
    if (!ownerView && !lifecycle.expiringSoon && !lifecycle.expired) {
      return const SizedBox.shrink();
    }
    final color = lifecycle.expired
        ? PipeBuyerColors.danger
        : lifecycle.expiringSoon
            ? PipeBuyerColors.orange
            : PipeBuyerColors.slate;
    final icon = lifecycle.expired
        ? Icons.event_busy_outlined
        : lifecycle.expiringSoon
            ? Icons.timer_outlined
            : Icons.event_available_outlined;
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            lifecycle.ownerLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
