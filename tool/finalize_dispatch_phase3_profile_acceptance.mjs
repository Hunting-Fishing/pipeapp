import fs from 'node:fs';

const path = 'docs/DISPATCH_NETWORK_MASTER_PLAN.md';
let source = fs.readFileSync(path, 'utf8');

const alreadyAdvanced =
  source.includes('**Current verified completion:** **48%**') &&
  source.includes('| 3 | Provider/company profile system | 15 | 11 | IN PROGRESS |') &&
  source.includes('**Current verified:** 11/15');

if (alreadyAdvanced) {
  console.log('Dispatch master plan already records Phase 3 profile browser acceptance at 48%.');
  process.exit(0);
}

const replacements = [
  ['**Current verified completion:** **45%**', '**Current verified completion:** **48%**'],
  ['| 3 | Provider/company profile system | 15 | 8 | IN PROGRESS |', '| 3 | Provider/company profile system | 15 | 11 | IN PROGRESS |'],
  ['| **TOTAL** |  | **100** | **45** | **45% COMPLETE** |', '| **TOTAL** |  | **100** | **48** | **48% COMPLETE** |'],
  ['**Current verified:** 8/15', '**Current verified:** 11/15'],
  ['- [ ] Availability: now/today/this week/unavailable. **1 pt**', '- [x] Availability: now/today/this week/unavailable. **1 pt**'],
  ['- [ ] Owner/operator and corporation/business-type support. **1 pt**', '- [x] Owner/operator and corporation/business-type support. **1 pt**'],
  ['- [ ] Profile completeness + edit experience. **1 pt**', '- [x] Profile completeness + edit experience. **1 pt**'],
];

for (const [before, after] of replacements) {
  if (source.includes(after)) continue;
  if (!source.includes(before)) {
    throw new Error(`Master plan browser-acceptance anchor missing: ${before}`);
  }
  source = source.replace(before, after);
}

const marker = '## Phase 3 remaining after the foundation gate';
if (!source.includes('Phase 3 company-profile persistence browser acceptance passed on 2026-08-17.')) {
  if (!source.includes(marker)) {
    throw new Error('Master plan Phase 3 remaining-work marker is missing.');
  }
  source = source.replace(
    marker,
    'Phase 3 company-profile persistence browser acceptance passed on 2026-08-17. Saved profile fields survive leaving and reopening the page, and the Dispatch navigation remained healthy.\n\n' + marker,
  );
}

fs.writeFileSync(path, source, 'utf8');
console.log('Dispatch master plan advanced to 48% after Phase 3 profile browser acceptance.');
