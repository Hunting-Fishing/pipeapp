import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_money.dart';

class MarketplaceOfferAnalysis {
  const MarketplaceOfferAnalysis({
    required this.listedQuantity,
    required this.requestedQuantity,
    required this.askingUnitPrice,
    required this.offeredUnitPrice,
  });

  final int listedQuantity;
  final int requestedQuantity;
  final num askingUnitPrice;
  final num offeredUnitPrice;

  int get normalizedRequestedQuantity =>
      requestedQuantity.clamp(0, listedQuantity).toInt();
  int get remainingQuantity => (listedQuantity - normalizedRequestedQuantity)
      .clamp(0, listedQuantity)
      .toInt();
  double get requestedQuantityPercent => listedQuantity <= 0
      ? 0
      : normalizedRequestedQuantity / listedQuantity * 100;
  double get remainingQuantityPercent =>
      listedQuantity <= 0 ? 0 : remainingQuantity / listedQuantity * 100;
  num get fullListingAskValue => askingUnitPrice * listedQuantity;
  num get requestedAskValue => askingUnitPrice * normalizedRequestedQuantity;
  num get offeredTotal => offeredUnitPrice * normalizedRequestedQuantity;
  num get remainingAskValue => askingUnitPrice * remainingQuantity;
  num get unitDifference => offeredUnitPrice - askingUnitPrice;
  num get requestedValueDifference => offeredTotal - requestedAskValue;
  double get priceDifferencePercent =>
      askingUnitPrice == 0 ? 0 : unitDifference / askingUnitPrice * 100;
  bool get valid =>
      listedQuantity > 0 &&
      normalizedRequestedQuantity > 0 &&
      requestedQuantity <= listedQuantity &&
      askingUnitPrice >= 0 &&
      offeredUnitPrice > 0;
}

class MarketplaceOfferAnalysisCard extends StatelessWidget {
  const MarketplaceOfferAnalysisCard({
    super.key,
    required this.analysis,
    this.unitLabel = 'pieces',
  });

  final MarketplaceOfferAnalysis analysis;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final difference = analysis.requestedValueDifference;
    final differenceColor = difference < 0
        ? PipeBuyerColors.danger
        : difference > 0
            ? PipeBuyerColors.success
            : PipeBuyerColors.success;
    final requestedPercent =
        analysis.requestedQuantityPercent.toStringAsFixed(1);
    final remainingPercent =
        analysis.remainingQuantityPercent.toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
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
                child: Text(
                  'Listing vs your offer',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _PercentPill(
                label: '$requestedPercent% requested',
                color: PipeBuyerColors.industrialBlue,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 460;
              final listing = _OfferSideCard(
                title: 'SELLER LISTING',
                accent: PipeBuyerColors.industrialBlue,
                rows: [
                  _MetricRow(
                    'Total quantity',
                    '${analysis.listedQuantity} $unitLabel',
                  ),
                  _MetricRow(
                    'Asking price',
                    '${marketplaceMoney(analysis.askingUnitPrice)} / $unitLabel',
                  ),
                  _MetricRow(
                    'Full listing value',
                    marketplaceMoney(analysis.fullListingAskValue),
                    strong: true,
                  ),
                ],
              );
              final offer = _OfferSideCard(
                title: 'YOUR OFFER',
                accent: PipeBuyerColors.orangePressed,
                rows: [
                  _MetricRow(
                    'Quantity requested',
                    '${analysis.normalizedRequestedQuantity} $unitLabel ($requestedPercent%)',
                  ),
                  _MetricRow(
                    'Offer price',
                    '${marketplaceMoney(analysis.offeredUnitPrice)} / $unitLabel',
                  ),
                  _MetricRow(
                    'Offer total',
                    marketplaceMoney(analysis.offeredTotal),
                    strong: true,
                  ),
                ],
              );
              if (!sideBySide) {
                return Column(
                  children: [listing, const SizedBox(height: 9), offer],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: listing),
                  const SizedBox(width: 9),
                  Expanded(child: offer),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: differenceColor.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: differenceColor.withValues(alpha: .22),
              ),
            ),
            child: Column(
              children: [
                _DenseComparisonRow(
                  label: 'Requested qty at seller ask',
                  value: marketplaceMoney(analysis.requestedAskValue),
                ),
                _DenseComparisonRow(
                  label: 'Your offer on requested qty',
                  value: marketplaceMoney(analysis.offeredTotal),
                  valueColor: differenceColor,
                  strong: true,
                ),
                const Divider(height: 16),
                _DenseComparisonRow(
                  label: 'Unit price difference',
                  value:
                      '${_signedMoney(analysis.unitDifference)} / $unitLabel  (${_signedPercent(analysis.priceDifferencePercent)})',
                  valueColor: differenceColor,
                ),
                _DenseComparisonRow(
                  label: 'Total difference on requested qty',
                  value: _signedMoney(analysis.requestedValueDifference),
                  valueColor: differenceColor,
                  strong: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: PipeBuyerColors.industrialBlue.withValues(alpha: .055),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: PipeBuyerColors.industrialBlue.withValues(alpha: .16),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final quantity = _InventoryMetric(
                  icon: Icons.inventory_2_outlined,
                  label: 'Remaining inventory',
                  value:
                      '${analysis.remainingQuantity} $unitLabel ($remainingPercent%)',
                );
                final value = _InventoryMetric(
                  icon: Icons.payments_outlined,
                  label: 'Remaining value at ask',
                  value: marketplaceMoney(analysis.remainingAskValue),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [quantity, const SizedBox(height: 7), value],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: quantity),
                    const SizedBox(width: 12),
                    Expanded(child: value),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MarketplaceOfferQuantityField extends StatelessWidget {
  const MarketplaceOfferQuantityField({
    super.key,
    required this.controller,
    required this.availableQuantity,
    required this.onChanged,
    this.unitLabel = 'pieces',
    this.errorText,
  });

  final TextEditingController controller;
  final int availableQuantity;
  final ValueChanged<String> onChanged;
  final String unitLabel;
  final String? errorText;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final fieldWidth = constraints.maxWidth >= 360
              ? 220.0
              : (constraints.maxWidth - 86).clamp(130.0, 220.0).toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity requested',
                        hintText: 'e.g. $availableQuantity',
                        errorText: errorText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.canvas,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD9E0E8)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unitLabel,
                        style: const TextStyle(
                          color: PipeBuyerColors.slate,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Available: $availableQuantity $unitLabel. Enter how many you want to purchase.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: PipeBuyerColors.muted,
                    ),
              ),
            ],
          );
        },
      );
}

