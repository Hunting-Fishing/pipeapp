import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/diagnostics/app_diagnostics.dart';
import 'marketplace_command_client.dart';

const int marketplaceRefundReviewMinReasonLength = 10;
const int marketplaceRefundReviewMaxReasonLength = 1600;

bool marketplacePaymentReviewPending(Map<String, dynamic> sale) {
  final activeCaseId = '${sale['activeFinancialCaseId'] ?? ''}'.trim();
  final financialStatus = '${sale['financialStatus'] ?? ''}'.trim();
  return activeCaseId.isNotEmpty || financialStatus == 'refund_requested';
}

bool marketplacePaymentReviewAvailable(Map<String, dynamic> sale) {
  if ('${sale['paymentProviderStatus'] ?? ''}' != 'paid') return false;
  if (marketplacePaymentReviewPending(sale)) return false;
  final financialStatus = '${sale['financialStatus'] ?? ''}'.trim();
  return !const {'refunded', 'disputed', 'charged_back'}
      .contains(financialStatus);
}

bool marketplacePaymentCancelReviewAvailable(
  Map<String, dynamic> sale, {
  required bool isBuyer,
}) {
  if (!marketplacePaymentReviewPending(sale)) return false;
  final activeCaseId = '${sale['activeFinancialCaseId'] ?? ''}'.trim();
  if (activeCaseId.isEmpty) return false;
  final requestedByUid =
      '${sale['activeFinancialCaseRequestedByUid'] ?? ''}'.trim();
  if (requestedByUid.isEmpty) return true;
  final viewerUid =
      '${isBuyer ? sale['buyerUid'] : sale['sellerUid'] ?? ''}'.trim();
  return viewerUid.isNotEmpty && requestedByUid == viewerUid;
}

bool marketplaceExternalSettlementAgreed(Map<String, dynamic> sale) {
  if ('${sale['paymentProviderStatus'] ?? ''}' == 'external_agreed') {
    return true;
  }
  return sale['externalSettlementBuyerConfirmed'] == true &&
      sale['externalSettlementSellerConfirmed'] == true;
}

bool marketplaceExternalSettlementAvailable(Map<String, dynamic> sale) {
  final status = '${sale['status'] ?? ''}'.trim();
  if (const {'cancelled', 'disputed'}.contains(status)) return false;
  final paymentStatus = '${sale['paymentProviderStatus'] ?? ''}'.trim();
  if (paymentStatus == 'paid' || marketplaceExternalSettlementAgreed(sale)) {
    return false;
  }
  final paymentIntentId = '${sale['stripePaymentIntentId'] ?? ''}'.trim();
  return paymentIntentId.isEmpty;
}

bool marketplaceRefundReviewReasonValid(String reason) {
  final length = reason.trim().length;
  return length >= marketplaceRefundReviewMinReasonLength &&
      length <= marketplaceRefundReviewMaxReasonLength;
}

String marketplaceRefundReviewRequestId(String transactionId, int seed) {
  final suffix = seed.toRadixString(36);
  const prefix = 'refund-';
  final normalized = transactionId.trim().replaceAll('/', '_');
  final maxTransactionLength = 180 - prefix.length - 1 - suffix.length;
  final safeTransaction = normalized.length > maxTransactionLength
      ? normalized.substring(0, maxTransactionLength)
      : normalized;
  return '$prefix$safeTransaction-$suffix';
}

Map<String, Object?> marketplaceRefundReviewPayload({
  required String requestId,
  required String transactionId,
  required String reason,
}) =>
    <String, Object?>{
      'requestId': requestId,
      'transactionId': transactionId,
      'reason': reason.trim(),
    };

class MarketplaceSecurePaymentPanel extends StatefulWidget {
  const MarketplaceSecurePaymentPanel({
    super.key,
    required this.transactionId,
    required this.isBuyer,
    this.payLabel = 'Pay securely',
  });

  final String transactionId;
  final bool isBuyer;
  final String payLabel;

  @override
  State<MarketplaceSecurePaymentPanel> createState() =>
      _MarketplaceSecurePaymentPanelState();
}

