# Firebase environments and controlled deployment

Date: July 22, 2026

## Approved production project

`flutter-flow-pipe` is the single approved production Firebase project. The
live PipeApp Android, iOS, and Web registrations all belong to project number
`426221783223`. Native production startup verifies both the compiled project
declaration and the initialized Firebase app before App Check is activated.

`pipebuyer-5c77f` currently contains no registered Firebase applications. It
is intentionally unassigned and must not be used as a second production
backend. A single release must never split Auth, Firestore, Storage, Hosting,
or Functions across the two projects.

## Safety boundary

The app defaults to `PIPE_ENV=local`. Local, development, test, verification,
and CI environments initialize the installed project metadata but immediately
redirect Auth, Firestore, Functions, and Storage to the local Firebase
Emulator Suite before repositories are used. A stopped emulator therefore
causes local connection failures instead of production fallback. Staging and
production fail at startup unless a complete Firebase web configuration is
compiled into the release. Partial overrides are rejected so one build cannot
accidentally mix resources from different projects.

Native Android and Apple builds still use their platform Firebase files. The
checked-in files are the approved `flutter-flow-pipe` production registrations.
A native production build must declare that exact project ID and verifies the
initialized project at runtime. Native staging continues to fail closed until
its separate platform apps and files are installed. Non-production builds
redirect all configured Firebase products to their platform-appropriate local
emulator host.

## Required Firebase projects

Create and retain separate cloud projects for:

- staging
- production

Development is emulator-first and does not require a shared cloud project. If
a shared development backend is introduced later, it must be a third isolated
project and must not reuse either staging or production.

Never point staging at `flutter-flow-pipe`. Production is hard-locked to that
project in the deployment workflow. Project selection is always passed to the
Firebase CLI with `--project`; the workflow does not depend on a developer's
local `.firebaserc`.

## Protected GitHub Environments

Create GitHub Environments named `staging` and `production`. The production
environment exists and has the verified Firebase identifiers below. The
current private repository plan rejected required-reviewer and deployment
branch protection rules. As a compensating control, the workflow verifies that
every production SHA is contained in `origin/main`, in addition to exact-SHA
checkout and full verification. Upgrade the GitHub plan or make the repository
eligible for environment protection before launch, then require an authorized
production reviewer.

Configure these Environment variables in each:

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

Production currently has the seven `PIPE_FIREBASE_*` values configured. App
Check and Workload Identity values remain deliberately absent, so deployment
fails closed until those cloud controls are created and verified.

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
