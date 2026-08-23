import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';

class MarketplaceDispatchSubscriptionAdminPanel extends StatefulWidget {
  const MarketplaceDispatchSubscriptionAdminPanel({super.key});

  @override
  State<MarketplaceDispatchSubscriptionAdminPanel> createState() =>
      _MarketplaceDispatchSubscriptionAdminPanelState();
}

class _MarketplaceDispatchSubscriptionAdminPanelState
    extends State<MarketplaceDispatchSubscriptionAdminPanel> {
  final MarketplaceCommandClient _commands = MarketplaceCommandClient();
  List<_DispatchInvoiceSummary> _invoices = const [];
  final Set<String> _reconciling = <String>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await _commands.execute(
        'getDispatchSubscriptionReconciliationQueue',
        const <String, Object?>{},
      );
      final raw = result['invoices'];
      final invoices = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => _DispatchInvoiceSummary.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const <_DispatchInvoiceSummary>[];
      if (!mounted) return;
      setState(() => _invoices = invoices);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Dispatch invoice reconciliation queue could not be loaded.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reconcile(String invoiceId) async {
    if (_reconciling.contains(invoiceId)) return;
    setState(() {
      _reconciling.add(invoiceId);
      _error = null;
    });
    try {
      await _commands.execute(
        'reconcileDispatchSubscriptionInvoice',
        <String, Object?>{'invoiceId': invoiceId},
        timeout: const Duration(seconds: 45),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'This Dispatch invoice could not be reconciled.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _reconciling.remove(invoiceId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: PipeBuyerColors.industrialBlue,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dispatch subscription reconciliation',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Stripe Invoice → InvoicePayment → PaymentIntent → Charge → Balance Transaction',
                      style: TextStyle(
                        color: PipeBuyerColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh Dispatch invoices',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PipeBuyerColors.danger.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: PipeBuyerColors.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_invoices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: PipeBuyerColors.muted,
                    size: 34,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No paid Dispatch subscription invoices yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'This is expected before the controlled Monthly/Yearly acceptance payments are completed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PipeBuyerColors.muted),
                  ),
                ],
              ),
            )
          else
            ..._invoices.take(20).map(
                  (invoice) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _InvoiceCard(
                      invoice: invoice,
                      reconciling: _reconciling.contains(invoice.invoiceId),
                      onReconcile: () => _reconcile(invoice.invoiceId),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _DispatchInvoiceSummary {
  const _DispatchInvoiceSummary({
    required this.invoiceId,
    required this.uid,
    required this.plan,
    required this.currency,
    required this.amountPaidMinor,
    required this.taxMinor,
    required this.affiliateCommissionAccrualStatus,
    required this.affiliateCommissionMinor,
    required this.reconciliationStatus,
    required this.reconciliationFailedChecks,
    required this.providerGrossMinor,
    required this.providerFeeMinor,
    required this.providerNetMinor,
    required this.stripeBalanceTransactionId,
  });

  final String invoiceId;
  final String uid;
  final String plan;
  final String currency;
  final int amountPaidMinor;
  final int taxMinor;
  final String affiliateCommissionAccrualStatus;
  final int affiliateCommissionMinor;
  final String reconciliationStatus;
  final List<String> reconciliationFailedChecks;
  final int providerGrossMinor;
  final int providerFeeMinor;
  final int providerNetMinor;
  final String stripeBalanceTransactionId;

  factory _DispatchInvoiceSummary.fromMap(Map<String, dynamic> data) {
    int amount(String key) => (data[key] as num?)?.toInt() ?? 0;
    final failed = data['reconciliationFailedChecks'];
    return _DispatchInvoiceSummary(
      invoiceId: '${data['invoiceId'] ?? ''}',
      uid: '${data['uid'] ?? ''}',
      plan: '${data['plan'] ?? ''}',
      currency: '${data['currency'] ?? 'CAD'}'.toUpperCase(),
      amountPaidMinor: amount('amountPaidMinor'),
      taxMinor: amount('taxMinor'),
      affiliateCommissionAccrualStatus:
          '${data['affiliateCommissionAccrualStatus'] ?? ''}',
      affiliateCommissionMinor: amount('affiliateCommissionMinor'),
      reconciliationStatus:
          '${data['reconciliationStatus'] ?? 'not_reconciled'}',
      reconciliationFailedChecks: failed is List
          ? failed.map((value) => '$value').toList(growable: false)
          : const <String>[],
      providerGrossMinor: amount('providerGrossMinor'),
      providerFeeMinor: amount('providerFeeMinor'),
      providerNetMinor: amount('providerNetMinor'),
      stripeBalanceTransactionId:
          '${data['stripeBalanceTransactionId'] ?? ''}',
    );
  }

  String money(int minor) => '$currency \$${(minor / 100).toStringAsFixed(2)}';
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.reconciling,
    required this.onReconcile,
  });

  final _DispatchInvoiceSummary invoice;
  final bool reconciling;
  final VoidCallback onReconcile;

  @override
  Widget build(BuildContext context) {
    final balanced = invoice.reconciliationStatus == 'balanced';
    final mismatch = invoice.reconciliationStatus == 'mismatch';
    final color = balanced
        ? PipeBuyerColors.success
        : mismatch
            ? PipeBuyerColors.danger
            : PipeBuyerColors.warning;
    final label = balanced
        ? 'BALANCED'
        : mismatch
            ? 'MISMATCH'
            : 'NOT RECONCILED';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  invoice.invoiceId,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${invoice.plan.isEmpty ? 'Dispatch' : invoice.plan} • ${invoice.money(invoice.amountPaidMinor)} paid • tax ${invoice.money(invoice.taxMinor)}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            'Affiliate: ${invoice.affiliateCommissionAccrualStatus.isEmpty ? 'not recorded' : invoice.affiliateCommissionAccrualStatus} • ${invoice.money(invoice.affiliateCommissionMinor)}',
            style: const TextStyle(
              color: PipeBuyerColors.muted,
              fontSize: 11,
            ),
          ),
          if (balanced || mismatch) ...[
            const SizedBox(height: 7),
            Text(
              'Provider gross ${invoice.money(invoice.providerGrossMinor)} • Stripe fee ${invoice.money(invoice.providerFeeMinor)} • net ${invoice.money(invoice.providerNetMinor)}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            if (invoice.stripeBalanceTransactionId.isNotEmpty)
              SelectableText(
                'Balance Transaction: ${invoice.stripeBalanceTransactionId}',
                style: const TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 10,
                ),
              ),
            if (invoice.reconciliationFailedChecks.isNotEmpty)
              Text(
                'Failed checks: ${invoice.reconciliationFailedChecks.join(', ')}',
                style: const TextStyle(
                  color: PipeBuyerColors.danger,
                  fontSize: 10,
                ),
              ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: reconciling ? null : onReconcile,
              icon: reconciling
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_alt_rounded),
              label: Text(reconciling
                  ? 'Reconciling…'
                  : 'Reconcile Stripe ↔ Firestore'),
            ),
          ),
        ],
      ),
    );
  }
}
