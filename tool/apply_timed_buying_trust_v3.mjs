import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';

const root = process.cwd();
const pagePath = path.join(root, 'lib/marketplace/marketplace_auctions_page.dart');
const v2Path = path.join(root, 'tool/apply_timed_buying_trust_v2.mjs');

if (!fs.existsSync(pagePath)) throw new Error('Missing marketplace_auctions_page.dart');
if (!fs.existsSync(v2Path)) throw new Error('Missing apply_timed_buying_trust_v2.mjs');

let page = fs.readFileSync(pagePath, 'utf8').replace(/\r\n/g, '\n');

// v2 contains the structural migration. Insert this detail-position widget
// first so v2 skips its legacy inline template block. This class intentionally
// uses Dart string concatenation instead of interpolation so the JavaScript
// migration layer cannot mistake Dart ${...} expressions for JS expressions.
if (!page.includes('class _TimedBuyingBuyerTrustPosition extends StatelessWidget')) {
  const anchor = 'class _AuctionDetailHero extends StatelessWidget {';
  const index = page.indexOf(anchor);
  if (index < 0) throw new Error('Could not insert buyer trust-position widget.');

  const widgetClass = [
    'class _TimedBuyingBuyerTrustPosition extends StatelessWidget {',
    '  const _TimedBuyingBuyerTrustPosition({',
    '    required this.listingId,',
    '    required this.listing,',
    '    required this.nextOffer,',
    '    required this.live,',
    '  });',
    '',
    '  final String listingId;',
    '  final Map<String, dynamic> listing;',
    '  final num nextOffer;',
    '  final bool live;',
    '',
    '  @override',
    '  Widget build(BuildContext context) {',
    '    final uid = FirebaseAuth.instance.currentUser?.uid;',
    "    if (uid == null || uid.isEmpty || listing['sellerUid'] == uid) {",
    '      return const SizedBox.shrink();',
    '    }',
    '    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(',
    '      stream: FirebaseFirestore.instance',
    "          .collection('auction_bids')",
    "          .where('listingId', isEqualTo: listingId)",
    "          .orderBy('createdAt', descending: true)",
    '          .limit(defaultActivityFeedLimit)',
    '          .snapshots(),',
    '      builder: (context, snapshot) {',
    '        final offers = (snapshot.data?.docs ?? const [])',
    '            .map((document) => document.data())',
    '            .toList(growable: false);',
    '        final participation = deriveTimedBuyingViewerParticipation(',
    '          viewerUid: uid,',
    '          listing: listing,',
    '          viewerOffers: offers,',
    '        );',
    '        if (!participation.hasParticipated) return const SizedBox.shrink();',
    '        final color = participation.leading',
    '            ? PipeBuyerColors.success',
    '            : participation.outbid',
    '                ? PipeBuyerColors.danger',
    '                : PipeBuyerColors.orangePressed;',
    '        final offersAhead = participation.offersAhead;',
    '        final positionText = participation.leading',
    "            ? 'Your top timed offer is ' +",
    '                marketplaceMoney(participation.viewerTopOffer) +',
    "                ' and it is the current lead.'",
    '            : participation.outbid',
    "                ? 'Your top: ' +",
    '                    marketplaceMoney(participation.viewerTopOffer) +',
    "                    ' • Lead: ' +",
    '                    marketplaceMoney(participation.currentLead) +',
    "                    ' • Behind by ' +",
    '                    marketplaceMoney(participation.amountBehind) +',
    '                    (offersAhead == null',
    "                        ? ''",
    "                        : ' • ' +",
    '                            offersAhead.toString() +',
    "                            (offersAhead == 1 ? ' offer ahead' : ' offers ahead')) +",
    '                    (live',
    "                        ? ' • Next minimum: ' + marketplaceMoney(nextOffer)",
    "                        : '')",
    "                : 'You have an active timed offer on this listing.';",
    '        return Container(',
    '          margin: const EdgeInsets.only(bottom: 10),',
    '          padding: const EdgeInsets.all(12),',
    '          decoration: BoxDecoration(',
    '            color: color.withValues(alpha: .07),',
    '            borderRadius: BorderRadius.circular(12),',
    '            border: Border.all(color: color.withValues(alpha: .5), width: 1.3),',
    '          ),',
    '          child: Row(',
    '            crossAxisAlignment: CrossAxisAlignment.start,',
    '            children: [',
    '              Icon(',
    '                participation.leading',
    '                    ? Icons.emoji_events_outlined',
    '                    : Icons.trending_up_outlined,',
    '                color: color,',
    '              ),',
    '              const SizedBox(width: 9),',
    '              Expanded(',
    '                child: Column(',
    '                  crossAxisAlignment: CrossAxisAlignment.start,',
    '                  children: [',
    '                    Text(',
    '                      participation.compactStatusLabel,',
    '                      style: TextStyle(',
    '                        color: color,',
    '                        fontWeight: FontWeight.w900,',
    '                        fontSize: 13,',
    '                      ),',
    '                    ),',
    '                    const SizedBox(height: 3),',
    '                    Text(',
    '                      positionText,',
    '                      style: const TextStyle(',
    '                        color: PipeBuyerColors.graphite,',
    '                        fontSize: 11.5,',
    '                        height: 1.35,',
    '                        fontWeight: FontWeight.w600,',
    '                      ),',
    '                    ),',
    '                  ],',
    '                ),',
    '              ),',
    '            ],',
    '          ),',
    '        );',
    '      },',
    '    );',
    '  }',
    '}',
    '',
    '',
  ].join('\n');

  page = page.slice(0, index) + widgetClass + page.slice(index);
  fs.writeFileSync(pagePath, page, 'utf8');
  console.log('prepared indentation-safe Timed Buying buyer-position widget');
}

await import(pathToFileURL(v2Path).href + `?run=${Date.now()}`);
