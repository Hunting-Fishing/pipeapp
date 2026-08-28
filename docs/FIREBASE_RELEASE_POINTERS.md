# Firebase release pointers

PipeApp Firebase releases can be initiated from GitHub without running local PowerShell deployment jobs.

## Release controls

Two branches are reserved as deployment pointers:

- `release/firebase-staging`
- `release/firebase-production`

Moving one of these branches to a specific commit triggers `.github/workflows/firebase-release-pointer.yml`. That lightweight workflow dispatches the existing protected `.github/workflows/deploy.yml` workflow with the exact 40-character commit SHA.

The existing deployment workflow remains the source of truth for environment validation, tests, Flutter build, Firebase CLI deployment, function parity checks, visual acceptance, and deployment evidence.

## Normal release operation

### Staging

Move `release/firebase-staging` to the commit that should be tested in Firebase staging. The pointer workflow dispatches `deploy.yml` with:

- environment: `staging`
- commit_sha: the exact pointer commit
- app_check_mode: `disabled` (preserves the current workflow default; change deliberately when App Check rollout is ready)

### Production

Move `release/firebase-production` only after explicit production-release approval. The pointer workflow dispatches `deploy.yml` with:

- environment: `production`
- commit_sha: the exact pointer commit
- app_check_mode: `disabled` (preserves current behavior; the verified deploy workflow emits its existing production warning)

The existing production deploy workflow also requires the release commit to be contained in `main`, so moving the production pointer to an unmerged feature commit will not publish it.

## Chat/Codex use

A connected development session with GitHub write access can publish by moving the appropriate release-pointer branch to an exact commit. No Firebase credential is exposed to the chat; Firebase credentials stay in the protected GitHub Environment and are consumed only by GitHub Actions.

A request such as `Deploy commit <sha> to Firebase staging` should move only `release/firebase-staging`. A production request must explicitly identify production before `release/firebase-production` is moved.

## Why this replaces local deployment jobs

The developer machine is no longer the deployment authority. Local PowerShell can still be used for optional development utilities, but Firebase publishing is initiated and executed in GitHub Actions. The existing Windows visual-acceptance step also runs on a GitHub-hosted runner, not on a local workstation.

## Credentials

Current deployment authentication remains the repository's existing `FIREBASE_TOKEN` GitHub Environment secret so this change does not disrupt the established deployment path. Do not commit Firebase tokens, service-account JSON, or other private credentials.

A later security improvement can migrate the Firebase CLI authentication from the legacy CI token to Google Workload Identity Federation without changing the release-pointer interface.

## Safety rules

1. Do not move `release/firebase-production` without an explicit production deployment request.
2. Production must deploy an exact commit already contained in `main`.
3. Do not put credentials in release branches, workflow files, logs, or chat messages.
4. Do not bypass `.github/workflows/deploy.yml`; it remains the guarded deploy implementation.
5. A failed deployment does not move or modify application source branches. Fix the failing check in source, merge as appropriate, then move the pointer to the corrected commit.
