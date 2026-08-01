import 'package:flutter/material.dart';
import '../core/accessibility/pipe_status_feedback.dart';

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
    this.sellerFeeRate = 0.025, // 2.5% Platform Seller Fee
    this.escrowFeeRate = 0.010, // 1.0% Escrow Protection Fee
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0878E8).withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long, color: Color(0xFF0878E8)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PIPE BUYER INVOICE',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Text(
                            'ID: ${invoice.invoiceId}',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: invoice.status == 'Paid' ? Colors.green.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: invoice.status == 'Paid' ? Colors.green.shade300 : Colors.amber.shade400,
                      ),
                    ),
                    child: Text(
                      invoice.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: invoice.status == 'Paid' ? Colors.green.shade800 : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Seller & Buyer Details
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ISSUED BY (SELLER)', style: _metaHeaderStyle),
                        const SizedBox(height: 4),
                        Text(invoice.sellerName, style: _metaBodyStyle),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BILLED TO (BUYER)', style: _metaHeaderStyle),
                        const SizedBox(height: 4),
                        Text(invoice.buyerName, style: _metaBodyStyle),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ISSUE DATE', style: _metaHeaderStyle),
                        const SizedBox(height: 4),
                        Text(_formatDate(invoice.issueDate), style: _metaBodyStyle),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PAYMENT DUE DATE', style: _metaHeaderStyle),
                        const SizedBox(height: 4),
                        Text(_formatDate(invoice.dueDate), style: _metaBodyStyle),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Itemized Breakdown Table
              Text('ITEMIZED SUMMARY', style: _metaHeaderStyle),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _itemRow(
                      invoice.listingTitle,
                      '${invoice.quantity} ${invoice.unitLabel} × \$${invoice.unitPrice.toStringAsFixed(2)}',
                      '\$${invoice.subtotal.toStringAsFixed(2)}',
                      isBoldTitle: true,
                    ),
                    const Divider(height: 20),
                    _itemRow(
                      'Escrow Protection Fee (1.0%)',
                      'Secure funds custody & inspection hold',
                      '\$${invoice.escrowProtectionFee.toStringAsFixed(2)}',
                    ),
                    if (invoice.freightCharge > 0) ...[
                      const SizedBox(height: 8),
                      _itemRow(
                        'Freight & Delivery Dispatch',
                        'Carrier transit charge',
                        '\$${invoice.freightCharge.toStringAsFixed(2)}',
                      ),
                    ],
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL AMOUNT DUE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '\$${invoice.totalDue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Color(0xFF0878E8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Actions Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        PipeFeedback.show(
                          context,
                          message: 'Redirecting to Instant Payment & Wire Transfer gateway…',
                          tone: PipeStatusTone.success,
                        );
                      },
                      icon: const Icon(Icons.payment),
                      label: const Text('Pay Now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const TextStyle _metaHeaderStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: Colors.grey,
    letterSpacing: 0.8,
  );

  static const TextStyle _metaBodyStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  Widget _itemRow(String title, String subtitle, String price, {bool isBoldTitle = false}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: isBoldTitle ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Text(
          price,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isBoldTitle ? Colors.black87 : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
