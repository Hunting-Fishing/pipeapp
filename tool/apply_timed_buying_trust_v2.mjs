import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const pageRelative = 'lib/marketplace/marketplace_auctions_page.dart';
const backendRelative = 'firebase/functions/marketplace_commands.js';
const seedRelative = 'firebase/functions/scripts/seed_visual_sandbox.js';

const pagePath = path.join(root, pageRelative);
const backendPath = path.join(root, backendRelative);
const seedPath = path.join(root, seedRelative);

for (const required of [pagePath, backendPath, seedPath]) {
  if (!fs.existsSync(required)) {
    throw new Error(`Missing ${path.relative(root, required)}`);
  }
}

function normalize(source) {
  return source.replace(/\r\n/g, '\n');
}

function insertBeforeIndex(source, index, text) {
  return source.slice(0, index) + text + source.slice(index);
}

function requireReplace(source, pattern, replacement, label) {
  if (typeof pattern === 'string') {
    if (source.includes(replacement)) return source;
    if (!source.includes(pattern)) {
      throw new Error(`Could not apply ${label}. Expected anchor was not found.`);
    }
    return source.replace(pattern, replacement);
  }
  if (pattern.test(source)) return source.replace(pattern, replacement);
  throw new Error(`Could not apply ${label}. Expected structural anchor was not found.`);
}

function optionalReplaceAll(source, before, after) {
  return source.includes(before) ? source.replaceAll(before, after) : source;
}

let page = normalize(fs.readFileSync(pagePath, 'utf8'));
if (!page.includes('Review & submit timed offer')) {
  throw new Error('Verified Timed Buying offer flow is missing. Preserve the verified offer flow before applying trust v2.');
}
if (!page.includes('Asset overview')) {
  throw new Error('Professional compact Asset Overview is missing. Preserve the verified compact detail pass.');
}

// Repair known mojibake introduced by prior Windows text migrations.
page = page
  .replaceAll('â€¢', '•')
  .replaceAll('â€¦', '…')
  .replaceAll('â€™', '’')
  .replaceAll('â€˜', '‘')
  .replaceAll('â€œ', '“')
  .replaceAll('â€', '”')
  .replaceAll('â€‘', '‑');

const presentationImport = "import 'marketplace_timed_buying_presentation.dart';";
const engagementImport = "import 'marketplace_timed_buying_engagement.dart';";
const trustImport = "import 'marketplace_timed_buying_trust.dart';";
if (!page.includes(engagementImport)) {
  if (!page.includes(presentationImport)) {
    throw new Error('Timed Buying presentation import is missing.');
  }
  page = page.replace(presentationImport, `${presentationImport}\n${engagementImport}`);
}
if (!page.includes(trustImport)) {
  page = page.replace(engagementImport, `${engagementImport}\n${trustImport}`);
}

page = page.replaceAll('TimedBuyingUrgencyFrame(', 'TimedBuyingAttentionFrame(');
page = page.replaceAll('showTimedBuyingLegend(context)', 'showTimedBuyingAttentionLegend(context)');
page = optionalReplaceAll(
  page,
  "'${data['title'] ?? 'Timed Buying listing'}'",
  "timedBuyingDisplayTitle(data['title'])",
);
page = optionalReplaceAll(
  page,
  "'${data['title'] ?? 'Auction listing'}'",
  "timedBuyingDisplayTitle(data['title'])",
);

// Board-level viewer-offer scope. This streams only the signed-in viewer's offers.
if (!page.includes('TimedBuyingViewerParticipationScope(')) {
  const bodyPattern = /([ \t]*)Expanded\(child: _body\(auctions\)\),/;
  const bodyMatch = page.match(bodyPattern);
  if (!bodyMatch || bodyMatch.index == null) {
    throw new Error('Could not wrap the Timed Buying board in viewer participation scope.');
  }
  const indent = bodyMatch[1];
  const replacement = `${indent}Expanded(\n${indent}  child: TimedBuyingViewerParticipationScope(\n${indent}    viewerUid: uid,\n${indent}    child: _body(auctions),\n${indent}  ),\n${indent}),`;
  page = page.replace(bodyPattern, replacement);
}

