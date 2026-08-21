import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design/pipe_buyer_components.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';
import 'marketplace_subscription_artwork.dart';

class MarketplaceDispatchSubscriptionBilling extends StatefulWidget {
  const MarketplaceDispatchSubscriptionBilling({super.key});

  @override
  State<MarketplaceDispatchSubscriptionBilling> createState() =>
      _MarketplaceDispatchSubscriptionBillingState();
}

class _MarketplaceDispatchSubscriptionBillingState
    extends State<MarketplaceDispatchSubscriptionBilling> {
  final MarketplaceCommandClient _commands = MarketplaceCommandClient();

  Map<String, dynamic>? _catalog;
  String? _loadingPlan;
  String? _error;
  bool _loadingCatalog = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  Future<void> _loadCatalog() async {
    if (mounted) {
      setState(() {
        _loadingCatalog = true;
        _error = null;
      });
    }
    try {
      final response = await _commands.execute(
        'getDispatchSubscriptionCatalog',
        const {},
      );
      if (!mounted) return;
      setState(() {
        _catalog = response;
        _loadingCatalog = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Dispatch subscription pricing is temporarily unavailable.',
        );
        _loadingCatalog = false;
      });
    }
  }

  Future<void> _startCheckout(String plan) async {
    if (_loadingPlan != null) return;
    setState(() {
      _loadingPlan = plan;
      _error = null;
    });
    try {
      final response = await _commands.execute(
        'createDispatchSubscriptionCheckout',
        {'plan': plan},
        timeout: const Duration(seconds: 45),
      );
      final rawUrl = '${response['checkoutUrl'] ?? ''}'.trim();
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw StateError('The secure payment link returned by the server is invalid.');
      }
      final opened = await launchUrl(uri);
      if (!opened) {
        throw StateError('The secure Stripe Checkout page could not be opened.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Secure Stripe Checkout opened. Membership activates only after Stripe confirms payment.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Secure Dispatch checkout could not be started.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loadingPlan = null);
      }
    }
  }

  String _priceLabel(Map<String, dynamic> plan, String fallbackInterval) {
    final currency = '${plan['currency'] ?? 'CAD'}'.toUpperCase();
    final amount = (plan['amount'] as num?)?.toDouble() ?? 0;
    final interval = '${plan['interval'] ?? fallbackInterval}'.toLowerCase();
    final amountText = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '$currency \$$amountText / $interval';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const PipeBuyerSectionCard(
        title: 'Dispatch membership',
        subtitle: 'Sign in to review Dispatch subscription options.',
        leading: Icon(Icons.lock_outline),
        child: Text('A signed-in Pipe Buyer account is required for billing.'),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? const <String, dynamic>{};
        final subscriptionStatus =
            '${userData['dispatchSubscriptionStatus'] ?? 'inactive'}'.toLowerCase();
        final subscriptionActiveFlag =
            userData['dispatchSubscriptionActive'] == true;
        final providerSubscriptionId =
            '${userData['stripeDispatchSubscriptionId'] ?? ''}'.trim();
        final active = subscriptionActiveFlag && subscriptionStatus == 'active';
        const terminalStatuses = {
          'canceled',
          'unpaid',
          'incomplete_expired',
          'paused',
          'inactive',
        };
        final hasExistingSubscription = subscriptionActiveFlag ||
            (providerSubscriptionId.startsWith('sub_') &&
                !terminalStatuses.contains(subscriptionStatus));
        final currentPlan =
            '${userData['dispatchSubscriptionPlan'] ?? ''}'.toLowerCase();
        final paymentStatus =
            '${userData['dispatchSubscriptionPaymentStatus'] ?? ''}'.toLowerCase();
        final paymentProblem =
            userData['dispatchSubscriptionPaymentProblem'] == true ||
                {'past_due', 'unpaid'}.contains(subscriptionStatus) ||
                paymentStatus == 'payment_failed';

        final catalog = _catalog ?? const <String, dynamic>{};
        final plans = _map(catalog['plans']);
        final monthly = _map(plans['monthly']);
        final yearly = _map(plans['yearly']);
        final checkoutAvailable = catalog['checkoutAvailable'] == true;
        final taxStatus = '${catalog['taxCollectionStatus'] ?? ''}'.trim();

        return PipeBuyerSectionCard(
          title: 'Dispatch membership',
          subtitle:
              'Choose Monthly or Yearly access. Prices and checkout availability come from the Pipe Buyer server.',
          leading: const Icon(Icons.credit_card_outlined),
          trailing: PipeBuyerStatusBadge(
            label: paymentProblem
                ? 'PAYMENT ATTENTION'
                : active
                    ? 'ACTIVE'
                    : checkoutAvailable
                        ? 'SECURE CHECKOUT'
                        : 'CHECKOUT HELD',
            icon: paymentProblem
                ? Icons.warning_amber_outlined
                : active
                    ? Icons.verified_outlined
                    : checkoutAvailable
                        ? Icons.lock_outline
                        : Icons.shield_outlined,
            tone: paymentProblem
                ? PipeBuyerStatusTone.warning
                : active
                    ? PipeBuyerStatusTone.success
                    : checkoutAvailable
                        ? PipeBuyerStatusTone.premium
                        : PipeBuyerStatusTone.warning,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (active) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.success.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: PipeBuyerColors.success.withValues(alpha: .24),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        color: PipeBuyerColors.success,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your ${currentPlan.isEmpty ? 'Dispatch' : currentPlan.toUpperCase()} membership is active. Stripe-confirmed invoice records are the authority for paid access.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (paymentProblem) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PipeBuyerColors.warning.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: PipeBuyerColors.warning.withValues(alpha: .24),
                    ),
                  ),
                  child: Text(
                    hasExistingSubscription
                        ? 'Stripe reported a payment problem on your existing Dispatch subscription. Resolve that subscription before starting another checkout; Pipe Buyer will not create a duplicate membership.'
                        : 'Stripe reported a payment problem. Paid membership is not granted from a browser redirect; provider confirmation is required.',
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (_loadingCatalog)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_catalog == null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error ?? 'Subscription pricing could not be loaded.',
                        style: const TextStyle(color: PipeBuyerColors.warning),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _loadCatalog,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                )
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final cardWidth = wide
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _SubscriptionPlanCard(
                            title: 'Dispatch Monthly',
                            price: _priceLabel(monthly, 'month'),
                            plan: 'monthly',
                            active: active,
                            selected: currentPlan == 'monthly',
                            enabled:
                                checkoutAvailable && !hasExistingSubscription,
                            loading: _loadingPlan == 'monthly',
                            onPressed: () => _startCheckout('monthly'),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _SubscriptionPlanCard(
                            title: 'Dispatch Yearly',
                            price: _priceLabel(yearly, 'year'),
                            plan: 'yearly',
                            active: active,
                            selected: currentPlan == 'yearly',
                            enabled:
                                checkoutAvailable && !hasExistingSubscription,
                            loading: _loadingPlan == 'yearly',
                            onPressed: () => _startCheckout('yearly'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  hasExistingSubscription && !active
                      ? 'An existing Stripe subscription is still on file. New checkout remains disabled until that subscription reaches a terminal state.'
                      : checkoutAvailable
                          ? 'Payment is completed on Stripe’s secure hosted Checkout. Pipe Buyer does not grant membership until a verified Stripe invoice event is processed.'
                          : 'Subscription checkout is currently held by server readiness controls. No payment will be attempted until those controls are satisfied.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .68),
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
              ],
              if (_error != null && _catalog != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: PipeBuyerColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SubscriptionPlanCard extends StatelessWidget {
  const _SubscriptionPlanCard({
    required this.title,
    required this.price,
    required this.plan,
    required this.active,
    required this.selected,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final String title;
  final String price;
  final String plan;
  final bool active;
  final bool selected;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MarketplaceSubscriptionArtwork(
                planTitle: title,
                fallbackLabel: title,
                height: 112,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                price,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: PipeBuyerColors.orangePressed,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                plan == 'monthly'
                    ? 'Recurring monthly Dispatch network access.'
                    : 'Recurring yearly Dispatch network access paid annually.',
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: enabled && !loading ? onPressed : null,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        selected && active
                            ? Icons.verified_outlined
                            : Icons.lock_outline,
                      ),
                label: Text(
                  selected && active
                      ? 'Current membership'
                      : loading
                          ? 'Opening secure checkout…'
                          : 'Continue to secure payment',
                ),
              ),
            ],
          ),
        ),
      );
}
