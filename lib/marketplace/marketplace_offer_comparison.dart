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
    this.maxRecords = 20,
  });

  final String listingId;
  final String sellerUid;
  final num? askingPrice;
  final int? availableQuantity;
  final int maxRecords;

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
          .limit(maxRecords)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final rawRows = snapshot.data!.docs
            .map(
              (doc) => _OfferComparisonRow.from(
                doc.id,
                doc.data(),
                askingPrice,
              ),
            )
            .toList(growable: false);
        final rows = isSeller ? _latestOfferPerBuyer(rawRows) : rawRows;
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
                  const Icon(
                    Icons.table_chart_outlined,
                    size: 19,
                    color: PipeBuyerColors.industrialBlue,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      isSeller
                          ? 'Current offers — compare side by side'
                          : 'Your offer history',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    isSeller
                        ? '${rows.length} buyer${rows.length == 1 ? '' : 's'}'
                        : '${rows.length} offer${rows.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (isSeller) ...[
                const SizedBox(height: 3),
                Text(
                  'Latest offer from each buyer is shown here. Detailed revisions remain available below.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: PipeBuyerColors.muted,
                      ),
                ),
              ],
              const SizedBox(height: 9),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 650) {
                    return _DesktopOfferTable(
                      rows: rows,
                      showBuyer: isSeller,
                      askingPrice: askingPrice,
                      availableQuantity: availableQuantity,
                    );
                  }
                  return Column(
                    children: [
                      for (var index = 0; index < rows.length; index++) ...[
                        _CompactOfferCard(
                          row: rows[index],
                          showBuyer: isSeller,
                          askingPrice: askingPrice,
                          availableQuantity: availableQuantity,
                        ),
                        if (index < rows.length - 1)
                          const SizedBox(height: 7),
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

class MarketplaceConversationOfferSummary extends StatelessWidget {
  const MarketplaceConversationOfferSummary({
    super.key,
    required this.listingId,
    required this.sellerUid,
    required this.currentPrice,
    required this.currentQuantity,
    required this.basis,
    required this.onOpenOffers,
    this.askingPrice,
    this.availableQuantity,
  });

  final String listingId;
  final String sellerUid;
  final num? askingPrice;
  final int? availableQuantity;
  final num? currentPrice;
  final int? currentQuantity;
  final String basis;
  final VoidCallback onOpenOffers;

  @override
  Widget build(BuildContext context) {
    final total = currentPrice == null || currentQuantity == null
        ? null
        : currentPrice! * currentQuantity!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.orangeSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.handshake_outlined,
                    color: PipeBuyerColors.orangePressed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Deal offer',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (currentQuantity != null)
                        _InlineMetric('Qty', '$currentQuantity'),
                      if (currentPrice != null)
                        _InlineMetric(
                          'Offer',
                          '${marketplaceMoney(currentPrice!)}${basis.isEmpty ? '' : ' • $basis'}',
                        ),
                      if (total != null)
                        _InlineMetric('Total', marketplaceMoney(total)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onOpenOffers,
                  icon: const Icon(Icons.table_rows_outlined, size: 17),
                  label: const Text('Compare offers'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MarketplaceOfferComparisonSummary(
              listingId: listingId,
              sellerUid: sellerUid,
              askingPrice: askingPrice,
              availableQuantity: availableQuantity,
              maxRecords: 12,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopOfferTable extends StatelessWidget {
  const _DesktopOfferTable({
    required this.rows,
    required this.showBuyer,
    required this.askingPrice,
    required this.availableQuantity,
  });

  final List<_OfferComparisonRow> rows;
  final bool showBuyer;
  final num? askingPrice;
  final int? availableQuantity;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 34,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 44,
          horizontalMargin: 8,
          columnSpacing: 18,
          columns: [
            if (showBuyer) const DataColumn(label: Text('BUYER')),
            const DataColumn(label: Text('QTY'), numeric: true),
            const DataColumn(label: Text('ASK'), numeric: true),
            const DataColumn(label: Text('OFFER'), numeric: true),
            const DataColumn(label: Text('TOTAL'), numeric: true),
            const DataColumn(label: Text('VS ASK'), numeric: true),
            const DataColumn(label: Text('STATUS')),
          ],
          rows: rows
              .map(
                (row) => DataRow(
                  color: WidgetStatePropertyAll(
                    _statusBackground(row.status),
                  ),
                  cells: [
                    if (showBuyer)
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: Text(
                            row.buyerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    DataCell(
                      Text(
                        _quantityText(row.quantity, availableQuantity),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(Text(
                      askingPrice == null
                          ? '—'
                          : marketplaceMoney(askingPrice!),
                    )),
                    DataCell(
                      Text(
                        marketplaceMoney(row.unitPrice),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    DataCell(
                      Text(
                        marketplaceMoney(row.total),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    DataCell(
                      Text(
                        _signedPercent(row.askDifferencePercent),
                        style: TextStyle(
                          color: _differenceColor(row.askDifferencePercent),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    DataCell(_OfferStatusPill(status: row.status)),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      );
}

class _CompactOfferCard extends StatelessWidget {
  const _CompactOfferCard({
    required this.row,
    required this.showBuyer,
    required this.askingPrice,
    required this.availableQuantity,
  });

  final _OfferComparisonRow row;
  final bool showBuyer;
  final num? askingPrice;
  final int? availableQuantity;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _statusBackground(row.status),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE3E8EF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    showBuyer ? row.buyerName : 'Your offer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                _OfferStatusPill(status: row.status),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 14,
              runSpacing: 5,
              children: [
                _InlineMetric(
                  'Qty',
                  _quantityText(row.quantity, availableQuantity),
                ),
                if (askingPrice != null)
                  _InlineMetric('Ask', marketplaceMoney(askingPrice!)),
                _InlineMetric('Offer', marketplaceMoney(row.unitPrice)),
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
          Text(
            '$label: ',
            style: const TextStyle(color: PipeBuyerColors.muted),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
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
    required this.buyerUid,
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
      buyerUid: '${data['buyerUid'] ?? ''}',
      buyerName: '${data['buyerDisplayName'] ?? 'Marketplace buyer'}',
      quantity: quantity,
      unitPrice: unit,
      total: total,
      askDifferencePercent: difference,
      status: '${data['status'] ?? 'pending'}',
    );
  }

  final String id;
  final String buyerUid;
  final String buyerName;
  final int quantity;
  final num unitPrice;
  final num total;
  final double askDifferencePercent;
  final String status;
}

List<_OfferComparisonRow> _latestOfferPerBuyer(
  List<_OfferComparisonRow> rows,
) {
  final seen = <String>{};
  final latest = <_OfferComparisonRow>[];
  for (final row in rows) {
    final key = row.buyerUid.isEmpty ? row.id : row.buyerUid;
    if (seen.add(key)) latest.add(row);
  }
  return latest;
}

String _quantityText(int quantity, int? available) {
  if (available == null || available <= 0) return '$quantity';
  final percent = quantity / available * 100;
  return '$quantity / $available (${percent.toStringAsFixed(1)}%)';
}

String _signedPercent(double value) =>
    '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)}%';

Color _differenceColor(double value) => value < 0
    ? PipeBuyerColors.danger
    : value > 0
        ? PipeBuyerColors.success
        : PipeBuyerColors.industrialBlue;

Color _statusBackground(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized == 'accepted' || normalized == 'completed') {
    return PipeBuyerColors.success.withValues(alpha: .045);
  }
  if (normalized == 'declined' ||
      normalized == 'cancelled' ||
      normalized == 'disputed') {
    return PipeBuyerColors.danger.withValues(alpha: .035);
  }
  if (normalized == 'countered' || normalized == 'counter') {
    return PipeBuyerColors.industrialBlue.withValues(alpha: .04);
  }
  return Colors.white;
}
