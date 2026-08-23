import fs from 'node:fs';

const target = 'lib/marketplace/marketplace_dispatch_page.dart';
let source = fs.readFileSync(target, 'utf8');

if (!source.includes('FirebaseAuth.instance.authStateChanges()')) {
  throw new Error(
    'Dispatch auth reactivity repair is missing. Refusing to wire the company profile onto an older page.',
  );
}

const importLine = "import 'marketplace_dispatch_company_profile_page.dart';";
if (!source.includes(importLine)) {
  const anchor = "import 'marketplace_dispatch_repository.dart';";
  if (!source.includes(anchor)) {
    throw new Error('Dispatch repository import anchor was not found.');
  }
  source = source.replace(anchor, `${anchor}\n${importLine}`);
}

const replacement = `body: accountState.providerRegistered
              ? const MarketplaceDispatchCompanyProfilePage()
              : _CarrierEnrollment(repo: repo),`;

if (!source.includes('MarketplaceDispatchCompanyProfilePage()')) {
  const anchor = 'body: _CarrierEnrollment(repo: repo),';
  const matches = source.split(anchor).length - 1;
  if (matches !== 1) {
    throw new Error(
      `Expected exactly one provider enrollment body anchor, found ${matches}.`,
    );
  }
  source = source.replace(anchor, replacement);
}

fs.writeFileSync(target, source, 'utf8');
console.log('Dispatch Company Profile now opens the live structured editor for registered providers.');
