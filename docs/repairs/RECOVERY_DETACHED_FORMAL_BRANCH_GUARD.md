# Recovery detached formal branch guard

Date: 2026-08-22

## Symptom

A clean recovery worktree at the audited formal checkpoint was intentionally
detached. The common formal branch guard accepted only a named
design/formal-beautification-foundation checkout.

## Root cause

The common guard assumed all valid formal worktrees have a branch name.

Pipe Buyer already had an accepted detached release-worktree rule: a detached
worktree is valid only when HEAD exactly equals
origin/design/formal-beautification-foundation.

## Permanent repair

Assert-PipeBuyerFormalBranch now permits:

1. A named worktree only when its branch is
   design/formal-beautification-foundation.
2. A detached worktree only when HEAD exactly equals
   origin/design/formal-beautification-foundation.

A detached SHA mismatch remains a hard failure.

## Verification checkpoint

2121fdd303cf879eda927e7c98dbf8726cb2e86d

## Related repair

docs/REPAIR_FORMAL_HOSTING_DETACHED_VERIFIER.md

## Future rule

Never disable branch safety to make a detached verifier pass. Detached
verification must prove exact SHA equality with the formal remote.