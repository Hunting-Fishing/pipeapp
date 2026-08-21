import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';
import 'marketplace_policy_center.dart';

bool dispatchMembershipStatusActive(Map<String, dynamic>? data) =>
    data != null && data['active'] == true;

bool dispatchHostedStripeSurfaceAllowed({required bool isWeb}) => isWeb;

String dispatchMembershipPaidThrough(Map<String, dynamic>? data) {
  final millis = (data?['currentPeriodEndMillis'] as num?)?.toInt();
  if (millis == null || millis <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

Map<String, dynamic> _stringMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String dispatchSubscriptionPriceLabel(
  Map<String, dynamic>? catalog,
  String plan,
) {
  final plans = _stringMap(catalog?['plans']);
  final entry = _stringMap(plans[plan]);
  final amountMinor = (entry['amountMinor'] as num?)?.toInt();
  final amount = amountMinor != null
      ? amountMinor / 100
      : (entry['amount'] as num?)?.toDouble();
  if (amount == null || amount < 0) return 'Price unavailable';
  final currency = '${entry['currency'] ?? 'CAD'}'.toUpperCase();
  final interval = '${entry['interval'] ?? ''}'.trim().toLowerCase();
  if (interval.isEmpty) return 'Price unavailable';
  final amountText = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  final prefix = currency == 'CAD' ? 'CA\$' : '$currency \$';
  return '$prefix$amountText / $interval';
}

class MarketplaceDispatchMembershipPage extends StatefulWidget {
  const MarketplaceDispatchMembershipPage({super.key});

  @override
  State<MarketplaceDispatchMembershipPage> createState() =>
      _MarketplaceDispatchMembershipPageState();
}

class _MarketplaceDispatchMembershipPageState
    extends State<MarketplaceDispatchMembershipPage> {
  final _commands = MarketplaceCommandClient();
  late Future<Map<String, dynamic>> _status;
  late Future<Map<String, dynamic>> _catalog;
  String? _busyPlan;
  bool _portalBusy = false;

  @override
  void initState() {
    super.initState();
    _status = _loadStatus();
    _catalog = dispatchHostedStripeSurfaceAllowed(isWeb: kIsWeb)
        ? _loadCatalog()
        : Future.value(const {});
  }

  Future<Map<String, dynamic>> _loadStatus() =>
      _commands.execute('getDispatchSubscriptionStatus', const {});

  Future<Map<String, dynamic>> _loadCatalog() =>
      _commands.execute('getDispatchSubscriptionCatalog', const {});

  void _refresh() {
    setState(() {
      _status = _loadStatus();
      if (dispatchHostedStripeSurfaceAllowed(isWeb: kIsWeb)) {
        _catalog = _loadCatalog();
      }
    });
  }

  Future<void> _openPolicies() async {
    if (!dispatchHostedStripeSurfaceAllowed(isWeb: kIsWeb)) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MarketplacePolicyCenterPage(),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _checkout(String plan) async {
    if (!dispatchHostedStripeSurfaceAllowed(isWeb: kIsWeb) ||
        _busyPlan != null ||
        _portalBusy) {
      return;
    }
    setState(() => _busyPlan = plan);
    try {
      final result = await _commands.execute(
        'createDispatchSubscriptionCheckout',
        {'plan': plan},
        timeout: const Duration(seconds: 45),
      );
      final uri = Uri.tryParse('${result['checkoutUrl'] ?? ''}');
      if (uri == null || uri.scheme != 'https') {
        throw StateError('Stripe did not return a valid membership checkout.');
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw StateError('Secure Stripe Checkout could not be opened.');
      }
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(
          error,
          fallback: 'Dispatch membership checkout could not be started.',
        ),
        tone: PipeStatusTone.error,
      );
      _refresh();
    } finally {
      if (mounted) setState(() => _busyPlan = null);
    }
  }

  Future<void> _openPortal() async {
    if (!dispatchHostedStripeSurfaceAllowed(isWeb: kIsWeb) ||
        _portalBusy ||
        _busyPlan != null) {
      return;
    }
    setState(() => _portalBusy = true);
    try {
      final result = await _commands.execute(
        'createDispatchSubscriptionPortalSession',
        const {},
        timeout: const Duration(seconds: 30),
      );
      final uri = Uri.tryParse('${result['portalUrl'] ?? ''}');
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.toLowerCase() != 'billing.stripe.com') {
        throw StateError('Stripe did not return a valid billing management link.');
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw StateError('Stripe subscription management could not be opened.');
      }
    } catch (error) {
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: marketplaceCommandErrorMessage(
          error,
          fallback: 'Dispatch subscription management is unavailable.',
        ),
        tone: PipeStatusTone.error,
      );
      _refresh();
    } finally {
      if (mounted) setState(() => _portalBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to manage Dispatch membership.')),
      );
    }
    final hostedStripeAllowed = dispatchHostedStripeSurfaceAllowed(isWeb: kIsWeb);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatch membership'),
        actions: [
          IconButton(
            tooltip: 'Refresh membership status',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _status,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final active = dispatchMembershipStatusActive(data);
          final paidThrough = dispatchMembershipPaidThrough(data);
          final paymentIssue = data?['paymentIssue'] == true;
          final cancelAtPeriodEnd = data?['cancelAtPeriodEnd'] == true;
          final managementAvailable = hostedStripeAllowed &&
              data?['managementAvailable'] == true;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _MembershipStatusCard(
                active: active,
                plan: '${data?['plan'] ?? ''}',
                paidThrough: paidThrough,
                paymentIssue: paymentIssue,
                cancelAtPeriodEnd: cancelAtPeriodEnd,
                managementAvailable: managementAvailable,
                managementBusy: _portalBusy,
                loading: snapshot.connectionState == ConnectionState.waiting,
                error: snapshot.hasError,
                onRetry: _refresh,
                onManage: _openPortal,
              ),
              const SizedBox(height: 16),
              if (!hostedStripeAllowed)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subscription purchasing is unavailable in this app build',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Existing active Dispatch memberships continue to work. New purchases and Stripe billing-management controls stay disabled here until the required native-store billing path is implemented.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                const Text(
                  'Choose your Dispatch membership',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Joining Dispatch is free. A paid membership is required before a carrier submits bids. Stripe securely handles recurring billing.',
                ),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, dynamic>>(
                  future: _catalog,
                  builder: (context, catalogSnapshot) {
                    final catalog = catalogSnapshot.data;
                    final checkoutAvailable = catalog?['checkoutAvailable'] == true;
                    final policyReviewRequired =
                        catalog?['policyAcceptanceRequired'] == true;
                    final catalogUnavailable = catalogSnapshot.hasError ||
                        catalogSnapshot.connectionState == ConnectionState.waiting;
                    final statusUnavailable = snapshot.hasError ||
                        snapshot.connectionState == ConnectionState.waiting;
                    final checkoutDisabled = active ||
                        _busyPlan != null ||
                        _portalBusy ||
                        statusUnavailable ||
                        catalogUnavailable ||
                        !checkoutAvailable;
                    final cards = [
                      _PlanCard(
                        title: 'Dispatch Monthly',
                        price: dispatchSubscriptionPriceLabel(catalog, 'monthly'),
                        description:
                            'Flexible recurring Dispatch carrier bidding access.',
                        icon: Icons.calendar_month_outlined,
                        busy: _busyPlan == 'monthly',
                        disabled: checkoutDisabled,
                        onPressed: () => _checkout('monthly'),
                      ),
                      _PlanCard(
                        title: 'Dispatch Yearly',
                        price: dispatchSubscriptionPriceLabel(catalog, 'yearly'),
                        description:
                            'Annual recurring Dispatch carrier bidding access.',
                        icon: Icons.calendar_today_outlined,
                        busy: _busyPlan == 'yearly',
                        disabled: checkoutDisabled,
                        onPressed: () => _checkout('yearly'),
                      ),
                    ];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (catalogSnapshot.hasError)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Current subscription pricing could not be verified from the server. Payment is disabled until pricing is available.',
                            ),
                          )
                        else if (!catalogUnavailable &&
                            policyReviewRequired &&
                            !active) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Review and accept the current Pipe Buyer policies before starting Dispatch billing. No charge has been created.',
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _openPolicies,
                              icon: const Icon(Icons.fact_check_outlined),
                              label: const Text('Review current policies'),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else if (!catalogUnavailable &&
                            !checkoutAvailable &&
                            !active)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Dispatch subscription checkout is currently held by Pipe Buyer payment-readiness controls.',
                            ),
                          ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 720) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: cards[0]),
                                  const SizedBox(width: 14),
                                  Expanded(child: cards[1]),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                cards[0],
                                const SizedBox(height: 12),
                                cards[1],
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFFEAF4FD),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_outline),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pipe Buyer never accepts a subscription amount from the app. The server selects the approved Stripe Price ID and Stripe confirms payment by signed webhook before membership is treated as paid.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class MarketplacePaymentReturnPage extends StatelessWidget {
  const MarketplacePaymentReturnPage({
    super.key,
    required this.success,
  });

  final bool success;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(success ? 'Payment submitted' : 'Payment cancelled')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        success ? Icons.verified_outlined : Icons.cancel_outlined,
                        size: 54,
                        color: success
                            ? PipeBuyerColors.success
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        success
                            ? 'Stripe received your checkout submission'
                            : 'Checkout was cancelled',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        success
                            ? 'Pipe Buyer does not grant paid access from this browser redirect. Your membership becomes active only after Stripe confirms the paid invoice through the signed server webhook.'
                            : 'Pipe Buyer does not mark a membership paid when checkout is cancelled. You can return to membership options whenever you are ready.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                const MarketplaceDispatchMembershipPage(),
                          ),
                        ),
                        icon: const Icon(Icons.workspace_premium_outlined),
                        label: const Text('View Dispatch membership'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _MembershipStatusCard extends StatelessWidget {
  const _MembershipStatusCard({
    required this.active,
    required this.plan,
    required this.paidThrough,
    required this.paymentIssue,
    required this.cancelAtPeriodEnd,
    required this.managementAvailable,
    required this.managementBusy,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onManage,
  });

  final bool active;
  final String plan;
  final String paidThrough;
  final bool paymentIssue;
  final bool cancelAtPeriodEnd;
  final bool managementAvailable;
  final bool managementBusy;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => Card(
        color: active ? const Color(0xFFE8F7F1) : const Color(0xFFFFF4E5),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(active ? Icons.verified_outlined : Icons.info_outline),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loading
                          ? 'Checking membership…'
                          : error
                              ? 'Membership status unavailable'
                              : active
                                  ? 'Dispatch membership active'
                                  : 'No active paid membership',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (active)
                      Text(
                        '${plan.trim().isEmpty ? 'Dispatch' : plan.trim()}${paidThrough.isEmpty ? '' : ' • paid through $paidThrough'}',
                      ),
                    if (active && paymentIssue) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Stripe reported a payment issue. Your already-paid access remains valid only through the paid-through date shown above.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (active && cancelAtPeriodEnd) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Renewal is cancelled at period end. Dispatch access remains available through the paid-through date shown above.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (managementAvailable && !loading && !error) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: managementBusy ? null : onManage,
                        icon: managementBusy
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.manage_accounts_outlined),
                        label: Text(
                          managementBusy
                              ? 'Opening Stripe…'
                              : 'Manage billing with Stripe',
                        ),
                      ),
                    ],
                    if (error)
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.description,
    required this.icon,
    required this.busy,
    required this.disabled,
    required this.onPressed,
  });

  final String title;
  final String price;
  final String description;
  final IconData icon;
  final bool busy;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 34, color: PipeBuyerColors.orange),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                price,
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(description),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: disabled ? null : onPressed,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline),
                  label: Text(busy ? 'Opening secure checkout…' : 'Continue to Secure Payment'),
                ),
              ),
            ],
          ),
        ),
      );
}
