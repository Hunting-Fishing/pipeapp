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
  if (!fs.existsSync(required)) throw new Error(`Missing ${path.relative(root, required)}`);
}

function replaceOnce(source, before, after, label) {
  if (source.includes(after)) return source;
  if (!source.includes(before)) throw new Error(`Could not apply ${label}. Expected anchor was not found.`);
  return source.replace(before, after);
}

// ---------------------------------------------------------------------------
// Flutter Timed Buying board + detail trust presentation.
// ---------------------------------------------------------------------------
let page = fs.readFileSync(pagePath, 'utf8');
if (!page.includes('Review & submit timed offer')) {
  throw new Error('Verified Timed Buying offer flow is missing. Apply the Timed Buying experience first.');
}
if (!page.includes('TimedBuyingAttentionFrame(') && !page.includes('TimedBuyingTrustFrame(')) {
  throw new Error('Timed Buying attention pass is missing. Apply attention before the trust pass.');
}

const trustImport = "import 'marketplace_timed_buying_trust.dart';";
if (!page.includes(trustImport)) {
  const anchor = "import 'marketplace_timed_buying_engagement.dart';";
  if (!page.includes(anchor)) throw new Error('Timed Buying engagement import is missing.');
  page = page.replace(anchor, `${anchor}\n${trustImport}`);
}

page = replaceOnce(
  page,
  '        Expanded(child: _body(auctions)),',
  `        Expanded(\n          child: TimedBuyingViewerParticipationScope(\n            viewerUid: uid,\n            child: _body(auctions),\n          ),\n        ),`,
  'viewer participation scope',
);

const cardStart = page.indexOf('class _AuctionCard extends StatelessWidget');
const cardEnd = page.indexOf('class _AuctionStateBadge extends StatelessWidget');
if (cardStart < 0 || cardEnd < 0 || cardEnd <= cardStart) {
  throw new Error('Could not isolate the Timed Buying board card.');
}
let card = page.slice(cardStart, cardEnd);

if (!card.includes('final participation =')) {
  const stateAnchor = `    final viewerOwnsListing = viewerUid != null && data['sellerUid'] == viewerUid;\n`;
  const stateReplacement = `${stateAnchor}    final participation = TimedBuyingViewerParticipationScope.maybeOf(context)\n            ?.forListing(document.id, data) ??\n        deriveTimedBuyingViewerParticipation(\n          viewerUid: viewerUid,\n          listing: data,\n          viewerOffers: const [],\n        );\n`;
  if (!card.includes(stateAnchor)) {
    throw new Error('Could not attach viewer participation state to the Timed Buying card.');
  }
  card = card.replace(stateAnchor, stateReplacement);
}

if (card.includes('return TimedBuyingAttentionFrame(')) {
  card = card.replace(
    'return TimedBuyingAttentionFrame(',
    `return TimedBuyingTrustFrame(\n      participation: participation,`,
  );
}

const oldBadge = `                if (viewerLeading || viewerOwnsListing)\n                  Positioned(\n                    right: 10,\n                    top: 10,\n                    child: TimedBuyingViewerPositionBadge(\n                      position: viewerOwnsListing\n                          ? TimedBuyingViewerPosition.seller\n                          : TimedBuyingViewerPosition.leading,\n                    ),\n                  ),`;
const newBadge = `                if (viewerOwnsListing || participation.hasParticipated)\n                  Positioned(\n                    right: 10,\n                    top: 10,\n                    child: viewerOwnsListing\n                        ? const TimedBuyingViewerPositionBadge(\n                            position: TimedBuyingViewerPosition.seller,\n                          )\n                        : TimedBuyingParticipationBadge(\n                            participation: participation,\n                          ),\n                  ),`;
if (!card.includes(newBadge)) {
  if (!card.includes(oldBadge)) {
    throw new Error('Could not upgrade the Timed Buying card participation badge.');
  }
  card = card.replace(oldBadge, newBadge);
}

page = page.slice(0, cardStart) + card + page.slice(cardEnd);

const trustHistoryAnchor = `                          _BidHistory(\n                            listingId: widget.document.id,\n                            listing: data,\n                          ),`;
const trustHistoryReplacement = `                          const TimedBuyingTrustStrip(),\n                          const SizedBox(height: 8),\n                          _BidHistory(\n                            listingId: widget.document.id,\n                            listing: data,\n                          ),`;
page = replaceOnce(
  page,
  trustHistoryAnchor,
  trustHistoryReplacement,
  'authenticated activity trust strip',
);

