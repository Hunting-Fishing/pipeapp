# Pipe Buyer — 366 Autonomous Builder Adapter

Status: project adapter prepared  
Central engine: `Hunting-Fishing/366-AI-Software-Homebrew`  
Engine branch during development: `agent/autonomous-builder-v2`  
Engine directory: `autonomous-builder/`

## Purpose

Pipe Buyer does not own the Autonomous Builder engine. This repository owns only the project knowledge, risk/compatibility adapter, and project-specific verification that the central 366 Autonomous Builder consumes.

The central engine is responsible for orchestration, Codex worker/reviewer execution, timeouts, recovery, generic guard behavior, graduation fingerprints, commits, and optional pushes.

Pipe Buyer remains responsible for what the product is supposed to become and for proving that Pipe-specific behavior is correct.

## Files retained in Pipe Buyer

```text
.autobuild/
  project.json
  risk_policy.json
  feature_contract.json
  reviewer_fault_cases.json

AGENTS.md

docs/
  PROJECT_KNOWLEDGE_INDEX.md
  PRODUCT_VISION.md
  MASTER_ROADMAP.md
  SHIP_72_HOUR_PLAN.md
  ARCHITECTURE.md
  DESIGN_SYSTEM.md
  QUALITY_GATES.md
  FEATURE_REGISTRY.md
  DECISION_REGISTER.md
  domain trackers / policies / runbooks

tool/
  verify.ps1
  autonomous_compatibility.mjs
  autonomous_compatibility_test.mjs
```

Generic worker prompts, schemas, process control, guard/recovery code, reviewer orchestration, and engine fault tests live in the 366 AI Builder repository instead of this application repo.

## Pipe Buyer project contract

`.autobuild/project.json` uses the central engine's project schema version 3 and declares:

- Pipe Buyer identity;
- `AGENTS.md` policy;
- complete project verification command;
- reusable `agent/autobuild` writer branch;
- project risk policy;
- knowledge hierarchy;
- source/document/change budgets;
- worker/reviewer/verification timeouts;
- human-only production/provider/critical-risk boundaries;
- project control files that invalidate prior graduation when changed;
- Pipe-specific compatibility and reviewer fault tests.

## Knowledge model

The central worker reconstructs context from Git rather than relying on an old chat session.

Always-read Pipe Buyer knowledge includes the Product Vision, Master Roadmap, active ship plan, Architecture, Quality Gates, Definition of Done, non-functional requirements, Decision Register, and Risk Register.

Relevant domain knowledge is then loaded for UI, payments, Marketplace, data, security, providers, release, or technical-debt work.

The detailed tracker remains authoritative for task completion. The worker may not infer provider, legal, device, or production completion from source code alone.

## Functionality preservation

Pipe Buyer supplies several project-specific compatibility layers:

- `docs/FEATURE_REGISTRY.md` — durable capability inventory;
- `.autobuild/feature_contract.json` — critical machine anchors;
- `tool/autonomous_compatibility.mjs` — inventories Flutter route signatures and Firebase Function exports;
- existing Flutter, Firebase Functions, Rules, integration, release-manifest, and Function-parity tests.

The central engine adds the generic change/risk guard and independent read-only reviewer around these project checks.

## Reviewer graduation cases

`.autobuild/reviewer_fault_cases.json` contains controlled Pipe-specific defects used only in disposable worktrees during graduation. Current cases test whether the reviewer blocks:

- loss of the listing deep-link contract;
- administrator MFA bypass;
- corruption of the Dispatch monthly subscription amount.

They are project knowledge/tests, not engine implementation.

## Running from the 366 AI Builder clone

The central engine should be cloned separately from Pipe Buyer. From that clone:

```powershell
.\autonomous-builder\tool\autonomous_graduation.ps1 `
  -ProjectPath "D:\Pipe App Flutter\pipe-app-1w4gyj"
```

After graduation passes, begin with one bounded watched worker:

```powershell
.\autonomous-builder\tool\autonomous_build.ps1 `
  -ProjectPath "D:\Pipe App Flutter\pipe-app-1w4gyj" `
  -Hours 0.5 `
  -MaxTasks 1
```

A normal multi-hour run later uses the same engine and target path with a larger time/task budget and optional `-Push`.

## Branch model

Pipe Buyer uses one reusable autonomous writer branch:

```text
main
  \
   agent/autobuild
      verified commit A
      verified commit B
      verified commit C
```

The engine does not create one branch per task. Commits are checkpoints. Merge to `main` remains human-controlled.

## Human-only boundaries

The central engine may prepare and verify development code, but Pipe Buyer does not authorize it to:

- merge to `main`;
- deploy or activate production;
- mutate live Stripe/provider configuration;
- move live money;
- perform destructive production data changes;
- expose secrets;
- make legal/tax/compliance declarations;
- publish app-store releases;
- weaken security/tests/release gates to obtain a green result.

## Separation rule

Do not re-copy the central engine back into Pipe Buyer. Changes to orchestration, generic prompts/schemas, timeouts, process control, recovery, guard logic, or engine graduation belong in `366-AI-Software-Homebrew/autonomous-builder`.

Changes to Pipe Buyer's product requirements, design, roadmaps, features, payments, data/security contracts, or project verification belong here.
