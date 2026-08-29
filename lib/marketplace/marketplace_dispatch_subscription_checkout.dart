import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dispatch_promotion_code_field.dart';
import 'marketplace_command_client.dart';
import 'marketplace_subscription_billing_policy.dart';

const dispatchPromotionCodeHelpText =
    'Have a promo code? Apply it before payment, or enter it on Stripe Checkout.';

bool dispatchPromotionCodeEntryAvailable(String plan) =>
    plan.trim().toLowerCase() == 'monthly';

String dispatchSubscriptionPlanLabel(Map<String, dynamic>? plan) {
  if (plan == null) return 'Subscribe';
  final currency = '${plan['currency'] ?? 'CAD'}'.toUpperCase();
  final amount = num.tryParse('${plan['amount'] ?? ''}');
  final interval = '${plan['interval'] ?? ''}'.trim().toLowerCase();
  if (amount == null || amount <= 0 || interval.isEmpty) return 'Subscribe';
  final amountText =
      amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  final currencyText = switch (currency) {
    'CAD' => 'CA\$$amountText',
    'USD' => 'US\$$amountText',
    _ => '$currency $amountText',
  };
  return '$currencyText / $interval';
}

class DispatchSubscriptionCheckoutButton extends StatefulWidget {
  const DispatchSubscriptionCheckoutButton({super.key, required this.plan});

  final String plan;

  @override
  State<DispatchSubscriptionCheckoutButton> createState() =>
      _DispatchSubscriptionCheckoutButtonState();
}

