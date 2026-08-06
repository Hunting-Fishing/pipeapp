import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Compile-time safety contract for the payment-provider foundation.
///
/// Money movement stays unavailable until provider approval, legal review,
/// operational reconciliation, verified webhooks, and a separate release
/// approval are complete.
abstract final class MarketplacePaymentSafetyPolicy {
  static const paymentsEnabled = false;
  static const tokenPurchasesEnabled = false;
  static const platformCustodyEnabled = false;
  static const directBankDetailsAllowed = false;
  static const clientSecretEntryAllowed = false;

  static const providers = <String>[
    'Stripe Connect',
    'PayPal Multiparty',
  ];
}

class MarketplacePaymentReadinessPanel extends StatelessWidget {
  const MarketplacePaymentReadinessPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          color: colors.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security_outlined,
                        color: colors.onSecondaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Provider-managed payments — not active',
                        style: TextStyle(
                          color: colors.onSecondaryContainer,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Pipe Buyer does not collect, hold, release, or refund transaction funds in this release. Payment and token purchase controls remain disabled until the approved provider, legal, webhook, reconciliation, and release gates are complete.',
                  style: TextStyle(color: colors.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _SectionTitle(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Administrator billing controls',
        ),
        const SizedBox(height: 8),
        const _ReadinessCard(
          title: 'Commission schedule',
          status: 'Draft architecture',
          icon: Icons.percent_outlined,
          details:
              'A future server command will version percentage, fixed, minimum, maximum, currency, jurisdiction, payer, and effective-date rules. Checkout must snapshot the exact approved schedule used for each transaction.',
        ),
        const SizedBox(height: 10),
        const _ReadinessCard(
          title: 'Internal tokens',
          status: 'Disabled',
          icon: Icons.toll_outlined,
          details:
              'Tokens are planned as non-cash, non-transferable app entitlements. They are not a stored-value balance, cannot be withdrawn, and can only be issued or consumed by audited server commands after separate approval.',
        ),
        const SizedBox(height: 10),
        const _ReadinessCard(
          title: 'Provider credentials and payout accounts',
          status: 'Server environment only',
          icon: Icons.key_outlined,
          details:
              'Secret keys, webhook signing secrets, merchant credentials, and payout bank details must never be entered in Flutter or stored in client-readable Firestore documents. Configure them through protected provider dashboards and server secret storage.',
        ),
        const SizedBox(height: 18),
        const _SectionTitle(
          icon: Icons.shopping_cart_checkout_outlined,
          title: 'User transaction providers',
        ),
        const SizedBox(height: 8),
        const _ReadinessCard(
          title: 'Stripe Connect',
          status: 'Provider approval required',
          icon: Icons.credit_card_outlined,
          details:
              'Planned for connected-seller onboarding, provider-hosted card checkout, eligible wallets and bank-transfer methods, provider payouts, and a server-calculated application fee.',
        ),
        const SizedBox(height: 10),
        const _ReadinessCard(
          title: 'PayPal Multiparty',
          status: 'Partner approval required',
          icon: Icons.account_balance_wallet_outlined,
          details:
              'Planned for PayPal seller onboarding and approved partner-fee collection. Provider onboarding and account capability checks must complete before a seller can receive payments.',
        ),
        const SizedBox(height: 10),
        const _ReadinessCard(
          title: 'Bank transfer',
          status: 'Processor-managed only',
          icon: Icons.account_balance_outlined,
          details:
              'Planned only where the selected processor supports virtual account details, transaction references, payment confirmation, and automated reconciliation. Pipe Buyer will not publish its own raw bank account details to buyers.',
        ),
        const SizedBox(height: 18),
        const _SectionTitle(
          icon: Icons.rule_folder_outlined,
          title: 'Required activation gates',
        ),
        const SizedBox(height: 8),
        const _ActivationChecklist(),
      ],
    );
  }
}

class MarketplaceTransactionRecordsPanel extends StatelessWidget {
  const MarketplaceTransactionRecordsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Read-only marketplace lifecycle records'),
              subtitle: Text(
                'These records do not prove that a payment was collected, held, released, refunded, or settled. Provider payment records will be server-authored only after the payment system is approved and activated.',
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('marketplace_transactions')
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Transaction records are unavailable.'),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final records = snapshot.data?.docs ?? const [];
              if (records.isEmpty) {
                return const Center(
                  child: Text('No marketplace lifecycle records found.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final record = records[index];
                  final data = record.data();
                  final quantity =
                      (data['requestedQuantity'] as num?)?.toInt() ?? 1;
                  final total = (data['offeredTotal'] as num?)?.toDouble() ??
                      ((data['offeredUnitPrice'] as num?)?.toDouble() ?? 0) *
                          quantity;
                  final title = '${data['listingTitle'] ?? 'Marketplace item'}';
                  final lifecycleStatus =
                      '${data['status'] ?? 'recorded'}'.trim();
                  final providerStatus =
                      '${data['providerPaymentStatus'] ?? 'not connected'}'
                          .trim();

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Lifecycle: $lifecycleStatus\nProvider payment: $providerStatus',
                      ),
                      trailing: Text(
                        total > 0 ? '\$${total.toStringAsFixed(2)}' : '—',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.title,
    required this.status,
    required this.icon,
    required this.details,
  });

  final String title;
  final String status;
  final IconData icon;
  final String details;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    details,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivationChecklist extends StatelessWidget {
  const _ActivationChecklist();

  @override
  Widget build(BuildContext context) {
    const items = <String>[
      'Provider platform approval and live marketplace capabilities',
      'Seller KYC/KYB onboarding and payout eligibility',
      'Protected server secrets and signed webhook verification',
      'Idempotent payment, fee, refund, dispute, and reconciliation records',
      'Versioned commission and token policies approved by administrators',
      'Published seller, buyer, refund, dispute, tax, and privacy terms',
      'Country, currency, sanctions, and payment-method eligibility review',
      'Separate reviewed release enabling paid features',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.radio_button_unchecked, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}
