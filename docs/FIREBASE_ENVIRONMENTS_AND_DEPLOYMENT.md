# Firebase environments and controlled deployment

Date: July 22, 2026

## Approved production project

`flutter-flow-pipe` is the single approved production Firebase project. The
live PipeApp Android, iOS, and Web registrations all belong to project number
`426221783223`. Native production startup verifies both the compiled project
declaration and the initialized Firebase app before App Check is activated.

`pipebuyer-5c77f` is the isolated staging project. It has separate Web,
Android, and iOS Firebase registrations plus a Standard `(default)` Firestore
database in `nam5`. It must never be used as a second production backend. A
single release must never split Auth, Firestore, Storage, Hosting, or Functions
across the two projects.

## Safety boundary

The app defaults to `PIPE_ENV=local`. Local, development, test, verification,
and CI environments initialize the installed project metadata but immediately
redirect Auth, Firestore, Functions, and Storage to the local Firebase
Emulator Suite before repositories are used. A stopped emulator therefore
causes local connection failures instead of production fallback. Staging and
production fail at startup unless a complete Firebase web configuration is
compiled into the release. Partial overrides are rejected so one build cannot
accidentally mix resources from different projects.

Native production builds use the checked-in platform Firebase files belonging
to `flutter-flow-pipe`. Native staging builds use the separate public Android
and iOS registrations for `pipebuyer-5c77f` selected by runtime configuration.
Both environments require the matching project declaration and verify the
initialized project at runtime. Non-production development builds redirect all
configured Firebase products to their platform-appropriate local emulator
host.

## Required Firebase projects

Retain the separate cloud projects already assigned for:

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

GitHub Environments named `staging` and `production` now exist and both contain
their seven verified public Firebase identifiers. A July 29 read-only check
found no required-reviewer rules, allowed administrator bypass, and found no
protection on `main`. Configure approved reviewers, bypass policy, and branch
restrictions before launch. As repository-level compensating controls, the
workflow verifies that every production SHA is contained in `origin/main`,
checks out the exact SHA, runs full verification, and now requires a private
Environment guard matching the selected target.

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

Configure this Environment secret separately in each Environment:

- `PIPE_DEPLOY_ENVIRONMENT_GUARD`, set exactly to `staging` in the staging
  Environment and exactly to `production` in the production Environment.

The guard prevents an automatically created, copied, or incorrectly selected
Environment from proceeding with public Firebase values alone. It does not
replace GitHub required reviewers or branch protection.

The Google service account must have only the roles needed to deploy this
Firebase application. GitHub authenticates with Workload Identity Federation;
do not create or store a long-lived service-account JSON key in the
repository.

Workload Identity values remain deliberately absent in both environments, so
the protected deployment fails closed until keyless cloud authentication is
created and verified. App Check uses the explicit `disabled`, `observe`, or
`enforce` workflow mode documented in `APP_CHECK_ROLLOUT.md`; production rejects
anything except `enforce`, and `observe`/`enforce` require the public web
provider key.

Native Crashlytics collection is also fail-closed. Android and Apple manifests
default it off, and the centralized reporter enables it only for a controlled
staging or production build compiled with
`PIPE_REMOTE_DIAGNOSTICS_ENABLED=true`. See
`docs/PRODUCTION_DIAGNOSTICS_RUNBOOK.md` for device proof, privacy, triage, and
ownership requirements. Web reporting is not yet operational.

The staging Firestore rules and indexes were deployed successfully on July 22,
2026. Staging Storage is not yet provisioned: the Firebase CLI enabled the
Storage API and then stopped because no default bucket exists. Provision the
bucket explicitly in the approved North American location before deploying
Storage rules. A Hosting-only rehearsal is live at
`https://pipebuyer-5c77f.web.app` (version `c5b6e2f11524c0eb`) and a read-only
endpoint check returned HTTP 200. A second version (`9c53baeec68b39a9`) was
released and the retained baseline was restored; Firebase recorded live release
`1784695881916000` as a `ROLLBACK` to `c5b6e2f11524c0eb`. Authentication
is now initialized with Email/Password enabled from the reviewed root config;
a disposable account create/delete smoke test passed. Functions remain
undeployed. The owner reports that billing has since been enabled, but the
current evidence is still the zero-Function read-only inventory; billing and
Cloud Build availability are not considered proven until the controlled
workflow successfully deploys to staging. App Check, keyless CI deployment,
visual acceptance, and data/full-service rollback remain to be configured and
verified.

A second deployment preflight on July 28, 2026—before the owner reported
enabling billing—authenticated as the project owner and again reached the
explicit `pipebuyer-5c77f` target, but Google rejected Cloud Build enablement.
No Function was created. The attempt confirmed 70 expected exports and zero
deployed Functions. A later read-only inventory confirmed that the project and
its Web, Android, and iOS registrations are active, but a controlled deployment
is still required to prove the new billing state and deployed parity.

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
deploys by explicit project ID. The repository-root `firebase.json` serves
`build/web`, so no copied `firebase/public` artifact is involved and Firebase
never has to traverse outside its configured project directory.

After a successful deployment, a separate Windows acceptance job opens the
explicit project's `web.app` URL in an isolated headless browser. It waits
past the Flutter splash, rejects blank or monochrome captures and browser
exceptions, tests 390x844 and 1440x1000 viewports, and retains both screenshots
as 30-day workflow artifacts. A successful HTTP response alone is not treated
as visual acceptance.

Before deployment, the workflow generates `build/release-manifest.json`. It
records the exact commit and environment, explicit Firebase project, expected
Function names, Functions source hash, Firebase config/rules/index hashes, and
the deterministic web artifact hash. Controlled manifests reject uncommitted
tracked source and record the exact App Check rollout state. The manifest is
included in the protected workflow summary as release evidence.

The Firebase CLI deployment message records the selected environment, exact
release SHA, and GitHub workflow run. Whether deployment succeeds or fails, the
workflow retains every available machine-readable release artifact for 30
days: the manifest, full Firebase deploy log, deployed Function inventory, and
Function parity report. This retained artifact is necessary audit evidence; it
does not by itself count as staging acceptance or operational approval.

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

Gate 1 remains open until staging Storage/Auth/Functions/Hosting are configured,
App Check and keyless CI deployment are operational, staging deployment and
rollback are rehearsed, diagnostics have an operational owner, and
backup/restore evidence is recorded.

The backup and recovery procedure is documented in
`docs/FIREBASE_BACKUP_RESTORE_RUNBOOK.md`. It remains unproven until an isolated
restore rehearsal is completed.