const cardStart = page.indexOf('class _AuctionCard extends StatelessWidget');
const cardEnd = page.indexOf('class _AuctionStateBadge extends StatelessWidget');
if (cardStart < 0 || cardEnd < 0 || cardEnd <= cardStart) {
  throw new Error('Could not isolate the Timed Buying board card.');
}
let card = page.slice(cardStart, cardEnd);

if (!card.includes('final viewerUid =')) {
  const statePattern = /(\s*final live = isAuctionLive\(data, now\);\n)(\s*final presentation = MarketplaceListingPresentation\.fromMap\()/;
  const stateMatch = card.match(statePattern);
  if (!stateMatch) {
    throw new Error('Could not add current-viewer state to the Timed Buying card.');
  }
  const baseIndent = stateMatch[1].match(/\n([ \t]*)final live/)?.[1] ?? '    ';
  const insert = `${stateMatch[1]}${baseIndent}final viewerUid = FirebaseAuth.instance.currentUser?.uid;\n${baseIndent}final viewerLeading = viewerUid != null && data['highBidderUid'] == viewerUid;\n${baseIndent}final viewerOwnsListing = viewerUid != null && data['sellerUid'] == viewerUid;\n`;
  card = card.replace(statePattern, `${insert}${stateMatch[2]}`);
}

if (!card.includes('final participation =')) {
  const ownerPattern = /(\s*final viewerOwnsListing = viewerUid != null && data\['sellerUid'\] == viewerUid;\n)/;
  const ownerMatch = card.match(ownerPattern);
  if (!ownerMatch) throw new Error('Could not attach viewer participation state to the card.');
  const indent = ownerMatch[1].match(/^([ \t]*)/)?.[1] ?? '    ';
  const state = `${ownerMatch[1]}${indent}final participation = TimedBuyingViewerParticipationScope.maybeOf(context)\n${indent}        ?.forListing(document.id, data) ??\n${indent}    deriveTimedBuyingViewerParticipation(\n${indent}      viewerUid: viewerUid,\n${indent}      listing: data,\n${indent}      viewerOffers: const [],\n${indent}    );\n`;
  card = card.replace(ownerPattern, state);
}

if (!card.includes('return TimedBuyingTrustFrame(')) {
  if (!card.includes('return TimedBuyingAttentionFrame(')) {
    throw new Error('Could not find the Timed Buying attention frame on the card.');
  }
  card = card.replace(
    'return TimedBuyingAttentionFrame(',
    'return TimedBuyingTrustFrame(\n      participation: participation,',
  );
}

// Insert the signed-in viewer status at the top-right of the media without
// depending on the exact indentation created by earlier compact passes.
if (!card.includes('TimedBuyingParticipationBadge(')) {
  const stateBadgePattern = /^([ \t]*)Positioned\(\n[ \t]*right: 10,\n[ \t]*bottom: 10,\n[ \t]*child: _AuctionStateBadge\(/m;
  const stateBadge = card.match(stateBadgePattern);
  if (!stateBadge || stateBadge.index == null) {
    throw new Error('Could not locate the LIVE/ENDED/UPCOMING badge structurally.');
  }
  const indent = stateBadge[1];
  const participantBadge = `${indent}if (viewerOwnsListing || participation.hasParticipated)\n${indent}  Positioned(\n${indent}    right: 10,\n${indent}    top: 10,\n${indent}    child: viewerOwnsListing\n${indent}        ? const TimedBuyingViewerPositionBadge(\n${indent}            position: TimedBuyingViewerPosition.seller,\n${indent}          )\n${indent}        : TimedBuyingParticipationBadge(\n${indent}            participation: participation,\n${indent}          ),\n${indent}  ),\n`;
  card = insertBeforeIndex(card, stateBadge.index, participantBadge);
}

if (!card.includes('TimedBuyingAttentionStrip(')) {
  const firstPaddingPattern = /^([ \t]*)Padding\(\n[ \t]*padding: const EdgeInsets\.fromLTRB\(14, 13, 14, 14\),/m;
  const padding = card.match(firstPaddingPattern);
  if (!padding || padding.index == null) {
    throw new Error('Could not place the explicit urgency strip beneath the Timed Buying card media.');
  }
  const indent = padding[1];
  const strip = `${indent}TimedBuyingAttentionStrip(\n${indent}  start: start,\n${indent}  end: end,\n${indent}  compact: true,\n${indent}),\n`;
  card = insertBeforeIndex(card, padding.index, strip);
}

page = page.slice(0, cardStart) + card + page.slice(cardEnd);

// Highlight the viewer's own rows in Timed Offer Activity and expose participant identity.
const historyStart = page.indexOf('class _BidHistory extends StatelessWidget');
const historyEnd = page.indexOf('class _AuctionLoadError extends StatelessWidget');
if (historyStart < 0 || historyEnd < 0 || historyEnd <= historyStart) {
  throw new Error('Could not isolate Timed Offer Activity.');
}
let history = page.slice(historyStart, historyEnd);

if (!history.includes('final viewerOwnsOffer =')) {
  const returnCardPattern = /(\s*)return Card\(\n([ \t]*)margin:/;
  const returnMatch = history.match(returnCardPattern);
  if (!returnMatch) throw new Error('Could not locate Timed Offer Activity card rows.');
  const statementIndent = returnMatch[1].match(/\n([ \t]*)$/)?.[1] ?? '                ';
  const cardPropIndent = returnMatch[2];
  const state = `${statementIndent}final viewerOwnsOffer = uid != null && data['bidderUid'] == uid;\n${statementIndent}final leadingOffer = data['status'] == 'leading' || data['status'] == 'won';\n${statementIndent}final surpassedOffer = data['status'] == 'outbid';\n${statementIndent}final viewerRowColor = leadingOffer\n${statementIndent}    ? PipeBuyerColors.success\n${statementIndent}    : surpassedOffer\n${statementIndent}        ? PipeBuyerColors.danger\n${statementIndent}        : PipeBuyerColors.orangePressed;\n${statementIndent}return Card(\n${cardPropIndent}color: viewerOwnsOffer\n${cardPropIndent}    ? viewerRowColor.withValues(alpha: .07)\n${cardPropIndent}    : null,\n${cardPropIndent}shape: RoundedRectangleBorder(\n${cardPropIndent}  borderRadius: BorderRadius.circular(10),\n${cardPropIndent}  side: BorderSide(\n${cardPropIndent}    color: viewerOwnsOffer\n${cardPropIndent}        ? viewerRowColor.withValues(alpha: .58)\n${cardPropIndent}        : Theme.of(context).dividerColor,\n${cardPropIndent}    width: viewerOwnsOffer ? 1.4 : .7,\n${cardPropIndent}  ),\n${cardPropIndent}),\n${cardPropIndent}margin:`;
  history = history.replace(returnCardPattern, state);
}

if (!history.includes('TimedBuyingOfferActivityHeader(')) {
  const titlePattern = /title:\s*Text\(\s*marketplaceMoney\(data\['amount'\] as num\? \?\? 0\),\s*style:\s*const TextStyle\(fontWeight: FontWeight\.w900\),\s*\),/s;
  if (!titlePattern.test(history)) {
    throw new Error('Could not replace the Timed Offer Activity amount header with participant identity.');
  }
  history = history.replace(
    titlePattern,
    `title: TimedBuyingOfferActivityHeader(\n                      bid: data,\n                      viewerUid: uid,\n                    ),`,
  );
}

page = page.slice(0, historyStart) + history + page.slice(historyEnd);

// Add a buyer-position summary directly above authenticated activity.
if (!page.includes('class _TimedBuyingBuyerTrustPosition extends StatelessWidget')) {
  const insertBefore = 'class _AuctionDetailHero extends StatelessWidget {';
  const index = page.indexOf(insertBefore);
  if (index < 0) throw new Error('Could not insert Timed Buying buyer trust-position widget.');
  const widgetClass = `class _TimedBuyingBuyerTrustPosition extends StatelessWidget {\n  const _TimedBuyingBuyerTrustPosition({\n    required this.listingId,\n    required this.listing,\n    required this.nextOffer,\n    required this.live,\n  });\n\n  final String listingId;\n  final Map<String, dynamic> listing;\n  final num nextOffer;\n  final bool live;\n\n  @override\n  Widget build(BuildContext context) {\n    final uid = FirebaseAuth.instance.currentUser?.uid;\n    if (uid == null || uid.isEmpty || listing['sellerUid'] == uid) {\n      return const SizedBox.shrink();\n    }\n    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(\n      stream: FirebaseFirestore.instance\n          .collection('auction_bids')\n          .where('listingId', isEqualTo: listingId)\n          .orderBy('createdAt', descending: true)\n          .limit(defaultActivityFeedLimit)\n          .snapshots(),\n      builder: (context, snapshot) {\n        final offers = (snapshot.data?.docs ?? const [])\n            .map((document) => document.data())\n            .toList(growable: false);\n        final participation = deriveTimedBuyingViewerParticipation(\n          viewerUid: uid,\n          listing: listing,\n          viewerOffers: offers,\n        );\n        if (!participation.hasParticipated) return const SizedBox.shrink();\n        final color = participation.leading\n            ? PipeBuyerColors.success\n            : participation.outbid\n                ? PipeBuyerColors.danger\n                : PipeBuyerColors.orangePressed;\n        final offersAhead = participation.offersAhead;\n        final detail = participation.leading\n            ? 'Your top timed offer is ${marketplaceMoney(participation.viewerTopOffer)} and it is the current lead.'\n            : participation.outbid\n                ? 'Your top: ${marketplaceMoney(participation.viewerTopOffer)} • Lead: ${marketplaceMoney(participation.currentLead)} • Behind by ${marketplaceMoney(participation.amountBehind)}${offersAhead != null ? ' • $offersAhead ${offersAhead == 1 ? 'offer' : 'offers'} ahead' : ''}${live ? ' • Next minimum: ${marketplaceMoney(nextOffer)}' : ''}'\n                : 'You have an active timed offer on this listing.';\n        return Container(\n          margin: const EdgeInsets.only(bottom: 10),\n          padding: const EdgeInsets.all(12),\n          decoration: BoxDecoration(\n            color: color.withValues(alpha: .07),\n            borderRadius: BorderRadius.circular(12),\n            border: Border.all(color: color.withValues(alpha: .5), width: 1.3),\n          ),\n          child: Row(\n            crossAxisAlignment: CrossAxisAlignment.start,\n            children: [\n              Icon(\n                participation.leading\n                    ? Icons.emoji_events_outlined\n                    : Icons.trending_up_outlined,\n                color: color,\n              ),\n              const SizedBox(width: 9),\n              Expanded(\n                child: Column(\n                  crossAxisAlignment: CrossAxisAlignment.start,\n                  children: [\n                    Text(\n                      participation.compactStatusLabel,\n                      style: TextStyle(\n                        color: color,\n                        fontWeight: FontWeight.w900,\n                        fontSize: 13,\n                      ),\n                    ),\n                    const SizedBox(height: 3),\n                    Text(\n                      detail,\n                      style: const TextStyle(\n                        color: PipeBuyerColors.graphite,\n                        fontSize: 11.5,\n                        height: 1.35,\n                        fontWeight: FontWeight.w600,\n                      ),\n                    ),\n                  ],\n                ),\n              ),\n            ],\n          ),\n        );\n      },\n    );\n  }\n}\n\n`;
  page = insertBeforeIndex(page, index, widgetClass);
}

if (!page.includes('const TimedBuyingTrustStrip()')) {
  const bidHistoryPattern = /([ \t]*)_BidHistory\(\n[ \t]*listingId: widget\.document\.id,\n[ \t]*listing: data,\n[ \t]*\),/;
  const bidHistory = page.match(bidHistoryPattern);
  if (!bidHistory || bidHistory.index == null) {
    throw new Error('Could not attach authenticated-member trust presentation above Timed Offer Activity.');
  }
  const indent = bidHistory[1];
  const replacement = `${indent}_TimedBuyingBuyerTrustPosition(\n${indent}  listingId: widget.document.id,\n${indent}  listing: data,\n${indent}  nextOffer: next,\n${indent}  live: live,\n${indent}),\n${indent}const TimedBuyingTrustStrip(),\n${indent}const SizedBox(height: 8),\n${bidHistory[0]}`;
  page = page.replace(bidHistoryPattern, replacement);
}

fs.writeFileSync(pagePath, page, 'utf8');
console.log(`updated ${pageRelative}`);

// ---------------------------------------------------------------------------
// Backend identity snapshot for every new timed offer.
// ---------------------------------------------------------------------------
let backend = normalize(fs.readFileSync(backendPath, 'utf8'));
if (!backend.includes('async function timedOfferPublicIdentity(')) {
  const insertBefore = '  const placeAuctionBid = featureCommand("auctions", async (request) => {';
  const index = backend.indexOf(insertBefore);
  if (index < 0) throw new Error('Could not insert Timed Buying public identity helper.');
  const helper = `  function maskedTimedOfferPersonalName(rawName) {\n    const parts = String(rawName || \"\").trim().split(/\\s+/).filter(Boolean);\n    if (parts.length === 0) return \"Authenticated buyer\";\n    if (parts.length === 1) return parts[0].slice(0, 40);\n    const last = parts[parts.length - 1];\n    return (parts[0] + \" \" + last.slice(0, 1).toUpperCase() + \".\").slice(0, 80);\n  }\n\n  async function timedOfferPublicIdentity(transaction, buyerUid, request) {\n    const userSnapshot = await transaction.get(db.collection(\"users\").doc(buyerUid));\n    const user = userSnapshot.data() || {};\n    const accountType = String(user.accountType || \"personal\").trim() || \"personal\";\n    let publicName = \"\";\n    if (accountType === \"business\") {\n      const businessSnapshot = await transaction.get(\n          db.collection(\"public_business_profiles\").doc(buyerUid),\n      );\n      publicName = String(\n          businessSnapshot.data() && businessSnapshot.data().publicName ||\n          user.businessName || user.displayName || user.display_name || \"\",\n      ).trim();\n    } else {\n      const personalName = String(\n          user.display_name || user.displayName ||\n          (buyerUid === request.auth.uid && request.auth.token && request.auth.token.name) ||\n          \"\",\n      ).trim();\n      publicName = maskedTimedOfferPersonalName(personalName);\n    }\n    return {\n      bidderPublicName: (publicName || \"Authenticated buyer\").slice(0, 160),\n      bidderVerified: approvedAccountVerification(user),\n      bidderAccountType: accountType.slice(0, 40),\n      bidderIdentityVersion: 1,\n    };\n  }\n\n`;
  backend = insertBeforeIndex(backend, index, helper);
}

if (!backend.includes('const bidderIdentity = await timedOfferPublicIdentity(')) {
  backend = requireReplace(
    backend,
    `      await requireEligibleBidder(transaction, uid, isAdministrator(request));\n\n      let previousBidRef = null;`,
    `      await requireEligibleBidder(transaction, uid, isAdministrator(request));\n      const bidderIdentity = await timedOfferPublicIdentity(\n          transaction, uid, request,\n      );\n      const sequenceNumber = Number(listing.bidCount || 0) + 1;\n\n      let previousBidRef = null;`,
    'server-side timed-offer identity snapshot',
  );
}
if (!backend.includes('...bidderIdentity,')) {
  backend = requireReplace(
    backend,
    `        bidderUid: uid,\n        amount: validated.amount,`,
    `        bidderUid: uid,\n        ...bidderIdentity,\n        sequenceNumber,\n        amount: validated.amount,`,
    'timed-offer identity fields',
  );
}
fs.writeFileSync(backendPath, backend, 'utf8');
console.log(`updated ${backendRelative}`);

// ---------------------------------------------------------------------------
// Deterministic sandbox: two authenticated participants alternate offers.
// ---------------------------------------------------------------------------
let seed = normalize(fs.readFileSync(seedPath, 'utf8'));
seed = seed.replaceAll('Timed Auction — CAT D6 Dozer', 'Timed Buying — CAT D6 Dozer');
seed = seed.replaceAll(
  'Live visual-sandbox auction with six bids and a closing-time urgency state.',
  'Live visual-sandbox Timed Buying listing with authenticated member activity and a closing-time urgency state.',
);
seed = seed.replace('currentBid: 42500,', 'currentBid: 44500,');
seed = seed.replace('bidCount: 6,', 'bidCount: 8,');
seed = seed.replace('highBidderUid: "visual-buyer",', 'highBidderUid: "visual-carrier",');
seed = seed.replace('currentBidId: "visual-auction-bid-006",', 'currentBidId: "visual-auction-bid-008",');
seed = seed.replace('auctionEndAt: atHours(6),', 'auctionEndAt: atHours(5),');

if (!seed.includes('Northline Heavy Haul Ltd.')) {
  const liveOffersStart = seed.indexOf('  const liveBidAmounts = [');
  const endedOfferStart = seed.indexOf('  set("auction_bids/visual-ended-bid-009"', liveOffersStart);
  if (liveOffersStart < 0 || endedOfferStart < 0 || endedOfferStart <= liveOffersStart) {
    throw new Error('Could not isolate the visual Timed Buying offer fixture.');
  }
  const trustedOffers = `  const liveTimedOffers = [\n    {amount: 36000, bidderUid: \"visual-buyer\", bidderPublicName: \"Alex B.\", bidderAccountType: \"personal\"},\n    {amount: 37500, bidderUid: \"visual-carrier\", bidderPublicName: \"Northline Heavy Haul Ltd.\", bidderAccountType: \"business\"},\n    {amount: 39000, bidderUid: \"visual-buyer\", bidderPublicName: \"Alex B.\", bidderAccountType: \"personal\"},\n    {amount: 40500, bidderUid: \"visual-carrier\", bidderPublicName: \"Northline Heavy Haul Ltd.\", bidderAccountType: \"business\"},\n    {amount: 41500, bidderUid: \"visual-buyer\", bidderPublicName: \"Alex B.\", bidderAccountType: \"personal\"},\n    {amount: 42500, bidderUid: \"visual-carrier\", bidderPublicName: \"Northline Heavy Haul Ltd.\", bidderAccountType: \"business\"},\n    {amount: 43500, bidderUid: \"visual-buyer\", bidderPublicName: \"Alex B.\", bidderAccountType: \"personal\"},\n    {amount: 44500, bidderUid: \"visual-carrier\", bidderPublicName: \"Northline Heavy Haul Ltd.\", bidderAccountType: \"business\"},\n  ];\n  liveTimedOffers.forEach((offer, index) => {\n    const number = String(index + 1).padStart(3, \"0\");\n    set(\`auction_bids/visual-auction-bid-\${number}\`, {\n      listingId: \"visual-auction-dozer\",\n      bidderUid: offer.bidderUid,\n      bidderPublicName: offer.bidderPublicName,\n      bidderVerified: true,\n      bidderAccountType: offer.bidderAccountType,\n      bidderIdentityVersion: 1,\n      sequenceNumber: index + 1,\n      amount: offer.amount,\n      status: index === liveTimedOffers.length - 1 ? \"leading\" : \"outbid\",\n      createdAt: atHours(-8 + index),\n      visualSandbox: true,\n    });\n  });\n`;
  seed = seed.slice(0, liveOffersStart) + trustedOffers + seed.slice(endedOfferStart);
}
fs.writeFileSync(seedPath, seed, 'utf8');
console.log(`updated ${seedRelative}`);

const requiredMarkers = [
  'TimedBuyingTrustFrame(',
  'TimedBuyingParticipationBadge(',
  'TimedBuyingOfferActivityHeader(',
  'TimedBuyingTrustStrip()',
  '_TimedBuyingBuyerTrustPosition(',
  'TimedBuyingAttentionStrip(',
];
for (const marker of requiredMarkers) {
  if (!page.includes(marker)) throw new Error(`Timed Buying trust v2 is missing marker: ${marker}`);
}
if (!backend.includes('bidderPublicName') || !backend.includes('sequenceNumber')) {
  throw new Error('Timed Buying backend identity markers are missing.');
}
if (!seed.includes('Northline Heavy Haul Ltd.')) {
  throw new Error('Authenticated multi-participant sandbox fixture is missing.');
}

console.log('\nTimed Buying trust v2 applied successfully.');
console.log('The migration is indentation-tolerant and preserves the compact local card layout.');
console.log('Viewer participation, leading/outbid position, verified identity and authenticated activity are now represented.');
