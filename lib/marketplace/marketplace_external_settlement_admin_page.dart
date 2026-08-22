import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/data/bounded_firestore_query.dart';
import 'marketplace_admin_access.dart';
import 'marketplace_canada_gst_hst_threshold_panel.dart';
import 'marketplace_data_state.dart';

class MarketplaceExternalSettlementAdminPage extends StatefulWidget {
  const MarketplaceExternalSettlementAdminPage({super.key});

  @override
  State<MarketplaceExternalSettlementAdminPage> createState() =>
      _MarketplaceExternalSettlementAdminPageState();
}

class _MarketplaceExternalSettlementAdminPageState
    extends State<MarketplaceExternalSettlementAdminPage> {
  late Future<MarketplaceAdministratorState> _access;

  @override
  void initState() {
    super.initState();
    _access = marketplaceAdministratorState(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('External Settlement Fee Queue')),
        body: FutureBuilder<MarketplaceAdministratorState>(
          future: _access,
          builder: (context, accessSnapshot) {
            if (!accessSnapshot.hasData) {
              return const MarketplaceDataStateView.loading(
                title: 'Checking administrator access',
                message: 'Verifying administrator role and MFA evidence…',
              );
            }
            if (accessSnapshot.data != MarketplaceAdministratorState.authorized) {
              return MarketplaceDataStateView(
                kind: MarketplaceDataStateKind.unavailable,
                icon: Icons.admin_panel_settings_outlined,
                title: 'Administrator access required',
                message: _accessMessage(accessSnapshot.data!),
                primaryLabel: 'Refresh administrator access',
                onPrimary: () => setState(() {
                  _access = marketplaceAdministratorState(forceRefresh: true);
                }),
              );
            }
            return _feeQueue();
          },
        ),
      );

  Widget _feeQueue() {
    final buyerConfirmations = FirebaseFirestore.instance
        .collection('marketplace_transactions')
        .where('externalSettlementBuyerConfirmed', isEqualTo: true)
        .limit(defaultActivityFeedLimit)
        .snapshots();
    final sellerConfirmations = FirebaseFirestore.instance
        .collection('marketplace_transactions')
        .where('externalSettlementSellerConfirmed', isEqualTo: true)
        .limit(defaultActivityFeedLimit)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: buyerConfirmations,
      builder: (context, buyerSnapshot) {
        if (buyerSnapshot.hasError) {
          return MarketplaceDataStateView.failure(
            error: buyerSnapshot.error,
            resource: 'External settlement fee queue',
            onRetry: () => setState(() {}),
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: sellerConfirmations,
          builder: (context, sellerSnapshot) {
            if (sellerSnapshot.hasError) {
              return MarketplaceDataStateView.failure(
                error: sellerSnapshot.error,
                resource: 'External settlement fee queue',
                onRetry: () => setState(() {}),
              );
            }
            if (!buyerSnapshot.hasData || !sellerSnapshot.hasData) {
              return const MarketplaceDataStateView.loading(
                title: 'Loading fee queue',
                message: 'Retrieving external-settlement payment states…',
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
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  MarketplaceCanadaGstHstThresholdPanel(),
                  SizedBox(height: 12),
                  MarketplaceDataStateView(
                    kind: MarketplaceDataStateKind.empty,
                    icon: Icons.receipt_long_outlined,
                    title: 'External settlement queue is empty',
                    message:
                        'Transactions appear here when either party confirms external settlement.',
                  ),
                ],
              );
            }

            final counts = <String, int>{};
            for (final document in transactions) {
              final state = _adminFeeState(document.data()).label;
              counts[state] = (counts[state] ?? 0) + 1;
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const MarketplaceCanadaGstHstThresholdPanel(),
                const SizedBox(height: 12),
                _summary(counts, transactions.length),
                const SizedBox(height: 12),
                ...transactions.map(
                  (document) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _transactionCard(document.id, document.data()),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _summary(Map<String, int> counts, int total) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_heart_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$total external-settlement transaction${total == 1 ? '' : 's'} in the current review window',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: counts.entries
                    .map((entry) => Chip(label: Text('${entry.key}: ${entry.value}')))
                    .toList(),
              ),
              const SizedBox(height: 6),
              const Text(
                'Read-only financial operations view. Client code cannot mark fees paid, override Stripe evidence, or edit settlement confirmations.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      );

  Widget _transactionCard(
    String transactionId,
    Map<String, dynamic> transaction,
  ) {
    final state = _adminFeeState(transaction);
    final fee = Map<String, dynamic>.from(
      transaction['marketplaceFeeSnapshot'] as Map? ?? const {},
    );
    final feeMinor = (fee['marketplaceFeeMinor'] as num?)?.toInt() ?? 0;
    final currency = '${fee['currency'] ?? transaction['currency'] ?? 'CAD'}'
        .toUpperCase();
    final attempt =
        (transaction['marketplaceFeeCheckoutAttempt'] as num?)?.toInt();
    final updatedAt = transaction['updatedAt'] as Timestamp?;
    final buyerConfirmed =
        transaction['externalSettlementBuyerConfirmed'] == true;
    final sellerConfirmed =
        transaction['externalSettlementSellerConfirmed'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(state.icon, color: state.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transactionId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Buyer ${buyerConfirmed ? '✓' : 'pending'} • Seller ${sellerConfirmed ? '✓' : 'pending'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(state.icon, size: 16, color: state.color),
                  label: Text(state.label),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Fee: ${_moneyMinor(feeMinor, currency)}'
              '${attempt == null ? '' : ' • Checkout attempt $attempt'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            _reference('Seller', transaction['sellerUid']),
            _reference('Buyer', transaction['buyerUid']),
            _reference('Checkout', transaction['stripeMarketplaceFeeSessionId']),
            _reference(
                'PaymentIntent', transaction['stripeMarketplaceFeePaymentIntentId']),
            _reference('Charge', transaction['stripeMarketplaceFeeChargeId']),
            if (transaction['marketplaceFeeTaxExposureReviewRequired'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Tax exposure review required • ${transaction['marketplaceFeeTaxCollectionStatus'] ?? 'registration pending'}',
                  style: TextStyle(
                    color: Colors.deepOrange.shade700,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (updatedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Updated ${_date(updatedAt.toDate())}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reference(String label, dynamic value) {
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '$label: $text',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: Colors.black54),
      ),
    );
  }

  _AdminFeeState _adminFeeState(Map<String, dynamic> transaction) {
    final buyerConfirmed =
        transaction['externalSettlementBuyerConfirmed'] == true;
    final sellerConfirmed =
        transaction['externalSettlementSellerConfirmed'] == true;
    if (_stripeMarketplacePathStarted(transaction) &&
        (buyerConfirmed || sellerConfirmed)) {
      return const _AdminFeeState(
        'PATH CONFLICT',
        Icons.warning_amber_outlined,
        Colors.red,
      );
    }
    if (transaction['marketplaceFeeTaxExposureReviewRequired'] == true) {
      return const _AdminFeeState(
        'TAX REVIEW',
        Icons.account_balance_outlined,
        Colors.deepOrange,
      );
    }
    if (!(buyerConfirmed && sellerConfirmed)) {
      return const _AdminFeeState(
        'CONFIRMATION PENDING',
        Icons.hourglass_top_outlined,
        Colors.blueGrey,
      );
    }
    return switch ('${transaction['marketplaceFeeStatus'] ?? ''}') {
      'collected' => const _AdminFeeState(
          'PAID', Icons.check_circle_outline, Colors.green),
      'processing' => const _AdminFeeState(
          'PROCESSING', Icons.sync_outlined, Colors.blue),
      'payment_failed' => const _AdminFeeState(
          'FAILED', Icons.error_outline, Colors.red),
      'checkout_created' => const _AdminFeeState(
          'CHECKOUT OPEN', Icons.open_in_new, Colors.indigo),
      _ => const _AdminFeeState(
          'FEE DUE', Icons.payments_outlined, Colors.orange),
    };
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

  String _accessMessage(MarketplaceAdministratorState state) => switch (state) {
        MarketplaceAdministratorState.signedOut =>
          'Sign in with an administrator account to continue.',
        MarketplaceAdministratorState.roleMissing =>
          'This account does not have the administrator role.',
        MarketplaceAdministratorState.mfaRequired =>
          'Administrator access requires a sign-in that completed MFA.',
        MarketplaceAdministratorState.unavailable =>
          'Administrator claims could not be verified. Refresh and try again.',
        MarketplaceAdministratorState.authorized => '',
      };

  String _moneyMinor(int minor, String currency) =>
      '$currency ${(minor / 100).toStringAsFixed(2)}';

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

class _AdminFeeState {
  const _AdminFeeState(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
