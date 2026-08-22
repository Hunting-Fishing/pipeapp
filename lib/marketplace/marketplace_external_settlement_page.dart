import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/data/bounded_firestore_query.dart';
import 'marketplace_command_client.dart';
import 'marketplace_data_state.dart';
import 'marketplace_external_settlement_client.dart';

class MarketplaceExternalSettlementPage extends StatefulWidget {
  const MarketplaceExternalSettlementPage({super.key});

  @override
  State<MarketplaceExternalSettlementPage> createState() =>
      _MarketplaceExternalSettlementPageState();
}

class _MarketplaceExternalSettlementPageState
    extends State<MarketplaceExternalSettlementPage> {
  final _client = MarketplaceExternalSettlementClient();
  final Set<String> _busyTransactions = <String>{};

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: MarketplaceDataStateView(
          kind: MarketplaceDataStateKind.unavailable,
          icon: Icons.lock_outline,
          title: 'Sign in required',
          message: 'Sign in to manage marketplace settlement and fees.',
        ),
      );
    }

    final buyerStream = FirebaseFirestore.instance
        .collection('marketplace_transactions')
        .where('buyerUid', isEqualTo: user.uid)
        .limit(defaultActivityFeedLimit)
        .snapshots();
    final sellerStream = FirebaseFirestore.instance
        .collection('marketplace_transactions')
        .where('sellerUid', isEqualTo: user.uid)
        .limit(defaultActivityFeedLimit)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settlement & Pipe Buyer Fees'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: buyerStream,
        builder: (context, buyerSnapshot) {
          if (buyerSnapshot.hasError) {
            return _loadFailure(buyerSnapshot.error);
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: sellerStream,
            builder: (context, sellerSnapshot) {
              if (sellerSnapshot.hasError) {
                return _loadFailure(sellerSnapshot.error);
              }
              if (!buyerSnapshot.hasData || !sellerSnapshot.hasData) {
                return const MarketplaceDataStateView.loading(
                  title: 'Loading settlement records',
                  message: 'Retrieving your current marketplace transactions…',
                );
              }

              final byId = <String,
                  QueryDocumentSnapshot<Map<String, dynamic>>>{};
              for (final document in buyerSnapshot.data!.docs) {
                byId[document.id] = document;
              }
              for (final document in sellerSnapshot.data!.docs) {
                byId[document.id] = document;
              }
              final transactions = byId.values.toList()
                ..sort((left, right) {
                  final leftAt = left.data()['updatedAt'] as Timestamp?;
                  final rightAt = right.data()['updatedAt'] as Timestamp?;
                  return (rightAt?.millisecondsSinceEpoch ?? 0)
                      .compareTo(leftAt?.millisecondsSinceEpoch ?? 0);
                });

              if (transactions.isEmpty) {
                return const MarketplaceDataStateView(
                  kind: MarketplaceDataStateKind.empty,
                  icon: Icons.handshake_outlined,
                  title: 'No settlement records yet',
                  message:
                      'Accepted marketplace transactions will appear here for buyer and seller settlement confirmation.',
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _introCard(),
                  const SizedBox(height: 12),
                  if (buyerSnapshot.data!.docs.length == defaultActivityFeedLimit ||
                      sellerSnapshot.data!.docs.length ==
                          defaultActivityFeedLimit)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Showing the latest settlement window'),
                        subtitle: Text(
                          'Older transactions remain stored in the authoritative marketplace ledger.',
                        ),
                      ),
                    ),
                  ...transactions.map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _transactionCard(
                        document.id,
                        document.data(),
                        user.uid,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _introCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'External settlement',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Buyer and seller may agree to settle the industrial sale outside Stripe. Both parties must confirm that choice. Pipe Buyer then bills only its server-calculated marketplace fee to the seller through secure Stripe Checkout.',
              ),
              SizedBox(height: 6),
              Text(
                'Pipe Buyer does not mark the marketplace fee paid from a browser redirect. Paid status comes from verified Stripe webhook evidence.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      );

  Widget _transactionCard(
    String transactionId,
    Map<String, dynamic> transaction,
    String uid,
  ) {
    final isSeller = transaction['sellerUid'] == uid;
    final buyerExternalConfirmed =
        transaction['externalSettlementBuyerConfirmed'] == true;
    final sellerExternalConfirmed =
        transaction['externalSettlementSellerConfirmed'] == true;
    final fullyExternalConfirmed =
        buyerExternalConfirmed && sellerExternalConfirmed;
    final userExternalConfirmed =
        isSeller ? sellerExternalConfirmed : buyerExternalConfirmed;
    final feeStatus = '${transaction['marketplaceFeeStatus'] ?? ''}'.trim();
    final transactionStatus =
        '${transaction['status'] ?? 'pending_completion'}'.trim();
    final stripePathStarted = _stripeMarketplacePathStarted(transaction);
    final blocked = const {'cancelled', 'disputed'}.contains(transactionStatus);
    final busy = _busyTransactions.contains(transactionId);
    final fee = Map<String, dynamic>.from(
      transaction['marketplaceFeeSnapshot'] as Map? ?? const {},
    );
    final feeMinor = (fee['marketplaceFeeMinor'] as num?)?.toInt();
    final currency = '${fee['currency'] ?? transaction['currency'] ?? 'CAD'}'
        .trim()
        .toUpperCase();
    final listingLabel = '${transaction['listingTitle'] ?? ''}'.trim();
    final listingId = '${transaction['listingId'] ?? ''}'.trim();
    final displayTitle = listingLabel.isNotEmpty
        ? listingLabel
        : listingId.isNotEmpty
            ? 'Listing $listingId'
            : 'Marketplace transaction';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Icon(isSeller
                      ? Icons.sell_outlined
                      : Icons.shopping_cart_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${isSeller ? 'Seller' : 'Buyer'} • ${_transactionStatusLabel(transactionStatus)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                _feeStatusChip(feeStatus, fullyExternalConfirmed),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _confirmationTile(
                    'Buyer',
                    buyerExternalConfirmed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _confirmationTile(
                    'Seller',
                    sellerExternalConfirmed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (feeMinor != null && feeMinor > 0)
              _feeSummary(feeMinor, currency, fee),
            if (stripePathStarted) ...[
              const SizedBox(height: 10),
              _notice(
                Icons.credit_card_outlined,
                'This transaction already started the full Stripe marketplace payment path. External settlement is locked to prevent duplicate payment paths.',
                Colors.deepOrange,
              ),
            ] else if (blocked) ...[
              const SizedBox(height: 10),
              _notice(
                Icons.block_outlined,
                'External settlement cannot be changed while this transaction is ${_transactionStatusLabel(transactionStatus).toLowerCase()}.',
                Colors.blueGrey,
              ),
            ] else ...[
              const SizedBox(height: 10),
              if (!userExternalConfirmed)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _confirmExternalSettlement(
                              transactionId,
                              isSeller: isSeller,
                            ),
                    icon: const Icon(Icons.handshake_outlined),
                    label: const Text('Confirm external settlement'),
                  ),
                )
              else if (!fullyExternalConfirmed)
                _notice(
                  Icons.hourglass_top_outlined,
                  'Your external-settlement confirmation is recorded. Waiting for the other party.',
                  Colors.blue,
                ),
              if (fullyExternalConfirmed) ...[
                _notice(
                  Icons.verified_outlined,
                  'Both parties confirmed external settlement. The industrial sale remains outside Stripe; only the Pipe Buyer marketplace fee is billed here.',
                  Colors.green,
                ),
                const SizedBox(height: 10),
                if (isSeller)
                  _sellerFeeAction(
                    transactionId,
                    transaction,
                    feeStatus,
                    busy,
                  )
                else
                  _buyerFeeStatus(feeStatus),
              ],
            ],
            if (_busyTransactions.contains(transactionId)) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 10),
            Text(
              'Transaction reference: $transactionId',
              style: const TextStyle(fontSize: 10.5, color: Colors.black54),
            ),
            if ('${transaction['stripeMarketplaceFeeChargeId'] ?? ''}'
                .startsWith('ch_'))
              Text(
                'Stripe charge: ${transaction['stripeMarketplaceFeeChargeId']}',
                style: const TextStyle(fontSize: 10.5, color: Colors.black54),
              ),
          ],
        ),
      ),
    );
  }

  Widget _confirmationTile(String party, bool confirmed) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: confirmed ? const Color(0xFFE8F7ED) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: confirmed ? Colors.green.shade200 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
              color: confirmed ? Colors.green : Colors.blueGrey,
              size: 19,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '$party ${confirmed ? 'confirmed' : 'pending'}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );

  Widget _feeSummary(
    int feeMinor,
    String currency,
    Map<String, dynamic> fee,
  ) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pipe Buyer marketplace fee',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${_moneyMinor(feeMinor, currency)} • Policy ${fee['scheduleRevision'] ?? 'server snapshot'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _sellerFeeAction(
    String transactionId,
    Map<String, dynamic> transaction,
    String feeStatus,
    bool busy,
  ) {
    if (feeStatus == 'collected') {
      return _notice(
        Icons.task_alt_outlined,
        'Pipe Buyer marketplace fee paid and verified by Stripe.',
        Colors.green,
      );
    }
    if (feeStatus == 'processing') {
      return _notice(
        Icons.sync_outlined,
        'Stripe is processing the marketplace fee. Do not start another payment.',
        Colors.blue,
      );
    }
    final failed = feeStatus == 'payment_failed';
    final checkoutCreated = feeStatus == 'checkout_created';
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: busy ? null : () => _openFeeCheckout(transactionId),
        icon: Icon(failed
            ? Icons.refresh_outlined
            : checkoutCreated
                ? Icons.open_in_new
                : Icons.lock_outline),
        label: Text(failed
            ? 'Retry Pipe Buyer fee payment'
            : checkoutCreated
                ? 'Continue secure fee checkout'
                : 'Pay Pipe Buyer marketplace fee'),
      ),
    );
  }

  Widget _buyerFeeStatus(String feeStatus) {
    if (feeStatus == 'collected') {
      return _notice(
        Icons.task_alt_outlined,
        'Seller marketplace fee has been paid and verified.',
        Colors.green,
      );
    }
    if (feeStatus == 'processing') {
      return _notice(
        Icons.sync_outlined,
        'Seller marketplace fee payment is processing.',
        Colors.blue,
      );
    }
    if (feeStatus == 'payment_failed') {
      return _notice(
        Icons.error_outline,
        'Seller marketplace fee payment needs another attempt.',
        Colors.deepOrange,
      );
    }
    return _notice(
      Icons.payments_outlined,
      'The seller is responsible for the Pipe Buyer marketplace fee.',
      Colors.blueGrey,
    );
  }

  Widget _feeStatusChip(String feeStatus, bool fullyExternalConfirmed) {
    if (!fullyExternalConfirmed) {
      return const Chip(label: Text('SETTLEMENT PENDING'));
    }
    return switch (feeStatus) {
      'collected' => const Chip(
          avatar: Icon(Icons.check_circle, color: Colors.green, size: 17),
          label: Text('FEE PAID'),
        ),
      'processing' => const Chip(
          avatar: Icon(Icons.sync, color: Colors.blue, size: 17),
          label: Text('PROCESSING'),
        ),
      'payment_failed' => const Chip(
          avatar: Icon(Icons.error_outline, color: Colors.deepOrange, size: 17),
          label: Text('PAYMENT FAILED'),
        ),
      'checkout_created' => const Chip(label: Text('CHECKOUT OPEN')),
      _ => const Chip(label: Text('FEE DUE')),
    };
  }

  Widget _notice(IconData icon, String message, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      );

  Widget _loadFailure(Object? error) => MarketplaceDataStateView.failure(
        error: error,
        resource: 'Settlement records',
        retryLabel: 'Refresh account',
        onRetry: () async {
          await FirebaseAuth.instance.currentUser?.reload();
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
          if (mounted) setState(() {});
        },
      );

  Future<void> _confirmExternalSettlement(
    String transactionId, {
    required bool isSeller,
  }) async {
    final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.handshake_outlined, size: 38),
            title: const Text('Confirm external settlement?'),
            content: Text(
              isSeller
                  ? 'You are confirming that buyer and seller will settle the industrial sale outside Stripe. After both parties confirm, you are responsible for paying the server-calculated Pipe Buyer marketplace fee through secure Stripe Checkout.'
                  : 'You are confirming that buyer and seller will settle the industrial sale outside Stripe. Pipe Buyer will not collect the industrial sale proceeds. After both parties confirm, the seller is responsible for the Pipe Buyer marketplace fee.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Go back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm external settlement'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted) return;

    await _runBusy(transactionId, () async {
      final result = await _client.confirm(transactionId);
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: result.fullyConfirmed
            ? 'Both parties confirmed external settlement.'
            : 'Your external-settlement confirmation was recorded.',
        tone: PipeStatusTone.success,
      );
    }, operation: 'confirm_external_settlement');
  }

  Future<void> _openFeeCheckout(String transactionId) async {
    await _runBusy(transactionId, () async {
      final result = await _client.createFeeCheckout(transactionId);
      if (!mounted) return;
      if (result.alreadyPaid) {
        PipeFeedback.show(
          context,
          message: 'The Pipe Buyer marketplace fee is already paid.',
          tone: PipeStatusTone.success,
        );
        return;
      }
      if (result.processing) {
        PipeFeedback.show(
          context,
          message:
              'Stripe is processing this fee payment. No second payment was created.',
          tone: PipeStatusTone.info,
        );
        return;
      }
      if (result.paymentFailed) {
        PipeFeedback.show(
          context,
          message:
              'The previous fee payment failed. Select retry again to create a clean new payment attempt.',
          tone: PipeStatusTone.error,
        );
        return;
      }
      final uri = result.checkoutUri;
      if (uri == null || !result.canLaunchCheckout) {
        throw StateError('The secure Stripe checkout link is unavailable.');
      }
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('The secure Stripe checkout could not be opened.');
      }
    }, operation: 'open_external_fee_checkout');
  }

  Future<void> _runBusy(
    String transactionId,
    Future<void> Function() action, {
    required String operation,
  }) async {
    if (_busyTransactions.contains(transactionId)) return;
    setState(() => _busyTransactions.add(transactionId));
    try {
      await action();
    } catch (error) {
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The settlement action could not be completed. Try again.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyTransactions.remove(transactionId));
    }
  }

  bool _stripeMarketplacePathStarted(Map<String, dynamic> transaction) {
    final sessionId = '${transaction['stripeCheckoutSessionId'] ?? ''}'.trim();
    final paymentMethod = '${transaction['paymentMethod'] ?? ''}'.trim();
    final provider = '${transaction['paymentProvider'] ?? ''}'.trim();
    final providerStatus =
        '${transaction['paymentProviderStatus'] ?? ''}'.trim();
    return sessionId.startsWith('cs_') ||
        paymentMethod == 'stripe_checkout' ||
        provider == 'stripe' ||
        const {'checkout_created', 'processing', 'paid'}
            .contains(providerStatus);
  }

  String _transactionStatusLabel(String status) => switch (status) {
        'pending_completion' => 'Awaiting completion',
        'awaiting_buyer_confirmation' => 'Awaiting buyer',
        'awaiting_seller_confirmation' => 'Awaiting seller',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        'disputed' => 'Disputed',
        _ => status.replaceAll('_', ' '),
      };

  String _moneyMinor(int minor, String currency) =>
      '$currency ${(minor / 100).toStringAsFixed(2)}';
}
