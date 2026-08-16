import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const pageRelative = 'lib/marketplace/marketplace_auctions_page.dart';
const pagePath = path.join(root, pageRelative);
if (!fs.existsSync(pagePath)) throw new Error(`Missing ${pageRelative}`);

let source = fs.readFileSync(pagePath, 'utf8');

function optionalReplace(before, after) {
  if (source.includes(before)) source = source.replaceAll(before, after);
}

if (!source.includes('Review & submit timed offer') ||
    !source.includes('TimedBuyingUrgencyFrame(')) {
  throw new Error(
    'Apply the verified Timed Buying migration before the attention/position pass.',
  );
}

const engagementImport = "import 'marketplace_timed_buying_engagement.dart';";
if (!source.includes(engagementImport)) {
  const anchor = "import 'marketplace_timed_buying_presentation.dart';";
  if (!source.includes(anchor)) {
    throw new Error('Timed Buying presentation import is missing.');
  }
  source = source.replace(anchor, `${anchor}\n${engagementImport}`);
}

source = source.replaceAll('TimedBuyingUrgencyFrame(', 'TimedBuyingAttentionFrame(');
source = source.replaceAll('showTimedBuyingLegend(context)', 'showTimedBuyingAttentionLegend(context)');

optionalReplace(
  "'\${data['title'] ?? 'Timed Buying listing'}'",
  "timedBuyingDisplayTitle(data['title'])",
);
optionalReplace(
  "'\${data['title'] ?? 'Auction listing'}'",
  "timedBuyingDisplayTitle(data['title'])",
);
optionalReplace(
  "final description = '\${data['description'] ?? ''}'.trim();",
  "final description = timedBuyingPublicMessage('\${data['description'] ?? ''}');",
);

const cardStart = source.indexOf('class _AuctionCard extends StatelessWidget');
const cardEnd = source.indexOf('class _AuctionStateBadge extends StatelessWidget');
if (cardStart < 0 || cardEnd < 0 || cardEnd <= cardStart) {
  throw new Error('Could not isolate the Timed Buying board card.');
}
let card = source.slice(cardStart, cardEnd);

if (!card.includes('viewerLeading')) {
  const stateAnchor = `    final live = isAuctionLive(data, now);\n    final presentation = MarketplaceListingPresentation.fromMap(`;
  const replacement = `    final live = isAuctionLive(data, now);\n    final viewerUid = FirebaseAuth.instance.currentUser?.uid;\n    final viewerLeading = viewerUid != null && data['highBidderUid'] == viewerUid;\n    final viewerOwnsListing = viewerUid != null && data['sellerUid'] == viewerUid;\n    final presentation = MarketplaceListingPresentation.fromMap(`;
  if (!card.includes(stateAnchor)) {
    throw new Error('Could not add viewer position state to the Timed Buying card.');
  }
  card = card.replace(stateAnchor, replacement);
}

if (!card.includes('TimedBuyingViewerPositionBadge(')) {
  const badgeAnchor = `                Positioned(\n                  right: 10,\n                  bottom: 10,\n                  child: _AuctionStateBadge(`;
  const badge = `                if (viewerLeading || viewerOwnsListing)\n                  Positioned(\n                    right: 10,\n                    top: 10,\n                    child: TimedBuyingViewerPositionBadge(\n                      position: viewerOwnsListing\n                          ? TimedBuyingViewerPosition.seller\n                          : TimedBuyingViewerPosition.leading,\n                    ),\n                  ),\n${badgeAnchor}`;
  if (!card.includes(badgeAnchor)) {
    throw new Error('Could not place the viewer-position badge on the Timed Buying card.');
  }
  card = card.replace(badgeAnchor, badge);
}

if (!card.includes('TimedBuyingAttentionStrip(')) {
  const stripAnchor = `              ],\n            ),\n            Padding(\n              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),`;
  const strip = `              ],\n            ),\n            TimedBuyingAttentionStrip(\n              start: start,\n              end: end,\n              compact: true,\n            ),\n            Padding(\n              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),`;
  if (!card.includes(stripAnchor)) {
    throw new Error('Could not add the explicit urgency strip to the Timed Buying card.');
  }
  card = card.replace(stripAnchor, strip);
}

source = source.slice(0, cardStart) + card + source.slice(cardEnd);

