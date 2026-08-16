import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const relative = 'lib/marketplace/oil_gas_marketplace.dart';
const target = path.join(process.cwd(), relative);
if (!fs.existsSync(target)) throw new Error(`Missing ${relative}`);

let source = fs.readFileSync(target, 'utf8');

// Step 4 uses live form state in its description, so it cannot be a const widget.
source = source.replace(
  "            const MarketplaceListingFormSectionHeader(\n              step: 4,",
  "            MarketplaceListingFormSectionHeader(\n              step: 4,",
);

if (!source.includes("MarketplaceListingFormSectionHeader(\n              step: 4,") ||
    !source.includes("title: 'Listing terms'")) {
  throw new Error('Could not verify the dynamic Listing terms section header.');
}

fs.writeFileSync(target, source, 'utf8');
console.log(`updated ${relative}`);
console.log('Professional listing-form post-migration analyzer fixes applied.');
