import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const relative = 'lib/marketplace/marketplace_auctions_page.dart';
const target = path.join(root, relative);
if (!fs.existsSync(target)) throw new Error(`Missing ${relative}`);

let source = fs.readFileSync(target, 'utf8');
if (!source.includes('Review & submit timed offer') || !source.includes('Timed Buying')) {
  throw new Error(
    'The verified Timed Buying migration is not present. Apply it before compacting the detail layout.',
  );
}

const specsImport = "import 'marketplace_listing_specs.dart';";
if (!source.includes(specsImport)) {
  const anchor = "import 'marketplace_listing_status.dart';";
  if (!source.includes(anchor)) {
    throw new Error('Could not locate marketplace_listing_status.dart import.');
  }
  source = source.replace(anchor, `${anchor}\n${specsImport}`);
}

const replacement = `class _AuctionListingDetails extends StatelessWidget {
  const _AuctionListingDetails({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final description = '\${data['description'] ?? ''}'.trim();
    final hasSpecs = marketplaceListingSpecs(data).isNotEmpty;
    if (!hasSpecs && description.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSpecs)
          MarketplaceListingSpecsGrid(
            listing: data,
            title: 'Asset overview',
            maxVisibleSpecs: 8,
          ),
        if (description.isNotEmpty) ...[
          if (hasSpecs) const SizedBox(height: 12),
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: PipeBuyerColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              color: PipeBuyerColors.graphite,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _BidActionPanel`;

const classPattern = /class _AuctionListingDetails extends StatelessWidget \{[\s\S]*?\n\}\n\nclass _BidActionPanel/;
if (source.includes("title: 'Asset overview'") && source.includes(specsImport)) {
  console.log('Compact Asset overview is already applied.');
} else {
  if (!classPattern.test(source)) {
    throw new Error('Could not isolate _AuctionListingDetails for safe replacement.');
  }
  source = source.replace(classPattern, replacement);
}

// Keep offer history readable but reduce the large vertical card rhythm. The
// command/withdraw behavior stays untouched; only ListTile density changes.
const historyBefore = `                return Card(
                  margin: const EdgeInsets.only(bottom: 7),
                  child: ListTile(`;
const historyAfter = `                return Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -3),
                    minLeadingWidth: 32,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),`;
if (source.includes(historyBefore)) {
  source = source.replace(historyBefore, historyAfter);
}

if (!source.includes('MarketplaceListingSpecsGrid(') ||
    !source.includes("title: 'Asset overview'")) {
  throw new Error('Compact asset-detail migration did not produce required markers.');
}

fs.writeFileSync(target, source, 'utf8');
console.log(`updated ${relative}`);
console.log('Compact Asset overview + denser timed-offer activity applied.');
