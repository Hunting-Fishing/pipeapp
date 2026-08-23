import fs from 'node:fs';

import {
  loadDispatchQuoteV2Files,
  transformDispatchQuoteV2Foundation,
} from './dispatch_quote_v2_foundation_transform_v2.mjs';

const {paths, files} = loadDispatchQuoteV2Files();
const before = Object.fromEntries(
  Object.entries(paths).map(([key, filePath]) => [key, fs.readFileSync(filePath, 'utf8')]),
);
const transformed = transformDispatchQuoteV2Foundation(files);

for (const [key, filePath] of Object.entries(paths)) {
  const after = fs.readFileSync(filePath, 'utf8');
  if (after !== before[key]) {
    throw new Error(`STOP: Quote v2 dry-run modified production source: ${filePath}`);
  }
}

if (!transformed.page.includes('MarketplaceDispatchQuoteForm.show(')) {
  throw new Error('STOP: Jobs candidate does not use the reusable quote form.');
}
if (transformed.page.includes("labelText: 'All-in transport price'")) {
  throw new Error('STOP: Jobs candidate still contains the legacy all-in quote dialog.');
}
if (!transformed.dashboard.includes('MarketplaceDispatchQuoteForm.show(')) {
  throw new Error('STOP: Dashboard candidate does not use the reusable quote form.');
}
if (!transformed.repository.includes("'quoteBreakdown': quoteBreakdown")) {
  throw new Error('STOP: Repository candidate does not send quoteBreakdown.');
}
if (!transformed.policy.includes('validateDispatchQuoteBreakdown')) {
  throw new Error('STOP: Server policy candidate does not validate quote breakdowns.');
}
if (!transformed.commands.includes('quoteReference:')) {
  throw new Error('STOP: Server command candidate does not persist quote references.');
}

console.log('PIPE BUYER DISPATCH QUOTE V2 DRY-RUN PASSED');
console.log('Exact local source recognized: PASS');
console.log('Legacy Jobs all-in quote dialog removed in candidate: PASS');
console.log('Reusable quote form wired to Jobs + Dashboard in candidate: PASS');
console.log('Full quote breakdown transmitted in candidate: PASS');
console.log('Server-side quote calculation validation installed in candidate: PASS');
console.log('Stable quote reference + version metadata installed in candidate: PASS');
console.log('Production source modified by dry-run: NO');
