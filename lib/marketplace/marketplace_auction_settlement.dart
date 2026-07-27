import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import 'marketplace_auction_repository.dart';
import 'marketplace_command_client.dart';
import 'marketplace_money.dart';

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
            return _message(
              Icons.sync_problem_outlined,
              'Settlement details could not be loaded. Retry after refreshing.',
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final sale = snapshot.data!.data();
          if (sale == null) return _finalizeCard();
          return _settlementCard(sale);
        },
      );

  Widget _finalizeCard() => Card(
        color: const Color(0xFFFFF5E8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Finalize auction result',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'The timer has ended. Confirm the server-calculated winner or no-sale result.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _finalize,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: const Text('Finalize result'),
              ),
            ],
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
    return Card(
      color: const Color(0xFFEAF7F1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.handshake_outlined, color: Colors.teal),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Auction settlement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              Chip(label: Text(_statusLabel(status))),
            ]),
            Text(
              '${marketplaceMoney(sale['agreedTotal'] as num? ?? 0)} total • '
              '${sale['agreedQuantity'] ?? 1} units',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _confirmation('Winning bidder', buyerConfirmed),
            _confirmation('Seller', sellerConfirmed),
            const SizedBox(height: 8),
            const Text(
              'These confirmations record completion between the parties. They do not represent escrow, payment release, or a refund.',
              style: TextStyle(fontSize: 11, color: Color(0xFF66758A)),
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
              Wrap(spacing: 8, runSpacing: 8, children: [
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
              ]),
            ],
            TextButton.icon(
              onPressed: () => _showHistory(context),
              icon: const Icon(Icons.history),
              label: const Text('View permanent settlement history'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmation(String label, bool confirmed) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          confirmed ? Icons.check_circle : Icons.schedule_outlined,
          color: confirmed ? Colors.green : Colors.orange,
        ),
        title: Text(label),
        trailing: Text(confirmed ? 'Confirmed' : 'Waiting'),
      );

  Widget _message(IconData icon, String text) => Card(
        child: ListTile(leading: Icon(icon), title: Text(text)),
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