enum MarketplaceOfferRequirementState { missing, complete, invalid }

class MarketplaceOfferRequirement {
  const MarketplaceOfferRequirement({
    required this.key,
    required this.label,
    required this.state,
    required this.icon,
    this.detail = '',
    this.onTap,
  });

  final String key;
  final String label;
  final MarketplaceOfferRequirementState state;
  final IconData icon;
  final String detail;
  final VoidCallback? onTap;

  bool get complete => state == MarketplaceOfferRequirementState.complete;
}

class MarketplaceOfferRequirementsPanel extends StatelessWidget {
  const MarketplaceOfferRequirementsPanel({
    super.key,
    required this.requirements,
  });

  final List<MarketplaceOfferRequirement> requirements;

  @override
  Widget build(BuildContext context) {
    final missing = requirements.where((item) => !item.complete).toList();
    final complete = missing.isEmpty;
    final accent =
        complete ? PipeBuyerColors.success : PipeBuyerColors.orangePressed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete ? Icons.task_alt_rounded : Icons.checklist_rounded,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  complete
                      ? 'Offer ready to submit'
                      : '${missing.length} required item${missing.length == 1 ? '' : 's'} remaining',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (!complete) ...[
            const SizedBox(height: 8),
            for (final requirement in missing)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: requirement.onTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          requirement.state ==
                                  MarketplaceOfferRequirementState.invalid
                              ? Icons.error_outline
                              : requirement.icon,
                          size: 18,
                          color: requirement.state ==
                                  MarketplaceOfferRequirementState.invalid
                              ? PipeBuyerColors.danger
                              : PipeBuyerColors.orangePressed,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                requirement.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (requirement.detail.isNotEmpty)
                                Text(
                                  requirement.detail,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        if (requirement.onTap != null)
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class MarketplaceOfferDateField extends StatelessWidget {
  const MarketplaceOfferDateField({
    super.key,
    required this.step,
    required this.label,
    required this.icon,
    required this.value,
    required this.onPressed,
    this.required = true,
  });

  final int step;
  final String label;
  final IconData icon;
  final DateTime? value;
  final VoidCallback onPressed;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final complete = value != null;
    final accent =
        complete ? PipeBuyerColors.success : PipeBuyerColors.orangePressed;
    return Material(
      color: complete
          ? PipeBuyerColors.success.withValues(alpha: .065)
          : PipeBuyerColors.orange.withValues(alpha: .04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: accent.withValues(alpha: complete ? .42 : .28),
          width: complete ? 1.5 : 1.1,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: complete
                      ? const Icon(
                          Icons.check_rounded,
                          color: PipeBuyerColors.success,
                          size: 21,
                        )
                      : Text(
                          '$step',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      complete
                          ? _formatDate(value!)
                          : required
                              ? 'Required — select a date'
                              : 'Optional — select a date',
                      style: TextStyle(
                        color: complete
                            ? PipeBuyerColors.success
                            : PipeBuyerColors.muted,
                        fontSize: 11,
                        fontWeight:
                            complete ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                complete ? Icons.verified_rounded : Icons.chevron_right_rounded,
                color: accent,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferSideCard extends StatelessWidget {
  const _OfferSideCard({
    required this.title,
    required this.accent,
    required this.rows,
  });

  final String title;
  final Color accent;
  final List<_MetricRow> rows;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .045),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: .14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: accent,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 7),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: _DenseComparisonRow(
                  label: row.label,
                  value: row.value,
                  strong: row.strong,
                ),
              ),
          ],
        ),
      );
}

class _MetricRow {
  const _MetricRow(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
}

class _DenseComparisonRow extends StatelessWidget {
  const _DenseComparisonRow({
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
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  color: PipeBuyerColors.slate,
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
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}

class _PercentPill extends StatelessWidget {
  const _PercentPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .18)),
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

class _InventoryMetric extends StatelessWidget {
  const _InventoryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: PipeBuyerColors.industrialBlue),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: PipeBuyerColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

String _signedMoney(num value) {
  if (value == 0) return marketplaceMoney(0);
  return '${value > 0 ? '+' : '-'}${marketplaceMoney(value.abs())}';
}

String _signedPercent(double value) =>
    '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}%';

String _formatDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
