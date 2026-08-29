import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_auction_repository.dart';
import 'marketplace_command_client.dart';
import 'marketplace_escrow_repository.dart';
import 'marketplace_data_state.dart';
import 'marketplace_money.dart';
import 'marketplace_invoice_generator.dart';

class MarketplaceAuctionSettlement extends StatefulWidget {
  const MarketplaceAuctionSettlement({
    super.key,
    required this.listingId,
    required this.listing,
  });

  final String listingId;
  final Map<String, dynamic> listing;

  @override
  State<MarketplaceAuctionSettlement> createState() =>
      _MarketplaceAuctionSettlementState();
}

class _MarketplaceAuctionSettlementState
    extends State<MarketplaceAuctionSettlement> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('auction_transactions')
            .doc(widget.listingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return MarketplaceDataStateView.failure(
              error: snapshot.error,
              resource: 'Settlement details',
              onRetry: () => setState(() {}),
              compact: true,
            );
          }
          if (!snapshot.hasData) {
            return const MarketplaceDataStateView.loading(
              title: 'Loading settlement',
              message: 'Checking the latest auction completion status…',
              compact: true,
            );
          }
          final sale = snapshot.data!.data();
          if (sale == null) return _finalizeCard();
          return _settlementCard(sale);
        },
      );

  Widget _finalizeCard() => PipeBuyerSectionCard(
        title: 'Finalize auction result',
        subtitle:
            'The timer has ended. Confirm the server-calculated winner or no-sale result before settlement begins.',
        leading: const _SectionIcon(
          Icons.gavel_outlined,
          tone: PipeBuyerStatusTone.warning,
        ),
        trailing: const PipeBuyerStatusBadge(
          label: 'ACTION REQUIRED',
          icon: Icons.schedule_outlined,
          tone: PipeBuyerStatusTone.warning,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : _finalize,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fact_check_outlined),
            label: Text(_busy ? 'Finalizing result…' : 'Finalize result'),
          ),
        ),
      );

  Widget _settlementCard(Map<String, dynamic> sale) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final buyer = uid == sale['buyerUid'];
    final status = '${sale['status'] ?? 'pending_completion'}';
    final buyerConfirmed = sale['buyerConfirmed'] == true;
    final sellerConfirmed = sale['sellerConfirmed'] == true;
    final closed = const {
      'completed',
      'cancelled',
      'disputed',
      'buyer_default_reported',
      'seller_default_reported',
    }.contains(status);
    final myConfirmation = buyer ? buyerConfirmed : sellerConfirmed;
    final total = sale['agreedTotal'] as num? ?? 0;
    final quantity = sale['agreedQuantity'] ?? 1;
    final statusTone = _statusTone(status);
    final escrowStatus =
        parseEscrowStatus('${sale['escrowStatus'] ?? sale['status']}');

    return PipeBuyerSectionCard(
      title: 'Auction settlement',
      subtitle:
          'Permanent closeout record between the successful buyer and seller.',
      leading: const _SectionIcon(
        Icons.handshake_outlined,
        tone: PipeBuyerStatusTone.success,
      ),
      trailing: PipeBuyerStatusBadge(
        label: _statusLabel(status),
        icon: _statusIcon(status),
        tone: statusTone,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final items = [
                _SettlementFact(
                  label: 'Agreed total',
                  value: marketplaceMoney(total),
                  icon: Icons.payments_outlined,
                  tone: PipeBuyerStatusTone.premium,
                ),
                _SettlementFact(
                  label: 'Quantity',
                  value: '$quantity units',
                  icon: Icons.inventory_2_outlined,
                  tone: PipeBuyerStatusTone.info,
                ),
                _SettlementFact(
                  label: 'Your role',
                  value: buyer ? 'Successful buyer' : 'Seller',
                  icon:
                      buyer ? Icons.person_outline : Icons.storefront_outlined,
                  tone: PipeBuyerStatusTone.neutral,
                ),
              ];
              if (compact) {
                return Column(
                  children: items
                      .expand((item) => [
                            item,
                            const SizedBox(height: 8),
                          ])
                      .toList(growable: false),
                );
              }
              return Row(
                children: items
                    .expand((item) => [
                          Expanded(child: item),
                          const SizedBox(width: 8),
                        ])
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: PipeBuyerColors.industrialBlue.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: PipeBuyerColors.industrialBlue.withValues(alpha: .18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: PipeBuyerColors.industrialBlue
                            .withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: PipeBuyerColors.industrialBlue,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment & settlement',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Stripe processes supported payments and seller transfers. Pipe Buyer records provider status; this is not an escrow or trust account.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    PipeBuyerStatusBadge(
                      label: formatEscrowStatus(escrowStatus).toUpperCase(),
                      icon: Icons.account_balance_wallet_outlined,
                      tone: _escrowTone('${sale['escrowStatus'] ?? status}'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final price =
                          (sale['winningBidAmount'] as num?)?.toDouble() ?? 0.0;
                      final title =
                          '${widget.listing['title'] ?? 'Auction Item'}';
                      final invoice = MarketplaceInvoice(
                        invoiceId:
                            'INV-${widget.listingId.substring(0, 8).toUpperCase()}',
                        listingTitle: title,
                        sellerName:
                            '${widget.listing['sellerName'] ?? 'Seller'}',
                        buyerName:
                            '${sale['winningBidderName'] ?? 'Winning Bidder'}',
                        unitPrice: price,
                        quantity: 1,
                        unitLabel: 'lot',
                        issueDate: DateTime.now(),
                        dueDate: DateTime.now().add(const Duration(days: 7)),
                        status: sale['escrowStatus'] == 'released'
                            ? 'Paid'
                            : 'Unpaid',
                      );
                      showDialog<void>(
                        context: context,
                        builder: (_) =>
                            MarketplaceInvoiceDialog(invoice: invoice),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('View Itemized Invoice'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Completion confirmations',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          _confirmation('Successful buyer', buyerConfirmed),
          const SizedBox(height: 7),
          _confirmation('Seller', sellerConfirmed),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 19),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'These confirmations record completion between the parties. They do not represent escrow, payment release, or a refund.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!closed && !myConfirmation)
            FilledButton.icon(
              onPressed: _busy ? null : _confirmCompletion,
              icon: const Icon(Icons.verified_outlined),
              label: Text(
                  buyer ? 'Confirm item received' : 'Confirm sale fulfilled'),
            ),
          if (!closed) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _reasonAction('dispute'),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Open dispute'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _reasonAction(
                            buyer
                                ? 'report_seller_default'
                                : 'report_buyer_default',
                          ),
                  icon: const Icon(Icons.gavel_outlined),
                  label: Text(
                    buyer ? 'Report seller default' : 'Report buyer default',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showHistory(context),
              icon: const Icon(Icons.history),
              label: const Text('View permanent settlement history'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmation(String label, bool confirmed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: (confirmed ? PipeBuyerColors.success : PipeBuyerColors.warning)
              .withValues(alpha: .07),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color:
                (confirmed ? PipeBuyerColors.success : PipeBuyerColors.warning)
                    .withValues(alpha: .18),
          ),
        ),
        child: Row(
          children: [
            Icon(
              confirmed ? Icons.check_circle : Icons.schedule_outlined,
              color:
                  confirmed ? PipeBuyerColors.success : PipeBuyerColors.warning,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            PipeBuyerStatusBadge(
              label: confirmed ? 'CONFIRMED' : 'WAITING',
              icon: confirmed ? Icons.check : Icons.schedule_outlined,
              tone: confirmed
                  ? PipeBuyerStatusTone.success
                  : PipeBuyerStatusTone.warning,
            ),
          ],
        ),
      );

  Future<void> _finalize() => _run(
        () => MarketplaceAuctionRepository()
            .finalizeAuction(listingId: widget.listingId),
        'Auction result finalized.',
      );

  Future<void> _confirmCompletion() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm completion?'),
            content: const Text(
              'Your confirmation is permanent. The auction is completed only after both parties confirm.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Go back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm completion'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _run(
      () => MarketplaceAuctionRepository().updateTransaction(
        widget.listingId,
        'confirm_completion',
      ),
      'Your completion confirmation was recorded.',
    );
  }

  Future<void> _reasonAction(String action) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action == 'dispute' ? 'Open dispute' : 'Report default'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Reason *',
            hintText: 'Describe what happened and the resolution attempted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 10) Navigator.pop(dialogContext, value);
            },
            child: const Text('Submit for review'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    await _run(
      () => MarketplaceAuctionRepository().updateTransaction(
        widget.listingId,
        action,
        reason: reason,
      ),
      action == 'dispute'
          ? 'Dispute opened for review.'
          : 'Default report opened for review.',
    );
  }

  Future<void> _run(Future<void> Function() command, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await command();
      if (mounted) {
        PipeFeedback.show(
          context,
          message: success,
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(error),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showHistory(BuildContext context) async {
    final history = await FirebaseFirestore.instance
        .collection('auction_transactions')
        .doc(widget.listingId)
        .collection('revisions')
        .limit(100)
        .get();
    history.docs.sort((a, b) => (b.data()['revision'] as num? ?? 0)
        .compareTo(a.data()['revision'] as num? ?? 0));
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Settlement history'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: history.docs.map((document) {
              final data = document.data();
              return ListTile(
                leading: CircleAvatar(child: Text('${data['revision'] ?? 1}')),
                title: Text(_statusLabel('${data['status'] ?? 'created'}')),
                subtitle: Text(
                  '${data['event'] ?? 'auction_won'}'
                  '${data['reason'] == null ? '' : '\n${data['reason']}'}',
                ),
              );
            }).toList(growable: false),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  PipeBuyerStatusTone _statusTone(String status) => switch (status) {
        'completed' => PipeBuyerStatusTone.success,
        'disputed' ||
        'buyer_default_reported' ||
        'seller_default_reported' =>
          PipeBuyerStatusTone.danger,
        'cancelled' => PipeBuyerStatusTone.neutral,
        _ => PipeBuyerStatusTone.warning,
      };

  IconData _statusIcon(String status) => switch (status) {
        'completed' => Icons.check_circle_outline,
        'disputed' => Icons.report_problem_outlined,
        'buyer_default_reported' ||
        'seller_default_reported' =>
          Icons.gavel_outlined,
        'cancelled' => Icons.cancel_outlined,
        _ => Icons.schedule_outlined,
      };

  PipeBuyerStatusTone _escrowTone(String status) {
    final normalized = status.trim().toLowerCase();
    if (const {'released', 'completed', 'paid'}.contains(normalized)) {
      return PipeBuyerStatusTone.success;
    }
    if (const {'disputed', 'failed', 'cancelled'}.contains(normalized)) {
      return PipeBuyerStatusTone.danger;
    }
    return PipeBuyerStatusTone.info;
  }

  String _statusLabel(String status) => switch (status) {
        'pending_completion' => 'PENDING',
        'awaiting_buyer_confirmation' => 'WAITING FOR BUYER',
        'awaiting_seller_confirmation' => 'WAITING FOR SELLER',
        'completed' => 'COMPLETED',
        'disputed' => 'DISPUTED',
        'buyer_default_reported' => 'BUYER DEFAULT REPORTED',
        'seller_default_reported' => 'SELLER DEFAULT REPORTED',
        'cancelled' => 'CANCELLED',
        _ => status.replaceAll('_', ' ').toUpperCase(),
      };
}

class _SettlementFact extends StatelessWidget {
  const _SettlementFact({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final PipeBuyerStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = pipeBuyerToneColor(tone);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
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
                            .withValues(alpha: .56),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
