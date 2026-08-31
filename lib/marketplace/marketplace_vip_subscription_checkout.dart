import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dispatch_promotion_code_field.dart';
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
  final _promoController = TextEditingController();
  late Future<Map<String, dynamic>> _viewFuture;
  bool _busy = false;
  bool _promoBusy = false;
  String _promoSummary = '';

  @override
  void initState() {
    super.initState();
    _viewFuture = _loadView();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
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

  void _promoChanged(String value) {
    if (_promoSummary.isEmpty) return;
    setState(() => _promoSummary = '');
  }

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
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: const Text('Loading VIP membership…'),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Have a promo code? Apply it before payment, or enter it on Stripe Checkout.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            DispatchPromotionCodeField(
              controller: _promoController,
              busy: _promoBusy,
              enabled: !_busy,
              appliedSummary: _promoSummary,
              onChanged: _promoChanged,
              onApply: _applyCheckoutPromotion,
              helperText:
                  'Apply it here before payment. If you leave it blank, Stripe Checkout also has a promo-code entry.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || _promoBusy ? null : _startCheckout,
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
          ],
        );
      },
    );
  }

  Future<void> _applyCheckoutPromotion() async {
    if (_promoBusy || _busy || !marketplaceHostedMembershipBillingAllowed()) {
      return;
    }
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      _showMessage('Enter a promo code first.');
      return;
    }
    setState(() {
      _promoBusy = true;
      _promoSummary = '';
    });
    try {
      final result = await MarketplaceCommandClient().execute(
        'createVipSubscriptionCheckout',
        <String, Object?>{'plan': 'monthly', 'promotionCode': code},
      );
      if (result['promotionCodeApplied'] != true) {
        throw StateError('Stripe did not confirm that promo code.');
      }
      final summary = '${result['promotionCodeSummary'] ?? ''}'.trim();
      if (!mounted) return;
      setState(() {
        _promoSummary = summary.isEmpty
            ? 'Promo code accepted by Stripe.'
            : 'Promo applied — $summary.';
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        marketplaceCommandErrorMessage(
          error,
          fallback:
              'That promo code could not be applied. Check it and try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _promoBusy = false);
    }
  }

  Future<void> _startCheckout() async {
    if (_busy || _promoBusy || !marketplaceHostedMembershipBillingAllowed()) {
      return;
    }
    final payload = <String, Object?>{'plan': 'monthly'};
    final code = _promoController.text.trim();
    if (code.isNotEmpty) payload['promotionCode'] = code;
    setState(() => _busy = true);
    try {
      final result = await MarketplaceCommandClient().execute(
        'createVipSubscriptionCheckout',
        payload,
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
      _showMessage(
        marketplaceCommandErrorMessage(
          error,
          fallback:
              'VIP checkout could not be opened. No charge was created.',
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
      _showMessage(
        marketplaceCommandErrorMessage(
          error,
          fallback: 'VIP renewal could not be updated safely.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}