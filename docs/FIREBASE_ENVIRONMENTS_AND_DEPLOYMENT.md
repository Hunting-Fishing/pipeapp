# Firebase environments and controlled deployment

Date: July 20, 2026

## Safety boundary

Development may use the existing `flutter-flow-pipe` web configuration when
no build values are supplied. Staging and production fail at startup unless a
complete Firebase web configuration is compiled into the release. Partial
overrides are rejected so one build cannot accidentally mix resources from
different projects.

Native Android and Apple builds still use their platform Firebase files.
Separate native flavors and project files remain required before Gate 1 can be
completed.

## Required Firebase projects

Create and retain separate projects for:

- development
- staging
- production

Never point a staging or production GitHub Environment at
`flutter-flow-pipe` unless that project has been explicitly approved for that
role. Project selection is always passed to the Firebase CLI with `--project`;
the workflow does not depend on a developer's local `.firebaserc`.

## Protected GitHub Environments

Create protected GitHub Environments named `staging` and `production`.
Production must require an authorized reviewer. Configure these Environment
variables in each:

- `PIPE_FIREBASE_API_KEY`
- `PIPE_FIREBASE_AUTH_DOMAIN`
- `PIPE_FIREBASE_PROJECT_ID`
- `PIPE_FIREBASE_STORAGE_BUCKET`
- `PIPE_FIREBASE_MESSAGING_SENDER_ID`
- `PIPE_FIREBASE_WEB_APP_ID`
- `PIPE_FIREBASE_MEASUREMENT_ID` (optional)
- `PIPE_APP_CHECK_WEB_RECAPTCHA_KEY`
- `GOOGLE_WORKLOAD_IDENTITY_PROVIDER`
- `GOOGLE_DEPLOY_SERVICE_ACCOUNT`

The Google service account must have only the roles needed to deploy this
Firebase application. GitHub authenticates with Workload Identity Federation;
do not create or store a long-lived service-account JSON key in the
repository.

## Release procedure

1. Merge a commit only after the `Quality` workflow succeeds.
2. Open the `Deploy verified Firebase release` workflow.
3. Select `staging` and enter the full 40-character verified commit SHA.
4. Complete staging acceptance testing.
5. Run the same workflow for `production` with the accepted SHA.
6. Retain the workflow URL, release summary, Firebase release identifiers, and
   acceptance record in the launch evidence.

The workflow checks out the exact SHA, reruns analysis, tests Functions and
Firestore rules, builds `build/web` with the selected Firebase values, and
deploys by explicit project ID. `firebase/firebase.json` serves
`../build/web`, so no copied `firebase/public` artifact is involved.

Before deployment, the workflow generates `build/release-manifest.json`. It
records the exact commit and environment, explicit Firebase project, expected
Function names, Functions source hash, Firebase config/rules/index hashes, and
the deterministic web artifact hash. The manifest is included in the protected
workflow summary as release evidence.

## Rollback

Before a production deployment, record the currently active Hosting release,
Functions revision/source SHA, Firestore and Storage rules release, and index
state.

If rollback is required:

1. Disable affected high-risk features with their server controls.
2. Roll Hosting back to the recorded previous release in Firebase.
3. Run the deployment workflow against the last accepted source SHA to restore
   Functions, rules, indexes, and Hosting from one reviewed revision.
4. If a data migration was involved, follow its separately reviewed restore
   procedure; never guess or manually rewrite production documents.
5. Verify the mandatory smoke journeys and record the incident correlation ID.

Gate 1 remains open until isolated Firebase projects exist, native flavors are
separated, staging deployment and rollback are rehearsed, diagnostics have an
operational owner, and backup/restore evidence is recorded.

The backup and recovery procedure is documented in
`docs/FIREBASE_BACKUP_RESTORE_RUNBOOK.md`. It remains unproven until an isolated
restore rehearsal is completed.
