import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';

class MarketplaceInvoice {
  const MarketplaceInvoice({
    required this.invoiceId,
    required this.listingTitle,
    required this.sellerName,
    required this.buyerName,
    required this.unitPrice,
    required this.quantity,
    required this.unitLabel,
    this.freightCharge = 0.0,
    this.sellerFeeRate = 0.025,
    this.escrowFeeRate = 0.010,
    required this.issueDate,
    required this.dueDate,
    this.status = 'Unpaid',
  });

  final String invoiceId;
  final String listingTitle;
  final String sellerName;
  final String buyerName;
  final double unitPrice;
  final int quantity;
  final String unitLabel;
  final double freightCharge;
  final double sellerFeeRate;
  final double escrowFeeRate;
  final DateTime issueDate;
  final DateTime dueDate;
  final String status;

  double get subtotal => unitPrice * quantity;
  double get sellerCommissionFee => subtotal * sellerFeeRate;
  double get escrowProtectionFee => subtotal * escrowFeeRate;
  double get totalDue => subtotal + escrowProtectionFee + freightCharge;

  Map<String, dynamic> toJson() => {
        'invoiceId': invoiceId,
        'listingTitle': listingTitle,
        'sellerName': sellerName,
        'buyerName': buyerName,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'unitLabel': unitLabel,
        'subtotal': subtotal,
        'sellerCommissionFee': sellerCommissionFee,
        'escrowProtectionFee': escrowProtectionFee,
        'freightCharge': freightCharge,
        'totalDue': totalDue,
        'issueDate': issueDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'status': status,
      };
}

class MarketplaceInvoiceDialog extends StatelessWidget {
  const MarketplaceInvoiceDialog({super.key, required this.invoice});

  final MarketplaceInvoice invoice;

  bool get _paid => invoice.status.trim().toLowerCase() == 'paid';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _invoiceHeader(context),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  final seller = _MetaField(
                    label: 'ISSUED BY (SELLER)',
                    value: invoice.sellerName,
                    icon: Icons.storefront_outlined,
                  );
                  final buyer = _MetaField(
                    label: 'BILLED TO (BUYER)',
                    value: invoice.buyerName,
                    icon: Icons.person_outline,
                  );
                  if (compact) {
                    return Column(
                      children: [seller, const SizedBox(height: 8), buyer],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: seller),
                      const SizedBox(width: 8),
                      Expanded(child: buyer),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  final issue = _MetaField(
                    label: 'ISSUE DATE',
                    value: _formatDate(invoice.issueDate),
                    icon: Icons.event_note_outlined,
                  );
                  final due = _MetaField(
                    label: 'PAYMENT DUE DATE',
                    value: _formatDate(invoice.dueDate),
                    icon: Icons.event_busy_outlined,
                  );
                  if (compact) {
                    return Column(
                      children: [issue, const SizedBox(height: 8), due],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: issue),
                      const SizedBox(width: 8),
                      Expanded(child: due),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              PipeBuyerSectionCard(
                title: 'Itemized summary',
                subtitle:
                    'Buyer-facing amount due for this marketplace transaction.',
                leading: const _SectionIcon(
                  Icons.receipt_long_outlined,
                  tone: PipeBuyerStatusTone.info,
                ),
                child: Column(
                  children: [
                    _itemRow(
                      context,
                      invoice.listingTitle,
                      '${invoice.quantity} ${invoice.unitLabel} × \$${invoice.unitPrice.toStringAsFixed(2)}',
                      '\$${invoice.subtotal.toStringAsFixed(2)}',
                      isBoldTitle: true,
                    ),
                    const Divider(height: 24),
                    _itemRow(
                      context,
                      'Escrow Protection Fee (${(invoice.escrowFeeRate * 100).toStringAsFixed(1)}%)',
                      'Secure funds custody & inspection hold',
                      '\$${invoice.escrowProtectionFee.toStringAsFixed(2)}',
                    ),
                    if (invoice.freightCharge > 0) ...[
                      const SizedBox(height: 10),
                      _itemRow(
                        context,
                        'Freight & Delivery Dispatch',
                        'Carrier transit charge',
                        '\$${invoice.freightCharge.toStringAsFixed(2)}',
                      ),
                    ],
                    const Divider(height: 26),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.orangeSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              PipeBuyerColors.orange.withValues(alpha: .18),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'TOTAL AMOUNT DUE',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '\$${invoice.totalDue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 23,
                              color: PipeBuyerColors.orangePressed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: PipeBuyerColors.industrialBlue.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: PipeBuyerColors.industrialBlue.withValues(alpha: .16),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: PipeBuyerColors.industrialBlue,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Seller marketplace commission is accounted for separately from the buyer-facing amount due shown on this invoice.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 480;
                  final close = OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  );
                  final pay = FilledButton.icon(
                    onPressed: _paid
                        ? null
                        : () {
                            PipeFeedback.show(
                              context,
                              message:
                                  'Redirecting to Instant Payment & Wire Transfer gateway…',
                              tone: PipeStatusTone.success,
                            );
                          },
                    icon: Icon(
                      _paid ? Icons.check_circle_outline : Icons.payment,
                    ),
                    label: Text(_paid ? 'Paid' : 'Pay Now'),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [pay, const SizedBox(height: 8), close],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: close),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: pay),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _invoiceHeader(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: PipeBuyerColors.orange.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: PipeBuyerColors.orange,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PIPE BUYER INVOICE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    'ID: ${invoice.invoiceId}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            PipeBuyerStatusBadge(
              label: invoice.status.toUpperCase(),
              icon: _paid
                  ? Icons.check_circle_outline
                  : Icons.schedule_outlined,
              tone: _paid
                  ? PipeBuyerStatusTone.success
                  : PipeBuyerStatusTone.warning,
            ),
          ],
        ),
      );

  Widget _itemRow(
    BuildContext context,
    String title,
    String subtitle,
    String price, {
    bool isBoldTitle = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight:
                      isBoldTitle ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .58),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          price,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: isBoldTitle
                ? Theme.of(context).colorScheme.onSurface
                : PipeBuyerColors.slate,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _MetaField extends StatelessWidget {
  const _MetaField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: PipeBuyerColors.orangeSoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 18,
                color: PipeBuyerColors.orangePressed,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: .52),
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon(this.icon, {required this.tone});

  final IconData icon;
  final PipeBuyerStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = pipeBuyerToneColor(tone);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }
}
