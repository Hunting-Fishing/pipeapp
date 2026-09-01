import 'package:flutter/material.dart';

enum MarketplaceJourneyTone { neutral, info, warning, success, danger }

@immutable
class MarketplaceJourneyStatus {
  const MarketplaceJourneyStatus({
    required this.currentStatus,
    required this.nextAction,
    required this.responsibleParty,
    this.tone = MarketplaceJourneyTone.info,
  });

  final String currentStatus;
  final String nextAction;
  final String responsibleParty;
  final MarketplaceJourneyTone tone;
}

MarketplaceJourneyStatus marketplaceOfferJourneyStatus({
  required String status,
  required bool viewerIsSeller,
}) {
  final normalized = status.trim().toLowerCase();
  switch (normalized) {
    case 'pending':
      return MarketplaceJourneyStatus(
        currentStatus: viewerIsSeller
            ? 'Offer waiting for your review'
            : 'Offer sent to the seller',
        nextAction: viewerIsSeller
            ? 'Review the terms. You can accept the offer, counter in Messages, or keep discussing the deal.'
            : 'Wait for the seller to accept or counter. You can keep discussing the terms in Messages.',
        responsibleParty: viewerIsSeller ? 'Seller (you)' : 'Seller',
        tone: MarketplaceJourneyTone.warning,
      );
    case 'accepted':
      return const MarketplaceJourneyStatus(
        currentStatus: 'Offer accepted',
        nextAction:
            'Continue with the payment and completion steps shown below.',
        responsibleParty: 'Buyer and seller',
        tone: MarketplaceJourneyTone.success,
      );
    case 'archived':
      return const MarketplaceJourneyStatus(
        currentStatus: 'Offer closed',
        nextAction: 'No action is required on this offer.',
        responsibleParty: 'No action required',
        tone: MarketplaceJourneyTone.neutral,
      );
    case 'cancelled':
    case 'canceled':
    case 'withdrawn':
    case 'declined':
    case 'rejected':
      return const MarketplaceJourneyStatus(
        currentStatus: 'Offer is no longer active',
        nextAction: 'No action is required on this offer.',
        responsibleParty: 'No action required',
        tone: MarketplaceJourneyTone.neutral,
      );
    case 'completed':
      return const MarketplaceJourneyStatus(
        currentStatus: 'Offer transaction completed',
        nextAction: 'No offer action is required.',
        responsibleParty: 'No action required',
        tone: MarketplaceJourneyTone.success,
      );
    case 'disputed':
      return const MarketplaceJourneyStatus(
        currentStatus: 'Transaction is under review',
        nextAction:
            'Wait for Pipe Buyer review and respond if support requests more information.',
        responsibleParty: 'Pipe Buyer support',
        tone: MarketplaceJourneyTone.danger,
      );
    default:
      return const MarketplaceJourneyStatus(
        currentStatus: 'Offer status needs review',
        nextAction:
            'Refresh this offer or contact Pipe Buyer support before taking another offer action.',
        responsibleParty: 'Pipe Buyer support',
        tone: MarketplaceJourneyTone.warning,
      );
  }
}

