import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';
import 'marketplace_dispatch_membership_page.dart';

class MarketplaceDispatchSubscriptionBilling extends StatefulWidget {
  const MarketplaceDispatchSubscriptionBilling({super.key});

  @override
  State<MarketplaceDispatchSubscriptionBilling> createState() =>
      _MarketplaceDispatchSubscriptionBillingState();
}

class _MarketplaceDispatchSubscriptionBillingState
    extends State<MarketplaceDispatchSubscriptionBilling> {
  final MarketplaceCommandClient _commands = MarketplaceCommandClient();
  late Future<Map<String, dynamic>> _catalog;

  @override
  void initState() {
    super.initState();
    _catalog = _loadCatalog();
  }

  Future<Map<String, dynamic>> _loadCatalog() =>
      _commands.execute('getDispatchSubscriptionCatalog', const {});

  void _retry() {
    setState(() => _catalog = _loadCatalog());
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  String _priceLabel(Map<String, dynamic> plan, String fallbackInterval) {
    final currency = '${plan['currency'] ?? 'CAD'}'.toUpperCase();
    final amountMinor = (plan['amountMinor'] as num?)?.toInt();
    final amount = amountMinor != null
        ? amountMinor / 100
        : (plan['amount'] as num?)?.toDouble() ?? 0;
    final interval = '${plan['interval'] ?? fallbackInterval}'.toLowerCase();
    final amountText = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    final prefix = currency == 'CAD' ? 'CA\$' : '$currency \$';
    return '$prefix$amountText / $interval';
  }

  void _openMembership() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MarketplaceDispatchMembershipPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<Map<String, dynamic>>(
        future: _catalog,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final catalog = snapshot.data ?? const <String, dynamic>{};
          final plans = _map(catalog['plans']);
          final monthly = _map(plans['monthly']);
          final yearly = _map(plans['yearly']);
          final checkoutAvailable = catalog['checkoutAvailable'] == true;
          final taxStatus = '${catalog['taxCollectionStatus'] ?? ''}'.trim();

          return PipeBuyerSectionCard(
            title: 'Dispatch membership',
            subtitle: loading
                ? 'Loading the current Pipe Buyer subscription catalog…'
                : 'Current recurring Dispatch pricing comes from the same server-owned configuration used to create Stripe Checkout.',
            leading: const _BillingIcon(),
            trailing: PipeBuyerStatusBadge(
              label: loading
                  ? 'CHECKING'
                  : snapshot.hasError
                      ? 'UNAVAILABLE'
                      : checkoutAvailable
                          ? 'SECURE CHECKOUT'
                          : 'CHECKOUT HELD',
              icon: loading
                  ? Icons.sync_outlined
                  : snapshot.hasError
                      ? Icons.cloud_off_outlined
                      : checkoutAvailable
                          ? Icons.lock_outline
                          : Icons.shield_outlined,
              tone: snapshot.hasError || !checkoutAvailable
                  ? PipeBuyerStatusTone.warning
                  : PipeBuyerStatusTone.premium,
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : snapshot.hasError
                    ? Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Dispatch pricing could not be verified from the server. No fallback price is shown.',
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 700;
                              final width = wide
                                  ? (constraints.maxWidth - 12) / 2
                                  : constraints.maxWidth;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: width,
                                    child: _SubscriptionPriceCard(
                                      title: 'Dispatch Monthly',
                                      price: _priceLabel(monthly, 'month'),
                                      description:
                                          'Recurring carrier bidding access billed monthly.',
                                      icon: Icons.calendar_month_outlined,
                                    ),
                                  ),
                                  SizedBox(
                                    width: width,
                                    child: _SubscriptionPriceCard(
                                      title: 'Dispatch Yearly',
                                      price: _priceLabel(yearly, 'year'),
                                      description:
                                          'Recurring carrier bidding access billed annually.',
                                      icon: Icons.calendar_today_outlined,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          Text(
                            checkoutAvailable
                                ? 'Stripe-hosted Checkout opens only after the server confirms payment readiness. A browser return never grants paid access; signed Stripe provider evidence does.'
                                : 'Subscription checkout is currently held by server readiness controls. Viewing the plans does not start a charge.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  height: 1.45,
                                ),
                          ),
                          if (taxStatus.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Billing tax status: ${taxStatus.replaceAll('_', ' ')}.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _openMembership,
                            icon: const Icon(Icons.workspace_premium_outlined),
                            label: const Text('View membership options'),
                          ),
                        ],
                      ),
          );
        },
      );
}

class _BillingIcon extends StatelessWidget {
  const _BillingIcon();

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: PipeBuyerColors.orangeSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.sell_outlined,
          color: PipeBuyerColors.orangePressed,
        ),
      );
}

class _SubscriptionPriceCard extends StatelessWidget {
  const _SubscriptionPriceCard({
    required this.title,
    required this.price,
    required this.description,
    required this.icon,
  });

  final String title;
  final String price;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PipeBuyerColors.orangeSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: PipeBuyerColors.orange.withValues(alpha: .24),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: PipeBuyerColors.orangePressed),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
