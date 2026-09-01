from pathlib import Path

messages_path = Path('lib/marketplace/marketplace_messages_page.dart')
messages = messages_path.read_text(encoding='utf-8')

old = "import 'marketplace_secure_payment.dart';\n"
new = "import 'marketplace_journey_status.dart';\nimport 'marketplace_secure_payment.dart';\n"
if messages.count(old) != 1:
    raise SystemExit(f'messages import anchor mismatch: {messages.count(old)}')
messages = messages.replace(old, new, 1)

old = """          if (hasTransaction) ...[
            const SizedBox(height: 10),
            MarketplaceTransactionPanel(
"""
new = """          if (!hasTransaction) ...[
            const SizedBox(height: 10),
            MarketplaceJourneyStatusCard(
              status: marketplaceOfferJourneyStatus(
                status: offerStatus,
                viewerIsSeller: isSeller,
              ),
            ),
          ],
          if (hasTransaction) ...[
            const SizedBox(height: 10),
            MarketplaceTransactionPanel(
"""
if messages.count(old) != 1:
    raise SystemExit(f'offer journey anchor mismatch: {messages.count(old)}')
messages = messages.replace(old, new, 1)

old = """      final paymentReadyForCompletion =
          paymentStatus == 'paid' || paymentStatus == 'external_agreed';
      return Container(
"""
new = """      final paymentReadyForCompletion =
          paymentStatus == 'paid' || paymentStatus == 'external_agreed';
      final dispatchRequested =
          '${widget.offer['truckingPlan'] ?? ''}' == 'request_dispatch';
      final journeyStatus = marketplaceTransactionJourneyStatus(
        transaction,
        viewerIsBuyer: !widget.isSeller,
        dispatchRequested: dispatchRequested,
      );
      return Container(
"""
if messages.count(old) != 1:
    raise SystemExit(f'transaction state anchor mismatch: {messages.count(old)}')
messages = messages.replace(old, new, 1)

old = """            Text(
              '${_money(transaction['agreedTotal'] ?? widget.offer['offeredTotal'])} • '
              '${transaction['agreedQuantity'] ?? widget.offer['requestedQuantity'] ?? 0} units',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 9),
            Row(
"""
new = """            Text(
              '${_money(transaction['agreedTotal'] ?? widget.offer['offeredTotal'])} • '
              '${transaction['agreedQuantity'] ?? widget.offer['requestedQuantity'] ?? 0} units',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            MarketplaceJourneyStatusCard(status: journeyStatus),
            const SizedBox(height: 10),
            Row(
"""
if messages.count(old) != 1:
    raise SystemExit(f'transaction card anchor mismatch: {messages.count(old)}')
messages = messages.replace(old, new, 1)

old = """                if (!terminal && !buyerConfirmed && !sellerConfirmed)
                  OutlinedButton.icon(
"""
new = """                if (status == 'completed' && dispatchRequested)
                  FilledButton.tonalIcon(
                    onPressed: () => MarketplaceNavigation.goToDispatch(context),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Continue to Dispatch'),
                  ),
                if (!terminal && !buyerConfirmed && !sellerConfirmed)
                  OutlinedButton.icon(
"""
if messages.count(old) != 1:
    raise SystemExit(f'Dispatch handoff anchor mismatch: {messages.count(old)}')
messages = messages.replace(old, new, 1)
messages_path.write_text(messages, encoding='utf-8')

auction_path = Path('lib/marketplace/marketplace_auction_settlement.dart')
auction = auction_path.read_text(encoding='utf-8')

old = "import 'marketplace_secure_payment.dart';\n"
new = "import 'marketplace_journey_status.dart';\nimport 'marketplace_secure_payment.dart';\n"
if auction.count(old) != 1:
    raise SystemExit(f'auction import anchor mismatch: {auction.count(old)}')
auction = auction.replace(old, new, 1)

old = """    final escrowStatus = parseEscrowStatus(
      '${sale['escrowStatus'] ?? sale['status']}',
    );

    return PipeBuyerSectionCard(
"""
new = """    final escrowStatus = parseEscrowStatus(
      '${sale['escrowStatus'] ?? sale['status']}',
    );
    final journeyStatus = marketplaceTransactionJourneyStatus(
      sale,
      viewerIsBuyer: buyer,
      timedBuying: true,
    );

    return PipeBuyerSectionCard(
"""
if auction.count(old) != 1:
    raise SystemExit(f'auction state anchor mismatch: {auction.count(old)}')
auction = auction.replace(old, new, 1)

old = """      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
"""
new = """      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MarketplaceJourneyStatusCard(status: journeyStatus),
          const SizedBox(height: 12),
          LayoutBuilder(
"""
if auction.count(old) != 1:
    raise SystemExit(f'auction card anchor mismatch: {auction.count(old)}')
auction = auction.replace(old, new, 1)
auction_path.write_text(auction, encoding='utf-8')
