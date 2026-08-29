import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'marketplace_command_client.dart';

String dispatchSubscriptionPlanLabel(Map<String, dynamic>? plan) {
  if (plan == null) return 'Subscribe';
  final currency = '${plan['currency'] ?? 'CAD'}'.toUpperCase();
  final amount = num.tryParse('${plan['amount'] ?? ''}');
  final interval = '${plan['interval'] ?? ''}'.trim().toLowerCase();
  if (amount == null || amount <= 0 || interval.isEmpty) return 'Subscribe';
  final amountText = amount % 1 == 0
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
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
  late Future<Map<String, dynamic>> _viewFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _viewFuture = _loadView();
  }

  Future<Map<String, dynamic>> _loadView() async {
    final results = await Future.wait([
      MarketplaceCommandClient().execute(
        'getDispatchSubscriptionCatalog',
        const <String, Object?>{},
      ),
      MarketplaceCommandClient().execute(
        'getDispatchSubscriptionStatus',
        const <String, Object?>{},
      ),
    ]);
    return <String, dynamic>{'catalog': results[0], 'status': results[1]};
  }

  void _reload() => setState(() => _viewFuture = _loadView());

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

      final active = status['active'] == true;
      final managementAvailable = status['managementAvailable'] == true;
      final paymentIssue = status['paymentIssue'] == true;
      if (active) {
        if (managementAvailable) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _openPortal,
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
            ),
          );
        }
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Dispatch membership active'),
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
            label: Text(!policiesCurrent ? 'Review terms to subscribe' : price),
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
            _busy ? 'Opening secure checkout…' : 'Subscribe • $price',
          ),
        ),
      );
    },
  );

  Future<void> _startCheckout() async {
    await _openProviderUrl(
      command: 'createDispatchSubscriptionCheckout',
      payload: <String, Object?>{'plan': widget.plan},
      resultField: 'checkoutUrl',
      expectedHostSuffix: 'stripe.com',
      openingMessage: 'Secure subscription checkout could not be opened.',
    );
  }

  Future<void> _openPortal() async {
    await _openProviderUrl(
      command: 'createDispatchSubscriptionPortalSession',
      payload: const <String, Object?>{},
      resultField: 'portalUrl',
      expectedHostSuffix: 'stripe.com',
      openingMessage: 'Dispatch billing management could not be opened.',
    );
  }

  Future<void> _openProviderUrl({
    required String command,
    required Map<String, Object?> payload,
    required String resultField,
    required String expectedHostSuffix,
    required String openingMessage,
  }) async {
    if (_busy) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            marketplaceCommandErrorMessage(
              error,
              fallback: '$openingMessage No charge was created.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
