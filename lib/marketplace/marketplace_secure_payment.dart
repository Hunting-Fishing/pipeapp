import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/diagnostics/app_diagnostics.dart';
import 'marketplace_command_client.dart';
import 'marketplace_payment_terms.dart';

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
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              MarketplacePaymentTermsPanel(
                transactionId: widget.transactionId,
                sale: sale,
                isBuyer: widget.isBuyer,
              ),
            ],
          ),
        );
      }

      final paymentPlan = '${sale['paymentPlan'] ?? ''}';
      final paymentPlanStatus = '${sale['paymentPlanStatus'] ?? ''}';
      final splitFlowOwnsPayment =
          paymentPlanStatus == 'proposal_pending' ||
          (paymentPlan == 'deposit_balance' && paymentPlanStatus == 'active');
      if (splitFlowOwnsPayment) {
        return MarketplacePaymentTermsPanel(
          transactionId: widget.transactionId,
          sale: sale,
          isBuyer: widget.isBuyer,
        );
      }

      if (!widget.isBuyer) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.schedule_outlined, size: 19),
                SizedBox(width: 8),
                Expanded(child: Text('Awaiting secure payment from the buyer.')),
              ],
            ),
            MarketplacePaymentTermsPanel(
              transactionId: widget.transactionId,
              sale: sale,
              isBuyer: false,
            ),
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
          MarketplacePaymentTermsPanel(
            transactionId: widget.transactionId,
            sale: sale,
            isBuyer: true,
          ),
        ],
      );
    },
  );

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
