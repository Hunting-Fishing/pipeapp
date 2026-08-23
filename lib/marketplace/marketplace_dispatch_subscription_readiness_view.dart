import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

class MarketplaceDispatchSubscriptionReadinessView extends StatelessWidget {
  const MarketplaceDispatchSubscriptionReadinessView({
    super.key,
    required this.readiness,
    required this.portal,
    required this.working,
    required this.error,
    required this.resultMessage,
    required this.onVerifyLifecycleWebhook,
    required this.onToggleRecoveryVerification,
    required this.onRefresh,
  });

  final Map<String, dynamic> readiness;
  final Map<String, dynamic> portal;
  final bool working;
  final String? error;
  final String? resultMessage;
  final VoidCallback onVerifyLifecycleWebhook;
  final VoidCallback onToggleRecoveryVerification;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final portalEnabled = portal['enabled'] == true;
    final portalId = '${portal['stripePortalConfigurationId'] ?? ''}'.trim();
    final portalProviderVerified = portal['providerVerified'] == true;
    final portalVerifiedId =
        '${portal['providerVerifiedConfigurationId'] ?? ''}'.trim();
    final portalProviderRevision =
        '${portal['providerVerificationRevision'] ?? ''}'.trim();
    final portalReady = portalEnabled &&
        portalProviderVerified &&
        portalId.startsWith('bpc_') &&
        portalVerifiedId == portalId &&
        portalProviderRevision.isNotEmpty;

    final coreWebhook = readiness['stripeWebhookVerified'] == true;
    final lifecycle =
        readiness['stripeSubscriptionLifecycleWebhookVerified'] == true;
    final recovery = readiness['stripeSubscriptionRecoveryVerified'] == true;
    final reconciliation = readiness['stripeReconciliationReady'] == true;
    final subscriptions = readiness['stripeSubscriptionsEnabled'] == true;
    final taxPrepared = readiness['stripeTaxReady'] == true ||
        readiness['canadaGstHstSmallSupplier'] == true ||
        (readiness['stripeTaxRegistrationPending'] == true &&
            readiness['stripeTaxPendingBillingApproved'] == true);

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
    final nextAction = dispatchSubscriptionNextAction(
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
            if (resultMessage != null) ...[
              const SizedBox(height: 10),
              _MessageBox(message: resultMessage!, error: false),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              _MessageBox(message: error!, error: true),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: working ? null : onVerifyLifecycleWebhook,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(
                    lifecycle
                        ? 'Re-verify lifecycle webhook'
                        : 'Verify live lifecycle webhook',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: working ? null : onToggleRecoveryVerification,
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
                  onPressed: working ? null : onRefresh,
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

String dispatchSubscriptionNextAction({
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
