import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();

function file(relative) {
  return path.join(root, relative);
}

function read(relative) {
  const target = file(relative);
  if (!fs.existsSync(target)) throw new Error(`Missing required file: ${relative}`);
  return fs.readFileSync(target, 'utf8');
}

function write(relative, content) {
  fs.writeFileSync(file(relative), content, 'utf8');
  console.log(`updated ${relative}`);
}

function replaceRequired(source, before, after, label) {
  if (source.includes(after)) return source;
  if (!source.includes(before)) {
    throw new Error(`Timed Buying migration could not find: ${label}`);
  }
  return source.replace(before, after);
}

function replaceOptional(source, before, after) {
  return source.includes(before) ? source.replaceAll(before, after) : source;
}

function replaceRegex(source, pattern, replacement) {
  return source.replace(pattern, replacement);
}

function patchTimedBuyingPage() {
  const relative = 'lib/marketplace/marketplace_auctions_page.dart';
  let source = read(relative);

  source = replaceRequired(
    source,
    "import 'marketplace_listing_status.dart';\nimport 'marketplace_money.dart';",
    "import 'marketplace_listing_status.dart';\nimport 'marketplace_money.dart';\nimport 'marketplace_timed_buying_presentation.dart';",
    'Timed Buying presentation import',
  );

  source = replaceRequired(
    source,
    'onShowLegend: () => showMarketplaceListingLegend(context),',
    'onShowLegend: () => showTimedBuyingLegend(context),',
    'Timed Buying time legend action',
  );

  const labels = [
    ['Loading timed auction', 'Loading Timed Buying'],
    ['Retrieving current bids, timing, and listing details…', 'Retrieving current timed offers, timing, and listing details…'],
    ['Timed auctions', 'Timed Buying'],
    ['Timed auction', 'Timed Buying'],
    ['This auction may have ended, been removed, or the link may be incorrect.', 'This Timed Buying listing may have closed, been removed, or the link may be incorrect.'],
    ['The auction index is still being prepared. Try again shortly.', 'The Timed Buying index is still being prepared. Try again shortly.'],
    ['My auctions', 'My Timed Buying'],
    ['Loading auctions', 'Loading Timed Buying'],
    ['Retrieving current bidding and closing times…', 'Retrieving current timed offers and closing times…'],
    ['All auctions loaded.', 'All Timed Buying listings loaded.'],
    ['Load more auctions', 'Load more Timed Buying'],
    ['PIPE BUYER AUCTIONS', 'PIPE BUYER TIMED BUYING'],
    ['Bid on oilfield pipe, equipment and industrial inventory with clear timing and auditable bid history.', 'Use timed offers for oilfield pipe, equipment and industrial inventory with clear closing times and auditable offer activity.'],
    ['Create auction', 'Create timed listing'],
    ['Signals', 'Time legend'],
    ['Auction listing', 'Timed Buying listing'],
    ['Current highest bid', 'Leading offer'],
    ['Starting bid', 'Opening offer'],
    ['This is your auction', 'This is your Timed Buying listing'],
    ['Bid activity and seller controls appear here.', 'Timed-offer activity and seller controls appear here.'],
    ['Accept leading bid', 'Accept leading offer'],
    ['Bid history', 'Timed offer activity'],
    ['CURRENT HIGHEST BID', 'LEADING OFFER'],
    ['STARTING BID', 'OPENING OFFER'],
    ['Bid total', 'Offer total'],
    ['Place your bid', 'Submit a timed offer'],
    ['Review the amount carefully before submitting a binding bid.', 'Review the amount carefully before submitting a binding timed offer.'],
    ['Your bid • minimum', 'Your timed offer • minimum'],
    ['Review and place bid', 'Review & submit timed offer'],
    ['Bidding unavailable', 'Timed offers unavailable'],
    ['Bids are binding. The seller and winning bidder finalize payment and logistics through marketplace messaging.', 'Timed offers are binding. The seller and successful buyer finalize payment and logistics through marketplace messaging.'],
    ['Bid pricing analysis', 'Timed offer analysis'],
    ['Next minimum bid', 'Next minimum offer'],
    ['Next bid total', 'Next offer total'],
    ['No bids yet', 'No timed offers yet'],
    ['The first eligible bid will appear here.', 'The first eligible timed offer will appear here.'],
    ['Showing the latest 100 bids', 'Showing the latest 100 timed offers'],
    ['Withdraw this bid?', 'Withdraw this timed offer?'],
    ['Keep bid', 'Keep timed offer'],
    ['Withdraw bid', 'Withdraw timed offer'],
    ['Bid withdrawn. Auction totals were updated.', 'Timed offer withdrawn. Timed Buying totals were updated.'],
    ['Auctions could not be loaded', 'Timed Buying could not be loaded'],
    ['More auctions could not be loaded', 'More Timed Buying listings could not be loaded'],
    ['Timed Buying listings will appear here separately from Marketplace inventory.', 'Timed Buying listings will appear here separately from Marketplace inventory.'],
    ['Create an auction', 'Create a timed listing'],
    ['Check more auctions', 'Check more Timed Buying'],
    ['This immediately closes the auction.', 'This immediately closes the Timed Buying listing.'],
    ['Purchase confirmed. The auction is closed.', 'Purchase confirmed. Timed Buying is closed.'],
    ['Accept below reserve?', 'Accept below seller minimum?'],
    ['Keep auction open', 'Keep Timed Buying open'],
    ['Accept and end auction', 'Accept and close'],
    ['Leading bid accepted. The bidder was notified.', 'Leading offer accepted. The buyer was notified.'],
    ['No reserve price', 'No seller minimum'],
    ['Reserve has been met', 'Seller minimum has been met'],
    ['Reserve not met', 'Seller minimum not met'],
    ["_row('Reserve',", "_row('Seller minimum',"],
  ];
  for (const [before, after] of labels) {
    source = replaceOptional(source, before, after);
  }

  source = replaceOptional(source, 'Icons.gavel_outlined', 'Icons.timer_outlined');
  source = replaceOptional(source, 'Icons.gavel', 'Icons.timer_rounded');
  source = replaceOptional(
    source,
    'IndustrialIconAssets.complianceGavel',
    'IndustrialIconAssets.inventory',
  );
  source = replaceOptional(source, "?? 'Auction'", "?? 'Timed Buying'");
  source = replaceOptional(source, "} bids'", "} timed offers'");
  source = replaceOptional(
    source,
    "\$bidCount \${bidCount == 1 ? 'bid' : 'bids'}",
    "\$bidCount \${bidCount == 1 ? 'timed offer' : 'timed offers'}",
  );
  source = replaceOptional(source, 'leading bid', 'leading timed offer');
  source = replaceOptional(source, 'Leading bid', 'Leading timed offer');
  source = replaceOptional(source, 'winning bidder', 'successful buyer');
  source = replaceOptional(source, 'the bidder', 'the buyer');
  source = replaceOptional(source, 'end this auction', 'close this Timed Buying listing');

  source = replaceRequired(
    source,
    `    return Card(\n      clipBehavior: Clip.antiAlias,\n      margin: const EdgeInsets.only(bottom: 12),\n      elevation: presentation.emphasized ? 2 : 0,`,
    `    return TimedBuyingUrgencyFrame(\n      start: start,\n      end: end,\n      margin: const EdgeInsets.only(bottom: 12),\n      child: Card(\n        clipBehavior: Clip.antiAlias,\n        margin: EdgeInsets.zero,\n        elevation: presentation.emphasized ? 2 : 0,`,
    'Timed Buying urgency border wrapper',
  );

  source = replaceRequired(
    source,
    `          ],\n        ),\n      ),\n    );\n  }\n}\n\nclass _AuctionStateBadge`,
    `          ],\n        ),\n      ),\n    ),\n    );\n  }\n}\n\nclass _AuctionStateBadge`,
    'Timed Buying urgency border closing',
  );

  source = replaceRequired(
    source,
    `          final live = isAuctionLive(data, now);\n          final ended = isAuctionEnded(data, now);`,
    `          final live = isAuctionLive(data, now);\n          final ended = isAuctionEnded(data, now);\n          if (live && !_submitting && _bid.text.trim().isEmpty) {\n            WidgetsBinding.instance.addPostFrameCallback((_) {\n              if (!mounted || _bid.text.trim().isNotEmpty) return;\n              _bid.text = next.toStringAsFixed(2);\n              _bid.selection = TextSelection.collapsed(offset: _bid.text.length);\n            });\n          }`,
    'Timed offer minimum prefill',
  );

  source = replaceRequired(
    source,
    `  Future<void> _placeBid() async {\n    final amount = num.tryParse(_bid.text.replaceAll(RegExp(r'[^0-9.]'), ''));\n    if (amount == null) return;`,
    `  Future<void> _placeBid() async {\n    final amount = num.tryParse(_bid.text.replaceAll(RegExp(r'[^0-9.]'), ''));\n    if (amount == null) {\n      PipeFeedback.show(\n        context,\n        message: 'Enter a timed offer amount to continue.',\n        tone: PipeStatusTone.error,\n      );\n      return;\n    }`,
    'Timed offer empty-input feedback',
  );

  const confirmationReplacements = [
    ['Place this bid?', 'Submit this timed offer?'],
    ['Submit a binding bid of', 'Submit a binding timed offer of'],
    ['Place bid', 'Submit timed offer'],
    ['Bid placed.', 'Timed offer submitted.'],
  ];
  for (const [before, after] of confirmationReplacements) {
    source = replaceOptional(source, before, after);
  }

  source = source.replaceAll(
    'message: marketplaceCommandErrorMessage(error),',
    'message: timedBuyingPublicMessage(marketplaceCommandErrorMessage(error)),',
  );

  source = replaceRequired(
    source,
    `String _auctionTimeLabel(DateTime? start, DateTime? end) {\n  final now = DateTime.now();\n  if (start == null || end == null) return 'Schedule unavailable';\n  if (now.isBefore(start)) return 'Starts in \${_duration(start.difference(now))}';\n  if (!now.isBefore(end)) return 'Ended';\n  return 'Ends in \${_duration(end.difference(now))}';\n}`,
    `String _auctionTimeLabel(DateTime? start, DateTime? end) =>\n    timedBuyingTimeLabel(start: start, end: end);`,
    'Timed Buying countdown wording',
  );

  source = replaceRegex(
    source,
    /title: 'No \$\{filter\.toLowerCase\(\)\} auctions',/g,
    "title: 'No \${filter.toLowerCase()} Timed Buying listings',",
  );

  if (!source.includes('TimedBuyingUrgencyFrame(') ||
      !source.includes('Review & submit timed offer') ||
      !source.includes("message: 'Enter a timed offer amount to continue.'")) {
    throw new Error('Timed Buying page migration did not produce required UI/function markers.');
  }

  write(relative, source);
}

