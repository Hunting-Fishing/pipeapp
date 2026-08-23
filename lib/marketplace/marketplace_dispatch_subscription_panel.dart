import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design/pipe_buyer_theme.dart';
import 'marketplace_command_client.dart';
import 'marketplace_dispatch_subscription_client.dart';
import 'marketplace_subscription_artwork.dart';

class MarketplaceDispatchSubscriptionPanel extends StatefulWidget {
  const MarketplaceDispatchSubscriptionPanel({
    super.key,
    this.client,
  });

  final MarketplaceDispatchSubscriptionClient? client;

  @override
  State<MarketplaceDispatchSubscriptionPanel> createState() =>
      _MarketplaceDispatchSubscriptionPanelState();
}

class _MarketplaceDispatchSubscriptionPanelState
    extends State<MarketplaceDispatchSubscriptionPanel>
    with WidgetsBindingObserver {
  late final MarketplaceDispatchSubscriptionClient _client;
  MarketplaceDispatchSubscriptionStatus? _status;
  bool _loading = true;
  bool _workingBilling = false;
  String? _workingPlan;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _client = widget.client ?? MarketplaceDispatchSubscriptionClient();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        _workingPlan == null &&
        !_workingBilling) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final status = await _client.getStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Dispatch membership status could not be loaded.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkout(String plan) async {
    if (_workingPlan != null || _workingBilling) return;
    setState(() {
      _workingPlan = plan;
      _error = null;
    });
    try {
      final result = await _client.createCheckout(plan);
      if (!mounted) return;
      if (result.alreadySubscribed || result.processing) {
        await _load();
        return;
      }
      if (!result.canLaunchCheckout) {
        throw StateError('The secure Stripe Checkout link is unavailable.');
      }
      final uri = Uri.parse(result.checkoutUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw StateError('Secure Stripe Checkout could not be opened.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete payment in Stripe, then return to Pipe Buyer. Dispatch access updates automatically from the payment provider.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Dispatch Checkout could not be started.',
        );
      });
    } finally {
      if (mounted) setState(() => _workingPlan = null);
    }
  }

  Future<void> _manageBilling() async {
    if (_workingBilling || _workingPlan != null) return;
    setState(() {
      _workingBilling = true;
      _error = null;
    });
    try {
      final result = await _client.createBillingPortal();
      final launched = await launchUrl(
        Uri.parse(result.portalUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('Secure Stripe billing management could not be opened.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Dispatch billing management could not be opened.',
        );
      });
    } finally {
      if (mounted) setState(() => _workingBilling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _status == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final status = _status;
    if (status == null) {
      return _StatusFailure(message: _error, onRetry: _load);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CurrentDispatchMembership(status: status, onRefresh: _load),
        if (status.canManageBilling) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _workingBilling ? null : _manageBilling,
            icon: _workingBilling
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.manage_accounts_outlined),
            label: Text(
              _workingBilling
                  ? 'Opening secure billing…'
                  : 'Manage billing or cancel in Stripe',
            ),
          ),
        ] else if (status.alreadySubscribed) ...[
          const SizedBox(height: 10),
          const _BillingManagementUnavailable(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          _InlineError(message: _error!),
        ],
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _DispatchPlanCard(
                plan: 'monthly',
                title: 'Dispatch Monthly',
                eyebrow: 'FLEXIBLE DISPATCH ACCESS',
                artworkLabel: 'Transport & Hauling',
                catalog: status.monthly,
                status: status,
                working: _workingPlan == 'monthly',
                disabledByOtherWork:
                    _workingBilling ||
                    (_workingPlan != null && _workingPlan != 'monthly'),
                onCheckout: () => _checkout('monthly'),
              ),
              _DispatchPlanCard(
                plan: 'yearly',
                title: 'Dispatch Yearly',
                eyebrow: 'ANNUAL DISPATCH ACCESS',
                artworkLabel: 'Semi Truck',
                catalog: status.yearly,
                status: status,
                working: _workingPlan == 'yearly',
                disabledByOtherWork:
                    _workingBilling ||
                    (_workingPlan != null && _workingPlan != 'yearly'),
                onCheckout: () => _checkout('yearly'),
              ),
            ];
            if (constraints.maxWidth >= 560) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
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
        const SizedBox(height: 10),
        Text(
          'Payment and access state comes from Stripe webhooks and the Pipe Buyer server. Returning from Checkout does not activate membership by itself.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: .62),
              ),
        ),
      ],
    );
  }
}

