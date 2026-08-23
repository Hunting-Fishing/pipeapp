import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'marketplace_command_client.dart';
import 'marketplace_dispatch_subscription_client.dart';
import 'marketplace_dispatch_subscription_components.dart';

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
  int _loadGeneration = 0;

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
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final status = await _client.getStatus();
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _status = status);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Dispatch membership status could not be loaded.',
        );
      });
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
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
      return MarketplaceDispatchStatusFailure(
        message: _error,
        onRetry: _load,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarketplaceDispatchCurrentMembership(
          status: status,
          onRefresh: _load,
        ),
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
          const MarketplaceDispatchBillingManagementUnavailable(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          MarketplaceDispatchInlineError(message: _error!),
        ],
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              MarketplaceDispatchPlanCard(
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
              MarketplaceDispatchPlanCard(
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