MarketplaceJourneyStatus marketplaceTransactionJourneyStatus(
  Map<String, dynamic> transaction, {
  required bool viewerIsBuyer,
  bool timedBuying = false,
  bool dispatchRequested = false,
}) {
  final status = '${transaction['status'] ?? 'pending_completion'}'
      .trim()
      .toLowerCase();
  final paymentStatus =
      '${transaction['paymentProviderStatus'] ?? 'not_started'}'
          .trim()
          .toLowerCase();
  final financialStatus = '${transaction['financialStatus'] ?? ''}'
      .trim()
      .toLowerCase();
  final activeFinancialCaseId = '${transaction['activeFinancialCaseId'] ?? ''}'
      .trim();
  final buyerConfirmed = transaction['buyerConfirmed'] == true;
  final sellerConfirmed = transaction['sellerConfirmed'] == true;
  final buyerLabel = timedBuying ? 'Successful buyer' : 'Buyer';
  final sellerLabel = 'Seller';
  final buyerResponsible = viewerIsBuyer ? '$buyerLabel (you)' : buyerLabel;
  final sellerResponsible = viewerIsBuyer ? sellerLabel : '$sellerLabel (you)';

  if (activeFinancialCaseId.isNotEmpty ||
      financialStatus == 'refund_requested') {
    return const MarketplaceJourneyStatus(
      currentStatus: 'Payment review in progress',
      nextAction:
          'Wait for Pipe Buyer review. Respond if support asks for more information.',
      responsibleParty: 'Pipe Buyer support',
      tone: MarketplaceJourneyTone.warning,
    );
  }

  if (financialStatus == 'refunded') {
    return const MarketplaceJourneyStatus(
      currentStatus: 'Payment refunded',
      nextAction:
          'No payment action is required. Keep the transaction record for your files.',
      responsibleParty: 'No action required',
      tone: MarketplaceJourneyTone.neutral,
    );
  }

  if (status == 'disputed' ||
      status == 'buyer_default_reported' ||
      status == 'seller_default_reported' ||
      financialStatus == 'disputed' ||
      financialStatus == 'charged_back') {
    return const MarketplaceJourneyStatus(
      currentStatus: 'Transaction is under review',
      nextAction:
          'Wait for Pipe Buyer review and respond if support requests more information.',
      responsibleParty: 'Pipe Buyer support',
      tone: MarketplaceJourneyTone.danger,
    );
  }

  if (status == 'cancelled' || status == 'canceled') {
    return const MarketplaceJourneyStatus(
      currentStatus: 'Transaction cancelled',
      nextAction: 'No further transaction action is required.',
      responsibleParty: 'No action required',
      tone: MarketplaceJourneyTone.neutral,
    );
  }

  if (status == 'completed' || (buyerConfirmed && sellerConfirmed)) {
    if (dispatchRequested) {
      return const MarketplaceJourneyStatus(
        currentStatus: 'Marketplace transaction complete',
        nextAction:
            'Continue the requested delivery handoff in Dispatch. This marketplace transaction does not create or charge a Dispatch job automatically.',
        responsibleParty: 'Buyer and seller',
        tone: MarketplaceJourneyTone.success,
      );
    }
    return const MarketplaceJourneyStatus(
      currentStatus: 'Transaction complete',
      nextAction:
          'No transaction action is required. Keep the permanent record for your files.',
      responsibleParty: 'No action required',
      tone: MarketplaceJourneyTone.success,
    );
  }

  const activeStatuses = {
    'pending_completion',
    'awaiting_buyer_confirmation',
    'awaiting_seller_confirmation',
  };
  if (!activeStatuses.contains(status)) {
    return const MarketplaceJourneyStatus(
      currentStatus: 'Transaction status needs review',
      nextAction:
          'Refresh this transaction or contact Pipe Buyer support before confirming completion.',
      responsibleParty: 'Pipe Buyer support',
      tone: MarketplaceJourneyTone.warning,
    );
  }

  final paymentReady =
      paymentStatus == 'paid' || paymentStatus == 'external_agreed';
  if (!paymentReady) {
    return MarketplaceJourneyStatus(
      currentStatus: paymentStatus == 'checkout_created'
          ? 'Secure payment still required'
          : 'Payment not started',
      nextAction: viewerIsBuyer
          ? 'Complete secure payment before either party confirms completion.'
          : 'Wait for the buyer to complete secure payment. Completion stays locked until payment or an approved external settlement is confirmed.',
      responsibleParty: buyerResponsible,
      tone: MarketplaceJourneyTone.warning,
    );
  }

  if (buyerConfirmed || status == 'awaiting_seller_confirmation') {
    return MarketplaceJourneyStatus(
      currentStatus: '$buyerLabel confirmation recorded',
      nextAction: viewerIsBuyer
          ? 'Wait for the seller to confirm the sale was fulfilled.'
          : 'Confirm the sale was fulfilled when your part of the transaction is complete.',
      responsibleParty: sellerResponsible,
      tone: MarketplaceJourneyTone.info,
    );
  }

  if (sellerConfirmed || status == 'awaiting_buyer_confirmation') {
    return MarketplaceJourneyStatus(
      currentStatus: '$sellerLabel confirmation recorded',
      nextAction: viewerIsBuyer
          ? 'Confirm the purchase was received when you have the item or agreed delivery.'
          : 'Wait for the buyer to confirm the purchase was received.',
      responsibleParty: buyerResponsible,
      tone: MarketplaceJourneyTone.info,
    );
  }

  return MarketplaceJourneyStatus(
    currentStatus: paymentStatus == 'external_agreed'
        ? 'External settlement confirmed • completion pending'
        : 'Payment received • completion pending',
    nextAction: viewerIsBuyer
        ? 'Confirm the purchase was received when you have the item or agreed delivery.'
        : 'Confirm the sale was fulfilled when your part of the transaction is complete.',
    responsibleParty: '$buyerLabel and $sellerLabel',
    tone: MarketplaceJourneyTone.info,
  );
}

class MarketplaceJourneyStatusCard extends StatelessWidget {
  const MarketplaceJourneyStatusCard({super.key, required this.status});

  final MarketplaceJourneyStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, status.tone);
    return Semantics(
      container: true,
      label:
          'Current status: ${status.currentStatus}. Next action: ${status.nextAction}. Who acts next: ${status.responsibleParty}.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_toneIcon(status.tone), color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  'What happens next',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _JourneyLine(label: 'Current status', value: status.currentStatus),
            const SizedBox(height: 6),
            _JourneyLine(label: 'Next action', value: status.nextAction),
            const SizedBox(height: 6),
            _JourneyLine(
              label: 'Who acts next',
              value: status.responsibleParty,
            ),
          ],
        ),
      ),
    );
  }

  Color _toneColor(BuildContext context, MarketplaceJourneyTone tone) =>
      switch (tone) {
        MarketplaceJourneyTone.success => Colors.green.shade700,
        MarketplaceJourneyTone.danger => Theme.of(context).colorScheme.error,
        MarketplaceJourneyTone.warning => Colors.orange.shade800,
        MarketplaceJourneyTone.info => Theme.of(context).colorScheme.primary,
        MarketplaceJourneyTone.neutral => Colors.blueGrey.shade700,
      };

  IconData _toneIcon(MarketplaceJourneyTone tone) => switch (tone) {
    MarketplaceJourneyTone.success => Icons.check_circle_outline,
    MarketplaceJourneyTone.danger => Icons.report_problem_outlined,
    MarketplaceJourneyTone.warning => Icons.schedule_outlined,
    MarketplaceJourneyTone.info => Icons.route_outlined,
    MarketplaceJourneyTone.neutral => Icons.info_outline,
  };
}

class _JourneyLine extends StatelessWidget {
  const _JourneyLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 96,
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(value)),
    ],
  );
}
