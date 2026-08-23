import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), '..');
const expectedBranch = 'design/formal-beautification-foundation';
const planPath = path.join(repoRoot, 'docs', 'DISPATCH_NETWORK_MASTER_PLAN.md');

function fail(message) {
  throw new Error(`STOP: ${message}`);
}

function currentBranch() {
  return execFileSync('git', ['branch', '--show-current'], {
    cwd: repoRoot,
    encoding: 'utf8',
  }).trim();
}

function replaceOne(text, regex, replacement, label) {
  const flags = regex.flags.includes('g') ? regex.flags : `${regex.flags}g`;
  const matcher = new RegExp(regex.source, flags);
  const matches = text.match(matcher) || [];
  if (matches.length !== 1) {
    fail(`${label}: expected exactly one match, found ${matches.length}.`);
  }
  return text.replace(regex, replacement);
}

if (currentBranch() !== expectedBranch) {
  fail(`Wrong branch. Expected ${expectedBranch}, found ${currentBranch()}.`);
}
if (!fs.existsSync(planPath)) fail('Dispatch master plan is missing.');

let text = fs.readFileSync(planPath, 'utf8').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
for (const marker of [
  '# Pipe Buyer Dispatch Network Master Plan',
  '# PHASE 3 - Provider and company profile system',
  '# PHASE 4 - Dispatch Service Directory + map',
  '## Phase 3 checklist',
  '### Current report',
]) {
  if (!text.includes(marker)) fail(`Master plan is missing required marker: ${marker}`);
}

const overall = [...text.matchAll(/\*\*Current verified completion:\*\* \*\*(\d+)%\*\*/g)]
    .map((match) => Number(match[1]));
if (overall.length !== 1 || ![50, 51, 52].includes(overall[0])) {
  fail(`Unexpected overall completion state: ${overall.join(', ') || 'missing'}.`);
}

text = replaceOne(
    text,
    /\*\*Current verified completion:\*\* \*\*\d+%\*\*/g,
    '**Current verified completion:** **52%**',
    'overall completion',
);
text = replaceOne(
    text,
    /\*\*Last updated:\*\* \d{4}-\d{2}-\d{2}/g,
    '**Last updated:** 2026-08-19',
    'last updated date',
);
text = replaceOne(
    text,
    /^\| 3 \| Provider\/company profile system \| 15 \| \d+ \| .* \|$/m,
    '| 3 | Provider/company profile system | 15 | 15 | GREEN |',
    'Phase 3 ledger row',
);
text = replaceOne(
    text,
    /^\| 4 \| Dispatch Service Directory \+ map \| 20 \| \d+ \| .* \|$/m,
    '| 4 | Dispatch Service Directory + map | 20 | 0 | IN PROGRESS |',
    'Phase 4 ledger row',
);
text = replaceOne(
    text,
    /^\| \*\*TOTAL\*\* \|  \| \*\*100\*\* \| \*\*\d+\*\* \| \*\*\d+% COMPLETE\*\* \|$/m,
    '| **TOTAL** |  | **100** | **52** | **52% COMPLETE** |',
    'total ledger row',
);

const phase3Start = text.indexOf('# PHASE 3 - Provider and company profile system');
const phase4Start = text.indexOf('# PHASE 4 - Dispatch Service Directory + map');
if (phase3Start < 0 || phase4Start <= phase3Start) fail('Could not bound Phase 3 section.');
let phase3 = text.slice(phase3Start, phase4Start);
phase3 = replaceOne(
    phase3,
    /\*\*Current verified:\*\* \d+\/15/,
    '**Current verified:** 15/15',
    'Phase 3 verified points',
);
phase3 = replaceOne(
    phase3,
    /\*\*Status:\*\* (?:IN PROGRESS|GREEN)/,
    '**Status:** GREEN',
    'Phase 3 status',
);
phase3 = replaceOne(
    phase3,
    /- \[[ x]\] Service area and home-base map setup\. \*\*1 pt\*\*/,
    '- [x] Service area and home-base map setup. **1 pt**',
    'service-area acceptance point',
);
phase3 = replaceOne(
    phase3,
    /- \[[ x]\] Credential\/insurance metadata with private document separation\. \*\*1 pt\*\*/,
    '- [x] Credential/insurance metadata with private document separation. **1 pt**',
    'credential acceptance point',
);

