# Pipe Buyer Decision Register

Status: active project memory

## Purpose

Use this register for durable product and engineering decisions that autonomous workers must not silently reinterpret. New decisions are appended. Superseded decisions remain recorded and point to the replacement decision.

## Decision format

Each decision records:

- ID;
- date;
- status (`ACTIVE`, `SUPERSEDED`, or `RETIRED`);
- decision;
- rationale/evidence;
- affected contracts or files;
- supersedes / superseded-by when applicable.

## Active decisions

### DEC-0001 — Repository development agent is separate from runtime application agent

Date: 2026-08-23  
Status: ACTIVE

The autonomous repository builder runs from a developer workspace and must not repurpose the Firebase Cloud Function named `agent`.

Reason: the runtime Function is an authenticated, fail-closed administrative endpoint with separate security and production controls.

Affected: `AGENTS.md`, `docs/ADMIN_AGENT_FUNCTION_SPEC.md`, autonomous builder files.

### DEC-0002 — One reusable autonomous writer branch

Date: 2026-08-23  
Status: ACTIVE

Use one long-lived/reusable project writer branch (default `agent/autobuild`) for autonomous development rather than creating a timestamp branch for every run.

Verified commits are checkpoints. Merge to `main` remains human controlled. Exceptional recovery branches require an explicit reason.

Affected: `.autobuild/project.json`, autonomous runner.

### DEC-0003 — 600 lines is a hard ordinary-source ceiling, not a target

Date: 2026-08-23  
Status: ACTIVE

Ordinary hand-written source files should generally remain below 450 lines and must not grow beyond 600 lines. Existing files over 600 lines may be reduced incrementally, but autonomous work must not increase an oversized legacy file.

Generated files, lockfiles, fixtures, and other configured derived artifacts are exempt.

Affected: `docs/QUALITY_GATES.md`, `.autobuild/project.json`, autonomous quality guard.

### DEC-0004 — Refactors are behavior-preserving increments

Date: 2026-08-23  
Status: ACTIVE

Broad refactoring and new product behavior must not be combined in one autonomous increment. Characterize at-risk behavior, extract one coherent responsibility, verify, commit, then perform later intentional behavior changes.

Affected: `docs/ARCHITECTURE.md`, `docs/QUALITY_GATES.md`, agent prompt.

### DEC-0005 — Product knowledge is hierarchical, not one giant prompt

Date: 2026-08-23  
Status: ACTIVE

Keep a short agent constitution plus separate vision, roadmap, architecture, quality, design, decisions, feature registry, and domain trackers. The worker reads core knowledge every iteration and domain knowledge only when relevant.

Affected: `.autobuild/project.json`, `AGENTS.md`, `automation/agent/task_prompt.md`.

### DEC-0006 — Autonomous runs are supervisor sessions composed of bounded workers

Date: 2026-08-23  
Status: ACTIVE

A multi-hour build session consists of multiple bounded worker invocations. Worker, repair, and verification timeouts are explicit project configuration. A timeout stops or recovers the current increment without losing prior verified commits.

Affected: `.autobuild/project.json`, autonomous runner.

### DEC-0007 — Pipe Buyer visual system remains centralized

Date: 2026-08-23  
Status: ACTIVE

Use `lib/core/design/pipe_buyer_theme.dart` and `docs/DESIGN_SYSTEM.md` as the visual contract. Feature pages must not create competing palettes/component systems when an established token or shared component exists.

Affected: Flutter UI code, Phase 1.1 work.

### DEC-0008 — Production and external acceptance remain human gates

Date: 2026-08-23  
Status: ACTIVE

Autonomous code may prepare production-facing changes and evidence tooling but may not merge to `main`, deploy/activate production, move live money, mutate live providers, or make legal/tax declarations.

Affected: all autonomous work.

## Supersession rule

When changing an active decision, append a new decision with a new ID, mark the older decision `SUPERSEDED`, and link both entries. Do not delete the old rationale.
