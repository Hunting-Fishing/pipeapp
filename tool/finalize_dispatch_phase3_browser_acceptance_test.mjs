import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import test from 'node:test';

const repoRoot = path.resolve(import.meta.dirname, '..');
const finalizerPath = path.join(
  repoRoot,
  'tool',
  'finalize_dispatch_phase3_browser_acceptance.mjs',
);

const baselinePlan = `# Pipe Buyer Dispatch Network Master Plan

**Current verified completion:** **50%**

| Phase | Scope | Total | Earned | Status |
|---|---|---:|---:|---|
| 3 | Provider/company profile system | 15 | 13 | IN PROGRESS |
| 4 | Dispatch Service Directory + map | 20 | 0 | BLOCKED |
| **TOTAL** |  | **100** | **50** | **50% COMPLETE** |

# PHASE 3 - Provider and company profile system

**Weight:** 15%
**Current verified:** 13/15
**Status:** IN PROGRESS

The purpose of Phase 3 is to turn the legacy provider record into a structured industrial company profile.

- [ ] Service area and home-base map setup. **1 pt**
- [ ] Credential/insurance metadata with private document separation. **1 pt**

## Phase 3 remaining after the foundation gate

1. mapped service-area browser acceptance;
2. credential browser acceptance.

Public profiles must never expose private email, phone, Auth UID, insurance files, exact private addresses, or internal moderation data.

# PHASE 4 - Dispatch Service Directory + map

**Weight:** 20%
**Current:** 0/20
**Status:** BLOCKED BY PHASE 3

### Current report

\`\`\`text
DISPATCH NETWORK STATUS
Overall: 50/100 = 50%
Current phase: Phase 3 - Provider/company profile system
Phase completion: 13/15 points verified
Gate: IN PROGRESS
\`\`\`
`;

function runFinalizer(planPath) {
  const result = spawnSync(
    process.execPath,
    [finalizerPath, '--plan', planPath],
    {encoding: 'utf8'},
  );
  if (result.status !== 0) {
    throw new Error(
      `Finalizer failed.\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}`,
    );
  }
  return result.stdout.trim();
}

test('Phase 3 browser finalizer is idempotent after the 52 percent transition', () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pipe-phase3-finalizer-'));
  const planPath = path.join(tempDir, 'DISPATCH_NETWORK_MASTER_PLAN.md');

  try {
    fs.writeFileSync(planPath, baselinePlan, 'utf8');

    const firstOutput = runFinalizer(planPath);
    const afterFirst = fs.readFileSync(planPath, 'utf8');

    assert.match(firstOutput, /recorded: 15\/15 GREEN, overall 52%/);
    assert.match(afterFirst, /\*\*Current verified completion:\*\* \*\*52%\*\*/);
    assert.match(
      afterFirst,
      /\| 3 \| Provider\/company profile system \| 15 \| 15 \| GREEN \|/,
    );
    assert.match(
      afterFirst,
      /\| 4 \| Dispatch Service Directory \+ map \| 20 \| 0 \| IN PROGRESS \|/,
    );
    assert.match(afterFirst, /Overall: 52\/100 = 52%/);

    const secondOutput = runFinalizer(planPath);
    const afterSecond = fs.readFileSync(planPath, 'utf8');

    assert.match(secondOutput, /already recorded at 52%/);
    assert.equal(afterSecond, afterFirst);
  } finally {
    fs.rmSync(tempDir, {recursive: true, force: true});
  }
});
