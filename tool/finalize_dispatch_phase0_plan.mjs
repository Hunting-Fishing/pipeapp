import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..");
const planPath = path.join(repoRoot, "docs", "DISPATCH_NETWORK_MASTER_PLAN.md");
const inventoryPath = path.join(
    repoRoot,
    "docs",
    "DISPATCH_PHASE0_FOUNDATION_INVENTORY.md",
);

if (!fs.existsSync(planPath)) {
  throw new Error("Dispatch master plan is missing.");
}
if (!fs.existsSync(inventoryPath)) {
  throw new Error("Dispatch Phase 0 foundation inventory is missing.");
}

let plan = fs.readFileSync(planPath, "utf8");
if (plan.includes("Overall: 26/100 = 26%") &&
    plan.includes("Current phase: Phase 1 - Role-aware Dispatch entry and navigation")) {
  console.log("Dispatch Phase 0 master-plan finalization already applied.");
  process.exit(0);
}

function replaceRequired(before, after, label) {
  if (!plan.includes(before)) {
    throw new Error(`Dispatch plan finalizer could not find: ${label}`);
  }
  plan = plan.replace(before, after);
}

replaceRequired(
    "**Current engineering completion:** **24%**",
    "**Current engineering completion:** **26%**",
    "top-level completion percentage",
);
replaceRequired(
    "| 0 | Existing Dispatch foundation verified | 10 | 8 | IN PROGRESS |",
    "| 0 | Existing Dispatch foundation verified | 10 | 10 | GREEN |",
    "Phase 0 ledger row",
);
replaceRequired(
    "| 1 | Role-aware entry and navigation architecture | 10 | 3 | BLOCKED BY PHASE 0 |",
    "| 1 | Role-aware entry and navigation architecture | 10 | 3 | IN PROGRESS |",
    "Phase 1 ledger row",
);
replaceRequired(
    "| **TOTAL** |  | **100** | **24** | **24% COMPLETE** |",
    "| **TOTAL** |  | **100** | **26** | **26% COMPLETE** |",
    "total ledger row",
);
replaceRequired(
    "### Why the baseline is 24%",
    "### Why the verified baseline is now 26%",
    "baseline heading",
);
replaceRequired(
    "These existing capabilities earn baseline points.",
    "These existing capabilities earn baseline points. Phase 0 now also has a committed source inventory and a focused green preservation gate covering analyzer, Flutter contracts, server policies/indexes, authenticated provider rules, job creation, carrier quote, award, private-route access, retry safety, and emulator cleanup.",
    "baseline explanation",
);
replaceRequired(
    "**Current:** 8/10",
    "**Current:** 10/10",
    "Phase 0 score",
);
replaceRequired(
    "- [ ] Document the exact current Firestore collections, server commands, rules, indexes, and production behavior that must be preserved. **1 pt**",
    "- [x] Document the exact current Firestore collections, server commands, rules, indexes, and production behavior that must be preserved. **1 pt** See `docs/DISPATCH_PHASE0_FOUNDATION_INVENTORY.md`.",
    "Phase 0 inventory checkbox",
);
replaceRequired(
    "- [ ] Add a focused baseline Dispatch regression test bundle before restructuring navigation/data. **1 pt**",
    "- [x] Add a focused baseline Dispatch regression test bundle before restructuring navigation/data. **1 pt** `tool/verify_dispatch_phase0.ps1` + `firebase/functions/integration/dispatch_phase0_baseline.mjs`.",
    "Phase 0 regression checkbox",
);
replaceRequired(
    "**STOP CONDITION:** No Phase 1 product restructuring until the two unchecked items above are complete.",
    "**PHASE 0 GATE: GREEN.** Phase 1 may begin. The frozen compatibility boundary is documented in `docs/DISPATCH_PHASE0_FOUNDATION_INVENTORY.md`.",
    "Phase 0 stop condition",
);

const oldReport = `DISPATCH NETWORK STATUS
Overall: 24/100 = 24%
Current phase: Phase 0 - Verify and freeze existing Dispatch foundation
Phase completion: 8/10 points
Gate: IN PROGRESS
Last verified: 2026-08-16
Analyzer: NOT RUN FOR THIS PLAN BASELINE
Targeted tests: NOT RUN FOR THIS PLAN BASELINE
Emulator journey: EXISTING DISPATCH FIXTURES ONLY
Visual acceptance: CURRENT LEGACY DISPATCH SCREEN OBSERVED
Blockers: baseline schema/rules inventory and focused Dispatch regression bundle still required
Next permitted task: complete Phase 0 inventory and baseline regression tests`;
const newReport = `DISPATCH NETWORK STATUS
Overall: 26/100 = 26%
Current phase: Phase 1 - Role-aware Dispatch entry and navigation
Phase completion: 3/10 points
Gate: IN PROGRESS
Last verified: 2026-08-16
Analyzer: PASS - strict Phase 0 Dispatch targets
Targeted tests: PASS - Flutter Dispatch + server policy/index contracts
Emulator journey: PASS - provider signup/approval -> job -> quote -> award + authenticated rules
Visual acceptance: NOT REQUIRED - Phase 0 changed verification/docs only
Blockers: none for Phase 1 entry/navigation work
Next permitted task: implement explicit role-aware Dispatch entry and replace legacy five-tab navigation`;
replaceRequired(oldReport, newReport, "current status report");

const oldNextAction = `# Current next action

**Complete Phase 0.**

Do not redesign the Dispatch tabs yet. First inventory the current Dispatch Firestore collections/commands/rules/indexes and create a focused regression bundle proving the existing provider signup/dashboard, job post, quote, and award behavior. Once Phase 0 reaches **10/10**, update this document to **26%** and begin Phase 1 role-aware navigation.`;
const newNextAction = `# Current next action

**Begin Phase 1 - role-aware Dispatch entry and navigation.**

Phase 0 is frozen and verified at **10/10**. Preserve the documented collection/command/rule/index compatibility boundary while implementing customer/provider/both account state, provider auto-dashboard entry, first-entry choices, and the target navigation: \`Dashboard | Request Service | Directory | Jobs\`.`;
replaceRequired(oldNextAction, newNextAction, "current next action");

fs.writeFileSync(planPath, plan, "utf8");
console.log("DISPATCH MASTER PLAN UPDATED: Phase 0 = 10/10, overall = 26%.");