const attentionHistoryTitle = `                    title: Row(\n                      children: [\n                        Expanded(\n                          child: Text(\n                            marketplaceMoney(data['amount'] as num? ?? 0),\n                            style: const TextStyle(fontWeight: FontWeight.w900),\n                          ),\n                        ),\n                        if (viewerOwnsOffer)\n                          TimedBuyingViewerPositionBadge(\n                            position: leadingOffer\n                                ? TimedBuyingViewerPosition.leading\n                                : surpassedOffer\n                                    ? TimedBuyingViewerPosition.outbid\n                                    : TimedBuyingViewerPosition.participating,\n                          ),\n                      ],\n                    ),`;
const trustHistoryTitle = `                    title: TimedBuyingOfferActivityHeader(\n                      bid: data,\n                      viewerUid: uid,\n                    ),`;
page = replaceOnce(
  page,
  attentionHistoryTitle,
  trustHistoryTitle,
  'participant identity in Timed Offer Activity',
);

fs.writeFileSync(pagePath, page, 'utf8');
console.log(`updated ${pageRelative}`);

// ---------------------------------------------------------------------------
// Backend: every new timed offer receives a bounded public identity snapshot.
// Personal names are masked; business names use the existing public profile.
// ---------------------------------------------------------------------------
let backend = fs.readFileSync(backendPath, 'utf8');

if (!backend.includes('async function timedOfferPublicIdentity(')) {
  const insertBefore = '  const placeAuctionBid = featureCommand("auctions", async (request) => {';
  const index = backend.indexOf(insertBefore);
  if (index < 0) throw new Error('Could not insert Timed Buying public identity helper.');
  const helper = `  function maskedTimedOfferPersonalName(rawName) {\n    const parts = String(rawName || \"\").trim().split(/\\s+/).filter(Boolean);\n    if (parts.length === 0) return \"Authenticated buyer\";\n    if (parts.length === 1) return parts[0].slice(0, 40);\n    const last = parts[parts.length - 1];\n    return (parts[0] + \" \" + last.slice(0, 1).toUpperCase() + \".\").slice(0, 80);\n  }\n\n  async function timedOfferPublicIdentity(transaction, buyerUid, request) {\n    const userSnapshot = await transaction.get(db.collection(\"users\").doc(buyerUid));\n    const user = userSnapshot.data() || {};\n    const accountType = String(user.accountType || \"personal\").trim() || \"personal\";\n    let publicName = \"\";\n    if (accountType === \"business\") {\n      const businessSnapshot = await transaction.get(\n          db.collection(\"public_business_profiles\").doc(buyerUid),\n      );\n      publicName = String(\n          businessSnapshot.data() && businessSnapshot.data().publicName ||\n          user.businessName || user.displayName || user.display_name || \"\",\n      ).trim();\n    } else {\n      const personalName = String(\n          user.display_name || user.displayName ||\n          (buyerUid === request.auth.uid && request.auth.token && request.auth.token.name) ||\n          \"\",\n      ).trim();\n      publicName = maskedTimedOfferPersonalName(personalName);\n    }\n    return {\n      bidderPublicName: (publicName || \"Authenticated buyer\").slice(0, 160),\n      bidderVerified: approvedAccountVerification(user),\n      bidderAccountType: accountType.slice(0, 40),\n      bidderIdentityVersion: 1,\n    };\n  }\n\n`;
  backend = backend.slice(0, index) + helper + backend.slice(index);
}

const eligibilityAnchor = `      await requireEligibleBidder(transaction, uid, isAdministrator(request));\n\n      let previousBidRef = null;`;
const identityAnchor = `      await requireEligibleBidder(transaction, uid, isAdministrator(request));\n      const bidderIdentity = await timedOfferPublicIdentity(\n          transaction, uid, request,\n      );\n      const sequenceNumber = Number(listing.bidCount || 0) + 1;\n\n      let previousBidRef = null;`;
backend = replaceOnce(
  backend,
  eligibilityAnchor,
  identityAnchor,
  'server-side timed-offer identity snapshot',
);

