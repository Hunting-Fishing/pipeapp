import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';

class MarketplaceInvoice {
  const MarketplaceInvoice._({
    required this.transactionId,
    required this.listingTitle,
    required this.sellerName,
    required this.buyerName,
    required this.currency,
    required this.grossSaleMinor,
    required this.marketplaceFeeMinor,
    required this.sellerProceedsBeforeTaxMinor,
    required this.feePayer,
    required this.feeScheduleRevision,
    required this.paymentProviderStatus,
    required this.sellerPayoutStatus,
  });

  factory MarketplaceInvoice.fromMarketplaceTransaction({
    required String transactionId,
    required Map<String, dynamic> transaction,
    String sellerName = 'Seller',
    String buyerName = 'Successful buyer',
  }) {
    final rawSnapshot = transaction['marketplaceFeeSnapshot'];
    if (rawSnapshot is! Map) {
      throw const FormatException(
        'A server marketplace fee snapshot is required.',
      );
    }
    final snapshot = Map<String, dynamic>.from(rawSnapshot);
    if ('${snapshot['source'] ?? ''}'.trim() != 'server_fee_policy') {
      throw const FormatException(
        'The marketplace fee snapshot is not server verified.',
      );
    }

    final grossSaleMinor = _requiredMinor(snapshot, 'agreedTotalMinor');
    final marketplaceFeeMinor = _requiredMinor(
      snapshot,
      'marketplaceFeeMinor',
    );
    final sellerProceedsBeforeTaxMinor = _requiredMinor(
      snapshot,
      'sellerProceedsBeforeTaxMinor',
    );
    if (marketplaceFeeMinor > grossSaleMinor ||
        sellerProceedsBeforeTaxMinor != grossSaleMinor - marketplaceFeeMinor) {
      throw const FormatException(
        'The server marketplace fee snapshot is internally inconsistent.',
      );
    }

    final currency = '${snapshot['currency'] ?? transaction['currency'] ?? ''}'
        .trim()
        .toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const FormatException(
        'The server marketplace fee snapshot has no valid currency.',
      );
    }
    final feeScheduleRevision = '${snapshot['scheduleRevision'] ?? ''}'.trim();
    if (feeScheduleRevision.isEmpty) {
      throw const FormatException(
        'The server marketplace fee snapshot has no schedule revision.',
      );
    }

    return MarketplaceInvoice._(
      transactionId: transactionId.trim(),
      listingTitle:
          '${transaction['listingTitle'] ?? 'Marketplace sale'}'.trim(),
      sellerName: sellerName.trim().isEmpty ? 'Seller' : sellerName.trim(),
      buyerName:
          buyerName.trim().isEmpty ? 'Successful buyer' : buyerName.trim(),
      currency: currency,
      grossSaleMinor: grossSaleMinor,
      marketplaceFeeMinor: marketplaceFeeMinor,
      sellerProceedsBeforeTaxMinor: sellerProceedsBeforeTaxMinor,
      feePayer: '${snapshot['feePayer'] ?? 'seller'}'.trim().toLowerCase(),
      feeScheduleRevision: feeScheduleRevision,
      paymentProviderStatus:
          '${transaction['paymentProviderStatus'] ?? 'not_started'}'
              .trim()
              .toLowerCase(),
      sellerPayoutStatus:
          '${transaction['sellerPayoutStatus'] ?? 'not_released'}'
              .trim()
              .toLowerCase(),
    );
  }

  final String transactionId;
  final String listingTitle;
  final String sellerName;
  final String buyerName;
  final String currency;
  final int grossSaleMinor;
  final int marketplaceFeeMinor;
  final int sellerProceedsBeforeTaxMinor;
  final String feePayer;
  final String feeScheduleRevision;
  final String paymentProviderStatus;
  final String sellerPayoutStatus;

  bool get paid => paymentProviderStatus == 'paid';

  String get paymentProviderStatusLabel =>
      _statusLabel(paymentProviderStatus, fallback: 'Not started');

  String get sellerPayoutStatusLabel =>
      _statusLabel(sellerPayoutStatus, fallback: 'Not released');

  String money(int amountMinor) => NumberFormat.currency(
        locale: 'en_US',
        name: currency,
        symbol: '$currency ',
        decimalDigits: 2,
      ).format(amountMinor / 100);

  Map<String, dynamic> toJson() => {
        'transactionId': transactionId,
        'listingTitle': listingTitle,
        'sellerName': sellerName,
        'buyerName': buyerName,
        'currency': currency,
        'grossSaleMinor': grossSaleMinor,
        'marketplaceFeeMinor': marketplaceFeeMinor,
        'sellerProceedsBeforeTaxMinor': sellerProceedsBeforeTaxMinor,
        'feePayer': feePayer,
        'feeScheduleRevision': feeScheduleRevision,
        'paymentProviderStatus': paymentProviderStatus,
        'sellerPayoutStatus': sellerPayoutStatus,
      };

  static int _requiredMinor(Map<String, dynamic> snapshot, String field) {
    final value = snapshot[field];
    if (value is! num ||
        !value.isFinite ||
        value < 0 ||
        value.roundToDouble() != value.toDouble()) {
      throw FormatException(
          'The server marketplace fee snapshot has no $field.');
    }
    return value.toInt();
  }

  static String _statusLabel(String value, {required String fallback}) {
    if (value.isEmpty) return fallback;
    return switch (value) {
      'not_started' => 'Not started',
      'checkout_created' => 'Checkout ready',
      'processing' => 'Processing',
      'paid' => 'Paid',
      'failed' => 'Failed',
      'external_agreed' => 'External settlement agreed',
      'partially_refunded' => 'Partially refunded',
      'refunded' => 'Refunded',
      'pending_release' => 'Pending release',
      'released' => 'Released',
      'blocked_seller_not_ready' => 'Seller setup required',
      'blocked_financial_hold' => 'Financial hold',
      'not_released' => 'Not released',
      _ => value
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' '),
    };
  }
}

