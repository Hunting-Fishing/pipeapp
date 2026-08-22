import 'package:flutter/material.dart';

/// Public-facing membership presentation.
///
/// This enum is display-only. Billing/entitlement authority must come from
/// server-owned membership data; clients must never upgrade themselves by
/// writing one of these values locally.
enum MarketplaceMembershipTier {
  unpublished,
  standard,
  bronze,
  silver,
  gold,
  vip,
}

extension MarketplaceMembershipTierPresentation on MarketplaceMembershipTier {
  String get label => switch (this) {
        MarketplaceMembershipTier.unpublished => 'Membership not published',
        MarketplaceMembershipTier.standard => 'Standard',
        MarketplaceMembershipTier.bronze => 'Bronze',
        MarketplaceMembershipTier.silver => 'Silver',
        MarketplaceMembershipTier.gold => 'Gold',
        MarketplaceMembershipTier.vip => 'VIP',
      };

  Color get color => switch (this) {
        MarketplaceMembershipTier.unpublished => const Color(0xFF94A3B8),
        MarketplaceMembershipTier.standard => const Color(0xFF64748B),
        MarketplaceMembershipTier.bronze => const Color(0xFFB87333),
        MarketplaceMembershipTier.silver => const Color(0xFFA7B0BC),
        MarketplaceMembershipTier.gold => const Color(0xFFD4AF37),
        MarketplaceMembershipTier.vip => const Color(0xFF7C3AED),
      };
}

MarketplaceMembershipTier marketplaceMembershipTierFrom(Object? value) {
  final normalized = '${value ?? ''}'.trim().toLowerCase();
  return switch (normalized) {
    'vip' => MarketplaceMembershipTier.vip,
    'gold' => MarketplaceMembershipTier.gold,
    'silver' => MarketplaceMembershipTier.silver,
    'bronze' => MarketplaceMembershipTier.bronze,
    'standard' => MarketplaceMembershipTier.standard,
    _ => MarketplaceMembershipTier.unpublished,
  };
}

/// Bounded public reputation summary.
///
/// Raw reports, reporter identities, internal moderation evidence and private
/// score inputs must never be placed in this object.
class MarketplaceReputationSummary {
  const MarketplaceReputationSummary({
    this.score,
    this.status = 'new',
    this.reviewAverage,
    this.reviewCount = 0,
    this.completedTransactionCount = 0,
    this.responseBand = '',
    this.reliabilityBand = '',
    this.scoreVersion = 0,
  });

  factory MarketplaceReputationSummary.fromMap(Map<String, dynamic>? data) {
    final source = data ?? const <String, dynamic>{};
    final rawScore = source['reputationScore'];
    final parsedScore =
        rawScore is num ? rawScore.round().clamp(0, 100).toInt() : null;
    final rawAverage = source['reviewAverage'];
    return MarketplaceReputationSummary(
      score: parsedScore,
      status: '${source['reputationStatus'] ?? 'new'}'.trim().toLowerCase(),
      reviewAverage: rawAverage is num ? rawAverage.toDouble() : null,
      reviewCount: _safeInt(source['reviewCount']),
      completedTransactionCount: _safeInt(source['completedTransactionCount']),
      responseBand: '${source['responseBand'] ?? ''}'.trim(),
      reliabilityBand: '${source['reliabilityBand'] ?? ''}'.trim(),
      scoreVersion: _safeInt(source['scoreVersion']),
    );
  }

  final int? score;
  final String status;
  final double? reviewAverage;
  final int reviewCount;
  final int completedTransactionCount;
  final String responseBand;
  final String reliabilityBand;
  final int scoreVersion;

  bool get hasPublishedScore => score != null && status != 'new';

  String get statusLabel => switch (status) {
        'established' => 'Established',
        'emerging' => 'Emerging',
        'new' => 'Building reputation',
        _ => status.isEmpty ? 'Building reputation' : _titleCase(status),
      };

  String get scoreLabel => hasPublishedScore ? '${score!}' : 'NEW';