const bidWriteAnchor = `        bidderUid: uid,\n        amount: validated.amount,`;
const bidWriteReplacement = `        bidderUid: uid,\n        ...bidderIdentity,\n        sequenceNumber,\n        amount: validated.amount,`;
backend = replaceOnce(
  backend,
  bidWriteAnchor,
  bidWriteReplacement,
  'timed-offer trust fields',
);

fs.writeFileSync(backendPath, backend, 'utf8');
console.log(`updated ${backendRelative}`);

// ---------------------------------------------------------------------------
// Sandbox: multiple authenticated participants, not six offers from one user.
// visual-buyer is outbid by the verified carrier on the last offer so both
// leading and surpassed states can be reviewed by switching test accounts.
// ---------------------------------------------------------------------------
let seed = fs.readFileSync(seedPath, 'utf8');
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

const liveOffersStart = seed.indexOf('  const liveBidAmounts = [');
const endedOfferStart = seed.indexOf('  set("auction_bids/visual-ended-bid-009"', liveOffersStart);
if (liveOffersStart < 0 || endedOfferStart < 0 || endedOfferStart <= liveOffersStart) {
  throw new Error('Could not isolate the visual Timed Buying offer fixture.');
}
const trustedOffers = `  const liveTimedOffers = [\n    {amount: 36000, bidderUid: \"visual-buyer\", bidderPublicName: \"Alex B.\", bidderAccountType: \"personal\"},\n    {amount: 37500, bidderUid: \"visual-carrier\", bidderPublicName: \"Northline Heavy Haul Ltd.\", bidderAccountType: \"business\"},\n    {amount: 39000, bidderUid: \"visual-buyer\", bidderPublicName: \"Alex B.\", bidderAccountType: \"personal\"},\n    {amount: 40500, bidderUid: \"visual-carrier\", bidderPublicName: \"Northline Heavy Haul Ltd.\", bidderAccountType: \"business\"},\n    {amount: 41500, bidderUid: \"visual-buyer\", bidderPublicName: \"Alex B.\", bidderAccountType: \"personal\"},\n    {amount: 42500, bidderUid: \"visual-carrier\", bidderPublicName: \"Northline Heavy Haul Ltd.\", bidderAccountType: \"business\"},\n    {amount: 43500, bidderUid: \"visual-buyer\", bidderPublicName: \"Alex B.\", bidderAccountType: \"personal\"},\n    {amount: 44500, bidderUid: \"visual-carrier\", bidderPublicName: \"Northline Heavy Haul Ltd.\", bidderAccountType: \"business\"},\n  ];\n  liveTimedOffers.forEach((offer, index) => {\n    const number = String(index + 1).padStart(3, \"0\");\n    set(\`auction_bids/visual-auction-bid-\${number}\`, {\n      listingId: \"visual-auction-dozer\",\n      bidderUid: offer.bidderUid,\n      bidderPublicName: offer.bidderPublicName,\n      bidderVerified: true,\n      bidderAccountType: offer.bidderAccountType,\n      bidderIdentityVersion: 1,\n      sequenceNumber: index + 1,\n      amount: offer.amount,\n      status: index === liveTimedOffers.length - 1 ? \"leading\" : \"outbid\",\n      createdAt: atHours(-8 + index),\n      visualSandbox: true,\n    });\n  });\n`;
seed = seed.slice(0, liveOffersStart) + trustedOffers + seed.slice(endedOfferStart);

fs.writeFileSync(seedPath, seed, 'utf8');
console.log(`updated ${seedRelative}`);

if (!page.includes('TimedBuyingTrustFrame(') ||
    !page.includes('TimedBuyingParticipationBadge(') ||
    !page.includes('TimedBuyingOfferActivityHeader(') ||
    !page.includes('TimedBuyingTrustStrip()') ||
    !backend.includes('bidderPublicName') ||
    !backend.includes('sequenceNumber') ||
    !seed.includes('Northline Heavy Haul Ltd.')) {
  throw new Error('Timed Buying trust migration did not produce all required markers.');
}

console.log('\nTimed Buying participant trust enhancement applied.');
console.log('Public participant identity is bounded: verified status + business public name or masked personal name.');
console.log('No anonymous timed offers are represented; bidderUid remains authoritative and server-written.');
