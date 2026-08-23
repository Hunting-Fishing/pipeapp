import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const pageRelative = 'lib/marketplace/marketplace_auctions_page.dart';
const trustRelative = 'lib/marketplace/marketplace_timed_buying_trust.dart';
const pagePath = path.join(root, pageRelative);
const trustPath = path.join(root, trustRelative);

for (const required of [pagePath, trustPath]) {
  if (!fs.existsSync(required)) {
    throw new Error(`Missing ${path.relative(root, required)}`);
  }
}

let page = fs.readFileSync(pagePath, 'utf8').replace(/\r\n/g, '\n');
let trust = fs.readFileSync(trustPath, 'utf8').replace(/\r\n/g, '\n');

// The trust card no longer uses the earlier viewerLeading local directly;
// TimedBuyingViewerParticipation is authoritative for leading/outbid state.
page = page.replace(
  /^([ \t]*)final viewerLeading = viewerUid != null && data\['highBidderUid'\] == viewerUid;\n/m,
  '',
);

// v3 deliberately generated this block with string concatenation so JavaScript
// would not interpret Dart interpolation. Once the Dart source exists, rewrite
// it to idiomatic Dart interpolation before analyzer runs.
const positionPattern = /        final offersAhead = participation\.offersAhead;\n        final positionText = participation\.leading[\s\S]*?                : 'You have an active timed offer on this listing\.';/;
if (positionPattern.test(page)) {
  const cleanPosition = [
    '        final offersAhead = participation.offersAhead;',
    "        final aheadText = offersAhead == null",
    "            ? ''",
    "            : ' • $offersAhead ${offersAhead == 1 ? 'offer' : 'offers'} ahead';",
    "        final nextText = live ? ' • Next minimum: ${marketplaceMoney(nextOffer)}' : '';",
    '        final positionText = participation.leading',
    "            ? 'Your top timed offer is ${marketplaceMoney(participation.viewerTopOffer)} and it is the current lead.'",
    '            : participation.outbid',
    "                ? 'Your top: ${marketplaceMoney(participation.viewerTopOffer)} • Lead: ${marketplaceMoney(participation.currentLead)} • Behind by ${marketplaceMoney(participation.amountBehind)}$aheadText$nextText'",
    "                : 'You have an active timed offer on this listing.';",
  ].join('\n');
  page = page.replace(positionPattern, cleanPosition);
}

if (page.includes('final viewerLeading =')) {
  throw new Error('Unused viewerLeading analyzer cleanup did not apply.');
}
if (page.includes("'Your top: ' +") || page.includes("' • Lead: ' +")) {
  throw new Error('Timed Buying buyer-position string interpolation cleanup did not apply.');
}

// The scope's public maybeOf API previously exposed a private inherited-widget
// type. Keep the API behavior unchanged while making the type public so Dart's
// library_private_types_in_public_api lint is satisfied.
trust = trust.replaceAll(
  '_TimedBuyingParticipationData',
  'TimedBuyingParticipationData',
);

// Public widgets must expose a named key. The inherited participation data is
// public after the cleanup above, so make its constructor fully lint-clean.
trust = trust.replace(
  '  const TimedBuyingParticipationData({\n    required this.viewerUid,',
  '  const TimedBuyingParticipationData({\n    super.key,\n    required this.viewerUid,',
);

if (trust.includes('_TimedBuyingParticipationData')) {
  throw new Error('Private participation data type remains after analyzer cleanup.');
}
if (!trust.includes('class TimedBuyingParticipationData extends InheritedWidget')) {
  throw new Error('Public participation data type was not produced.');
}
if (!trust.includes('const TimedBuyingParticipationData({\n    super.key,')) {
  throw new Error('Public participation widget key cleanup did not apply.');
}

fs.writeFileSync(pagePath, page, 'utf8');
fs.writeFileSync(trustPath, trust, 'utf8');

console.log(`analyzer cleanup updated ${pageRelative}`);
console.log(`analyzer cleanup updated ${trustRelative}`);
console.log('Removed unused viewer state, normalized Dart interpolation, publicized the participation data type, and added its widget key.');
