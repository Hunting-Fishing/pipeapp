import 'package:flutter/material.dart';

import 'marketplace_command_client.dart';

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

  Map<String, dynamic> _readiness = const {};
  Map<String, dynamic> _portal = const {};
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
      final responses = await Future.wait([
        _commands.execute('getPaymentProviderReadiness', const {}),
        _commands.execute('getDispatchBillingPortalReadiness', const {}),
      ]);
      if (!mounted) return;
      setState(() {
        _readiness = responses[0];
        _portal = responses[1];
      });
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

  Future<void> _setRecoveryVerified(bool verified) async {
    if (_working) return;
    if (verified) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm Stripe recovery verification'),
              content: const Text(
                'Confirm only after reviewing the live Stripe Dashboard and verifying the intended Smart Retry policy and failed-payment customer email settings. This records an audited production-readiness assertion; it does not enable subscriptions.',
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

    final portalEnabled = _portal['enabled'] == true;
    final portalId = '${_portal['stripePortalConfigurationId'] ?? ''}'.trim();
    final coreWebhook = _readiness['stripeWebhookVerified'] == true;
    final lifecycle =
        _readiness['stripeSubscriptionLifecycleWebhookVerified'] == true;
    final recovery = _readiness['stripeSubscriptionRecoveryVerified'] == true;
    final reconciliation = _readiness['stripeReconciliationReady'] == true;
    final subscriptions = _readiness['stripeSubscriptionsEnabled'] == true;
    final taxPrepared = _readiness['stripeTaxReady'] == true ||
        _readiness['canadaGstHstSmallSupplier'] == true ||
        (_readiness['stripeTaxRegistrationPending'] == true &&
            _readiness['stripeTaxPendingBillingApproved'] == true);
    final providerPrerequisites = portalEnabled &&
        portalId.startsWith('bpc_') &&
        coreWebhook &&
        lifecycle &&
        recovery &&
        reconciliation &&
        taxPrepared;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Dispatch launch readiness',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Prerequisite verification only. This panel cannot activate public subscriptions.',
            ),
            const SizedBox(height: 14),
            _GateRow(
              label: 'Stripe Billing Portal',
              ready: portalEnabled && portalId.startsWith('bpc_'),
              detail: portalId.isEmpty
                  ? 'No reviewed bpc_ configuration recorded'
                  : portalId,
            ),
            _GateRow(
              label: 'Core signed webhook',
              ready: coreWebhook,
              detail: coreWebhook ? 'Verified' : 'Not verified',
            ),
            _GateRow(
              label: 'Subscription lifecycle events',
              ready: lifecycle,
              detail: lifecycle
                  ? 'Provider-verified against live Stripe endpoint'
                  : 'Live provider verification required',
            ),
            _GateRow(
              label: 'Smart Retry + failed-payment email',
              ready: recovery,
              detail: recovery
                  ? 'Administrator Dashboard verification recorded'
                  : 'Stripe Dashboard review required',
            ),
            _GateRow(
              label: 'Provider reconciliation',
              ready: reconciliation,
              detail: reconciliation ? 'Ready' : 'Not ready',
            ),
            _GateRow(
              label: 'GST/HST billing state',
              ready: taxPrepared,
              detail: taxPrepared ? 'Authorized billing state' : 'Not prepared',
            ),
            _GateRow(
              label: 'Dispatch subscriptions',
              ready: subscriptions,
              detail: subscriptions ? 'ENABLED' : 'OFF',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                providerPrerequisites
                    ? 'Provider prerequisites are ready for the controlled acceptance phase. Public activation remains a separate audited action.'
                    : 'Controlled subscription acceptance remains blocked until every prerequisite above is green.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 10),
              Text(_resultMessage!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _working ? null : _verifyLifecycleWebhook,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Verify live lifecycle webhook'),
                ),
                OutlinedButton.icon(
                  onPressed: _working
                      ? null
                      : () => _setRecoveryVerified(!recovery),
                  icon: Icon(
                    recovery
                        ? Icons.remove_circle_outline
                        : Icons.mark_email_read_outlined,
                  ),
                  label: Text(
                    recovery
                        ? 'Revoke recovery verification'
                        : 'Record recovery verification',
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh launch readiness',
                  onPressed: _working ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GateRow extends StatelessWidget {
  const _GateRow({
    required this.label,
    required this.ready,
    required this.detail,
  });

  final String label;
  final bool ready;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ready ? Icons.check_circle_rounded : Icons.cancel_outlined,
              size: 20,
              color: ready
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
}
