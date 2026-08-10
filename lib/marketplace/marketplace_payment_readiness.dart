import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'marketplace_command_client.dart';

class MarketplacePaymentReadinessPanel extends StatefulWidget {
  const MarketplacePaymentReadinessPanel({super.key});

  @override
  State<MarketplacePaymentReadinessPanel> createState() =>
      _MarketplacePaymentReadinessPanelState();
}

class _MarketplacePaymentReadinessPanelState
    extends State<MarketplacePaymentReadinessPanel> {
  final MarketplaceCommandClient _commands = MarketplaceCommandClient();

  Map<String, dynamic>? _catalog;
  Map<String, dynamic>? _readiness;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  double _moneyAmount(Object? byCurrency, String currency) {
    final currencies = _map(byCurrency);
    final money = _map(currencies[currency]);
    return (money['amount'] as num?)?.toDouble() ?? 0;
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final responses = await Future.wait([
        _commands.execute('getMarketplaceFeeCatalog', const {}),
        _commands.execute('getPaymentProviderReadiness', const {}),
      ]);
      if (!mounted) return;
      setState(() {
        _catalog = responses[0];
        _readiness = responses[1];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Live billing configuration could not be loaded.',
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final catalog = _catalog ?? const <String, dynamic>{};
    final readiness = _readiness ?? const <String, dynamic>{};
    final pipe = _map(catalog['pipe']);
    final equipment = _map(catalog['equipment']);
    final dispatch = _map(catalog['dispatch']);
    final monthly = _map(dispatch['monthly']);
    final yearly = _map(dispatch['yearly']);
    final affiliate = _map(catalog['affiliate']);
    final taxCodes = _map(catalog['taxCodes']);
    final tiers = _mapList(equipment['tiers']);

    final taxReady = readiness['stripeTaxReady'] == true;
    final taxPending = readiness['stripeTaxRegistrationPending'] == true;
    final fullCheckout = readiness['stripeCheckoutEnabled'] == true;
    final feeBilling = readiness['stripeFeeBillingEnabled'] == true;
    final subscriptions = readiness['stripeSubscriptionsEnabled'] == true;
    final connect = readiness['stripeConnectOnboardingEnabled'] == true;
    final webhook = readiness['stripeWebhookVerified'] == true;

    final taxStatus = taxReady
        ? 'Registered / tax-ready'
        : taxPending
            ? 'Registration pending'
            : 'Not tax-ready';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _AdminBanner(
            title: 'Pipe Buyer Fees & Tax Control Center',
            subtitle:
                'Authoritative marketplace fee rules are loaded from the server billing engine. Tax status below reflects Pipe Buyer application gates; legal tax registrations remain controlled by the tax authority and Stripe Tax registrations.',
            icon: Icons.price_check_outlined,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusChip(
                label: 'Stripe mode',
                value: '${readiness['stripeMode'] ?? 'unknown'}'.toUpperCase(),
                enabled: readiness['stripeMode'] == 'production',
              ),
              _StatusChip(
                label: 'Fee billing',
                value: feeBilling ? 'LIVE' : 'OFF',
                enabled: feeBilling,
              ),
              _StatusChip(
                label: 'Dispatch billing',
                value: subscriptions ? 'LIVE' : 'OFF',
                enabled: subscriptions,
              ),
              _StatusChip(
                label: 'Seller Connect',
                value: connect ? 'LIVE' : 'OFF',
                enabled: connect,
              ),
              _StatusChip(
                label: 'Signed webhook',
                value: webhook ? 'VERIFIED' : 'NOT VERIFIED',
                enabled: webhook,
              ),
              _StatusChip(
                label: 'Full marketplace checkout',
                value: fullCheckout ? 'LIVE' : 'HELD',
                enabled: fullCheckout,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            icon: Icons.straighten_outlined,
            title: 'Pipe marketplace fee',
            trailing: 'Schedule ${catalog['scheduleRevision'] ?? '—'}',
          ),
          const SizedBox(height: 8),
          _FeeCard(
            title: 'Pipe / tubing / casing / OCTG',
            headline:
                'CAD \$${_moneyAmount(pipe['unitFeeByCurrency'], 'CAD').toStringAsFixed(2)} per stick',
            lines: [
              'Minimum fee: CAD \$${_moneyAmount(pipe['minimumFeeByCurrency'], 'CAD').toStringAsFixed(2)}',
              'Maximum fee: CAD \$${_moneyAmount(pipe['maximumFeeByCurrency'], 'CAD').toStringAsFixed(2)}',
              'USD rule: \$${_moneyAmount(pipe['unitFeeByCurrency'], 'USD').toStringAsFixed(2)} per stick • minimum \$${_moneyAmount(pipe['minimumFeeByCurrency'], 'USD').toStringAsFixed(2)} • maximum \$${_moneyAmount(pipe['maximumFeeByCurrency'], 'USD').toStringAsFixed(2)}',
              'Fee payer: ${catalog['feePayer'] ?? 'seller'}',
              'External-settlement sales use the same fee schedule.',
            ],
            icon: Icons.linear_scale_outlined,
          ),
          const SizedBox(height: 18),
          const _SectionTitle(
            icon: Icons.precision_manufacturing_outlined,
            title: 'Equipment & asset marketplace fees',
          ),
          const SizedBox(height: 8),
          _FeeCard(
            title: 'Heavy equipment, vehicles, buildings & other assets',
            headline:
                'Minimum CAD \$${_moneyAmount(equipment['minimumFeeByCurrency'], 'CAD').toStringAsFixed(2)}',
            lines: [
              for (var index = 0; index < tiers.length; index++)
                _tierLabel(tiers, index),
            ],
            icon: Icons.construction_outlined,
          ),
          const SizedBox(height: 18),
          const _SectionTitle(
            icon: Icons.local_shipping_outlined,
            title: 'Dispatch subscription fees',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _FeeCard(
                  title: 'Dispatch Monthly',
                  headline:
                      '${monthly['currency'] ?? 'CAD'} \$${((monthly['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} / month',
                  lines: const ['Recurring Stripe Billing subscription'],
                  icon: Icons.calendar_month_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FeeCard(
                  title: 'Dispatch Yearly',
                  headline:
                      '${yearly['currency'] ?? 'CAD'} \$${((yearly['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} / year',
                  lines: const ['Recurring Stripe Billing subscription'],
                  icon: Icons.event_repeat_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionTitle(
            icon: Icons.hub_outlined,
            title: 'Affiliate share',
          ),
          const SizedBox(height: 8),
          _FeeCard(
            title: 'Affiliate commission allocation',
            headline:
                '${((affiliate['sharePercent'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}% of the Pipe Buyer marketplace fee',
            lines: const [
              'Calculated from Pipe Buyer fee revenue, not from the buyer-seller gross sale price.',
              'Affiliate payout activation remains separately gated.',
            ],
            icon: Icons.group_work_outlined,
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            icon: Icons.account_balance_outlined,
            title: 'Tax configuration',
            trailing: taxStatus,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statusRow(
                    'Canadian GST/HST registration',
                    taxReady
                        ? 'Tax-ready'
                        : taxPending
                            ? 'Pending confirmation'
                            : 'Not ready',
                    taxReady,
                    pending: taxPending,
                  ),
                  _statusRow(
                    'Automatic tax for full buyer-to-seller checkout',
                    fullCheckout ? 'Enabled' : 'Held until tax-ready',
                    fullCheckout,
                    pending: !fullCheckout,
                  ),
                  const Divider(height: 24),
                  Text(
                    'Stripe tax codes',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text('Physical marketplace goods: ${taxCodes['defaultPhysicalGoods'] ?? '—'}'),
                  Text('Pipe Buyer marketplace service fee: ${taxCodes['marketplaceService'] ?? '—'}'),
                  Text('Dispatch SaaS: ${taxCodes['dispatchSaas'] ?? '—'}'),
                  const SizedBox(height: 10),
                  const Text(
                    'Stripe processing costs are provider charges and are not part of the Pipe Buyer marketplace fee schedule shown above.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh live fee & tax status'),
          ),
        ],
      ),
    );
  }

  String _tierLabel(List<Map<String, dynamic>> tiers, int index) {
    final tier = tiers[index];
    final percent = (tier['feePercent'] as num?)?.toDouble() ?? 0;
    final upper = (tier['upToExclusive'] as num?)?.toDouble();
    final lower = index == 0
        ? 0.0
        : ((tiers[index - 1]['upToExclusive'] as num?)?.toDouble() ?? 0);
    if (upper == null) {
      return '${percent.toStringAsFixed(0)}% on sales of CAD \$${lower.toStringAsFixed(0)} and above';
    }
    return '${percent.toStringAsFixed(0)}% on sales from CAD \$${lower.toStringAsFixed(0)} to under CAD \$${upper.toStringAsFixed(0)}';
  }

  Widget _statusRow(
    String label,
    String value,
    bool enabled, {
    bool pending = false,
  }) {
    final color = enabled
        ? Colors.green
        : pending
            ? Colors.orange
            : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            enabled
                ? Icons.check_circle
                : pending
                    ? Icons.schedule
                    : Icons.cancel,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
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
              title: Text('Marketplace transaction lifecycle records'),
              subtitle: Text(
                'Provider-authored payment and fee fields are recorded alongside marketplace lifecycle state. Use the Fees & Tax tab for the authoritative current fee schedule.',
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
                  final lifecycleStatus = '${data['status'] ?? 'recorded'}'.trim();
                  final providerStatus =
                      '${data['paymentProviderStatus'] ?? data['providerPaymentStatus'] ?? 'not connected'}'
                          .trim();
                  final feeStatus = '${data['marketplaceFeeStatus'] ?? 'not billed'}';

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Lifecycle: $lifecycleStatus\nPayment: $providerStatus • Fee: $feeStatus',
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

class _AdminBanner extends StatelessWidget {
  const _AdminBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30, color: colors.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.onSecondaryContainer,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.onSecondaryContainer),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    required this.enabled,
  });

  final String label;
  final String value;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.green : Colors.orange;
    return Chip(
      avatar: Icon(
        enabled ? Icons.check_circle_outline : Icons.info_outline,
        size: 18,
        color: color,
      ),
      label: Text('$label: $value'),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;

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
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({
    required this.title,
    required this.headline,
    required this.lines,
    required this.icon,
  });

  final String title;
  final String headline;
  final List<String> lines;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(icon)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              headline,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(line)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
