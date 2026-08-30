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
  return !const {'refunded', 'disputed', 'charged_back'}.contains(financialStatus);
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
  final maxTransactionLength =
      180 - prefix.length - 1 - suffix.length;
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
  late final String _refundReviewRequestId;

  @override
  void initState() {
    super.initState();
    _refundReviewRequestId = marketplaceRefundReviewRequestId(
      widget.transactionId,
      DateTime.now().microsecondsSinceEpoch,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
      final paymentStatus = '${sale['paymentProviderStatus'] ?? 'not_started'}';
      final payoutStatus = '${sale['sellerPayoutStatus'] ?? ''}';
      final feeReady = sale['marketplaceFeeSnapshot'] is Map;
      final paid = paymentStatus == 'paid';
      if (paid) {
        final reviewPending = marketplacePaymentReviewPending(sale);
        final reviewAvailable = marketplacePaymentReviewAvailable(sale);
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
                  const Icon(Icons.check_circle_outline, color: Colors.green),
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
            ] else if (reviewAvailable) ...[
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: 'Payment problem or request refund review',
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _requestRefundReview,
                  icon: const Icon(Icons.support_agent_outlined),
                  label: const Text('Payment problem / Request refund review'),
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
      if (!widget.isBuyer) {
        return const Row(
          children: [
            Icon(Icons.schedule_outlined, size: 19),
            SizedBox(width: 8),
            Expanded(child: Text('Awaiting secure payment from the buyer.')),
          ],
        );
      }
      if (!feeReady) {
        return const Row(
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text('Calculating the server-verified transaction total…'),
            ),
          ],
        );
      }
      return SizedBox(
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

    setState(() => _busy = true);
    try {
      await MarketplaceCommandClient().execute(
        'requestMarketplaceRefund',
        marketplaceRefundReviewPayload(
          requestId: _refundReviewRequestId,
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