if (!source.includes('class _TimedBuyingBuyerPosition extends StatelessWidget')) {
  const insertBefore = 'class _AuctionDetailHero extends StatelessWidget {';
  const index = source.indexOf(insertBefore);
  if (index < 0) throw new Error('Could not insert Timed Buying buyer-position panel.');
  const participantClass = `class _TimedBuyingBuyerPosition extends StatelessWidget {\n  const _TimedBuyingBuyerPosition({\n    required this.listingId,\n    required this.listing,\n    required this.currentOffer,\n    required this.nextOffer,\n    required this.live,\n  });\n\n  final String listingId;\n  final Map<String, dynamic> listing;\n  final num currentOffer;\n  final num nextOffer;\n  final bool live;\n\n  @override\n  Widget build(BuildContext context) {\n    final uid = FirebaseAuth.instance.currentUser?.uid;\n    if (uid == null || listing['sellerUid'] == uid) {\n      return const SizedBox.shrink();\n    }\n    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(\n      stream: FirebaseFirestore.instance\n          .collection('auction_bids')\n          .where('listingId', isEqualTo: listingId)\n          .orderBy('createdAt', descending: true)\n          .limit(defaultActivityFeedLimit)\n          .snapshots(),\n      builder: (context, snapshot) {\n        final own = (snapshot.data?.docs ?? const [])\n            .where((document) => document.data()['bidderUid'] == uid)\n            .toList(growable: false);\n        final leading = listing['highBidderUid'] == uid;\n        if (own.isEmpty && !leading) return const SizedBox.shrink();\n        final lastAmount = own.isEmpty\n            ? currentOffer\n            : (own.first.data()['amount'] as num? ?? currentOffer);\n        final color = leading ? PipeBuyerColors.success : PipeBuyerColors.danger;\n        final icon = leading\n            ? Icons.emoji_events_outlined\n            : Icons.trending_up_outlined;\n        final title = leading ? 'You’re leading' : 'You’ve been surpassed';\n        final detail = leading\n            ? 'Your \${marketplaceMoney(lastAmount)} timed offer is currently leading.'\n            : 'Your latest \${marketplaceMoney(lastAmount)} timed offer is below the current leading offer. \${live ? 'Next minimum: \${marketplaceMoney(nextOffer)}.' : 'Timed Buying is closed.'}';\n        return Container(\n          margin: const EdgeInsets.only(top: 10),\n          padding: const EdgeInsets.all(12),\n          decoration: BoxDecoration(\n            color: color.withValues(alpha: .08),\n            borderRadius: BorderRadius.circular(12),\n            border: Border.all(color: color.withValues(alpha: .48), width: 1.3),\n          ),\n          child: Row(\n            crossAxisAlignment: CrossAxisAlignment.start,\n            children: [\n              Container(\n                width: 34,\n                height: 34,\n                decoration: BoxDecoration(\n                  color: color.withValues(alpha: .12),\n                  borderRadius: BorderRadius.circular(10),\n                ),\n                child: Icon(icon, color: color, size: 19),\n              ),\n              const SizedBox(width: 9),\n              Expanded(\n                child: Column(\n                  crossAxisAlignment: CrossAxisAlignment.start,\n                  children: [\n                    Text(\n                      title,\n                      style: TextStyle(\n                        color: color,\n                        fontWeight: FontWeight.w900,\n                        fontSize: 13.5,\n                      ),\n                    ),\n                    const SizedBox(height: 3),\n                    Text(\n                      detail,\n                      style: const TextStyle(\n                        color: PipeBuyerColors.graphite,\n                        fontSize: 11.5,\n                        height: 1.3,\n                        fontWeight: FontWeight.w600,\n                      ),\n                    ),\n                  ],\n                ),\n              ),\n            ],\n          ),\n        );\n      },\n    );\n  }\n}\n\n`;
  source = source.slice(0, index) + participantClass + source.slice(index);
}

if (!source.includes('_TimedBuyingBuyerPosition(\n                                    listingId: widget.document.id')) {
  const summaryEnd = `                                    bidCount:\n                                        (data['bidCount'] as num?)?.toInt() ?? 0,\n                                  ),\n                                  if (mine && reserve != null && reserve > 0) ...[`;
  const summaryReplacement = `                                    bidCount:\n                                        (data['bidCount'] as num?)?.toInt() ?? 0,\n                                  ),\n                                  _TimedBuyingBuyerPosition(\n                                    listingId: widget.document.id,\n                                    listing: data,\n                                    currentOffer: displayedAmount,\n                                    nextOffer: next,\n                                    live: live,\n                                  ),\n                                  if (mine && reserve != null && reserve > 0) ...[`;
  if (!source.includes(summaryEnd)) {
    throw new Error('Could not attach buyer position beneath the leading-offer summary.');
  }
  source = source.replace(summaryEnd, summaryReplacement);
}

