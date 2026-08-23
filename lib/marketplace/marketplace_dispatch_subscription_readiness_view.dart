import 'package:flutter/material.dart';

import '../core/design/pipe_buyer_theme.dart';

class MarketplaceDispatchSubscriptionReadinessView extends StatelessWidget {
  const MarketplaceDispatchSubscriptionReadinessView({
    super.key,
    required this.snapshot,
    required this.working,
    required this.error,
    required this.resultMessage,
    required this.onVerifyLifecycleWebhook,
    required this.onToggleRecoveryVerification,
    required this.onRefresh,
  });

  final Map<String, dynamic> snapshot;
  final bool working;
  final String? error;
  final String? resultMessage;
  final VoidCallback onVerifyLifecycleWebhook;
  final VoidCallback onToggleRecoveryVerification;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final featureFlagsReady = snapshot['featureFlagsReady'] == true;
    final dispatchFeatureEnabled = snapshot['dispatchFeatureEnabled'] == true;
    final paidFeaturesEnabled = snapshot['paidFeaturesEnabled'] == true;
    final productionModeReady = snapshot['productionModeReady'] == true;
    final portalReady = snapshot['portalReady'] == true;
    final portalId = '${snapshot['portalConfigurationId'] ?? ''}'.trim();
    final coreWebhook = snapshot['coreWebhookReady'] == true;
    final lifecycle = snapshot['lifecycleWebhookReady'] == true;
    final recovery = snapshot['recoveryReady'] == true;
    final reconciliation = snapshot['reconciliationReady'] == true;
    final taxPrepared = snapshot['taxReady'] == true;
    final subscriptions = snapshot['subscriptionsEnabled'] == true;
    final providerPrerequisites = snapshot['prerequisitesReady'] == true;
    final readyCount = (snapshot['readyCount'] as num?)?.toInt() ?? 0;
    final prerequisiteCount =
        (snapshot['prerequisiteCount'] as num?)?.toInt() ?? 8;

    final stripeTaxReady = snapshot['stripeTaxReady'] == true;
    final smallSupplierActive =
        snapshot['canadaGstHstSmallSupplier'] == true;
    final smallSupplierEvidenceReady =
        snapshot['smallSupplierBillingEvidenceReady'] == true;
    final pendingTaxApproved =
        snapshot['stripeTaxRegistrationPending'] == true &&
            snapshot['stripeTaxPendingBillingApproved'] == true;
    final taxDetail = dispatchTaxReadinessDetail(
      stripeTaxReady: stripeTaxReady,
      smallSupplierActive: smallSupplierActive,
      smallSupplierEvidenceReady: smallSupplierEvidenceReady,
      pendingTaxApproved: pendingTaxApproved,
      evidenceReason:
          '${snapshot['smallSupplierBillingEvidenceReason'] ?? ''}'.trim(),
      assessmentRevision:
          (snapshot['smallSupplierAssessmentRevision'] as num?)?.toInt() ?? 0,
      boundRevision:
          (snapshot['smallSupplierBoundRevision'] as num?)?.toInt() ?? 0,
    );

    final nextAction = dispatchSubscriptionNextAction(
      featureFlagsReady: featureFlagsReady,
      productionModeReady: productionModeReady,
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
                        'Server-projected production prerequisites only. Nothing on this card activates public subscriptions.',
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
                    value: prerequisiteCount <= 0
                        ? 0
                        : (readyCount / prerequisiteCount).clamp(0.0, 1.0),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$readyCount/$prerequisiteCount verified',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _GateRow(
              label: 'Dispatch feature availability',
              ready: featureFlagsReady,
              detail: featureFlagsReady
                  ? 'Dispatch and paidFeatures are enabled'
                  : 'dispatch=${dispatchFeatureEnabled ? 'ON' : 'OFF'} • paidFeatures=${paidFeaturesEnabled ? 'ON' : 'OFF'}',
            ),
            _GateRow(
              label: 'Stripe production mode',
              ready: productionModeReady,
              detail: productionModeReady
                  ? 'Production billing mode is selected'
                  : 'Production billing mode is not ready',
            ),
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
              detail: taxDetail,
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

String dispatchTaxReadinessDetail({
  required bool stripeTaxReady,
  required bool smallSupplierActive,
  required bool smallSupplierEvidenceReady,
  required bool pendingTaxApproved,
  required String evidenceReason,
  required int assessmentRevision,
  required int boundRevision,
}) {
  if (stripeTaxReady) {
    return 'Stripe Tax registration/readiness is authorized for billing.';
  }
  if (smallSupplierActive) {
    if (smallSupplierEvidenceReady) {
      return 'Canadian small-supplier evidence is current (assessment revision $assessmentRevision, bound revision $boundRevision).';
    }
    switch (evidenceReason) {
      case 'assessment_missing':
        return 'Small-supplier mode is active but the audited GST/HST threshold assessment is missing.';
      case 'assessment_revision_mismatch':
        return 'Small-supplier assessment is stale (assessment revision $assessmentRevision, bound revision $boundRevision).';
      case 'threshold_exceeded':
        return 'The audited GST/HST small-supplier threshold has been exceeded; registration review is required.';
      case 'attestation_missing':
      case 'assessment_invalid':
      case 'assessment_unversioned':
      case 'readiness_unbound':
        return 'Small-supplier billing evidence is incomplete and must be reviewed before billing.';
      default:
        return 'Small-supplier billing evidence is not currently authorized.';
    }
  }
  if (pendingTaxApproved) {
    return 'Tax registration is pending and the audited pending-registration billing treatment is approved.';
  }
  return 'No authorized GST/HST billing state is currently recorded.';
}

String dispatchSubscriptionNextAction({
  required bool featureFlagsReady,
  required bool productionModeReady,
  required bool portalReady,
  required bool coreWebhook,
  required bool lifecycle,
  required bool recovery,
  required bool reconciliation,
  required bool taxPrepared,
  required bool subscriptions,
}) {
  if (!featureFlagsReady) {
    return 'Enable the reviewed Dispatch and paidFeatures feature flags before subscription acceptance.';
  }
  if (!productionModeReady) {
    return 'Complete the audited Stripe production-mode readiness step before subscription acceptance.';
  }
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
