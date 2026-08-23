import fs from 'node:fs';

const pagePath = 'lib/marketplace/marketplace_dispatch_page.dart';
let text = fs.readFileSync(pagePath, 'utf8');

const importLine = "import 'marketplace_dispatch_directory.dart';";
const importAnchor = "import 'marketplace_dispatch_company_profile_page.dart';";
const oldBlock = `DispatchSection.directory => MarketplaceDispatchDirectoryFoundation(
              accountState: accountState,
              legacyProviderTools: accountState.providerRegistered
                  ? _PilotTruckSection(repo: repo)
                  : null,
            ),`;
const newBlock = `DispatchSection.directory => MarketplaceDispatchDirectoryPage(
              legacyProviderTools: accountState.providerRegistered
                  ? _PilotTruckSection(repo: repo)
                  : null,
            ),`;

const alreadyIntegrated = text.includes(importLine) && text.includes(newBlock);
if (alreadyIntegrated) {
  console.log('Dispatch Phase 4 directory integration is already applied.');
  process.exit(0);
}

if (!text.includes(importAnchor)) {
  throw new Error('Dispatch page company profile import anchor was not found.');
}
if (!text.includes(oldBlock)) {
  throw new Error('Dispatch page Directory foundation switch anchor was not found.');
}

text = text.replace(importAnchor, `${importAnchor}\n${importLine}`);
text = text.replace(oldBlock, newBlock);

fs.writeFileSync(pagePath, text, 'utf8');
console.log('Dispatch Phase 4 directory integration applied.');