class _DispatchSubscriptionCheckoutButtonState
    extends State<DispatchSubscriptionCheckoutButton> {
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
    final statusFuture = MarketplaceCommandClient().execute(
      'getDispatchSubscriptionStatus',
      const <String, Object?>{},
    );
    if (!marketplaceHostedMembershipBillingAllowed()) {
      return <String, dynamic>{
        'catalog': const <String, dynamic>{},
        'status': await statusFuture,
      };
    }
    final results = await Future.wait([
      MarketplaceCommandClient().execute(
        'getDispatchSubscriptionCatalog',
        const <String, Object?>{},
      ),
      statusFuture,
    ]);
    return <String, dynamic>{'catalog': results[0], 'status': results[1]};
  }

  void _reload() => setState(() => _viewFuture = _loadView());

  void _promoChanged(String value) {
    if (_promoSummary.isEmpty) return;
    setState(() => _promoSummary = '');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _viewFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry subscription status'),
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
                label: const Text('Loading subscription…'),
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
          final planData = plans[widget.plan] is Map
              ? Map<String, dynamic>.from(plans[widget.plan] as Map)
              : null;
          final price = dispatchSubscriptionPlanLabel(planData);
          final hostedBillingAllowed =
              marketplaceHostedMembershipBillingAllowed();

          final active = status['active'] == true;
          final statusPlan = '${status['plan'] ?? ''}'.trim().toLowerCase();
          final managementAvailable = status['managementAvailable'] == true;
          final paymentIssue = status['paymentIssue'] == true;
          if (active) {
            if (!hostedBillingAllowed) {
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Dispatch membership active'),
                ),
              );
            }
            final managementButton = managementAvailable
                ? FilledButton.icon(
                    onPressed: _busy || _promoBusy ? null : _openPortal,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            paymentIssue
                                ? Icons.warning_amber_rounded
                                : Icons.manage_accounts_outlined,
                          ),
                    label: Text(
                      _busy
                          ? 'Opening billing…'
                          : paymentIssue
                              ? 'Fix billing / manage subscription'
                              : 'Manage Dispatch billing',
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Dispatch membership active'),
                  );
            if (statusPlan != 'monthly') {
              return SizedBox(width: double.infinity, child: managementButton);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                managementButton,
                const SizedBox(height: 12),
                DispatchPromotionCodeField(
                  controller: _promoController,
                  busy: _promoBusy,
                  enabled: !_busy,
                  appliedSummary: _promoSummary,
                  onChanged: _promoChanged,
                  onApply: _applyExistingPromotion,
                  applyLabel: 'Apply to subscription',
                  helperText:
                      'Already subscribed? Stripe checks eligibility and applies an accepted code to future eligible invoices. Your current paid period is not refunded.',
                ),
              ],
            );
          }

          if (!hostedBillingAllowed) {
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.info_outline_rounded),
                label: Text(marketplaceNativeSubscriptionUnavailableMessage),
              ),
            );
          }

          final checkoutAvailable = catalog['checkoutAvailable'] == true;
          final providerReady = catalog['providerCheckoutReady'] == true;
          final policiesCurrent = catalog['policyAcceptanceCurrent'] == true;
          if (!checkoutAvailable) {
            final message = !policiesCurrent
                ? 'Accept the current Pipe Buyer Terms and Privacy Policy, then retry.'
                : !providerReady
                    ? 'Dispatch subscription checkout is temporarily unavailable.'
                    : 'Dispatch subscription checkout is not available for this account yet.';
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message))),
                icon: const Icon(Icons.info_outline_rounded),
                label: Text(
                    !policiesCurrent ? 'Review terms to subscribe' : price),
              ),
            );
          }

          final promoEntryAvailable =
              dispatchPromotionCodeEntryAvailable(widget.plan);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (promoEntryAvailable) ...[
                Text(
                  dispatchPromotionCodeHelpText,
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
              ],
              FilledButton.icon(
                onPressed: _busy || _promoBusy ? null : _startCheckout,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline_rounded),
                label: Text(
                  _busy ? 'Opening secure checkout…' : 'Subscribe • $price',
                ),
              ),
            ],
          );
        },
      );

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
        'createDispatchSubscriptionCheckout',
        <String, Object?>{'plan': widget.plan, 'promotionCode': code},
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
          fallback: 'That promo code could not be applied. Check it and try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _promoBusy = false);
    }
  }

  Future<void> _applyExistingPromotion() async {
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
        'applyDispatchSubscriptionPromotionCode',
        <String, Object?>{'promotionCode': code},
      );
      if (result['applied'] != true) {
        throw StateError('Stripe did not confirm that promo code.');
      }
      final summary = '${result['promotionSummary'] ?? ''}'.trim();
      if (!mounted) return;
      setState(() {
        _promoSummary = summary.isEmpty
            ? 'Promo applied to future eligible invoices.'
            : 'Promo applied — $summary. Future eligible invoices will use it.';
      });
      _reload();
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        marketplaceCommandErrorMessage(
          error,
          fallback: 'That promo code could not be applied to this subscription.',
        ),
      );
    } finally {
      if (mounted) setState(() => _promoBusy = false);
    }
  }

  Future<void> _startCheckout() async {
    if (!marketplaceHostedMembershipBillingAllowed()) return;
    final payload = <String, Object?>{'plan': widget.plan};
    if (dispatchPromotionCodeEntryAvailable(widget.plan)) {
      final code = _promoController.text.trim();
      if (code.isNotEmpty) payload['promotionCode'] = code;
    }
    await _openProviderUrl(
      command: 'createDispatchSubscriptionCheckout',
      payload: payload,
      resultField: 'checkoutUrl',
      expectedHostSuffix: 'stripe.com',
      openingMessage: 'Secure subscription checkout could not be opened.',
    );
  }

  Future<void> _openPortal() async {
    if (!marketplaceHostedMembershipBillingAllowed()) return;
    await _openProviderUrl(
      command: 'createDispatchSubscriptionPortalSession',
      payload: const <String, Object?>{},
      resultField: 'portalUrl',
      expectedHostSuffix: 'stripe.com',
      openingMessage: 'Dispatch billing management could not be opened.',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openProviderUrl({
    required String command,
    required Map<String, Object?> payload,
    required String resultField,
    required String expectedHostSuffix,
    required String openingMessage,
  }) async {
    if (_busy || _promoBusy || !marketplaceHostedMembershipBillingAllowed()) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await MarketplaceCommandClient().execute(command, payload);
      final rawUrl = '${result[resultField] ?? ''}'.trim();
      final uri = Uri.tryParse(rawUrl);
      final host = uri?.host.toLowerCase() ?? '';
      if (uri == null ||
          uri.scheme != 'https' ||
          !(host == expectedHostSuffix ||
              host.endsWith('.$expectedHostSuffix'))) {
        throw StateError('Stripe did not return a valid secure URL.');
      }
      final opened = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!opened) throw StateError(openingMessage);
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        marketplaceCommandErrorMessage(
          error,
          fallback: '$openingMessage No charge was created.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
