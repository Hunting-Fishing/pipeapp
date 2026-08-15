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

  double get offerToAskPercent => analysis.askingUnitPrice <= 0
      ? 0
      : analysis.offeredUnitPrice / analysis.askingUnitPrice * 100;

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
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: PipeBuyerColors.orangeSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.calculate_outlined,
                  color: PipeBuyerColors.orangePressed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offer comparison',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const Text(
                      'The original listing is locked in view. Only your offer values change.',
                      style: TextStyle(
                        color: PipeBuyerColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _MetricPill(
                label: '$requestedPercent% of inventory',
                color: PipeBuyerColors.industrialBlue,
              ),
            ],
          ),
          const SizedBox(height: 13),
          _buildComparisonPanels(
            context,
            requestedPercent: requestedPercent,
          ),
          const SizedBox(height: 13),
          _AnalyticsPanel(
            analysis: analysis,
            unitLabel: unitLabel,
            requestedPercent: requestedPercent,
            remainingPercent: remainingPercent,
            offerToAskPercent: offerToAskPercent,
            impliedFullLotOfferValue: impliedFullLotOfferValue,
            impliedFullLotDifference: impliedFullLotDifference,
            requestedDifferenceColor: requestedDifferenceColor,
            projectedDifferenceColor: projectedDifferenceColor,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonPanels(
    BuildContext context, {
    required String requestedPercent,
  }) {
    final original = _CommercePanel(
      eyebrow: 'LOCKED BASELINE',
      title: 'Original listing',
      icon: Icons.lock_outline_rounded,
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

    final requestedAtAsk = _CommercePanel(
      eyebrow: 'SELLER ASK ON YOUR QTY',
      title: 'Requested slice',
      icon: Icons.content_cut_rounded,
      accent: PipeBuyerColors.slate,
      rows: [
        _CommerceRow(
          'Quantity requested',
          '${analysis.normalizedRequestedQuantity} $unitLabel ($requestedPercent%)',
          strong: true,
        ),
        _CommerceRow(
          'Seller ask stays',
          '${marketplaceMoney(analysis.askingUnitPrice)} / $unitLabel',
        ),
        _CommerceRow(
          'Requested value at ask',
          marketplaceMoney(analysis.requestedAskValue),
          strong: true,
        ),
      ],
    );

    final offer = _CommercePanel(
      eyebrow: 'LIVE BUYER VALUES',
      title: 'Your offer',
      icon: Icons.handshake_outlined,
      accent: PipeBuyerColors.orangePressed,
      rows: [
        _CommerceRow(
          'Quantity requested',
          '${analysis.normalizedRequestedQuantity} $unitLabel',
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

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: original),
              const SizedBox(width: 9),
              Expanded(child: requestedAtAsk),
              const SizedBox(width: 9),
              Expanded(child: offer),
            ],
          );
        }
        if (constraints.maxWidth >= 500) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: original),
                  const SizedBox(width: 9),
                  Expanded(child: offer),
                ],
              ),
              const SizedBox(height: 9),
              requestedAtAsk,
            ],
          );
        }
        return Column(
          children: [
            original,
            const SizedBox(height: 9),
            requestedAtAsk,
            const SizedBox(height: 9),
            offer,
          ],
        );
      },
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({
    required this.analysis,
    required this.unitLabel,
    required this.requestedPercent,
    required this.remainingPercent,
    required this.offerToAskPercent,
    required this.impliedFullLotOfferValue,
    required this.impliedFullLotDifference,
    required this.requestedDifferenceColor,
    required this.projectedDifferenceColor,
  });

  final MarketplaceOfferAnalysis analysis;
  final String unitLabel;
  final String requestedPercent;
  final String remainingPercent;
  final double offerToAskPercent;
  final num impliedFullLotOfferValue;
  final num impliedFullLotDifference;
  final Color requestedDifferenceColor;
  final Color projectedDifferenceColor;

  @override
  Widget build(BuildContext context) => Container(
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
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700
                    ? 3
                    : constraints.maxWidth >= 450
                        ? 2
                        : 1;
                final gap = 8.0;
                final width = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - gap * (columns - 1)) / columns;
                final metrics = <Widget>[
                  _AnalyticsTile(
                    label: 'Inventory requested',
                    value: '$requestedPercent%',
                    detail:
                        '${analysis.normalizedRequestedQuantity} of ${analysis.listedQuantity} $unitLabel',
                    icon: Icons.pie_chart_outline_rounded,
                    color: PipeBuyerColors.industrialBlue,
                  ),
                  _AnalyticsTile(
                    label: 'Inventory remaining',
                    value: '$remainingPercent%',
                    detail: '${analysis.remainingQuantity} $unitLabel remain',
                    icon: Icons.inventory_2_outlined,
                    color: analysis.remainingQuantity == 0
                        ? PipeBuyerColors.success
                        : PipeBuyerColors.industrialBlue,
                  ),
                  _AnalyticsTile(
                    label: 'Offer vs asking price',
                    value: '${offerToAskPercent.toStringAsFixed(1)}%',
                    detail:
                        '${_signedMoney(analysis.unitDifference)} / $unitLabel (${_signedPercent(analysis.priceDifferencePercent)})',
                    icon: Icons.compare_arrows_rounded,
                    color: requestedDifferenceColor,
                  ),
                  _AnalyticsTile(
                    label: 'Requested value at ask',
                    value: marketplaceMoney(analysis.requestedAskValue),
                    detail: 'Seller pricing on the quantity you selected',
                    icon: Icons.sell_outlined,
                    color: PipeBuyerColors.slate,
                  ),
                  _AnalyticsTile(
                    label: 'Your offer total',
                    value: marketplaceMoney(analysis.offeredTotal),
                    detail:
                        'Difference ${_signedMoney(analysis.requestedValueDifference)}',
                    icon: Icons.handshake_outlined,
                    color: requestedDifferenceColor,
                  ),
                  _AnalyticsTile(
                    label: 'Remaining value at ask',
                    value: marketplaceMoney(analysis.remainingAskValue),
                    detail:
                        'Value of inventory outside your requested quantity',
                    icon: Icons.account_balance_wallet_outlined,
                    color: PipeBuyerColors.industrialBlue,
                  ),
                  _AnalyticsTile(
                    label: 'Original full listing',
                    value: marketplaceMoney(analysis.fullListingAskValue),
                    detail:
                        '${analysis.listedQuantity} $unitLabel × ${marketplaceMoney(analysis.askingUnitPrice)}',
                    icon: Icons.lock_outline_rounded,
                    color: PipeBuyerColors.industrialBlue,
                  ),
                  _AnalyticsTile(
                    label: 'Full lot at your unit price',
                    value: marketplaceMoney(impliedFullLotOfferValue),
                    detail:
                        'Projection only — your entered price across the full lot',
                    icon: Icons.functions_rounded,
                    color: PipeBuyerColors.orangePressed,
                  ),
                  _AnalyticsTile(
                    label: 'Projected full-lot difference',
                    value: _signedMoney(impliedFullLotDifference),
                    detail:
                        'Vs original full ask (${_signedPercent(analysis.priceDifferencePercent)})',
                    icon: Icons.trending_down_rounded,
                    color: projectedDifferenceColor,
                  ),
                ];

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final metric in metrics)
                      SizedBox(width: width, child: metric),
                  ],
                );
              },
            ),
          ],
        ),
      );
}

class _AnalyticsTile extends StatelessWidget {
  const _AnalyticsTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 102),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: .14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: PipeBuyerColors.slate,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(
                color: PipeBuyerColors.muted,
                fontSize: 10,
                height: 1.25,
              ),
            ),
          ],
        ),
      );
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
          border: Border.all(color: accent.withValues(alpha: .22)),
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
                        style: const TextStyle(fontWeight: FontWeight.w900),
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
                child: _DenseRow(
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

class _DenseRow extends StatelessWidget {
  const _DenseRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Text(
              label,
              style: TextStyle(
                color: PipeBuyerColors.slate,
                fontSize: 11,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
              ),
            ),
          ),
        ],
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