class MarketplaceInvoiceDialog extends StatelessWidget {
  const MarketplaceInvoiceDialog({super.key, required this.invoice});

  final MarketplaceInvoice invoice;

  PipeBuyerStatusTone get _paymentTone =>
      switch (invoice.paymentProviderStatus) {
        'paid' => PipeBuyerStatusTone.success,
        'processing' || 'checkout_created' => PipeBuyerStatusTone.info,
        'failed' ||
        'refunded' ||
        'partially_refunded' =>
          PipeBuyerStatusTone.warning,
        _ => PipeBuyerStatusTone.neutral,
      };

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
              _recordHeader(context),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  final seller = _MetaField(
                    label: 'SELLER',
                    value: invoice.sellerName,
                    icon: Icons.storefront_outlined,
                  );
                  final buyer = _MetaField(
                    label: 'SUCCESSFUL BUYER',
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
              const SizedBox(height: 16),
              PipeBuyerSectionCard(
                title: 'Server-verified sale breakdown',
                subtitle:
                    'Amounts come from the immutable marketplace fee snapshot.',
                leading: const _SectionIcon(
                  Icons.receipt_long_outlined,
                  tone: PipeBuyerStatusTone.info,
                ),
                child: Column(
                  children: [
                    _itemRow(
                      context,
                      'Gross sale',
                      invoice.listingTitle,
                      invoice.money(invoice.grossSaleMinor),
                      isBoldTitle: true,
                    ),
                    const SizedBox(height: 10),
                    _itemRow(
                      context,
                      invoice.feePayer == 'seller'
                          ? 'Pipe Buyer seller fee'
                          : 'Pipe Buyer marketplace fee',
                      'Fee schedule ${invoice.feeScheduleRevision}',
                      '-${invoice.money(invoice.marketplaceFeeMinor)}',
                    ),
                    const Divider(height: 26),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.orangeSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: PipeBuyerColors.orange.withValues(alpha: .18),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'SELLER PROCEEDS BEFORE TAX',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            invoice.money(
                              invoice.sellerProceedsBeforeTaxMinor,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 21,
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  final payment = _MetaField(
                    label: 'PAYMENT PROVIDER STATUS',
                    value: invoice.paymentProviderStatusLabel,
                    icon: Icons.payments_outlined,
                  );
                  final payout = _MetaField(
                    label: 'SELLER PAYOUT STATUS',
                    value: invoice.sellerPayoutStatusLabel,
                    icon: Icons.account_balance_outlined,
                  );
                  if (compact) {
                    return Column(
                      children: [payment, const SizedBox(height: 8), payout],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: payment),
                      const SizedBox(width: 8),
                      Expanded(child: payout),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: PipeBuyerColors.industrialBlue.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        PipeBuyerColors.industrialBlue.withValues(alpha: .16),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 20,
                      color: PipeBuyerColors.industrialBlue,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'This record explains the server-approved sale and fee. It does not create a charge, move funds, or represent an escrow or trust account.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordHeader(BuildContext context) => Container(
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
                    'PIPE BUYER SALE RECORD',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    'Transaction: ${invoice.transactionId}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            PipeBuyerStatusBadge(
              label: invoice.paymentProviderStatusLabel.toUpperCase(),
              icon: invoice.paid
                  ? Icons.check_circle_outline
                  : Icons.schedule_outlined,
              tone: _paymentTone,
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
                  fontWeight: isBoldTitle ? FontWeight.w900 : FontWeight.w700,
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
