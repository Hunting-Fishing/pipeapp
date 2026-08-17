# Repair - Formal hosting verifier in detached worktree

Date: 2026-08-17

## Symptom

`tool/deploy_formal_hosting_only.ps1` created a clean detached Git worktree and then ran `tool/verify_dispatch_phase3_service_area_map.ps1`. The verifier failed before any product analysis or tests with:

`You cannot call a method on a null-valued expression.`

The failure occurred at the branch check that called `.Trim()` on the output of `git branch --show-current`.

## Root cause

A detached Git worktree intentionally has no current branch name. In that state, `git branch --show-current` produces no branch text. The verifier assumed a named branch was always present and called `.Trim()` directly on an empty PowerShell command result.

The hosting deploy script was correct to use a detached clean worktree because it isolates production release verification from the user's dirty development worktree. The verifier was too strict about the Git checkout shape.

## Permanent repair

The service-area verifier now supports two safe states:

1. A normal worktree must be on `design/formal-beautification-foundation`.
2. A detached worktree is accepted only when `HEAD` exactly equals `origin/design/formal-beautification-foundation`.

The verifier converts command output through `Out-String` before trimming, so an empty branch name cannot trigger a null-method exception.

This preserves the branch safety gate while allowing clean detached release worktrees.

## Proof rule

A detached worktree must print a confirmation that its `HEAD` matches the expected remote branch before the Phase 3 gate proceeds. Any detached SHA mismatch remains a hard failure.

The failed deployment changed no production Hosting state because the deployment script stops before the Flutter build and Firebase Hosting deploy when the verification gate fails.