class _MarketplaceSecurePaymentPanelState
    extends State<MarketplaceSecurePaymentPanel> {
  bool _busy = false;

  @override
  Widget build(
    BuildContext context,
  ) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('marketplace_transactions')
            .doc(widget.transactionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'Secure payment status is temporarily unavailable.',
              style: TextStyle(fontSize: 11, color: Colors.redAccent),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Row(
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Expanded(child: Text('Preparing secure payment…')),
              ],
            );
          }
          final sale = snapshot.data!.data() ?? const <String, dynamic>{};
          final paymentStatus =
              '${sale['paymentProviderStatus'] ?? 'not_started'}';
          final payoutStatus = '${sale['sellerPayoutStatus'] ?? ''}';
          final feeReady = sale['marketplaceFeeSnapshot'] is Map;
          final paid = paymentStatus == 'paid';
          if (paid) {
            final reviewPending = marketplacePaymentReviewPending(sale);
            final reviewAvailable = marketplacePaymentReviewAvailable(sale);
            final canCancelReview = marketplacePaymentCancelReviewAvailable(
              sale,
              isBuyer: widget.isBuyer,
            );
            final activeCaseId =
                '${sale['activeFinancialCaseId'] ?? ''}'.trim();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          payoutStatus == 'released'
                              ? 'Payment received • seller proceeds released'
                              : 'Payment received • seller proceeds pending completion release',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                if (reviewPending) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.rate_review_outlined, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment review in progress. Pipe Buyer will review the request before any refund is issued.',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canCancelReview) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      button: true,
                      label: 'Cancel payment review request',
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _cancelRefundReview(activeCaseId),
                        icon: const Icon(Icons.undo_outlined),
                        label: const Text('Cancel review request'),
                      ),
                    ),
                  ],
                ] else if (reviewAvailable) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    label: 'Payment problem or request refund review',
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _requestRefundReview,
                      icon: const Icon(Icons.support_agent_outlined),
                      label:
                          const Text('Payment problem / Request refund review'),
                    ),
                  ),
                  const Text(
                    'This asks Pipe Buyer to review the payment. It does not automatically refund or move money.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, color: Colors.black54),
                  ),
                ],
              ],
            );
          }
          if (marketplaceExternalSettlementAgreed(sale)) {
            final feeCollected =
                '${sale['marketplaceFeeStatus'] ?? ''}' == 'collected';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_outlined,
                          color: Colors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.isBuyer
                              ? 'External wire / PO settlement agreed by both parties.'
                              : feeCollected
                                  ? 'External wire / PO settlement agreed • marketplace fee paid'
                                  : 'External wire / PO settlement agreed • marketplace fee pending',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.isBuyer && !feeCollected && feeReady) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _startExternalFeeCheckout,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Pay Pipe Buyer marketplace fee'),
                  ),
                ],
              ],
            );
          }
          final buyerConfirmedExternal =
              sale['externalSettlementBuyerConfirmed'] == true;
          final sellerConfirmedExternal =
              sale['externalSettlementSellerConfirmed'] == true;
          final viewerConfirmedExternal =
              widget.isBuyer ? buyerConfirmedExternal : sellerConfirmedExternal;
          final canConfirmExternal =
              marketplaceExternalSettlementAvailable(sale);
          if (!widget.isBuyer) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_outlined, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        buyerConfirmedExternal
                            ? 'Buyer requested external wire / PO settlement.'
                            : 'Awaiting secure payment from the buyer.',
                      ),
                    ),
                  ],
                ),
                if (canConfirmExternal) ...[
                  const SizedBox(height: 8),
                  if (viewerConfirmedExternal)
                    const Text(
                      'External wire / PO settlement confirmed • awaiting buyer confirmation.',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _confirmExternalSettlement,
                      icon:
                          const Icon(Icons.account_balance_outlined, size: 18),
                      label:
                          const Text('Confirm external wire / PO settlement'),
                    ),
                ],
              ],
            );
          }
          if (!feeReady) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'Calculating the server-verified transaction total…'),
                    ),
                  ],
                ),
                if (canConfirmExternal && !viewerConfirmedExternal) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _confirmExternalSettlement,
                    icon: const Icon(Icons.account_balance_outlined, size: 18),
                    label: const Text('Settle directly by wire / PO instead'),
                  ),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _startPayment,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline),
                  label: Text(
                    _busy
                        ? 'Opening secure payment…'
                        : paymentStatus == 'checkout_created'
                            ? 'Continue secure payment'
                            : widget.payLabel,
                  ),
                ),
              ),
              if (canConfirmExternal) ...[
                const SizedBox(height: 8),
                if (viewerConfirmedExternal)
                  const Text(
                    'External wire / PO settlement confirmed • awaiting seller confirmation.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _confirmExternalSettlement,
                    icon: const Icon(Icons.account_balance_outlined, size: 18),
                    label: Text(
                      sellerConfirmedExternal
                          ? 'Confirm seller request for wire / PO settlement'
                          : 'Settle directly by wire / PO instead',
                    ),
                  ),
              ],
            ],
          );
        },
      );

  Future<void> _requestRefundReview() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          icon: const Icon(Icons.support_agent_outlined, size: 38),
          title: const Text('Request payment review'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Describe the payment problem. Pipe Buyer will review the transaction before any refund is issued.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: marketplaceRefundReviewMaxReasonLength,
                  onChanged: (_) => refresh(() {}),
                  decoration: const InputDecoration(
                    labelText: 'What happened? *',
                    hintText:
                        'For example: item not received, condition problem, duplicate payment, or agreed cancellation.',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Submitting this request does not guarantee a refund and does not release or reverse funds automatically.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: marketplaceRefundReviewReasonValid(controller.text)
                  ? () => Navigator.pop(dialogContext, controller.text.trim())
                  : null,
              child: const Text('Submit for review'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;

    final requestId = marketplaceRefundReviewRequestId(
      widget.transactionId,
      DateTime.now().microsecondsSinceEpoch,
    );
    setState(() => _busy = true);
    try {
      await MarketplaceCommandClient().execute(
        'requestMarketplaceRefund',
        marketplaceRefundReviewPayload(
          requestId: requestId,
          transactionId: widget.transactionId,
          reason: reason,
        ),
      );
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message:
            'Payment review requested. No automatic refund has been issued.',
        tone: PipeStatusTone.success,
      );
    } catch (error, stackTrace) {
      AppDiagnostics.record(
        error,
        stackTrace,
        subsystem: 'marketplace_payments',
        operation: 'request_refund_review',
        fatal: false,
      );
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback:
                'The payment review request could not be recorded. No refund was issued.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelRefundReview(String caseId) async {
    if (caseId.isEmpty) return;
    setState(() => _busy = true);
    try {
      await MarketplaceCommandClient().execute(
        'cancelMarketplaceRefundRequest',
        {'caseId': caseId},
      );
      if (!mounted) return;
      PipeFeedback.show(
        context,
        message: 'Payment review request cancelled.',
        tone: PipeStatusTone.success,
      );
    } catch (error, stackTrace) {
      AppDiagnostics.record(
        error,
        stackTrace,
        subsystem: 'marketplace_payments',
        operation: 'cancel_refund_review',
        fatal: false,
      );
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'The payment review request could not be cancelled.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmExternalSettlement() async {
    setState(() => _busy = true);
    try {
      final result = await MarketplaceCommandClient().execute(
        'confirmExternalSettlement',
        {'transactionId': widget.transactionId},
      );
      if (!mounted) return;
      final agreed = result['fullyConfirmed'] == true;
      PipeFeedback.show(
        context,
        message: agreed
            ? 'External wire / PO settlement is now agreed by both parties.'
            : 'External wire / PO settlement confirmed. Waiting for the other party.',
        tone: PipeStatusTone.success,
      );
    } catch (error, stackTrace) {
      AppDiagnostics.record(
        error,
        stackTrace,
        subsystem: 'marketplace_payments',
        operation: 'confirm_external_settlement',
        fatal: false,
      );
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'External settlement could not be confirmed.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startExternalFeeCheckout() async {
    setState(() => _busy = true);
    try {
      final result = await MarketplaceCommandClient().execute(
        'createExternalSettlementFeeCheckout',
        {'transactionId': widget.transactionId},
      );
      if (result['alreadyPaid'] == true) {
        if (mounted) {
          PipeFeedback.show(
            context,
            message: 'The Pipe Buyer marketplace fee is already paid.',
            tone: PipeStatusTone.success,
          );
        }
        return;
      }
      final rawUrl = '${result['checkoutUrl'] ?? ''}'.trim();
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || uri.scheme != 'https') {
        throw StateError('Stripe did not return a secure fee checkout URL.');
      }
      final opened = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!opened)
        throw StateError('Marketplace fee checkout could not be opened.');
    } catch (error, stackTrace) {
      AppDiagnostics.record(
        error,
        stackTrace,
        subsystem: 'marketplace_payments',
        operation: 'open_external_fee_checkout',
        fatal: false,
      );
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback:
                'Marketplace fee checkout could not be opened. No charge was created.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startPayment() async {
    setState(() => _busy = true);
    try {
      final result = await MarketplaceCommandClient().execute(
        'createMarketplaceCheckout',
        {'transactionId': widget.transactionId},
      );
      if (result['alreadyPaid'] == true) {
        if (mounted) {
          PipeFeedback.show(
            context,
            message: 'This purchase is already paid.',
            tone: PipeStatusTone.success,
          );
        }
        return;
      }
      final rawUrl = '${result['checkoutUrl'] ?? ''}'.trim();
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || uri.scheme != 'https') {
        throw StateError('Stripe did not return a secure checkout URL.');
      }
      final opened = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Secure checkout could not be opened.');
    } catch (error, stackTrace) {
      AppDiagnostics.record(
        error,
        stackTrace,
        subsystem: 'marketplace_payments',
        operation: 'open_secure_checkout',
        fatal: false,
      );
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback:
                'Secure payment could not be opened. No charge was created.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
