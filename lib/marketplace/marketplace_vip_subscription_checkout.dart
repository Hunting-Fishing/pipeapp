import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'marketplace_command_client.dart';
import 'marketplace_subscription_billing_policy.dart';
import 'membership_plan_management.dart';
import 'native_membership_billing.dart';

String vipSubscriptionPlanLabel(Map<String, dynamic>? plan) {
  if (plan == null) return 'VIP pricing unavailable';
  final currency = '${plan['currency'] ?? 'CAD'}'.toUpperCase();
  final amount = num.tryParse('${plan['amount'] ?? ''}');
  final interval = '${plan['interval'] ?? ''}'.trim().toLowerCase();
  if (amount == null || amount <= 0 || interval.isEmpty) {
    return 'VIP pricing unavailable';
  }
  final amountText =
      amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  final currencyText = switch (currency) {
    'CAD' => 'CA\$$amountText',
    'USD' => 'US\$$amountText',
    _ => '$currency $amountText',
  };
  return '$currencyText / $interval';
}

class VipSubscriptionCheckoutButton extends StatefulWidget {
  const VipSubscriptionCheckoutButton({super.key});

  @override
  State<VipSubscriptionCheckoutButton> createState() =>
      _VipSubscriptionCheckoutButtonState();
}

class _VipSubscriptionCheckoutButtonState
    extends State<VipSubscriptionCheckoutButton> {
  late Future<Map<String, dynamic>> _viewFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _viewFuture = _loadView();
  }

  Future<Map<String, dynamic>> _loadView() async {
    if (!marketplaceHostedMembershipBillingAllowed()) {
      return const <String, dynamic>{};
    }
    final results = await Future.wait([
      MarketplaceCommandClient().execute(
        'getVipSubscriptionCatalog',
        const <String, Object?>{},
      ),
      MarketplaceCommandClient().execute(
        'getVipSubscriptionStatus',
        const <String, Object?>{},
      ),
    ]);
    return <String, dynamic>{'catalog': results[0], 'status': results[1]};
  }

  void _reload() => setState(() => _viewFuture = _loadView());

  @override
  Widget build(BuildContext context) {
    if (!marketplaceHostedMembershipBillingAllowed()) {
      return const NativeMembershipPlanButton(targetPlan: 'vip_monthly');
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _viewFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry VIP status'),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: Text('Loading VIP membership…'),
            ),
          );
        }

        final view = snapshot.data ?? const <String, dynamic>{};
        final catalog = view['catalog'] is Map
            ? Map<String, dynamic>.from(view['catalog'] as Map)
            : const <String, dynamic>{};
        final status = view['status'] is Map
            ? Map<String, dynamic>.from(view['status'] as Map)
            : const <String, dynamic>{};
        final plans = catalog['plans'] is Map
            ? Map<String, dynamic>.from(catalog['plans'] as Map)
            : const <String, dynamic>{};
        final planData = plans['monthly'] is Map
            ? Map<String, dynamic>.from(plans['monthly'] as Map)
            : null;
        final price = vipSubscriptionPlanLabel(planData);
        final active = status['active'] == true;
        final canManageRenewal = status['canManageRenewal'] == true;
        final cancelAtPeriodEnd = status['cancelAtPeriodEnd'] == true;

        if (active) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MembershipPlanManagementButton(onChanged: _reload),
              if (canManageRenewal && cancelAtPeriodEnd) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      _busy ? null : () => _updateRenewal('resume_renewal'),
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.autorenew_rounded),
                  label: Text(
                    _busy ? 'Updating VIP…' : 'Resume VIP renewal',
                  ),
                ),
              ],
            ],
          );
        }

        final checkoutAvailable = catalog['checkoutAvailable'] == true;
        final providerReady = catalog['providerCheckoutReady'] == true;
        final policiesCurrent = catalog['policyAcceptanceCurrent'] == true;
        if (!checkoutAvailable) {
          final message = !policiesCurrent
              ? 'Accept the current Pipe Buyer Terms and Privacy Policy, then retry.'
              : !providerReady
                  ? 'VIP subscription checkout is temporarily unavailable.'
                  : 'VIP subscription checkout is not available for this account yet.';
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message))),
              icon: const Icon(Icons.info_outline_rounded),
              label:
                  Text(!policiesCurrent ? 'Review terms to subscribe' : price),
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _startCheckout,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_outline_rounded),
            label: Text(
              _busy ? 'Opening secure checkout…' : 'Join VIP • $price',
            ),
          ),
        );
      },
    );
  }

  Future<void> _startCheckout() async {
    if (_busy || !marketplaceHostedMembershipBillingAllowed()) return;
    setState(() => _busy = true);
    try {
      final result = await MarketplaceCommandClient().execute(
        'createVipSubscriptionCheckout',
        const <String, Object?>{'plan': 'monthly'},
      );
      final rawUrl = '${result['checkoutUrl'] ?? ''}'.trim();
      final uri = Uri.tryParse(rawUrl);
      final host = uri?.host.toLowerCase() ?? '';
      if (uri == null ||
          uri.scheme != 'https' ||
          !(host == 'stripe.com' || host.endsWith('.stripe.com'))) {
        throw StateError('Stripe did not return a valid secure URL.');
      }
      final opened = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('VIP checkout could not be opened.');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            marketplaceCommandErrorMessage(
              error,
              fallback:
                  'VIP checkout could not be opened. No charge was created.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateRenewal(String action) async {
    if (_busy || !marketplaceHostedMembershipBillingAllowed()) return;
    setState(() => _busy = true);
    try {
      await MarketplaceCommandClient().execute(
        'updateVipSubscriptionRenewal',
        <String, Object?>{'action': action},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('VIP automatic renewal has been restored.'),
        ),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            marketplaceCommandErrorMessage(
              error,
              fallback: 'VIP renewal could not be updated safely.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
