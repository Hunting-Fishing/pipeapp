import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..');
const planPath = path.join(repoRoot, 'docs', 'DISPATCH_NETWORK_MASTER_PLAN.md');

let source = fs.readFileSync(planPath, 'utf8');

const alreadyFinalized =
  source.includes('**Current verified completion:** **50%**') &&
  source.includes('| 3 | Provider/company profile system | 15 | 13 | IN PROGRESS |') &&
  source.includes('- [x] Equipment/fleet capability profiles. **2 pts**');

if (alreadyFinalized) {
  console.log('Dispatch master plan already records equipment browser acceptance at 50%.');
  process.exit(0);
}

const requiredBaseline = [
  '**Current verified completion:** **48%**',
  '| 3 | Provider/company profile system | 15 | 11 | IN PROGRESS |',
  '| **TOTAL** |  | **100** | **48** | **48% COMPLETE** |',
  '**Current verified:** 11/15',
  '- [ ] Equipment/fleet capability profiles. **2 pts**',
  'Phase 3 company-profile persistence browser acceptance passed on 2026-08-17.',
];

for (const marker of requiredBaseline) {
  if (!source.includes(marker)) {
    throw new Error(`Equipment acceptance finalizer baseline missing: ${marker}`);
  }
}

source = source
  .replace('**Current verified completion:** **48%**', '**Current verified completion:** **50%**')
  .replace(
    '| 3 | Provider/company profile system | 15 | 11 | IN PROGRESS |',
    '| 3 | Provider/company profile system | 15 | 13 | IN PROGRESS |',
  )
  .replace(
    '| **TOTAL** |  | **100** | **48** | **48% COMPLETE** |',
    '| **TOTAL** |  | **100** | **50** | **50% COMPLETE** |',
  )
  .replace('**Current verified:** 11/15', '**Current verified:** 13/15')
  .replace(
    '- [ ] Equipment/fleet capability profiles. **2 pts**',
    '- [x] Equipment/fleet capability profiles. **2 pts**',
  )
  .replace(
    'Phase 3 company-profile persistence browser acceptance passed on 2026-08-17. Saved profile fields survive leaving and reopening the page, and the Dispatch navigation remained healthy.',
    'Phase 3 company-profile persistence browser acceptance passed on 2026-08-17. Saved profile fields survive leaving and reopening the page, and the Dispatch navigation remained healthy.\n\nPhase 3 equipment/fleet capability browser acceptance passed on 2026-08-17. Existing and newly created fleet capability records remain available through Company Profile -> Manage fleet.',
  );

const reportPattern = /### Current report\s+```text[\s\S]*?```/;
if (!reportPattern.test(source)) {
  throw new Error('Dispatch current-report block could not be located.');
}

source = source.replace(
  reportPattern,
  `### Current report\n\n\`\`\`text\nDISPATCH NETWORK STATUS\nOverall: 50/100 = 50%\nCurrent phase: Phase 3 - Provider/company profile system\nPhase completion: 13/15 points verified\nGate: IN PROGRESS\nLast verified: 2026-08-17\nAnalyzer: Phase 3 equipment PASS\nTargeted tests: Phase 3 equipment + Phase 2 + Phase 1 regressions PASS\nEmulator journey: provider profile/fleet persistence preserved\nVisual acceptance: company profile + equipment/fleet PASS\nBlockers: mapped service area/home base and credential metadata remain\nNext permitted task: build mapped service area/home-base persistence with privacy projection\n\`\`\``,
);

fs.writeFileSync(planPath, source, 'utf8');
console.log('Dispatch master plan advanced to 50% after equipment browser acceptance.');