function patchAccountHub() {
  const relative = 'lib/marketplace/marketplace_account_hub.dart';
  let source = read(relative);
  const replacements = [
    ['TIMED AUCTION', 'TIMED BUYING'],
    ['Move listing to timed auction', 'Move listing to Timed Buying'],
    ['Publishing timed auction…', 'Publishing Timed Buying…'],
    ['Current bid ', 'Leading offer '],
    [' bids', ' timed offers'],
    ['Accept leading bid anyway', 'Accept leading offer'],
    ['Bidding history', 'Timed offer activity'],
    ['No reserve price', 'No seller minimum'],
    ['Reserve met', 'Seller minimum met'],
    ['below reserve', 'below seller minimum'],
  ];
  for (const [before, after] of replacements) source = replaceOptional(source, before, after);
  write(relative, source);
}

function patchAuth() {
  const relative = 'lib/marketplace/marketplace_auth_page.dart';
  let source = read(relative);
  source = replaceOptional(source, 'Timed auctions', 'Timed Buying');
  source = replaceOptional(source, 'timed auctions', 'Timed Buying');
  source = replaceOptional(source, 'bid on auctions', 'submit timed offers');
  source = replaceOptional(source, 'bid on timed auctions', 'submit timed offers');
  write(relative, source);
}

