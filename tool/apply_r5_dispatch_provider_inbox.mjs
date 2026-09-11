import fs from 'node:fs';

const path = 'lib/marketplace/marketplace_dispatch_dashboard.dart';
let source = fs.readFileSync(path, 'utf8');

const importMarker = "import 'marketplace_dispatch_repository.dart';\n";
const importLine = "import 'marketplace_dispatch_provider_inbox.dart';\n";
if (!source.includes(importLine)) {
  if (!source.includes(importMarker)) {
    throw new Error('Dispatch repository import marker not found.');
  }
  source = source.replace(importMarker, `${importMarker}${importLine}`);
}

const oldBlock = `                _summaryCards(),\n                const SizedBox(height: 16),\n                _operationsMap(mapCenter),`;
const newBlock = `                _summaryCards(),\n                const SizedBox(height: 16),\n                MarketplaceDispatchProviderInbox(\n                  repository: widget.repo,\n                  onOpenJobs: widget.onBrowseJobs,\n                ),\n                const SizedBox(height: 16),\n                _operationsMap(mapCenter),`;

if (!source.includes(newBlock)) {
  const matches = source.split(oldBlock).length - 1;
  if (matches !== 1) {
    throw new Error(`Expected exactly one dashboard insertion point, found ${matches}.`);
  }
  source = source.replace(oldBlock, newBlock);
}

const inboxCount = source.split('MarketplaceDispatchProviderInbox(').length - 1;
if (inboxCount !== 1) {
  throw new Error(`Expected exactly one provider inbox widget, found ${inboxCount}.`);
}

fs.writeFileSync(path, source);
console.log('R5 Dispatch provider inbox integration applied safely.');
