import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';
import 'marketplace_data_state.dart';

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
      return const MarketplaceDataStateView.loading(
        title: 'Loading billing readiness',
        message: 'Retrieving the live fee catalog and provider gates…',
      );
    }
    if (_error != null) {
      return MarketplaceDataStateView(
        kind: MarketplaceDataStateKind.error,
        title: 'Billing readiness could not be loaded',
        message: _error!,
        icon: Icons.account_balance_wallet_outlined,
        primaryLabel: 'Try again',
        primaryIcon: Icons.refresh,
        onPrimary: _load,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              wide ? 28 : 16,
              18,
              wide ? 28 : 16,
              32,
            ),
            children: [
              _ReadinessHero(
                mode: '${readiness['stripeMode'] ?? 'unknown'}'.toUpperCase(),
                scheduleRevision: '${catalog['scheduleRevision'] ?? '—'}',
                feeBilling: feeBilling,
                subscriptions: subscriptions,
                connect: connect,
                webhook: webhook,
                fullCheckout: fullCheckout,
                taxReady: taxReady,
                taxPending: taxPending,
              ),
              const SizedBox(height: 18),
              _ReadinessGrid(
                items: [
                  _ReadinessItem(
                    label: 'Fee billing',
                    value: feeBilling ? 'LIVE' : 'OFF',
                    icon: Icons.receipt_long_outlined,
                    enabled: feeBilling,
                  ),
                  _ReadinessItem(
                    label: 'Dispatch billing',
                    value: subscriptions ? 'LIVE' : 'OFF',
                    icon: Icons.local_shipping_outlined,
                    enabled: subscriptions,
                  ),
                  _ReadinessItem(
                    label: 'Seller Connect',
                    value: connect ? 'LIVE' : 'OFF',
                    icon: Icons.account_balance_outlined,
                    enabled: connect,
                  ),
                  _ReadinessItem(
                    label: 'Signed webhook',
                    value: webhook ? 'VERIFIED' : 'NOT VERIFIED',
                    icon: Icons.verified_user_outlined,
                    enabled: webhook,
                  ),
                  _ReadinessItem(
                    label: 'Marketplace checkout',
                    value: fullCheckout ? 'LIVE' : 'HELD',
                    icon: Icons.shopping_cart_checkout_outlined,
                    enabled: fullCheckout,
                  ),
                  _ReadinessItem(
                    label: 'Tax registration',
                    value: taxStatus.toUpperCase(),
                    icon: Icons.account_balance_wallet_outlined,
                    enabled: taxReady,
                    pending: taxPending,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _SectionTitle(
                icon: Icons.straighten_outlined,
                title: 'Pipe marketplace fee',
                subtitle: 'Pipe, tubing, casing and OCTG fee schedule',
                trailing: 'Schedule ${catalog['scheduleRevision'] ?? '—'}',
              ),
              const SizedBox(height: 10),
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
                accent: PipeBuyerColors.orange,
              ),
              const SizedBox(height: 22),
              const _SectionTitle(
                icon: Icons.precision_manufacturing_outlined,
                title: 'Equipment & asset marketplace fees',
                subtitle: 'Heavy equipment, vehicles, buildings and other assets',
              ),
              const SizedBox(height: 10),
              _FeeCard(
                title: 'Asset marketplace schedule',
                headline:
                    'Minimum CAD \$${_moneyAmount(equipment['minimumFeeByCurrency'], 'CAD').toStringAsFixed(2)}',
                lines: [
                  for (var index = 0; index < tiers.length; index++)
                    _tierLabel(tiers, index),
                ],
                icon: Icons.construction_outlined,
                accent: PipeBuyerColors.industrialBlue,
              ),
              const SizedBox(height: 22),
              const _SectionTitle(
                icon: Icons.local_shipping_outlined,
                title: 'Dispatch subscription fees',
                subtitle: 'Recurring Dispatch access plans from the live catalog',
              ),
              const SizedBox(height: 10),
              _ResponsiveFeePair(
                first: _FeeCard(
                  title: 'Dispatch Monthly',
                  headline:
                      '${monthly['currency'] ?? 'CAD'} \$${((monthly['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} / month',
                  lines: const ['Recurring Stripe Billing subscription'],
                  icon: Icons.calendar_month_outlined,
                  accent: PipeBuyerColors.orange,
                ),
                second: _FeeCard(
                  title: 'Dispatch Yearly',
                  headline:
                      '${yearly['currency'] ?? 'CAD'} \$${((yearly['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} / year',
                  lines: const ['Recurring Stripe Billing subscription'],
                  icon: Icons.event_repeat_outlined,
                  accent: PipeBuyerColors.success,
                ),
              ),
              const SizedBox(height: 22),
              const _SectionTitle(
                icon: Icons.hub_outlined,
                title: 'Affiliate share',
                subtitle: 'Marketplace-fee revenue allocation',
              ),
              const SizedBox(height: 10),
              _FeeCard(
                title: 'Affiliate commission allocation',
                headline:
                    '${((affiliate['sharePercent'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}% of the Pipe Buyer marketplace fee',
                lines: const [
                  'Calculated from Pipe Buyer fee revenue, not from the buyer-seller gross sale price.',
                  'Affiliate payout activation remains separately gated.',
                ],
                icon: Icons.group_work_outlined,
                accent: PipeBuyerColors.warning,
              ),
              const SizedBox(height: 26),
              _SectionTitle(
                icon: Icons.account_balance_outlined,
                title: 'Tax configuration',
                subtitle: 'Application readiness and configured Stripe tax codes',
                trailing: taxStatus,
              ),
              const SizedBox(height: 10),
              _TaxConfigurationCard(
                taxReady: taxReady,
                taxPending: taxPending,
                fullCheckout: fullCheckout,
                taxCodes: taxCodes,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh live fee & tax status'),
                ),
              ),
            ],
          );
        },
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
}

