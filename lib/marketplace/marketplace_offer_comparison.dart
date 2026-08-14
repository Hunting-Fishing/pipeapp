import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_money.dart';

class MarketplaceOfferComparisonSummary extends StatelessWidget {
  const MarketplaceOfferComparisonSummary({
    super.key,
    required this.listingId,
    required this.sellerUid,
    this.askingPrice,
    this.availableQuantity,
  });

  final String listingId;
  final String sellerUid;
  final num? askingPrice;
  final int? availableQuantity;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || listingId.isEmpty) return const SizedBox.shrink();
    final isSeller = uid == sellerUid;
    final roleField = isSeller ? 'sellerUid' : 'buyerUid';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('listingId', isEqualTo: listingId)
          .where(roleField, isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final rows = snapshot.data!.docs
            .map((doc) => _OfferComparisonRow.from(doc.id, doc.data(), askingPrice))
            .toList(growable: false);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.table_chart_outlined,
                      size: 19, color: PipeBuyerColors.industrialBlue),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      isSeller ? 'Offer comparison' : 'Your offer history',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    '${rows.length} record${rows.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 640) {
                    return _DesktopOfferTable(
                      rows: rows,
                      showBuyer: isSeller,
                      availableQuantity: availableQuantity,
                    );
                  }
                  return Column(
                    children: [
                      for (var index = 0; index < rows.length; index++) ...[
                        _CompactOfferCard(
                          row: rows[index],
                          showBuyer: isSeller,
                          availableQuantity: availableQuantity,
                        ),
                        if (index < rows.length - 1) const SizedBox(height: 7),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopOfferTable extends StatelessWidget {
  const _DesktopOfferTable({
    required this.rows,
    required this.showBuyer,
    required this.availableQuantity,
  });

  final List<_OfferComparisonRow> rows;
  final bool showBuyer;
  final int? availableQuantity;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 34,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 46,
          horizontalMargin: 8,
          columnSpacing: 22,
          columns: [
            if (showBuyer) const DataColumn(label: Text('BUYER')),
            const DataColumn(label: Text('QTY'), numeric: true),
            const DataColumn(label: Text('UNIT PRICE'), numeric: true),
            const DataColumn(label: Text('TOTAL'), numeric: true),
            const DataColumn(label: Text('VS ASK'), numeric: true),
            const DataColumn(label: Text('STATUS')),
          ],
          rows: rows
              .map((row) => DataRow(cells: [
                    if (showBuyer)
                      DataCell(SizedBox(
                        width: 145,
                        child: Text(
                          row.buyerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      )),
                    DataCell(Text(_quantityText(row.quantity, availableQuantity))),
                    DataCell(Text(marketplaceMoney(row.unitPrice))),
                    DataCell(Text(marketplaceMoney(row.total))),
                    DataCell(Text(
                      _signedPercent(row.askDifferencePercent),
                      style: TextStyle(
                        color: _differenceColor(row.askDifferencePercent),
                        fontWeight: FontWeight.w900,
                      ),
                    )),
                    DataCell(_OfferStatusPill(status: row.status)),
                  ]))
              .toList(growable: false),
        ),
      );
}

class _CompactOfferCard extends StatelessWidget {
  const _CompactOfferCard({
    required this.row,
    required this.showBuyer,
    required this.availableQuantity,
  });

  final _OfferComparisonRow row;
  final bool showBuyer;
  final int? availableQuantity;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: PipeBuyerColors.canvas,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (showBuyer)
                  Expanded(
                    child: Text(
                      row.buyerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  )
                else
                  const Expanded(
                    child: Text('Your offer',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                _OfferStatusPill(status: row.status),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 14,
              runSpacing: 5,
              children: [
                _InlineMetric('Qty', _quantityText(row.quantity, availableQuantity)),
                _InlineMetric('Unit', marketplaceMoney(row.unitPrice)),
                _InlineMetric('Total', marketplaceMoney(row.total)),
                _InlineMetric(
                  'Vs ask',
                  _signedPercent(row.askDifferencePercent),
                  color: _differenceColor(row.askDifferencePercent),
                ),
              ],
            ),
          ],
        ),
      );
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: PipeBuyerColors.muted)),
          Text(value,
              style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        ],
      );
}

class _OfferStatusPill extends StatelessWidget {
  const _OfferStatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final color = switch (normalized) {
      'accepted' || 'completed' => PipeBuyerColors.success,
      'declined' || 'cancelled' || 'disputed' => PipeBuyerColors.danger,
      'countered' || 'counter' => PipeBuyerColors.industrialBlue,
      _ => PipeBuyerColors.orangePressed,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Text(
        normalized.isEmpty ? 'pending' : normalized.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _OfferComparisonRow {
  const _OfferComparisonRow({
    required this.id,
    required this.buyerName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.askDifferencePercent,
    required this.status,
  });

  factory _OfferComparisonRow.from(
    String id,
    Map<String, dynamic> data,
    num? askingPrice,
  ) {
    final quantity = (data['requestedQuantity'] as num?)?.toInt() ?? 0;
    final unit = data['offeredUnitPrice'] as num? ?? 0;
    final total = data['offeredTotal'] as num? ?? unit * quantity;
    final difference = askingPrice == null || askingPrice == 0
        ? 0.0
        : ((unit - askingPrice) / askingPrice * 100).toDouble();
    return _OfferComparisonRow(
      id: id,
      buyerName: '${data['buyerDisplayName'] ?? 'Marketplace buyer'}',
      quantity: quantity,
      unitPrice: unit,
      total: total,
      askDifferencePercent: difference,
      status: '${data['status'] ?? 'pending'}',
    );
  }

  final String id;
  final String buyerName;
  final int quantity;
  final num unitPrice;
  final num total;
  final double askDifferencePercent;
  final String status;
}

String _quantityText(int quantity, int? available) {
  if (available == null || available <= 0) return '$quantity';
  final percent = quantity / available * 100;
  return '$quantity / $available (${percent.toStringAsFixed(0)}%)';
}

String _signedPercent(double value) =>
    '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}%';

Color _differenceColor(double value) => value < 0
    ? PipeBuyerColors.danger
    : value > 0
        ? PipeBuyerColors.success
        : PipeBuyerColors.industrialBlue;
