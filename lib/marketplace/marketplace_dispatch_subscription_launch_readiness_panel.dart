import 'package:flutter/material.dart';

import 'marketplace_command_client.dart';
import 'marketplace_dispatch_subscription_readiness_view.dart';

class MarketplaceDispatchSubscriptionLaunchReadinessPanel
    extends StatefulWidget {
  const MarketplaceDispatchSubscriptionLaunchReadinessPanel({super.key});

  @override
  State<MarketplaceDispatchSubscriptionLaunchReadinessPanel> createState() =>
      _MarketplaceDispatchSubscriptionLaunchReadinessPanelState();
}

class _MarketplaceDispatchSubscriptionLaunchReadinessPanelState
    extends State<MarketplaceDispatchSubscriptionLaunchReadinessPanel> {
  final MarketplaceCommandClient _commands = MarketplaceCommandClient();

  Map<String, dynamic> _snapshot = const {};
  bool _loading = true;
  bool _working = false;
  String? _error;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await _commands.execute(
        'getDispatchSubscriptionLaunchReadiness',
        const {},
      );
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Dispatch launch readiness could not be loaded.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyLifecycleWebhook() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
      _resultMessage = null;
    });
    try {
      final result = await _commands.execute(
        'verifyDispatchSubscriptionLifecycleWebhook',
        const {},
        timeout: const Duration(seconds: 45),
      );
      final verified = result['verified'] == true;
      final missing = result['missingEvents'];
      final missingEvents = missing is List
          ? missing.map((value) => '$value').toList(growable: false)
          : const <String>[];
      if (!mounted) return;
      setState(() {
        _resultMessage = verified
            ? 'Live Stripe lifecycle webhook events are verified.'
            : 'Lifecycle verification is incomplete: ${missingEvents.isEmpty ? 'the production endpoint is unavailable or not live' : missingEvents.join(', ')}.';
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Live Stripe lifecycle events could not be verified.',
        );
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _toggleRecoveryVerification() => _setRecoveryVerified(
        _snapshot['recoveryReady'] != true,
      );

  Future<void> _setRecoveryVerified(bool verified) async {
    if (_working) return;
    if (verified) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm Stripe recovery verification'),
              content: const Text(
                'Confirm only after reviewing the LIVE Stripe Dashboard and verifying the intended Smart Retry policy and failed-payment customer email settings. This records an audited production-readiness assertion; it does not enable subscriptions.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('I verified this'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _working = true;
      _error = null;
      _resultMessage = null;
    });
    try {
      await _commands.execute(
        'setPaymentProviderReadiness',
        <String, Object?>{
          'patch': <String, Object?>{
            'stripeSubscriptionRecoveryVerified': verified,
          },
          'confirmProduction': true,
          'reason': verified
              ? 'Administrator verified live Stripe Smart Retry and failed-payment customer email recovery settings.'
              : 'Administrator revoked the prior Stripe subscription recovery verification pending a new review.',
        },
      );
      if (!mounted) return;
      setState(() {
        _resultMessage = verified
            ? 'Subscription recovery settings are recorded as verified.'
            : 'Subscription recovery verification was revoked.';
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = marketplaceCommandErrorMessage(
          error,
          fallback: 'Subscription recovery verification could not be updated.',
        );
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MarketplaceDispatchSubscriptionReadinessView(
      snapshot: _snapshot,
      working: _working,
      error: _error,
      resultMessage: _resultMessage,
      onVerifyLifecycleWebhook: _verifyLifecycleWebhook,
      onToggleRecoveryVerification: _toggleRecoveryVerification,
      onRefresh: _load,
    );
  }
}