class _CurrentDispatchMembership extends StatelessWidget {
  const _CurrentDispatchMembership({
    required this.status,
    required this.onRefresh,
  });

  final MarketplaceDispatchSubscriptionStatus status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final presentation = _statusPresentation(status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: presentation.color.withValues(alpha: .28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: presentation.color.withValues(alpha: .14),
            foregroundColor: presentation.color,
            child: Icon(presentation.icon),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(presentation.message),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh membership status',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

({String title, String message, Color color, IconData icon}) _statusPresentation(
  MarketplaceDispatchSubscriptionStatus status,
) {
  final planLabel = status.plan == 'yearly'
      ? 'Yearly'
      : status.plan == 'monthly'
          ? 'Monthly'
          : 'Dispatch';
  if (status.reviewRequired) {
    return (
      title: 'Billing review required',
      message:
          'A subscription conflict needs review before another payment can start.',
      color: PipeBuyerColors.danger,
      icon: Icons.report_problem_outlined,
    );
  }
  if (status.entitlementActive && status.paymentIssue) {
    return (
      title: '$planLabel membership — payment issue',
      message:
          'Access is currently retained while Stripe retries payment. Check billing promptly.',
      color: Colors.deepOrange,
      icon: Icons.credit_card_off_outlined,
    );
  }
  if (status.entitlementActive) {
    return (
      title: '$planLabel membership active',
      message: 'Dispatch access is active and confirmed by the payment provider.',
      color: PipeBuyerColors.success,
      icon: Icons.verified_outlined,
    );
  }
  if (status.processing || status.providerStatus == 'processing') {
    return (
      title: 'Payment processing',
      message:
          'Stripe is still confirming the membership. Do not start another payment.',
      color: PipeBuyerColors.industrialBlue,
      icon: Icons.hourglass_top_rounded,
    );
  }
  if (status.checkoutOpen && !status.billingAvailable) {
    return (
      title: 'Checkout temporarily unavailable',
      message:
          'Your existing Checkout is preserved. Dispatch purchasing is temporarily unavailable; refresh later before continuing.',
      color: PipeBuyerColors.warning,
      icon: Icons.pause_circle_outline_rounded,
    );
  }
  if (status.checkoutOpen) {
    return (
      title: '$planLabel Checkout open',
      message: 'Continue the existing secure Stripe Checkout instead of starting over.',
      color: PipeBuyerColors.industrialBlue,
      icon: Icons.open_in_new_rounded,
    );
  }
  if (status.alreadySubscribed) {
    return (
      title: '$planLabel subscription not active',
      message:
          'Stripe still has an existing subscription in ${status.providerStatus}. Resolve billing before starting another subscription.',
      color: Colors.deepOrange,
      icon: Icons.warning_amber_rounded,
    );
  }
  if (status.paymentIssue) {
    return (
      title: 'Membership inactive — payment issue',
      message: 'Dispatch access is not active. Resolve the provider billing state first.',
      color: Colors.deepOrange,
      icon: Icons.credit_card_off_outlined,
    );
  }
  if (status.hasRecord && status.providerStatus == 'canceled') {
    return (
      title: 'Dispatch membership canceled',
      message: 'No active Dispatch membership is currently confirmed.',
      color: PipeBuyerColors.muted,
      icon: Icons.cancel_outlined,
    );
  }
  if (!status.billingAvailable) {
    return (
      title: 'Dispatch subscriptions are not open yet',
      message:
          'You can review Monthly and Yearly plans below. Secure purchasing will be available when Pipe Buyer billing is ready.',
      color: PipeBuyerColors.industrialBlue,
      icon: Icons.schedule_outlined,
    );
  }
  return (
    title: 'No active Dispatch membership',
    message: 'Choose Monthly or Yearly below to continue to secure Stripe Checkout.',
    color: PipeBuyerColors.muted,
    icon: Icons.local_shipping_outlined,
  );
}

class _DispatchPlanCard extends StatelessWidget {
  const _DispatchPlanCard({
    required this.plan,
    required this.title,
    required this.eyebrow,
    required this.artworkLabel,
    required this.catalog,
    required this.status,
    required this.working,
    required this.disabledByOtherWork,
    required this.onCheckout,
  });

  final String plan;
  final String title;
  final String eyebrow;
  final String artworkLabel;
  final MarketplaceDispatchSubscriptionPlan catalog;
  final MarketplaceDispatchSubscriptionStatus status;
  final bool working;
  final bool disabledByOtherWork;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final isCurrentPlan = status.plan == plan;
    final continueCheckout = status.checkoutOpen && isCurrentPlan;
    final blockedByOpenOtherPlan = status.checkoutOpen && !isCurrentPlan;
    final canPress = status.billingAvailable &&
        !disabledByOtherWork &&
        !status.reviewRequired &&
        !status.processing &&
        !status.alreadySubscribed &&
        !blockedByOpenOtherPlan &&
        (status.canStartCheckout || continueCheckout);
    final existingLabel = status.entitlementActive
        ? 'Current membership'
        : 'Existing subscription needs billing attention';
    final buttonLabel = working
        ? 'Opening secure Checkout…'
        : !status.billingAvailable && !status.alreadySubscribed
            ? 'Subscriptions not available yet'
            : continueCheckout
                ? 'Continue secure Checkout'
                : status.alreadySubscribed &&
                        (isCurrentPlan || status.plan.isEmpty)
                    ? existingLabel
                    : status.alreadySubscribed
                        ? 'Existing ${status.plan} subscription'
                        : blockedByOpenOtherPlan
                            ? 'Finish ${status.plan} Checkout first'
                            : 'Choose $title';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentPlan
              ? PipeBuyerColors.orangePressed.withValues(alpha: .55)
              : Theme.of(context).dividerColor,
          width: isCurrentPlan ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarketplaceSubscriptionArtwork(
            planTitle: title,
            fallbackLabel: artworkLabel,
            height: 124,
          ),
          const SizedBox(height: 12),
          Text(
            eyebrow,
            style: const TextStyle(
              color: PipeBuyerColors.orangePressed,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${catalog.formattedPrice} / ${catalog.interval}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: PipeBuyerColors.industrialBlue,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Final tax treatment is confirmed by the approved Pipe Buyer billing state and secure Stripe Checkout.',
            style: TextStyle(color: PipeBuyerColors.muted, fontSize: 10.5),
          ),
          const SizedBox(height: 10),
          const _Benefit(text: 'Load, carrier, quote and awarded-job workflows'),
          const _Benefit(text: 'Secure provider-managed recurring billing'),
          const _Benefit(
            text: 'Dispatch billing stays separate from marketplace transaction funds',
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canPress && !working ? onCheckout : null,
              icon: working
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline_rounded),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 17,
              color: PipeBuyerColors.success,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.35),
              ),
            ),
          ],
        ),
      );
}

class _BillingManagementUnavailable extends StatelessWidget {
  const _BillingManagementUnavailable();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PipeBuyerColors.warning.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PipeBuyerColors.warning.withValues(alpha: .25)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.manage_accounts_outlined, color: PipeBuyerColors.warning),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Secure billing management is temporarily unavailable. Your subscription state is preserved. Refresh later or contact Pipe Buyer support if you need billing assistance.',
              ),
            ),
          ],
        ),
      );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PipeBuyerColors.danger.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PipeBuyerColors.danger.withValues(alpha: .25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: PipeBuyerColors.danger),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      );
}

class _StatusFailure extends StatelessWidget {
  const _StatusFailure({required this.message, required this.onRetry});
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 38),
              const SizedBox(height: 8),
              Text(
                message ?? 'Dispatch membership status could not be loaded.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}