const completionBlock = `## Phase 3 completion evidence

Phase 3 reached 15/15 after browser acceptance completed on 2026-08-19:

- mapped service area survives save, leaving Company Profile, and reopening;
- Town/Region selection preserves municipality versus regional identity;
- approximate public home-base projection remains separate from exact private service-area data;
- credential/insurance metadata survives immediate Save & close, leaving the screen, and reopening;
- insurance coverage limits remain private and self-reported;
- Credential Analytics & alerts exposes actionable Current / Expired / Not provided / Evidence / Insurance drill-down;
- reminder settings remain private and are backed by the credential reminder engine;
- credential evidence remains private and never creates a public Pipe Buyer verification claim.

Public profiles must never expose private email, phone, Auth UID, insurance files, exact private addresses, or internal moderation data.`;

const remainingPattern = /## Phase 3 (?:remaining after the foundation gate|completion evidence|completion boundary)[\s\S]*?Public profiles must never expose private email, phone, Auth UID, insurance files, exact private addresses, or internal moderation data\./;
if (!remainingPattern.test(phase3)) {
  fail('Could not locate the bounded Phase 3 completion/remaining section.');
}
phase3 = phase3.replace(remainingPattern, completionBlock);
text = text.slice(0, phase3Start) + phase3 + text.slice(phase4Start);

const phase4SectionStart = text.indexOf('# PHASE 4 - Dispatch Service Directory + map');
const phase5SectionStart = text.indexOf('# PHASE 5 - Standalone Request Service workflow');
if (phase4SectionStart < 0 || phase5SectionStart <= phase4SectionStart) fail('Could not bound Phase 4 section.');
let phase4 = text.slice(phase4SectionStart, phase5SectionStart);
phase4 = replaceOne(
    phase4,
    /\*\*Status:\*\* (?:BLOCKED BY PHASE 3|IN PROGRESS)/,
    '**Status:** IN PROGRESS',
    'Phase 4 status',
);
text = text.slice(0, phase4SectionStart) + phase4 + text.slice(phase5SectionStart);

const report = `### Current report

\`\`\`text
DISPATCH NETWORK STATUS
Overall: 52/100 = 52%
Current phase: Phase 4 - Dispatch Service Directory + map
Phase completion: 0/20 points verified
Gate: IN PROGRESS
Last verified: 2026-08-19
Analyzer: Phase 3 credential analytics PASS
Targeted tests: Phase 3 service-area + credentials + analytics regressions PASS
Emulator journey: provider profile/service-area/credential persistence preserved
Visual acceptance: Phase 3 company profile + fleet + service area + credentials PASS
Blockers: none; Phase 4 unlocked
Next permitted task: build server-owned Directory projection/schema + security rules
\`\`\``;
text = replaceOne(
    text,
    /### Current report\n\n```text[\s\S]*?```/,
    report,
    'current status report',
);

const requiredFinal = [
  '**Current verified completion:** **52%**',
  '| 3 | Provider/company profile system | 15 | 15 | GREEN |',
  '| 4 | Dispatch Service Directory + map | 20 | 0 | IN PROGRESS |',
  '| **TOTAL** |  | **100** | **52** | **52% COMPLETE** |',
  '**Current verified:** 15/15',
  '- [x] Service area and home-base map setup. **1 pt**',
  '- [x] Credential/insurance metadata with private document separation. **1 pt**',
  'Overall: 52/100 = 52%',
  'Next permitted task: build server-owned Directory projection/schema + security rules',
];
for (const marker of requiredFinal) {
  if (!text.includes(marker)) fail(`Finalized master plan is missing: ${marker}`);
}

const stamp = new Date().toISOString().replace(/[-:TZ.]/g, '').slice(0, 14);
const backupDir = path.join(repoRoot, '_local_backups', `dispatch-phase3-finalizer-${stamp}`);
fs.mkdirSync(backupDir, {recursive: true});
fs.copyFileSync(planPath, path.join(backupDir, 'DISPATCH_NETWORK_MASTER_PLAN.md'));
fs.writeFileSync(planPath, text, 'utf8');

console.log(`Backup created: ${backupDir}`);
console.log('DISPATCH PHASE 3 BROWSER ACCEPTANCE FINALIZED');
console.log('Overall: 52/100 = 52%');
console.log('Phase 3: 15/15 GREEN');
console.log('Phase 4: 0/20 IN PROGRESS');
console.log('Phase 4 points awarded by finalizer: 0');