  Color get reputationColor {
    if (!hasPublishedScore) return const Color(0xFF1976D2);
    final value = score!;
    if (value >= 90) return const Color(0xFF16864B);
    if (value >= 80) return const Color(0xFF36A968);
    if (value >= 70) return const Color(0xFFD2A800);
    if (value >= 60) return const Color(0xFFF57C00);
    return const Color(0xFFD32F2F);
  }

  String get reputationBand {
    if (!hasPublishedScore) return 'New / building history';
    final value = score!;
    if (value >= 90) return 'Excellent';
    if (value >= 80) return 'Strong';
    if (value >= 70) return 'Good';
    if (value >= 60) return 'Watch';
    return 'At risk';
  }
}

class MarketplaceReputationBadge extends StatelessWidget {
  const MarketplaceReputationBadge({
    super.key,
    required this.summary,
    required this.membershipTier,
    this.size = 72,
    this.showLabel = true,
  });

  final MarketplaceReputationSummary summary;
  final MarketplaceMembershipTier membershipTier;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final badge = Semantics(
      button: true,
      label:
          '${membershipTier.label}. Pipe Buyer reputation ${summary.hasPublishedScore ? '${summary.score} out of 100' : 'building history'}. Tap for score legend.',
      child: Tooltip(
        message: _tooltipText,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _showLegend(context),
          child: Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: membershipTier.color, width: 4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: summary.reputationColor, width: 4),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: summary.reputationColor.withValues(alpha: .08),
                ),
                child: Center(
                  child: Text(
                    summary.scoreLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: summary.reputationColor,
                      fontSize:
                          summary.hasPublishedScore ? size * .29 : size * .18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: summary.hasPublishedScore ? 0 : .7,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!showLabel) return badge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(height: 5),
        Text(
          summary.hasPublishedScore
              ? '${summary.score}/100 · ${summary.statusLabel}'
              : 'Building reputation',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  String get _tooltipText => '${membershipTier.label} outer membership ring\n'
      '${summary.reputationBand} inner reputation ring\n'
      '${summary.hasPublishedScore ? '${summary.score}/100' : 'New provider — no public numeric score until enough history exists'}\n'
      'Select for the legend and score explanation.';

  Future<void> _showLegend(BuildContext context) => showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pipe Buyer reputation legend',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Two colored rings communicate two different things. Membership is not the same as reputation and cannot buy a higher reputation score.',
                  ),
                  const SizedBox(height: 18),
                  const Text('Outer ring — membership',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  for (final tier in MarketplaceMembershipTier.values)
                    _LegendRow(color: tier.color, label: tier.label),
                  const SizedBox(height: 16),
                  const Text('Inner ring — reputation',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const _LegendRow(
                    color: Color(0xFF1976D2),
                    label: 'Blue — New / building history',
                  ),
                  const _LegendRow(
                    color: Color(0xFF16864B),
                    label: 'Dark green — 90–100 Excellent',
                  ),
                  const _LegendRow(
                    color: Color(0xFF36A968),
                    label: 'Green — 80–89 Strong',
                  ),
                  const _LegendRow(
                    color: Color(0xFFD2A800),
                    label: 'Yellow — 70–79 Good',
                  ),
                  const _LegendRow(
                    color: Color(0xFFF57C00),
                    label: 'Orange — 60–69 Watch',
                  ),
                  const _LegendRow(
                    color: Color(0xFFD32F2F),
                    label: 'Red — below 60 At risk',
                  ),
                  const SizedBox(height: 16),
                  const Text('What the reputation system measures',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text(
                    '• Identity & business integrity — 20%\n'
                    '• Listing/profile quality — 15%\n'
                    '• Responsiveness — 15%\n'
                    '• Transaction/service performance — 25%\n'
                    '• Verified reviews — 15%\n'
                    '• Trust & Safety standing — 10%',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Only server-verified marketplace activity and confirmed Trust & Safety outcomes may affect the public score. Raw user reports do not automatically reduce a score. New accounts show “Building reputation” instead of a misleading 0/100.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Got it'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 4),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(label)),
          ],
        ),
      );
}

int _safeInt(Object? value) =>
    value is num ? value.round().clamp(0, 1 << 30).toInt() : 0;

String _titleCase(String value) {
  final words = value
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  return words
      .map((word) =>
          '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}