function patchCreateListing() {
  const relative = 'lib/marketplace/oil_gas_marketplace.dart';
  let source = read(relative);
  source = replaceOptional(source, 'Timed Auctions', 'Timed Buying');
  source = replaceOptional(source, 'Timed Auction', 'Timed Buying');
  source = replaceRegex(
    source,
    /Text\('Auction'\)/g,
    "Text('Timed Buying')",
  );
  source = replaceRegex(
    source,
    /(value:\s*'Auction'[\s\S]{0,120}?Text\()'Auction'(\))/g,
    "$1'Timed Buying'$2",
  );
  write(relative, source);
}

function patchSupportingUi() {
  const optional = [
    'lib/marketplace/marketplace_auction_settlement.dart',
    'lib/marketplace/marketplace_freight_quote.dart',
    'lib/marketplace/marketplace_public_profile_page.dart',
    'lib/marketplace/marketplace_dispatch_page.dart',
  ];
  for (const relative of optional) {
    if (!fs.existsSync(file(relative))) continue;
    let source = read(relative);
    source = replaceOptional(source, 'Timed Auctions', 'Timed Buying');
    source = replaceOptional(source, 'Timed Auction', 'Timed Buying');
    source = replaceOptional(source, 'timed auctions', 'Timed Buying');
    source = replaceRegex(source, /Text\('Auction'\)/g, "Text('Timed Buying')");
    source = replaceOptional(source, 'Auction listing', 'Timed Buying listing');
    source = replaceOptional(source, 'auction listing', 'Timed Buying listing');
    source = replaceOptional(source, 'winning bidder', 'successful buyer');
    source = replaceOptional(source, 'Winning bidder', 'Successful buyer');
    write(relative, source);
  }
}

patchTimedBuyingPage();
patchAccountHub();
patchAuth();
patchCreateListing();
patchSupportingUi();

console.log('\nTimed Buying public-language + urgency + offer-action migration applied.');
console.log('Internal Auction field names and callable identifiers were intentionally preserved for data compatibility.');
