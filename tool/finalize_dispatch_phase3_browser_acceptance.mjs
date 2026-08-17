import fs from 'node:fs';

const planPath = 'docs/DISPATCH_NETWORK_MASTER_PLAN.md';
let text = fs.readFileSync(planPath, 'utf8');

if (text.includes('**Current verified completion:** **52%**') &&
    text.includes('**Current verified:** 15/15') &&
    text.includes('Phase 4 - Dispatch Service Directory + map\n\n**Weight:** 20%\n**Current:** 0/20\n**Status:** IN PROGRESS')) {
  console.log('Dispatch Phase 3 browser acceptance is already recorded at 52%.');
  process.exit(0);
}

const required = [
  '**Current verified completion:** **50%**',
  '| 3 | Provider/company profile system | 15 | 13 | IN PROGRESS |',
  '| 4 | Dispatch Service Directory + map | 20 | 0 | BLOCKED |',
  '| **TOTAL** |  | **100** | **50** | **50% COMPLETE** |',
  '**Current verified:** 13/15',
  '- [ ] Service area and home-base map setup. **1 pt**',
  '- [ ] Credential/insurance metadata with private document separation. **1 pt**',
  '**Status:** BLOCKED BY PHASE 3',
];

for (const marker of required) {
  if (!text.includes(marker)) {
    throw new Error(`Phase 3 finalizer expected marker was not found: ${marker}`);
  }
}

text = text
  .replace('**Current verified completion:** **50%**', '**Current verified completion:** **52%**')
  .replace('| 3 | Provider/company profile system | 15 | 13 | IN PROGRESS |', '| 3 | Provider/company profile system | 15 | 15 | GREEN |')
  .replace('| 4 | Dispatch Service Directory + map | 20 | 0 | BLOCKED |', '| 4 | Dispatch Service Directory + map | 20 | 0 | IN PROGRESS |')
  .replace('| **TOTAL** |  | **100** | **50** | **50% COMPLETE** |', '| **TOTAL** |  | **100** | **52** | **52% COMPLETE** |')
  .replace('**Current verified:** 13/15', '**Current verified:** 15/15')
  .replace('**Status:** IN PROGRESS\n\nThe purpose of Phase 3', '**Status:** GREEN\n\nThe purpose of Phase 3')
  .replace('- [ ] Service area and home-base map setup. **1 pt**', '- [x] Service area and home-base map setup. **1 pt**')
  .replace('- [ ] Credential/insurance metadata with private document separation. **1 pt**', '- [x] Credential/insurance metadata with private document separation. **1 pt**')
  .replace('**Status:** BLOCKED BY PHASE 3', '**Status:** IN PROGRESS');

const remainingPattern = /## Phase 3 remaining after the foundation gate[\s\S]*?Public profiles must never expose private email, phone, Auth UID, insurance files, exact private addresses, or internal moderation data\./;
const completionBlock = `## Phase 3 completion evidence

Phase 3 reached 15/15 after the final browser acceptance on 2026-08-17:

- mapped service area survives save, leaving Company Profile, and reopening;
- approximate public home-base projection remains separate from exact private service-area data;
- credential/insurance metadata survives save, leaving the credential screen, and reopening;
- credential evidence remains in the private business document area and does not create a public verification claim;
- Phase 3 credential engineering gate passed strict analyzer, regressions, and Firestore/Storage emulator privacy tests.

Public profiles must never expose private email, phone, Auth UID, insurance files, exact private addresses, or internal moderation data.`;

if (!remainingPattern.test(text)) {
  throw new Error('Phase 3 completion section anchor was not found.');
}
text = text.replace(remainingPattern, completionBlock);

const reportPattern = /### Current report\n\n```text\nDISPATCH NETWORK STATUS[\s\S]*?```/;
const report = `### Current report

\`\`\`text
DISPATCH NETWORK STATUS
Overall: 52/100 = 52%
Current phase: Phase 4 - Dispatch Service Directory + map
Phase completion: 0/20 points verified
Gate: IN PROGRESS
Last verified: 2026-08-17
Analyzer: Phase 3 credential PASS
Targeted tests: Phase 3 + Phase 2 + Phase 1/auth regressions PASS
Emulator journey: credential Firestore/Storage privacy PASS
Visual acceptance: Phase 3 profile + fleet + service area + credentials PASS
Blockers: none for Phase 4 entry
Next permitted task: build the bounded Directory repository, list cards, and service/availability filters
\`\`\``;

if (!reportPattern.test(text)) {
  throw new Error('Current Dispatch status report block was not found.');
}
text = text.replace(reportPattern, report);

fs.writeFileSync(planPath, text, 'utf8');
console.log('Dispatch Phase 3 browser acceptance recorded: 15/15 GREEN, overall 52%.');
