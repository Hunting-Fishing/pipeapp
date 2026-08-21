import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';

bool dispatchMembershipStatusActive(Map<String, dynamic>? data) =>
    data != null && data['active'] == true;

String dispatchMembershipPaidThrough(Map<String, dynamic>? data) {
  final millis = (data?['currentPeriodEndMillis'] as num?)?.toInt();
  if (millis == null || millis <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
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
  String? _busyPlan;

  @override
  void initState() {
    super.initState();
    _status = _loadStatus();
  }

  Future<Map<String, dynamic>> _loadStatus() =>
      _commands.execute('getDispatchSubscriptionStatus', const {});

  void _refreshStatus() {
    setState(() => _status = _loadStatus());
  }

  Future<void> _checkout(String plan) async {
    if (_busyPlan != null) return;
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
      _refreshStatus();
    } finally {
      if (mounted) setState(() => _busyPlan = null);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispatch membership'),
        actions: [
          IconButton(
            tooltip: 'Refresh membership status',
            onPressed: _refreshStatus,
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
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _MembershipStatusCard(
                active: active,
                plan: '${data?['plan'] ?? ''}',
                paidThrough: paidThrough,
                loading: snapshot.connectionState == ConnectionState.waiting,
                error: snapshot.hasError,
                onRetry: _refreshStatus,
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose your Dispatch membership',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Joining Dispatch is free. A paid membership is required before a carrier submits bids. Stripe securely handles recurring billing.',
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final statusUnavailable = snapshot.hasError ||
                      snapshot.connectionState == ConnectionState.waiting;
                  final cards = [
                    _PlanCard(
                      title: 'Dispatch Monthly',
                      price: r'CA$25 / month',
                      description:
                          'Flexible recurring Dispatch carrier bidding access.',
                      icon: Icons.calendar_month_outlined,
                      busy: _busyPlan == 'monthly',
                      disabled: active || _busyPlan != null || statusUnavailable,
                      onPressed: () => _checkout('monthly'),
                    ),
                    _PlanCard(
                      title: 'Dispatch Yearly',
                      price: r'CA$300 / year',
                      description:
                          'Annual recurring Dispatch carrier bidding access.',
                      icon: Icons.calendar_today_outlined,
                      busy: _busyPlan == 'yearly',
                      disabled: active || _busyPlan != null || statusUnavailable,
                      onPressed: () => _checkout('yearly'),
                    ),
                  ];
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
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final bool active;
  final String plan;
  final String paidThrough;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        color: active ? const Color(0xFFE8F7F1) : const Color(0xFFFFF4E5),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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