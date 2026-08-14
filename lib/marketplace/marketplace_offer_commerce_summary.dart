import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_money.dart';
import 'marketplace_offer_analysis.dart';

/// Dense commerce summary for the Make Offer workflow.
///
/// The seller's original listing is deliberately isolated from the buyer's
/// editable values so changing quantity or unit price can never make the
/// original asking quantity/value disappear from view.
class MarketplaceOfferCommerceSummary extends StatelessWidget {
  const MarketplaceOfferCommerceSummary({
    super.key,
    required this.analysis,
    this.unitLabel = 'pieces',
  });

  final MarketplaceOfferAnalysis analysis;
  final String unitLabel;

  num get impliedFullLotOfferValue =>
      analysis.offeredUnitPrice * analysis.listedQuantity;

  num get impliedFullLotDifference =>
      impliedFullLotOfferValue - analysis.fullListingAskValue;

  @override
  Widget build(BuildContext context) {
    final requestedPercent =
        analysis.requestedQuantityPercent.toStringAsFixed(1);
    final remainingPercent =
        analysis.remainingQuantityPercent.toStringAsFixed(1);
    final requestedDifference = analysis.requestedValueDifference;
    final requestedDifferenceColor = _differenceColor(requestedDifference);
    final projectedDifferenceColor = _differenceColor(impliedFullLotDifference);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calculate_outlined,
                color: PipeBuyerColors.orangePressed,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offer comparison',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const Text(
                      'Original listing stays fixed while your offer updates.',
                      style: TextStyle(
                        color: PipeBuyerColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _MetricPill(
                label: '$requestedPercent% requested',
                color: PipeBuyerColors.industrialBlue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 500;
              final original = _CommercePanel(
                eyebrow: 'STATIC LISTING',
                title: 'Original listing',
                icon: Icons.inventory_2_outlined,
                accent: PipeBuyerColors.industrialBlue,
                rows: [
                  _CommerceRow(
                    'Original quantity',
                    '${analysis.listedQuantity} $unitLabel',
                    strong: true,
                  ),
                  _CommerceRow(
                    'Original asking price',
                    '${marketplaceMoney(analysis.askingUnitPrice)} / $unitLabel',
                    strong: true,
                  ),
                  _CommerceRow(
                    'Original full listing value',
                    marketplaceMoney(analysis.fullListingAskValue),
                    strong: true,
                  ),
                ],
              );
              final offer = _CommercePanel(
                eyebrow: 'LIVE OFFER',
                title: 'Your offer',
                icon: Icons.handshake_outlined,
                accent: PipeBuyerColors.orangePressed,
                rows: [
                  _CommerceRow(
                    'Requested quantity',
                    '${analysis.normalizedRequestedQuantity} $unitLabel ($requestedPercent%)',
                    strong: true,
                  ),
                  _CommerceRow(
                    'Your unit price',
                    '${marketplaceMoney(analysis.offeredUnitPrice)} / $unitLabel',
                    strong: true,
                  ),
                  _CommerceRow(
                    'Your offer total',
                    marketplaceMoney(analysis.offeredTotal),
                    strong: true,
                  ),
                ],
              );
              if (!sideBySide) {
                return Column(
                  children: [
                    original,
                    const SizedBox(height: 10),
                    offer,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: original),
                  const SizedBox(width: 10),
                  Expanded(child: offer),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PipeBuyerColors.canvas,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFE1E6EC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 18,
                      color: PipeBuyerColors.orangePressed,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'OFFER ANALYTICS',
                      style: TextStyle(
                        color: PipeBuyerColors.slate,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .75,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _AnalyticsRow(
                  label: 'Requested quantity share',
                  value: '$requestedPercent%',
                ),
                _AnalyticsRow(
                  label: 'Quantity remaining',
                  value:
                      '${analysis.remainingQuantity} $unitLabel ($remainingPercent%)',
                  valueColor: analysis.remainingQuantity == 0
                      ? PipeBuyerColors.success
                      : PipeBuyerColors.industrialBlue,
                ),
                _AnalyticsRow(
                  label: 'Requested value at seller ask',
                  value: marketplaceMoney(analysis.requestedAskValue),
                ),
                _AnalyticsRow(
                  label: 'Your offered value',
                  value: marketplaceMoney(analysis.offeredTotal),
                  valueColor: requestedDifferenceColor,
                ),
                _AnalyticsRow(
                  label: 'Unit-price difference',
                  value:
                      '${_signedMoney(analysis.unitDifference)} / $unitLabel  (${_signedPercent(analysis.priceDifferencePercent)})',
                  valueColor: requestedDifferenceColor,
                ),
                _AnalyticsRow(
                  label: 'Difference on requested quantity',
                  value: _signedMoney(requestedDifference),
                  valueColor: requestedDifferenceColor,
                  strong: true,
                ),
                const Divider(height: 18),
                _AnalyticsRow(
                  label: 'Remaining inventory value at ask',
                  value: marketplaceMoney(analysis.remainingAskValue),
                ),
                _AnalyticsRow(
                  label: 'Full-lot value at your unit price',
                  value: marketplaceMoney(impliedFullLotOfferValue),
                ),
                _AnalyticsRow(
                  label: 'Full-lot difference vs original ask',
                  value:
                      '${_signedMoney(impliedFullLotDifference)}  (${_signedPercent(analysis.priceDifferencePercent)})',
                  valueColor: projectedDifferenceColor,
                  strong: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommercePanel extends StatelessWidget {
  const _CommercePanel({
    required this.eyebrow,
    required this.title,
    required this.icon,
    required this.accent,
    required this.rows,
  });

  final String eyebrow;
  final String title;
  final IconData icon;
  final Color accent;
  final List<_CommerceRow> rows;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: accent.withValues(alpha: .2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _AnalyticsRow(
                  label: row.label,
                  value: row.value,
                  strong: row.strong,
                ),
              ),
          ],
        ),
      );
}

class _CommerceRow {
  const _CommerceRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;
}

class _AnalyticsRow extends StatelessWidget {
  const _AnalyticsRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.strong = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Text(
                label,
                style: TextStyle(
                  color: PipeBuyerColors.slate,
                  fontSize: 12,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 12,
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

Color _differenceColor(num value) {
  if (value < 0) return PipeBuyerColors.danger;
  if (value > 0) return PipeBuyerColors.success;
  return PipeBuyerColors.industrialBlue;
}

String _signedMoney(num value) {
  if (value == 0) return marketplaceMoney(0);
  return '${value > 0 ? '+' : '-'}${marketplaceMoney(value.abs())}';
}

String _signedPercent(double value) =>
    '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}%';