class MarketplaceTransactionRecordsPanel extends StatelessWidget {
  const MarketplaceTransactionRecordsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: PipeBuyerColors.orange,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marketplace lifecycle records',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Provider-authored payment and fee fields are recorded alongside marketplace lifecycle state. Use Fees & Tax for the authoritative current fee schedule.',
                        style: TextStyle(
                          color: Color(0xFFB7C1CE),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                return const MarketplaceDataStateView(
                  kind: MarketplaceDataStateKind.error,
                  title: 'Transaction records are unavailable',
                  message:
                      'The lifecycle record stream could not be loaded right now.',
                  icon: Icons.receipt_long_outlined,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const MarketplaceDataStateView.loading(
                  title: 'Loading lifecycle records',
                  message: 'Retrieving current transaction state…',
                );
              }

              final records = snapshot.data?.docs ?? const [];
              if (records.isEmpty) {
                return const MarketplaceDataStateView(
                  kind: MarketplaceDataStateKind.empty,
                  title: 'No marketplace lifecycle records',
                  message:
                      'Recorded marketplace transactions will appear here when available.',
                  icon: Icons.inventory_2_outlined,
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

                  return _TransactionRecordCard(
                    title: title,
                    lifecycleStatus: lifecycleStatus,
                    providerStatus: providerStatus,
                    feeStatus: feeStatus,
                    quantity: quantity,
                    total: total,
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

class _ReadinessHero extends StatelessWidget {
  const _ReadinessHero({
    required this.mode,
    required this.scheduleRevision,
    required this.feeBilling,
    required this.subscriptions,
    required this.connect,
    required this.webhook,
    required this.fullCheckout,
    required this.taxReady,
    required this.taxPending,
  });

  final String mode;
  final String scheduleRevision;
  final bool feeBilling;
  final bool subscriptions;
  final bool connect;
  final bool webhook;
  final bool fullCheckout;
  final bool taxReady;
  final bool taxPending;

  int get _readyCount => [
        feeBilling,
        subscriptions,
        connect,
        webhook,
        fullCheckout,
        taxReady,
      ].where((value) => value).length;

  @override
  Widget build(BuildContext context) {
    final count = _readyCount;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PipeBuyerColors.ink, PipeBuyerColors.graphite],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BILLING CONTROL CENTER',
                  style: TextStyle(
                    color: PipeBuyerColors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Fees & Tax Readiness',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Authoritative marketplace fee rules are loaded from the server billing engine. Tax status reflects Pipe Buyer application gates; legal registrations remain controlled by the tax authority and Stripe Tax registrations.',
                  style: TextStyle(
                    color: Color(0xFFB7C1CE),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            );

            final readiness = Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: PipeBuyerColors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'READINESS',
                        style: TextStyle(
                          color: Color(0xFFB7C1CE),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$count / 6',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: count / 6,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: Colors.white.withValues(alpha: .12),
                    color: PipeBuyerColors.orange,
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _HeroPill(label: mode, icon: Icons.cloud_outlined),
                      _HeroPill(
                        label: 'Schedule $scheduleRevision',
                        icon: Icons.rule_folder_outlined,
                      ),
                      _HeroPill(
                        label: taxReady
                            ? 'Tax ready'
                            : taxPending
                                ? 'Tax pending'
                                : 'Tax held',
                        icon: Icons.account_balance_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: 16),
                  readiness,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: identity),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: readiness),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: PipeBuyerColors.orange),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _ReadinessItem {
  const _ReadinessItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.enabled,
    this.pending = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool enabled;
  final bool pending;
}

class _ReadinessGrid extends StatelessWidget {
  const _ReadinessGrid({required this.items});

  final List<_ReadinessItem> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 3
              : constraints.maxWidth >= 620
                  ? 2
                  : 1;
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map((item) => SizedBox(
                      width: width,
                      child: _ReadinessStatusCard(item: item),
                    ))
                .toList(growable: false),
          );
        },
      );
}

class _ReadinessStatusCard extends StatelessWidget {
  const _ReadinessStatusCard({required this.item});

  final _ReadinessItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.enabled
        ? PipeBuyerColors.success
        : item.pending
            ? PipeBuyerColors.warning
            : PipeBuyerColors.muted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            item.enabled
                ? Icons.check_circle
                : item.pending
                    ? Icons.schedule
                    : Icons.remove_circle_outline,
            color: color,
            size: 19,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PipeBuyerColors.orangeSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: PipeBuyerColors.orange, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: PipeBuyerColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? PipeBuyerColors.darkSurfaceMuted
                    : PipeBuyerColors.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailing!,
                style: const TextStyle(
                  color: PipeBuyerColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      );
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({
    required this.title,
    required this.headline,
    required this.lines,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String headline;
  final List<String> lines;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              headline,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -.25,
              ),
            ),
            const SizedBox(height: 10),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: PipeBuyerColors.slate,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _ResponsiveFeePair extends StatelessWidget {
  const _ResponsiveFeePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 680) {
            return Column(
              children: [
                first,
                const SizedBox(height: 10),
                second,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 10),
              Expanded(child: second),
            ],
          );
        },
      );
}