if (!source.includes('viewerOwnsOffer')) {
  const historyReturn = `                return Card(\n                  margin: const EdgeInsets.only(bottom: 4),`;
  const historyReplacement = `                final viewerOwnsOffer = uid != null && data['bidderUid'] == uid;\n                final leadingOffer = data['status'] == 'leading';\n                final surpassedOffer = data['status'] == 'outbid';\n                final viewerRowColor = leadingOffer\n                    ? PipeBuyerColors.success\n                    : surpassedOffer\n                        ? PipeBuyerColors.danger\n                        : PipeBuyerColors.orangePressed;\n                return Card(\n                  color: viewerOwnsOffer\n                      ? viewerRowColor.withValues(alpha: .07)\n                      : null,\n                  shape: RoundedRectangleBorder(\n                    borderRadius: BorderRadius.circular(10),\n                    side: BorderSide(\n                      color: viewerOwnsOffer\n                          ? viewerRowColor.withValues(alpha: .52)\n                          : Theme.of(context).dividerColor,\n                      width: viewerOwnsOffer ? 1.3 : .7,\n                    ),\n                  ),\n                  margin: const EdgeInsets.only(bottom: 4),`;
  if (!source.includes(historyReturn)) {
    throw new Error('Could not find compact timed-offer activity cards. Apply compact details first.');
  }
  source = source.replace(historyReturn, historyReplacement);
}

const oldHistoryTitle = `                    title: Text(\n                      marketplaceMoney(data['amount'] as num? ?? 0),\n                      style: const TextStyle(fontWeight: FontWeight.w900),\n                    ),`;
const newHistoryTitle = `                    title: Row(\n                      children: [\n                        Expanded(\n                          child: Text(\n                            marketplaceMoney(data['amount'] as num? ?? 0),\n                            style: const TextStyle(fontWeight: FontWeight.w900),\n                          ),\n                        ),\n                        if (viewerOwnsOffer)\n                          TimedBuyingViewerPositionBadge(\n                            position: leadingOffer\n                                ? TimedBuyingViewerPosition.leading\n                                : surpassedOffer\n                                    ? TimedBuyingViewerPosition.outbid\n                                    : TimedBuyingViewerPosition.participating,\n                          ),\n                      ],\n                    ),`;
if (!source.includes(newHistoryTitle)) {
  if (!source.includes(oldHistoryTitle)) {
    throw new Error('Could not add viewer status to timed-offer activity rows.');
  }
  source = source.replace(oldHistoryTitle, newHistoryTitle);
}

fs.writeFileSync(pagePath, source, 'utf8');
console.log(`updated ${pageRelative}`);

const seedRelative = 'firebase/functions/scripts/seed_visual_sandbox.js';
const seedPath = path.join(root, seedRelative);
if (fs.existsSync(seedPath)) {
  let seed = fs.readFileSync(seedPath, 'utf8');
  seed = seed.replaceAll('Timed Auction — CAT D6 Dozer', 'Timed Buying — CAT D6 Dozer');
  seed = seed.replaceAll('Upcoming Auction — 2020 Bobcat T76', 'Timed Buying — Upcoming — 2020 Bobcat T76');
  seed = seed.replaceAll('Ended Auction — 48 ft Step Deck Trailer', 'Timed Buying — Closed — 48 ft Step Deck Trailer');
  seed = seed.replaceAll(
    'Live visual-sandbox auction with six bids and a closing-time urgency state.',
    'Live visual-sandbox Timed Buying listing with timed offers and a closing-time urgency state.',
  );
  seed = seed.replaceAll(
    'Upcoming visual-sandbox auction used to review scheduled states.',
    'Upcoming visual-sandbox Timed Buying listing used to review scheduled states.',
  );
  seed = seed.replaceAll(
    'Completed visual-sandbox auction for ended and settlement-state review.',
    'Completed visual-sandbox Timed Buying listing for closed and settlement-state review.',
  );
  seed = seed.replace('auctionEndAt: atHours(6),', 'auctionEndAt: atHours(5),');
  fs.writeFileSync(seedPath, seed, 'utf8');
  console.log(`updated ${seedRelative}`);
}

if (!source.includes('TimedBuyingAttentionFrame(') ||
    !source.includes('TimedBuyingAttentionStrip(') ||
    !source.includes('TimedBuyingViewerPositionBadge(') ||
    !source.includes('You’ve been surpassed')) {
  throw new Error('Timed Buying attention migration did not produce all required markers.');
}

console.log('\nTimed Buying urgency, buyer-position and activity highlighting applied.');
console.log('Internal Auction field names remain unchanged for backend compatibility.');
