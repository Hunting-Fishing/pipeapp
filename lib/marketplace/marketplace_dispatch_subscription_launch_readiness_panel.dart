import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';
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

    final portalEnabled = _portal['enabled'] == true;
    final portalId = '${_portal['stripePortalConfigurationId'] ?? ''}'.trim();
    final portalProviderVerified = _portal['providerVerified'] == true;
    final portalVerifiedId =
        '${_portal['providerVerifiedConfigurationId'] ?? ''}'.trim();
    final portalProviderRevision =
        '${_portal['providerVerificationRevision'] ?? ''}'.trim();
    final portalReady = portalEnabled &&
        portalProviderVerified &&
        portalId.startsWith('bpc_') &&
        portalVerifiedId == portalId &&
        portalProviderRevision.isNotEmpty;

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

    final prerequisiteStates = <bool>[
      portalReady,
      coreWebhook,
      lifecycle,
      recovery,
      reconciliation,
      taxPrepared,
    ];
    final readyCount = prerequisiteStates.where((ready) => ready).length;
    final providerPrerequisites = readyCount == prerequisiteStates.length;
    final nextAction = _nextAction(
      portalReady: portalReady,
      coreWebhook: coreWebhook,
      lifecycle: lifecycle,
      recovery: recovery,
      reconciliation: reconciliation,
      taxPrepared: taxPrepared,
      subscriptions: subscriptions,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  color: PipeBuyerColors.industrialBlue,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dispatch launch readiness',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Production prerequisites only. Nothing on this card activates public subscriptions.',
                        style: TextStyle(
                          color: PipeBuyerColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  label: subscriptions ? 'BILLING ON' : 'BILLING OFF',
                  ready: subscriptions,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: readyCount / prerequisiteStates.length,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$readyCount/${prerequisiteStates.length} verified',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _GateRow(
              label: 'Stripe Billing Portal',
              ready: portalReady,
              detail: portalReady
                  ? 'Provider-verified and bound to $portalId'
                  : 'Create the LIVE Portal configuration, then verify it with Stripe below',
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
                  ? 'Provider-verified against the live Stripe endpoint'
                  : 'Receiver deployment + live provider verification required',
            ),
            _GateRow(
              label: 'Smart Retry + failed-payment email',
              ready: recovery,
              detail: recovery
                  ? 'Administrator LIVE Dashboard review recorded'
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (providerPrerequisites
                        ? PipeBuyerColors.success
                        : PipeBuyerColors.warning)
                    .withValues(alpha: .07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (providerPrerequisites
                          ? PipeBuyerColors.success
                          : PipeBuyerColors.warning)
                      .withValues(alpha: .25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    providerPrerequisites
                        ? Icons.check_circle_outline_rounded
                        : Icons.route_outlined,
                    color: providerPrerequisites
                        ? PipeBuyerColors.success
                        : PipeBuyerColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          providerPrerequisites
                              ? 'Prerequisites ready'
                              : 'Recommended next action',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(nextAction),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 10),
              _MessageBox(message: _resultMessage!, error: false),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              _MessageBox(message: _error!, error: true),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _working ? null : _verifyLifecycleWebhook,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(
                    lifecycle
                        ? 'Re-verify lifecycle webhook'
                        : 'Verify live lifecycle webhook',
                  ),
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

String _nextAction({
  required bool portalReady,
  required bool coreWebhook,
  required bool lifecycle,
  required bool recovery,
  required bool reconciliation,
  required bool taxPrepared,
  required bool subscriptions,
}) {
  if (!portalReady) {
    return 'Create and review the LIVE Stripe Billing Portal, then use Verify & enable Billing Portal below.';
  }
  if (!coreWebhook) {
    return 'Verify the core signed Stripe webhook before subscription billing is considered.';
  }
  if (!lifecycle) {
    return 'After the accepted receiver is deployed, add the required Stripe subscription lifecycle events and run provider verification.';
  }
  if (!recovery) {
    return 'Review Smart Retry and failed-payment customer emails in the LIVE Stripe Dashboard, then record that review.';
  }
  if (!reconciliation) {
    return 'Complete the provider reconciliation readiness gate before controlled live acceptance.';
  }
  if (!taxPrepared) {
    return 'Complete the current authorized GST/HST billing state before collecting Dispatch subscription revenue.';
  }
  if (!subscriptions) {
    return 'All prerequisites are green. Proceed only with the documented controlled acceptance window; public activation remains a separate audited decision.';
  }
  return 'Dispatch subscriptions are enabled. Continue monitoring provider lifecycle, reconciliation, tax, and customer billing-management readiness.';
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
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ready ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 20,
              color: ready
                  ? PipeBuyerColors.success
                  : PipeBuyerColors.muted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 1),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: PipeBuyerColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.ready});

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? PipeBuyerColors.success : PipeBuyerColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? PipeBuyerColors.danger : PipeBuyerColors.success;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
