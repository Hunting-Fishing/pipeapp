# Autonomous Builder V2

Status: development scaffold  
Current host: Pipe Buyer branch `agent/autonomous-repo-builder`  
Intended architecture: reusable builder engine + thin per-project configuration  
Production activation: human controlled

## Architecture decision

The autonomous builder should ultimately live in its **own Git repository** and operate on local clones/worktrees of target repositories through `-ProjectPath`.

Do **not** copy a large autonomous agent implementation into every application repository. Each target project should own only the knowledge and project adapter needed to tell the reusable engine how that project works.

Recommended final shape:

```text
366-autonomous-builder/                 reusable engine repository
  tool/autonomous_build.ps1
  automation/agent/task_prompt.md
  automation/agent/result.schema.json
  automation/agent/project.schema.json
  templates/

PipeBuyer/                              target repository
  .autobuild/project.json
  .autobuild/feature_contract.json
  AGENTS.md
  docs/PRODUCT_VISION.md
  docs/MASTER_ROADMAP.md
  docs/ARCHITECTURE.md
  docs/QUALITY_GATES.md
  docs/DESIGN_SYSTEM.md
  docs/FEATURE_REGISTRY.md
  docs/DECISION_REGISTER.md
  domain trackers / runbooks
  project verification + optional guard adapter

OtherProject/
  .autobuild/project.json
  AGENTS.md
  project knowledge + verification
```

The V2 runner already accepts `-ProjectPath`, so the engine and target repository no longer have to be the same repository. The current Pipe Buyer PR is the staging location until the engine is extracted into its own repository.

## Why the engine should be separate

A central engine gives us:

- one place to improve orchestration, timeouts, state, result schemas, and branch lifecycle;
- consistent safety behavior across multiple projects;
- no repeated copies drifting apart;
- project repos retain their own product truth and design rules;
- engine updates do not require rewriting every app's roadmap;
- the engine can work against Flutter, React, Node, Python, Unity-support tooling, or other repos by changing the project adapter rather than the supervisor.

The engine should operate on a local worktree because coding agents need fast filesystem search, builds, emulators, compilers, and tests. GitHub remains the source/backup/review system; it is not the primary file-edit execution layer.

## Per-project contract

`.autobuild/project.json` defines:

- project identity;
- agent policy path;
- reusable writer branch;
- base branch;
- knowledge hierarchy;
- full verification command;
- source-file size budget;
- change budget;
- source/generated-file classification;
- worker/repair/verification/no-output timeouts;
- human-only safety gates.

This is what allows the same engine to talk to multiple repositories without hard-coding Pipe Buyer knowledge into the engine.

## Knowledge model

Project knowledge is hierarchical rather than one enormous prompt.

### Always-on knowledge

- product vision;
- master roadmap;
- architecture contract;
- quality gates;
- decision register;
- feature registry.

### Domain knowledge loaded when relevant

Examples for Pipe Buyer:

- design system + Phase 1.1 for UI work;
- payments tracker for Stripe/subscription/reconciliation work;
- Phase 2 audit for Marketplace/Wanted/Offers/Auctions/Dispatch work.

This reduces context waste and helps long sessions reconstruct the correct project state from Git rather than relying on one aging model conversation.

## Supervisor model

A four-hour autonomous run is not one four-hour model request.

```text
multi-hour supervisor
       |
       +-- bounded worker
       |     focused tests
       |     autonomous guard
       |     full project verification
       |     verified commit
       |
       +-- bounded worker
       |     ...
       |
       +-- bounded worker
             ...
```

Current Pipe Buyer defaults:

- worker timeout: 35 minutes;
- no-output watchdog: 10 minutes;
- repair timeout: 25 minutes;
- full verification timeout: 45 minutes.

A timed-out worker cannot create a verified commit. Earlier verified commits remain intact.

## Persistent state

The supervisor records operational state under `.agent-run/state.json`, including:

- project/run identity;
- writer branch and base branch;
- current iteration and phase;
- completed task count;
- previous/next task hints;
- last verified commit;
- final stop reason.

Logs, prompts, structured results, verification output, and failure patches remain under `.agent-run/` and are excluded from Git.

State is a recovery aid, not product truth. Product truth remains in Git-tracked knowledge, tests, and implementation.

## Branch model

V1 created timestamp branches for safety calibration. V2 uses a configured reusable branch:

```text
main
  \
   agent/autobuild
      commit A
      commit B
      commit C
      PR / review
```

Commits are checkpoints; branches are not checkpoints.

