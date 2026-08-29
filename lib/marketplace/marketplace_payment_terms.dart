import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import 'marketplace_command_client.dart';

int? parseMarketplaceMoneyMinor(String input) {
  final normalized = input.trim().replaceAll(',', '').replaceAll(r'$', '');
  final match = RegExp(r'^(\d{1,10})(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) return null;
  final whole = int.tryParse(match.group(1) ?? '');
  if (whole == null) return null;
  final fractionText = match.group(2) ?? '';
  final fraction = fractionText.isEmpty
      ? 0
      : int.tryParse(fractionText.padRight(2, '0'));
  if (fraction == null) return null;
  final minor = whole * 100 + fraction;
  return minor > 0 ? minor : null;
}

String marketplaceMoneyLabel(int minor, String currency) {
  final safeMinor = minor < 0 ? 0 : minor;
  final whole = safeMinor ~/ 100;
  final cents = safeMinor % 100;
  final amount = cents == 0
      ? '$whole'
      : '$whole.${cents.toString().padLeft(2, '0')}';
  final code = currency.trim().toUpperCase();
  return switch (code) {
    'CAD' => 'CA\$$amount',
    'USD' => 'US\$$amount',
    _ => '$code $amount',
  };
}

class MarketplacePaymentTermsPanel extends StatefulWidget {
  const MarketplacePaymentTermsPanel({
    super.key,
    required this.transactionId,
    required this.sale,
    required this.isBuyer,
  });

  final String transactionId;
  final Map<String, dynamic> sale;
  final bool isBuyer;

  @override
  State<MarketplacePaymentTermsPanel> createState() =>
      _MarketplacePaymentTermsPanelState();
}

class _MarketplacePaymentTermsPanelState
    extends State<MarketplacePaymentTermsPanel> {
  bool _busy = false;

  String get _currency => '${widget.sale['currency'] ?? 'CAD'}'.toUpperCase();

  String _requestId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${widget.transactionId.hashCode.abs()}';

  @override
  Widget build(BuildContext context) {
    if ('${widget.sale['paymentOrigin'] ?? ''}' == 'timed_buying') {
      return const SizedBox.shrink();
    }

    final providerStatus =
        '${widget.sale['paymentProviderStatus'] ?? 'not_started'}';
    final amountPaid = (widget.sale['amountPaidMinor'] as num?)?.toInt() ?? 0;
    final planStatus = '${widget.sale['paymentPlanStatus'] ?? ''}';
    final paymentPlan = '${widget.sale['paymentPlan'] ?? ''}';

    if (planStatus == 'proposal_pending') {
      final proposal = widget.sale['paymentPlanProposal'] is Map
          ? Map<String, dynamic>.from(widget.sale['paymentPlanProposal'] as Map)
          : const <String, dynamic>{};
      final deposit = (proposal['depositAmountMinor'] as num?)?.toInt() ?? 0;
      final balance = (proposal['balanceAmountMinor'] as num?)?.toInt() ?? 0;
      final revision =
          (widget.sale['paymentPlanProposalRevision'] as num?)?.toInt() ?? 0;
      final myApproved = widget.isBuyer
          ? proposal['buyerApproved'] == true
          : proposal['sellerApproved'] == true;
      return _termsCard(
        title: 'Deposit + balance proposal',
        body:
            '${marketplaceMoneyLabel(deposit, _currency)} deposit • ${marketplaceMoneyLabel(balance, _currency)} remaining balance. Both parties must approve these exact terms before a payment can start.',
        children: [
          if (myApproved)
            const Text(
              'You approved these terms. Waiting for the other party.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy || revision <= 0
                        ? null
                        : () => _approve(revision),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve terms'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy || revision <= 0
                        ? null
                        : () => _decline(revision),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
        ],
      );
    }

    if (paymentPlan == 'deposit_balance' && planStatus == 'active') {
      final deposit = (widget.sale['depositAmountMinor'] as num?)?.toInt() ?? 0;
      final balance = (widget.sale['balanceAmountMinor'] as num?)?.toInt() ?? 0;
      final required = (widget.sale['paymentRequiredMinor'] as num?)?.toInt() ??
          deposit + balance;
      final remaining =
          (widget.sale['balanceRemainingMinor'] as num?)?.toInt() ??
              (required - amountPaid).clamp(0, required);
      final depositPaid = amountPaid >= deposit && deposit > 0;
      final fullyPaid = required > 0 && amountPaid >= required;
      final partId = depositPaid ? 'balance' : 'deposit';
      final partAmount = depositPaid ? balance : deposit;
      final continuePart = providerStatus == 'checkout_created' ||
          providerStatus == 'processing';

      return _termsCard(
        title: fullyPaid ? 'Deposit plan paid' : 'Approved deposit + balance',
        body: fullyPaid
            ? 'Payment received. Seller proceeds remain subject to the normal completion-release safeguards.'
            : depositPaid
                ? '${marketplaceMoneyLabel(deposit, _currency)} deposit received • ${marketplaceMoneyLabel(remaining, _currency)} remaining.'
                : '${marketplaceMoneyLabel(deposit, _currency)} deposit due first • ${marketplaceMoneyLabel(balance, _currency)} balance after the deposit is confirmed.',
        children: [
          if (!fullyPaid && widget.isBuyer)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy || partAmount <= 0
                    ? null
                    : () => _startPartCheckout(partId),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline_rounded),
                label: Text(
                  _busy
                      ? 'Opening secure payment…'
                      : '${continuePart ? 'Continue' : 'Pay'} ${partId == 'deposit' ? 'deposit' : 'remaining balance'} • ${marketplaceMoneyLabel(partAmount, _currency)}',
                ),
              ),
            )
          else if (!fullyPaid)
            Text(
              depositPaid
                  ? 'Deposit received. Waiting for the buyer to pay the remaining balance.'
                  : 'Waiting for the buyer to pay the approved deposit.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
        ],
      );
    }

    final paymentStarted = amountPaid > 0 ||
        const {
          'checkout_created',
          'processing',
          'partially_paid',
          'paid',
          'refunded',
          'partially_refunded',
        }.contains(providerStatus);
    if (paymentStarted || planStatus == 'active') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : _propose,
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: const Text('Set deposit / balance terms'),
        ),
      ),
    );
  }

  Widget _termsCard({
    required String title,
    required String body,
    required List<Widget> children,
  }) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 12)),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...children,
            ],
          ],
        ),
      );

  Future<void> _propose() async {
    final fee = widget.sale['marketplaceFeeSnapshot'] is Map
        ? Map<String, dynamic>.from(widget.sale['marketplaceFeeSnapshot'] as Map)
        : const <String, dynamic>{};
    final total = (fee['agreedTotalMinor'] as num?)?.toInt() ?? 0;
    if (total <= 200) {
      _showError('This transaction is too small to split into a deposit and balance.');
      return;
    }
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Propose deposit terms'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction total: ${marketplaceMoneyLabel(total, _currency)}. Enter the deposit amount. The remaining balance is calculated by the server.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Deposit amount ($_currency)',
                hintText: 'Example: 500.00',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No payment starts until the other party approves the exact deposit and balance.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Send proposal'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null) return;
    final depositMinor = parseMarketplaceMoneyMinor(raw);
    if (depositMinor == null || depositMinor < 100 || total - depositMinor < 100) {
      _showError('Deposit and remaining balance must each be at least 1.00.');
      return;
    }
    await _runCommand(
      'proposeMarketplaceDepositPlan',
      {
        'transactionId': widget.transactionId,
        'requestId': _requestId('deposit_proposal'),
        'depositAmountMinor': depositMinor,
      },
      'Deposit terms sent for approval.',
    );
  }

  Future<void> _approve(int revision) => _runCommand(
        'approveMarketplaceDepositPlan',
        {
          'transactionId': widget.transactionId,
          'requestId': _requestId('deposit_approval'),
          'expectedRevision': revision,
        },
        'Deposit terms approved.',
      );

  Future<void> _decline(int revision) => _runCommand(
        'declineMarketplaceDepositPlan',
        {
          'transactionId': widget.transactionId,
          'requestId': _requestId('deposit_decline'),
          'expectedRevision': revision,
        },
        'Deposit proposal declined. Full payment remains available.',
      );

  Future<void> _startPartCheckout(String partId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await MarketplaceCommandClient().execute(
        'createMarketplacePaymentPartCheckout',
        {'transactionId': widget.transactionId, 'partId': partId},
      );
      if (result['alreadyPaid'] == true) return;
      final rawUrl = '${result['checkoutUrl'] ?? ''}'.trim();
      final uri = Uri.tryParse(rawUrl);
      final host = uri?.host.toLowerCase() ?? '';
      if (uri == null ||
          uri.scheme != 'https' ||
          !(host == 'stripe.com' || host.endsWith('.stripe.com'))) {
        throw StateError('Stripe did not return a valid secure payment URL.');
      }
      final opened = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Secure split payment could not be opened.');
    } catch (error) {
      _showError(
        marketplaceCommandErrorMessage(
          error,
          fallback: 'Secure split payment could not be opened. No charge was created.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runCommand(
    String command,
    Map<String, Object?> payload,
    String success,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await MarketplaceCommandClient().execute(command, payload);
      if (mounted) {
        PipeFeedback.show(
          context,
          message: success,
          tone: PipeStatusTone.success,
        );
      }
    } catch (error) {
      _showError(
        marketplaceCommandErrorMessage(
          error,
          fallback: 'Payment terms could not be updated.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    PipeFeedback.show(
      context,
      message: message,
      tone: PipeStatusTone.error,
    );
  }
}