class _TaxConfigurationCard extends StatelessWidget {
  const _TaxConfigurationCard({
    required this.taxReady,
    required this.taxPending,
    required this.fullCheckout,
    required this.taxCodes,
  });

  final bool taxReady;
  final bool taxPending;
  final bool fullCheckout;
  final Map<String, dynamic> taxCodes;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TaxStatusRow(
              label: 'Canadian GST/HST registration',
              value: taxReady
                  ? 'Tax-ready'
                  : taxPending
                      ? 'Pending confirmation'
                      : 'Not ready',
              enabled: taxReady,
              pending: taxPending,
            ),
            const SizedBox(height: 7),
            _TaxStatusRow(
              label: 'Automatic tax for full buyer-to-seller checkout',
              value: fullCheckout ? 'Enabled' : 'Held until tax-ready',
              enabled: fullCheckout,
              pending: !fullCheckout,
            ),
            const Divider(height: 28),
            const Text(
              'STRIPE TAX CODES',
              style: TextStyle(
                color: PipeBuyerColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            _TaxCodeRow(
              label: 'Physical marketplace goods',
              value: '${taxCodes['defaultPhysicalGoods'] ?? '—'}',
            ),
            _TaxCodeRow(
              label: 'Pipe Buyer marketplace service fee',
              value: '${taxCodes['marketplaceService'] ?? '—'}',
            ),
            _TaxCodeRow(
              label: 'Dispatch SaaS',
              value: '${taxCodes['dispatchSaas'] ?? '—'}',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: PipeBuyerColors.industrialBlue.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 17,
                    color: PipeBuyerColors.industrialBlue,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Stripe processing costs are provider charges and are not part of the Pipe Buyer marketplace fee schedule shown above.',
                      style: TextStyle(
                        color: PipeBuyerColors.slate,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _TaxStatusRow extends StatelessWidget {
  const _TaxStatusRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.pending,
  });

  final String label;
  final String value;
  final bool enabled;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? PipeBuyerColors.success
        : pending
            ? PipeBuyerColors.warning
            : PipeBuyerColors.danger;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          enabled
              ? Icons.check_circle
              : pending
                  ? Icons.schedule
                  : Icons.cancel,
          size: 19,
          color: color,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TaxCodeRow extends StatelessWidget {
  const _TaxCodeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: PipeBuyerColors.slate,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SelectableText(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}

class _TransactionRecordCard extends StatelessWidget {
  const _TransactionRecordCard({
    required this.title,
    required this.lifecycleStatus,
    required this.providerStatus,
    required this.feeStatus,
    required this.quantity,
    required this.total,
  });

  final String title;
  final String lifecycleStatus;
  final String providerStatus;
  final String feeStatus;
  final int quantity;
  final double total;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final content = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.orangeSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: PipeBuyerColors.orange,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _RecordPill(
                            label: 'Lifecycle',
                            value: lifecycleStatus,
                            icon: Icons.sync_alt_outlined,
                          ),
                          _RecordPill(
                            label: 'Payment',
                            value: providerStatus,
                            icon: Icons.payments_outlined,
                          ),
                          _RecordPill(
                            label: 'Fee',
                            value: feeStatus,
                            icon: Icons.price_check_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            final amount = Column(
              crossAxisAlignment:
                  compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Text(
                  total > 0 ? '\$${total.toStringAsFixed(2)}' : '—',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$quantity unit${quantity == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: PipeBuyerColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  const SizedBox(height: 12),
                  amount,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: content),
                const SizedBox(width: 16),
                amount,
              ],
            );
          },
        ),
      );
}

class _RecordPill extends StatelessWidget {
  const _RecordPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? PipeBuyerColors.darkSurfaceMuted
              : PipeBuyerColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: PipeBuyerColors.muted),
            const SizedBox(width: 4),
            Text(
              '$label: $value',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}