The supervisor:

- refuses direct `main` work unless a project explicitly allows it;
- creates the configured writer branch if it does not exist;
- reuses it on later runs;
- synchronizes the base branch into the writer branch when necessary and aborts on conflict;
- never autonomously merges the writer branch into `main`;
- pushes only after a verified commit when `-Push` is requested.

Exceptional recovery branches may exist, but branch creation must not be the normal task/session mechanism.

## Source-size and change guards

The Pipe Buyer project currently sets:

- source warning: 450 lines;
- ordinary source ceiling: 600 lines;
- maximum files touched per increment: 12;
- maximum added + deleted lines per increment: 800.

`tool/autonomous_guard.ps1` applies a migration-friendly rule:

- new ordinary source over 600 lines fails;
- existing ordinary source over 600 lines may be reduced;
- an already-oversized source file may not grow;
- configured generated/derived files are exempt;
- excessive change scope fails and must be split;
- machine-readable feature preservation anchors must remain present.

This prevents an old 1,000-line file from making autonomous mode unusable while still forcing gradual improvement.

## Refactoring model

Refactoring is contract preserving.

Before restructuring high-risk code, the worker must locate behavior, callers, routes, server commands, persistence/security contracts, and tests. It should add characterization coverage where needed, extract one coherent responsibility, verify, commit, and only then continue.

Broad refactoring and unrelated feature changes must not be mixed into one autonomous increment.

The goal is not artificially tiny files. Typical focused files may be 150–350 lines, but cohesion matters more than mechanically splitting every widget or helper.

## Feature preservation

Pipe Buyer maintains:

- `docs/FEATURE_REGISTRY.md` for the human/agent compatibility inventory;
- `.autobuild/feature_contract.json` for a small machine-readable set of critical anchors;
- existing project tests and release/function parity controls for deeper compatibility evidence.

A feature missing from the registry is not disposable. Working routes, commands, roles, Functions, flags, security contracts, lifecycle states, and user workflows remain compatibility surface unless an explicit deprecation decision exists.

## Information preservation

The project does not overwrite its own history to simplify context.

- detailed domain trackers remain authoritative for task evidence;
- the master roadmap indexes them rather than copying every checkbox;
- durable decisions are appended to the decision register;
- superseded decisions remain recorded with links to replacements;
- feature registry entries preserve product capability knowledge;
- completion claims require the evidence defined by the applicable tracker.

## Running V2 while this PR is still unmerged

Because the configured long-term branch is `agent/autobuild`, calibration on the V2 implementation branch should explicitly name the current branch:

```powershell
Set-Location -LiteralPath "D:\Pipe App Flutter\pipe-app-1w4gyj"
git fetch origin
git switch agent/autonomous-repo-builder
git pull

.\tool\autonomous_build.ps1 `
  -ProjectPath "D:\Pipe App Flutter\pipe-app-1w4gyj" `
  -Branch agent/autonomous-repo-builder `
  -Hours 1 `
  -MaxTasks 2
```

After V2 is reviewed/merged, normal operation becomes:

```powershell
.\tool\autonomous_build.ps1 `
  -ProjectPath "D:\Pipe App Flutter\pipe-app-1w4gyj" `
  -Hours 3 `
  -MaxTasks 8 `
  -Push
```

The configured writer branch will then be `agent/autobuild`.

## Multi-project invocation after engine extraction

From the future central builder repository:

```powershell
.\tool\autonomous_build.ps1 -ProjectPath "D:\Pipe App Flutter\pipe-app-1w4gyj" -Hours 3 -MaxTasks 8 -Push

.\tool\autonomous_build.ps1 -ProjectPath "D:\Some React App" -Hours 2 -MaxTasks 6 -Push
```

Each target repository supplies its own `.autobuild/project.json`, `AGENTS.md`, knowledge, quality command, and optional feature anchors.

## Human-controlled boundaries

The supervisor may prepare code and evidence tooling but must not autonomously:

- merge to `main`;
- deploy or activate production;
- mutate live payment/provider state;
- move live money;
- change secrets;
- make tax/legal/licensing declarations;
- publish to app stores;
- weaken security or tests to obtain green status.

## Next extraction step

Once the Pipe Buyer calibration run passes, move the reusable engine files into a dedicated Git repository. Keep Pipe Buyer's `.autobuild` configuration, project knowledge, feature registry, decisions, and project-specific verification inside Pipe Buyer.

The central engine should then be versioned independently, with target projects declaring the engine version they have been validated against.
